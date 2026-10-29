import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart'
    hide Event; // <--- CRUCIAL FIX
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app.dart';
import '../../core/constants.dart';
import '../../core/helpers.dart';
import '../../core/models.dart';
import '../../core/supabase_client.dart'; // <--- CRUCIAL FIX
import '../../data/repositories.dart';

class OrganizerHomeScreen extends StatefulWidget {
  const OrganizerHomeScreen({super.key});

  @override
  State<OrganizerHomeScreen> createState() => _OrganizerHomeScreenState();
}

class _OrganizerHomeScreenState extends State<OrganizerHomeScreen> {
  final ScrollController _scrollController = ScrollController();
  final List<Event> _events = [];

  bool _isLoading = true;
  bool _hasMore = true;
  DateTime? _cursor;
  Profile? _profile;

  @override
  void initState() {
    super.initState();
    _loadData();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoading && _hasMore) {
        _loadMoreEvents();
      }
    }
  }

  Future<void> _loadData() async {
    try {
      _profile = await authService.loadProfile();
      await _refreshEvents();
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), isError: true);
    }
  }

  Future<void> _refreshEvents() async {
    setState(() {
      _isLoading = true;
      _cursor = null;
    });
    try {
      final result = await eventService.listMyEvents();
      if (mounted) {
        setState(() {
          _events.clear();
          _events.addAll(result.items);
          _hasMore = result.hasMore;
          _cursor = result.lastCursor;
        });
      }
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMoreEvents() async {
    setState(() => _isLoading = true);
    try {
      final result = await eventService.listMyEvents(cursor: _cursor);
      if (mounted) {
        setState(() {
          _events.addAll(result.items);
          _hasMore = result.hasMore;
          _cursor = result.lastCursor;
        });
      }
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showCreateEventSheet() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CreateEventSheet(),
    );
    if (created == true) _refreshEvents();
  }

  Future<void> _openSettings() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(24),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.palette_outlined),
                title: const Text('Theme Mode'),
                trailing: IconButton(
                  icon: const Icon(Icons.nightlight_round),
                  onPressed: () async {
                    final newMode = themeNotifier.value == ThemeMode.light
                        ? ThemeMode.dark
                        : ThemeMode.light;
                    await saveTheme(newMode);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: AppColors.danger),
                title: const Text('Sign Out',
                    style: TextStyle(color: AppColors.danger)),
                onTap: () async {
                  await authService.signOut();
                  if (ctx.mounted) {
                    Navigator.pushNamedAndRemoveUntil(
                        ctx, '/auth', (route) => false);
                  }
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshEvents,
          color: AppColors.primary,
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              // 1. Header & Summary
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Organizer Dashboard',
                                style: AppTextStyles.bodyMedium
                                    .copyWith(color: AppColors.textSecondary),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _profile?.fullName?.split(' ').first ??
                                    'Organizer',
                                style: AppTextStyles.h1,
                              ),
                            ],
                          ),
                          GestureDetector(
                            onTap: _openSettings,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.settings_rounded,
                                  color: AppColors.textPrimary),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Premium Summary Card
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: AppColors.darkGradient,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.event_available_rounded,
                                  color: Colors.white, size: 32),
                            ),
                            const SizedBox(width: 20),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_events.length} Events Managed',
                                  style: AppTextStyles.h2
                                      .copyWith(color: Colors.white),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Tap an event to view live dashboard',
                                  style: AppTextStyles.bodySmall
                                      .copyWith(color: Colors.white70),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      Text('My Events', style: AppTextStyles.h3),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),

              // 2. Events List
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: _events.isEmpty && !_isLoading
                    ? SliverToBoxAdapter(child: _buildEmptyState())
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            if (index == _events.length) {
                              return const Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Center(
                                    child: CircularProgressIndicator(
                                        color: AppColors.primary)),
                              );
                            }
                            final event = _events[index];
                            return _EventCard(
                              event: event,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        _EventDashboardScreen(event: event),
                                  ),
                                ).then((_) => _refreshEvents());
                              },
                            );
                          },
                          childCount: _events.length + (_hasMore ? 1 : 0),
                        ),
                      ),
              ),

              // 3. Bottom Padding
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateEventSheet,
        backgroundColor: AppColors.secondary,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Event',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Column(
        children: [
          Icon(Icons.event_busy_rounded,
              size: 64, color: AppColors.surfaceMuted),
          const SizedBox(height: 16),
          Text('No events created yet', style: AppTextStyles.h3),
          const SizedBox(height: 8),
          Text(
            'Tap the button below to set up your first event and start issuing passes.',
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// EVENT CARD WIDGET
// ============================================================================

class _EventCard extends StatelessWidget {
  final Event event;
  final VoidCallback onTap;

  const _EventCard({required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isPast = event.isPast;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isPast
                        ? AppColors.surfaceMuted
                        : AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    event.eventType.toUpperCase(),
                    style: AppTextStyles.label.copyWith(
                      color:
                          isPast ? AppColors.textSecondary : AppColors.primary,
                      fontSize: 10,
                    ),
                  ),
                ),
                Text(
                  formatDate(event.startAt),
                  style: AppTextStyles.bodySmall
                      .copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              event.name,
              style: AppTextStyles.h3,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on_rounded,
                    size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    event.venueName ?? 'Venue TBD',
                    style: AppTextStyles.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildStatCol('Guard Code', event.guardCode),
                const SizedBox(width: 24),
                _buildStatCol('Time', formatTime(event.startAt)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCol(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.label.copyWith(fontSize: 10)),
        const SizedBox(height: 2),
        Text(value,
            style:
                AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }
}

// ============================================================================
// EVENT DASHBOARD SCREEN (Live Stats & Import)
// ============================================================================

class _EventDashboardScreen extends StatefulWidget {
  final Event event;
  const _EventDashboardScreen({required this.event});

  @override
  State<_EventDashboardScreen> createState() => _EventDashboardScreenState();
}

class _EventDashboardScreenState extends State<_EventDashboardScreen> {
  final ScrollController _scrollController = ScrollController();
  final List<Pass> _passes = [];

  bool _isLoading = true;
  bool _hasMore = true;
  DateTime? _cursor;
  int _total = 0;
  int _checkedIn = 0;
  int _pending = 0;

  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _loadStats();
    _loadPasses();
    _setupRealtime();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoading && _hasMore) {
        _loadMorePasses();
      }
    }
  }

  void _setupRealtime() {
    _realtimeChannel = Supabase.instance.client
        .channel('event_scans_${widget.event.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'scans',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'event_id',
            value: widget.event.id,
          ),
          callback: (payload) {
            _loadStats();
          },
        )
        .subscribe();
  }

  Future<void> _loadStats() async {
    final stats = await eventService.getEventStats(widget.event.id);
    if (mounted) {
      setState(() {
        _total = stats['total'] ?? 0;
        _checkedIn = stats['checked_in'] ?? 0;
        _pending = stats['pending'] ?? 0;
      });
    }
  }

  Future<void> _loadPasses() async {
    setState(() {
      _isLoading = true;
      _cursor = null;
    });
    try {
      final result = await supabase
          .from('passes')
          .select()
          .eq('event_id', widget.event.id)
          .order('created_at', ascending: false)
          .limit(30);

      if (mounted) {
        setState(() {
          _passes.clear();
          _passes.addAll(result.map((r) => Pass.fromMap(r)));
          _hasMore = result.length == 30;
          if (result.isNotEmpty)
            _cursor = DateTime.parse(result.last['created_at']);
        });
      }
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMorePasses() async {
    setState(() => _isLoading = true);
    try {
      var query =
          supabase.from('passes').select().eq('event_id', widget.event.id);

      if (_cursor != null) {
        query = query.lt('created_at', _cursor!.toUtc().toIso8601String());
      }

      final result =
          await query.order('created_at', ascending: false).limit(30);

      if (mounted) {
        setState(() {
          _passes.addAll(result.map((r) => Pass.fromMap(r)));
          _hasMore = result.length == 30;
          if (result.isNotEmpty)
            _cursor = DateTime.parse(result.last['created_at']);
        });
      }
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showImportOptions() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Import Attendees', style: AppTextStyles.h3),
            const SizedBox(height: 24),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: AppColors.infoLight,
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.file_upload_outlined,
                    color: AppColors.info),
              ),
              title: const Text('Import from CSV'),
              subtitle: const Text('Upload a file with Name, Phone, Email'),
              onTap: () {
                Navigator.pop(ctx);
                _importCsv();
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: AppColors.successLight,
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.contacts_rounded,
                    color: AppColors.success),
              ),
              title: const Text('Import from Phonebook'),
              subtitle: const Text('Select multiple contacts from your device'),
              onTap: () {
                Navigator.pop(ctx);
                _importContacts();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _importCsv() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final bytes = result.files.first.bytes;
      if (bytes == null) throw const AppException('Could not read file data.');

      final content = String.fromCharCodes(bytes);
      final rows = parseCsv(content);

      if (rows.isEmpty)
        throw const AppException('CSV file is empty or formatted incorrectly.');

      final newPasses = <Pass>[];
      for (final row in rows) {
        final name = row['name'] ?? row['visitor_name'];
        if (name == null || name.trim().isEmpty) continue;

        newPasses.add(Pass(
          id: '',
          qrToken: '',
          visitorName: name.trim(),
          visitorPhone: row['phone']?.trim(),
          visitorEmail: row['email']?.trim(),
          visitorType: row['type']?.trim() ?? 'Guest',
          kind: PassKind.event,
          eventId: widget.event.id,
          createdBy: authService.currentUser!.id,
          status: PassStatus.active,
          multipleEntries: false,
          validFrom: widget.event.startAt,
          validUntil: widget.event.endAt,
        ));
      }

      if (newPasses.isEmpty)
        throw const AppException(
            'No valid attendees found in CSV. Ensure "name" column exists.');

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (c) => const Center(
              child: CircularProgressIndicator(color: AppColors.primary)),
        );
      }

      await passService.createManyForEvent(newPasses);

      if (mounted) {
        Navigator.pop(context); // Pop loader
        showSnack(
            context, 'Successfully imported ${newPasses.length} attendees!');
        _loadStats();
        _loadPasses();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Pop loader if open
        showSnack(context, errorText(e), isError: true);
      }
    }
  }

  Future<void> _importContacts() async {
    try {
      final hasPermission =
          await FlutterContacts.requestPermission(readonly: true);
      if (!hasPermission)
        throw const AppException('Contacts permission denied.');

      final contacts = await FlutterContacts.getContacts(withProperties: true);
      if (contacts.isEmpty)
        throw const AppException('No contacts found on device.');

      if (!mounted) return;

      // Multi-select UI
      final selected = await showModalBottomSheet<List<Contact>>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => _ContactPickerSheet(contacts: contacts),
      );

      if (selected == null || selected.isEmpty) return;

      final newPasses = selected.map((c) {
        final name = c.displayName ?? 'Unknown';
        final phone = c.phones.isNotEmpty ? c.phones.first.number : null;
        return Pass(
          id: '',
          qrToken: '',
          visitorName: name,
          visitorPhone: phone,
          visitorType: 'Guest',
          kind: PassKind.event,
          eventId: widget.event.id,
          createdBy: authService.currentUser!.id,
          status: PassStatus.active,
          multipleEntries: false,
          validFrom: widget.event.startAt,
          validUntil: widget.event.endAt,
        );
      }).toList();

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (c) => const Center(
              child: CircularProgressIndicator(color: AppColors.primary)),
        );
      }

      await passService.createManyForEvent(newPasses);

      if (mounted) {
        Navigator.pop(context); // Pop loader
        showSnack(
            context, 'Successfully imported ${newPasses.length} attendees!');
        _loadStats();
        _loadPasses();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Pop loader if open
        showSnack(context, errorText(e), isError: true);
      }
    }
  }

  Future<void> _reissuePass(Pass pass) async {
    try {
      await eventService.reissuePass(pass.id);
      if (mounted) {
        showSnack(context, 'Pass re-issued! Old QR code is now invalid.');
      }
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.event.name),
        backgroundColor: AppColors.background,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _showImportOptions,
            icon: const Icon(Icons.person_add_alt_1_rounded,
                color: AppColors.primary),
            tooltip: 'Import Attendees',
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Live Stats Header
          Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: AppColors.premiumGradient,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatCol('Total', _total.toString(), Colors.white),
                Container(width: 1, height: 40, color: Colors.white24),
                _buildStatCol(
                    'Checked In', _checkedIn.toString(), Colors.white),
                Container(width: 1, height: 40, color: Colors.white24),
                _buildStatCol('Pending', _pending.toString(), Colors.white),
              ],
            ),
          ),

          // 2. Attendee List Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Attendees', style: AppTextStyles.h3),
                Text('${_passes.length} loaded',
                    style: AppTextStyles.bodySmall),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 3. List
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await _loadStats();
                await _loadPasses();
              },
              color: AppColors.primary,
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: _passes.length + (_hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _passes.length) {
                    return const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(
                          child: CircularProgressIndicator(
                              color: AppColors.primary)),
                    );
                  }
                  final pass = _passes[index];
                  return _AttendeeCard(
                    pass: pass,
                    onReissue: () => _reissuePass(pass),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCol(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: AppTextStyles.h1.copyWith(color: color, fontSize: 28),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTextStyles.label.copyWith(color: color.withOpacity(0.8)),
        ),
      ],
    );
  }
}

