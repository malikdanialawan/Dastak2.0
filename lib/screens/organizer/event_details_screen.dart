import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart'
    hide Event; // <--- CRUCIAL FIX
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants.dart';
import '../../core/helpers.dart';
import '../../core/models.dart';
import '../../core/supabase_client.dart'; // <--- CRUCIAL FIX
import '../../data/repositories.dart';
import '../../widgets/shared_widgets.dart';
import '../resident/pass_details_screen.dart';
import 'create_event_screen.dart';

class EventDetailsScreen extends StatefulWidget {
  final Event event;
  const EventDetailsScreen({super.key, required this.event});

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  final ScrollController _scrollController = ScrollController();

  late Event _event;
  final List<Pass> _passes = [];
  bool _isLoading = true;
  bool _isImporting = false;

  // Pagination
  bool _hasMore = true;
  DateTime? _cursor;

  // Stats
  int _total = 0;
  int _checkedIn = 0;
  int _pending = 0;

  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _event = widget.event;
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
        .channel('event_scans_${_event.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'scans',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'event_id',
            value: _event.id,
          ),
          callback: (payload) {
            _loadStats(); // Refresh live dashboard on scan
          },
        )
        .subscribe();
  }

  Future<void> _loadStats() async {
    final stats = await eventService.getEventStats(_event.id);
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
          .eq('event_id', _event.id)
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
      var query = supabase.from('passes').select().eq('event_id', _event.id);
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

  Future<void> _openMenu(String value) async {
    if (value == 'edit') {
      final updated = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => CreateEventScreen(event: _event)),
      );
      if (updated == true) {
        // Refresh event details
        final ev =
            await supabase.from('events').select().eq('id', _event.id).single();
        setState(() => _event = Event.fromMap(ev));
        _loadStats();
      }
    } else if (value == 'delete') {
      final yes = await ConfirmDialog.show(
        context,
        title: 'Delete Event?',
        message:
            'All passes and scans for "${_event.name}" will be permanently deleted.',
        confirmLabel: 'Delete',
        isDestructive: true,
      );
      if (!yes) return;
      try {
        await eventService.deleteEvent(_event.id);
        if (mounted) Navigator.pop(context);
      } catch (e) {
        if (mounted) showSnack(context, errorText(e), isError: true);
      }
    }
  }

  Future<void> _reissuePass(Pass pass) async {
    final yes = await ConfirmDialog.show(
      context,
      title: 'Re-issue Pass?',
      message:
          'The old QR code for ${pass.visitorName} will be invalidated immediately.',
      confirmLabel: 'Re-issue',
    );
    if (!yes) return;

    try {
      await eventService.reissuePass(pass.id);
      if (mounted) showSnack(context, 'Pass re-issued successfully!');
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), isError: true);
    }
  }

  // ==========================================================================
  // IMPORT LOGIC
  // ==========================================================================

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
        throw const AppException('CSV file is empty or incorrectly formatted.');

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
          eventId: _event.id,
          createdBy: authService.currentUser!.id,
          status: PassStatus.active,
          multipleEntries: false,
          validFrom: _event.startAt,
          validUntil: _event.endAt,
        ));
      }

      if (newPasses.isEmpty)
        throw const AppException(
            'No valid attendees found. Ensure a "name" column exists.');

      await _processBulkImport(newPasses);
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), isError: true);
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

      final selected = await showModalBottomSheet<List<Contact>>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => _ContactPickerSheet(contacts: contacts),
      );

      if (selected == null || selected.isEmpty) return;

      final newPasses = selected.map((c) {
        return Pass(
          id: '',
          qrToken: '',
          visitorName: c.displayName ?? 'Unknown',
          visitorPhone: c.phones.isNotEmpty ? c.phones.first.number : null,
          visitorType: 'Guest',
          kind: PassKind.event,
          eventId: _event.id,
          createdBy: authService.currentUser!.id,
          status: PassStatus.active,
          multipleEntries: false,
          validFrom: _event.startAt,
          validUntil: _event.endAt,
        );
      }).toList();

      await _processBulkImport(newPasses);
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), isError: true);
    }
  }

  Future<void> _processBulkImport(List<Pass> newPasses) async {
    setState(() => _isImporting = true);
    try {
      await passService.createManyForEvent(newPasses);
      if (mounted) {
        showSnack(
            context, 'Successfully imported ${newPasses.length} attendees!');
        _loadStats();
        _loadPasses();
      }
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), isError: true);
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  Future<void> _openPassDetails(Pass pass) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PassDetailsScreen(
          passId: pass.id,
          eventName: _event.name,
          canRevoke: true,
        ),
      ),
    );
    _loadStats(); // Status might have changed
    _loadPasses();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_event.name),
        backgroundColor: AppColors.background,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            onSelected: _openMenu,
            icon: const Icon(Icons.more_vert_rounded),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit Event')),
              PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete Event',
                      style: TextStyle(color: AppColors.danger))),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async {
              await _loadStats();
              await _loadPasses();
            },
            color: AppColors.primary,
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                // 1. Stats Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Container(
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
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatCol(
                              'Total', _total.toString(), Colors.white),
                          Container(
                              width: 1, height: 40, color: Colors.white24),
                          _buildStatCol('Checked In', _checkedIn.toString(),
                              AppColors.successLight),
                          Container(
                              width: 1, height: 40, color: Colors.white24),
                          _buildStatCol('Pending', _pending.toString(),
                              AppColors.warningLight),
                        ],
                      ),
                    ),
                  ),
                ),

                // 2. Section Header
                SliverToBoxAdapter(
                  child: Padding(
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
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                // 3. Attendee List
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  sliver: _passes.isEmpty && !_isLoading
                      ? SliverToBoxAdapter(child: _buildEmptyState())
                      : SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
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
                                onTap: () => _openPassDetails(pass),
                                onReissue: () => _reissuePass(pass),
                              );
                            },
                            childCount: _passes.length + (_hasMore ? 1 : 0),
                          ),
                        ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          ),

          // Import Overlay
          if (_isImporting)
            Container(
              color: Colors.black54,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: AppColors.primary),
                      const SizedBox(height: 16),
                      Text('Importing attendees...',
                          style: AppTextStyles.bodyMedium),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showImportOptions,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label:
            const Text('Import', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildStatCol(String label, String value, Color color) {
    return Column(
      children: [
        Text(value,
            style: AppTextStyles.h1.copyWith(color: color, fontSize: 28)),
        const SizedBox(height: 4),
        Text(label,
            style: AppTextStyles.label.copyWith(color: color.withOpacity(0.8))),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Column(
        children: [
          Icon(Icons.people_outline_rounded,
              size: 64, color: AppColors.surfaceMuted),
          const SizedBox(height: 16),
          Text('No attendees yet', style: AppTextStyles.h3),
          const SizedBox(height: 8),
          Text(
            'Tap the button below to import your guest list.',
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
// ATTENDEE CARD
// ============================================================================

class _AttendeeCard extends StatelessWidget {
  final Pass pass;
  final VoidCallback onTap;
  final VoidCallback onReissue;

  const _AttendeeCard(
      {required this.pass, required this.onTap, required this.onReissue});

  @override
  Widget build(BuildContext context) {
    final isUsed = pass.effectiveStatus == PassStatus.used;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isUsed ? AppColors.successLight : AppColors.surfaceMuted,
            width: 2,
          ),
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
                    color: isUsed ? AppColors.success : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pass.visitorName,
                    style: AppTextStyles.bodyLarge
                        .copyWith(fontWeight: FontWeight.bold),
                  ),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.success,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Checked In',
                  style: AppTextStyles.label
                      .copyWith(color: Colors.white, fontSize: 10),
                ),
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
      height: MediaQuery.of(context).size.height * 0.85,
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