// ============================================================================
// ATTENDEE CARD (With Re-issue)
// ============================================================================

class _AttendeeCard extends StatelessWidget {
  final Pass pass;
  final VoidCallback onReissue;

  const _AttendeeCard({required this.pass, required this.onReissue});

  @override
  Widget build(BuildContext context) {
    final isUsed = pass.effectiveStatus == PassStatus.used;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isUsed ? AppColors.successLight : AppColors.surfaceMuted,
            width: 2),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isUsed ? AppColors.successLight : AppColors.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                initials(pass.visitorName),
                style: AppTextStyles.h3.copyWith(
                    color:
                        isUsed ? AppColors.success : AppColors.textSecondary),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pass.visitorName,
                    style: AppTextStyles.bodyLarge
                        .copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  pass.visitorPhone != null
                      ? prettyPhone(pass.visitorPhone)
                      : 'No phone',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
          if (isUsed)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: AppColors.success,
                  borderRadius: BorderRadius.circular(8)),
              child: Text('Checked In',
                  style: AppTextStyles.label
                      .copyWith(color: Colors.white, fontSize: 10)),
            )
          else
            IconButton(
              onPressed: onReissue,
              icon: const Icon(Icons.refresh_rounded,
                  color: AppColors.textSecondary),
              tooltip: 'Re-issue Pass',
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// CONTACT PICKER SHEET
// ============================================================================

class _ContactPickerSheet extends StatefulWidget {
  final List<Contact> contacts;
  const _ContactPickerSheet({required this.contacts});

  @override
  State<_ContactPickerSheet> createState() => _ContactPickerSheetState();
}

class _ContactPickerSheetState extends State<_ContactPickerSheet> {
  final Set<Contact> _selected = {};

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            height: 4,
            width: 40,
            decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Select Contacts', style: AppTextStyles.h2),
                Text('${_selected.length} selected',
                    style: AppTextStyles.bodyMedium),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: widget.contacts.length,
              itemBuilder: (context, index) {
                final contact = widget.contacts[index];
                final isSelected = _selected.contains(contact);
                return ListTile(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selected.remove(contact);
                      } else {
                        _selected.add(contact);
                      }
                    });
                  },
                  leading: CircleAvatar(
                    backgroundColor:
                        isSelected ? AppColors.primary : AppColors.surfaceMuted,
                    child: Text(
                      contact.displayName?.isNotEmpty == true
                          ? contact.displayName![0]
                          : '?',
                      style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : AppColors.textSecondary),
                    ),
                  ),
                  title: Text(contact.displayName ?? 'Unknown'),
                  subtitle: Text(
                    contact.phones.isNotEmpty
                        ? contact.phones.first.number
                        : 'No phone',
                    style: AppTextStyles.bodySmall,
                  ),
                  trailing: Checkbox(
                    value: isSelected,
                    activeColor: AppColors.primary,
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selected.add(contact);
                        } else {
                          _selected.remove(contact);
                        }
                      });
                    },
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _selected.isEmpty
                    ? null
                    : () => Navigator.pop(context, _selected.toList()),
                child: const Text('Import Selected'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// CREATE EVENT SHEET
// ============================================================================

class _CreateEventSheet extends StatefulWidget {
  const _CreateEventSheet();

  @override
  State<_CreateEventSheet> createState() => _CreateEventSheetState();
}

class _CreateEventSheetState extends State<_CreateEventSheet> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  final _nameController = TextEditingController();
  final _venueController = TextEditingController();
  final _addressController = TextEditingController();

  String _eventType = kEventTypes.first;
  DateTime _startAt = DateTime.now().add(const Duration(days: 1));
  DateTime _endAt = DateTime.now().add(const Duration(days: 1, hours: 4));

  @override
  void dispose() {
    _nameController.dispose();
    _venueController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      final guardCode =
          'EVC-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';

      final newEvent = Event(
        id: '',
        organizerId: authService.currentUser!.id,
        name: _nameController.text.trim(),
        eventType: _eventType,
        guardCode: guardCode,
        gates: ['Main Entrance', 'VIP Entrance'],
        startAt: _startAt,
        endAt: _endAt,
        venueName: _venueController.text.trim(),
        address: _addressController.text.trim(),
      );

      await eventService.createEvent(newEvent);

      if (mounted) {
        Navigator.pop(context, true);
        showSnack(context, 'Event created successfully!');
      }
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            height: 4,
            width: 40,
            decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Create New Event', style: AppTextStyles.h2),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded,
                      color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(24, 24, 24, bottomInset + 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: fieldDecoration(
                          label: 'Event Name', icon: Icons.event_rounded),
                      textCapitalization: TextCapitalization.words,
                      validator: (v) => validateRequired(v, 'Event name'),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _eventType,
                      decoration: fieldDecoration(
                          label: 'Event Type', icon: Icons.category_outlined),
                      items: kEventTypes
                          .map(
                              (t) => DropdownMenuItem(value: t, child: Text(t)))
                          .toList(),
                      onChanged: (val) => setState(() => _eventType = val!),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _venueController,
                      decoration: fieldDecoration(
                          label: 'Venue Name (Optional)',
                          icon: Icons.business_rounded),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _addressController,
                      decoration: fieldDecoration(
                          label: 'Address (Optional)',
                          icon: Icons.location_on_outlined),
                    ),
                    const SizedBox(height: 24),
                    Text('Event Schedule', style: AppTextStyles.label),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final d = await pickDateTime(context,
                                  initial: _startAt);
                              if (d != null) setState(() => _startAt = d);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(16)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Starts',
                                      style: AppTextStyles.bodySmall),
                                  const SizedBox(height: 4),
                                  Text(formatDateTime(_startAt),
                                      style: AppTextStyles.bodyMedium.copyWith(
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final d =
                                  await pickDateTime(context, initial: _endAt);
                              if (d != null) setState(() => _endAt = d);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(16)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Ends', style: AppTextStyles.bodySmall),
                                  const SizedBox(height: 4),
                                  Text(formatDateTime(_endAt),
                                      style: AppTextStyles.bodyMedium.copyWith(
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submit,
                        child: _isLoading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : const Text('Create Event'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
