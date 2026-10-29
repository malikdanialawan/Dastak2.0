import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app.dart';
import '../../core/constants.dart';
import '../../core/helpers.dart';
import '../../core/models.dart';
import '../../data/repositories.dart';
import '../../widgets/pass_ticket.dart';

class ResidentHomeScreen extends StatefulWidget {
  const ResidentHomeScreen({super.key});

  @override
  State<ResidentHomeScreen> createState() => _ResidentHomeScreenState();
}

class _ResidentHomeScreenState extends State<ResidentHomeScreen> {
  final ScrollController _scrollController = ScrollController();
  final List<Pass> _passes = [];

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
        _loadMorePasses();
      }
    }
  }

  Future<void> _loadData() async {
    try {
      _profile = await authService.loadProfile();
      await _refreshPasses();
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), isError: true);
    }
  }

  Future<void> _refreshPasses() async {
    setState(() {
      _isLoading = true;
      _cursor = null;
    });
    try {
      final result = await passService.listMyPasses();
      if (mounted) {
        setState(() {
          _passes.clear();
          _passes.addAll(result.items);
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

  Future<void> _loadMorePasses() async {
    setState(() => _isLoading = true);
    try {
      final result = await passService.listMyPasses(cursor: _cursor);
      if (mounted) {
        setState(() {
          _passes.addAll(result.items);
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

  Future<void> _showCreatePassSheet() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CreatePassSheet(),
    );
    if (created == true) _refreshPasses();
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
          onRefresh: _refreshPasses,
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
                                'Welcome Back',
                                style: AppTextStyles.bodyMedium
                                    .copyWith(color: AppColors.textSecondary),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _profile?.fullName?.split(' ').first ??
                                    'Resident',
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
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.qr_code_2_rounded,
                                  color: Colors.white, size: 32),
                            ),
                            const SizedBox(width: 20),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_passes.where((p) => p.effectiveStatus == PassStatus.active).length} Active Passes',
                                  style: AppTextStyles.h2
                                      .copyWith(color: Colors.white),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Ready to scan at the gate',
                                  style: AppTextStyles.bodySmall
                                      .copyWith(color: Colors.white70),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      Text('Recent Passes', style: AppTextStyles.h3),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),

              // 2. Pass List
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
                            return GestureDetector(
                              onTap: () => _showPassDetails(pass),
                              child: PassTicket(pass: pass, isCompact: true),
                            );
                          },
                          childCount: _passes.length + (_hasMore ? 1 : 0),
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
        onPressed: _showCreatePassSheet,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Pass',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Column(
        children: [
          Icon(Icons.confirmation_number_outlined,
              size: 64, color: AppColors.surfaceMuted),
          const SizedBox(height: 16),
          Text('No passes yet', style: AppTextStyles.h3),
          const SizedBox(height: 8),
          Text(
            'Create a pass for your guests or domestic staff.',
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showPassDetails(Pass pass) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PassDetailSheet(pass: pass),
    ).then((_) => _refreshPasses());
  }
}

// ============================================================================
// CREATE PASS SHEET (Handles both Standard and Recurring)
// ============================================================================

class _CreatePassSheet extends StatefulWidget {
  const _CreatePassSheet();

  @override
  State<_CreatePassSheet> createState() => _CreatePassSheetState();
}

class _CreatePassSheetState extends State<_CreatePassSheet> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isRecurring = false;

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _vehicleController = TextEditingController();
  final _companyController = TextEditingController();

  String _visitorType = kTypeGuest;
  final Set<int> _selectedDays = {1, 2, 3, 4, 5}; // Default weekdays
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 18, minute: 0);

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _vehicleController.dispose();
    _companyController.dispose();
    super.dispose();
  }

  String _formatTime(TimeOfDay t) {
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isRecurring && _selectedDays.isEmpty) {
      showSnack(context, 'Select at least one day for recurring passes.',
          isError: true);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      final user = authService.currentUser;
      final profile = await authService.loadProfile();
      if (user == null || profile == null)
        throw const AppException('Session expired.');

      final newPass = Pass(
        id: '',
        qrToken: '', // Generated by DB
        visitorName: _nameController.text.trim(),
        visitorPhone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        visitorType: _visitorType,
        company: _companyController.text.trim().isEmpty
            ? null
            : _companyController.text.trim(),
        vehicle: _vehicleController.text.trim().isEmpty
            ? null
            : _vehicleController.text.trim(),
        apartment: profile.societyId ?? 'N/A',
        createdBy: user.id,
        societyId: profile.societyId,
        kind: PassKind.visitor,
        status: PassStatus.active,
        multipleEntries: _isRecurring,
        recurrenceDays: _isRecurring ? _selectedDays.toList() : [],
        windowStart: _isRecurring ? _formatTime(_startTime) : null,
        windowEnd: _isRecurring ? _formatTime(_endTime) : null,
        validFrom: DateTime.now(),
        validUntil: _isRecurring
            ? DateTime.now().add(const Duration(days: 90))
            : DateTime.now().add(const Duration(hours: 12)),
      );

      await passService.createPass(newPass);

      if (mounted) {
        Navigator.pop(context, true);
        showSnack(context, 'Pass created successfully!');
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
    final maxHeight = MediaQuery.of(context).size.height * 0.9;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            height: 4,
            width: 40,
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Create Visitor Pass', style: AppTextStyles.h2),
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
                          label: 'Visitor Name',
                          icon: Icons.person_outline_rounded),
                      textCapitalization: TextCapitalization.words,
                      validator: (v) => validateRequired(v, 'Visitor name'),
                    ),
                    const SizedBox(height: 16),

                    DropdownButtonFormField<String>(
                      value: _visitorType,
                      decoration: fieldDecoration(
                          label: 'Visitor Type', icon: Icons.category_outlined),
                      items: kVisitorTypes
                          .map(
                              (t) => DropdownMenuItem(value: t, child: Text(t)))
                          .toList(),
                      onChanged: (val) => setState(() => _visitorType = val!),
                    ),
                    const SizedBox(height: 16),

                    if (kCompaniesFor(_visitorType).isNotEmpty) ...[
                      DropdownButtonFormField<String>(
                        value: _companyController.text.isNotEmpty
                            ? _companyController.text
                            : null,
                        decoration: fieldDecoration(
                            label: 'Company', icon: Icons.business_rounded),
                        items: kCompaniesFor(_visitorType)
                            .map((c) =>
                                DropdownMenuItem(value: c, child: Text(c)))
                            .toList(),
                        onChanged: (val) =>
                            setState(() => _companyController.text = val ?? ''),
                      ),
                      const SizedBox(height: 16),
                    ],

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _phoneController,
                            decoration: fieldDecoration(
                                label: 'Phone (Optional)',
                                icon: Icons.phone_outlined),
                            keyboardType: TextInputType.phone,
                            validator: validatePhoneOptional,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _vehicleController,
                            decoration: fieldDecoration(
                                label: 'Vehicle (Optional)',
                                icon: Icons.directions_car_outlined),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Recurring Toggle
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.surfaceMuted),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.repeat_rounded,
                                      color: AppColors.primary),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Recurring Pass',
                                          style: AppTextStyles.bodyLarge
                                              .copyWith(
                                                  fontWeight: FontWeight.bold)),
                                      Text('For maids, drivers, or tutors',
                                          style: AppTextStyles.bodySmall),
                                    ],
                                  ),
                                ],
                              ),
                              Switch(
                                value: _isRecurring,
                                activeColor: AppColors.primary,
                                onChanged: (val) =>
                                    setState(() => _isRecurring = val),
                              ),
                            ],
                          ),
                          if (_isRecurring) ...[
                            const Divider(height: 32),
                            Text('Select Days',
                                style: AppTextStyles.label,
                                textAlign: TextAlign.left),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: kRecurrenceDays.entries.map((e) {
                                final isSelected =
                                    _selectedDays.contains(e.key);
                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      if (isSelected) {
                                        _selectedDays.remove(e.key);
                                      } else {
                                        _selectedDays.add(e.key);
                                      }
                                    });
                                  },
                                  child: Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppColors.primary
                                          : AppColors.background,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: isSelected
                                              ? AppColors.primary
                                              : AppColors.surfaceMuted),
                                    ),
                                    child: Center(
                                      child: Text(
                                        e.value[0], // M, T, W...
                                        style:
                                            AppTextStyles.bodyMedium.copyWith(
                                          color: isSelected
                                              ? Colors.white
                                              : AppColors.textSecondary,
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () async {
                                      final t = await showTimePicker(
                                          context: context,
                                          initialTime: _startTime);
                                      if (t != null)
                                        setState(() => _startTime = t);
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                          color: AppColors.background,
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text('Start Time',
                                              style: AppTextStyles.label),
                                          const SizedBox(height: 4),
                                          Text(_startTime.format(context),
                                              style: AppTextStyles.bodyLarge),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: InkWell(
                                    onTap: () async {
                                      final t = await showTimePicker(
                                          context: context,
                                          initialTime: _endTime);
                                      if (t != null)
                                        setState(() => _endTime = t);
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                          color: AppColors.background,
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text('End Time',
                                              style: AppTextStyles.label),
                                          const SizedBox(height: 4),
                                          Text(_endTime.format(context),
                                              style: AppTextStyles.bodyLarge),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
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
                            : const Text('Generate Pass'),
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

// ============================================================================
// PASS DETAIL SHEET
// ============================================================================

class _PassDetailSheet extends StatelessWidget {
  final Pass pass;
  const _PassDetailSheet({required this.pass});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 4,
            width: 40,
            decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 24),

          // Full Ticket
          PassTicket(pass: pass),

          const SizedBox(height: 24),

          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      try {
                        await shareService.sharePass(pass);
                      } catch (e) {
                        if (context.mounted)
                          showSnack(context, errorText(e), isError: true);
                      }
                    },
                    icon: const Icon(Icons.share_rounded),
                    label: const Text('Share'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      // Re-use the share logic but target WhatsApp directly
                      final success = await shareService.openWhatsApp(pass);
                      if (context.mounted) {
                        if (success) {
                          showSnack(context, 'Opened WhatsApp');
                        } else {
                          showSnack(context, 'Could not open WhatsApp',
                              isError: true);
                        }
                      }
                    },
                    icon: const Icon(Icons.chat_rounded),
                    label: const Text('WhatsApp'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (pass.effectiveStatus == PassStatus.active)
            TextButton.icon(
              onPressed: () async {
                try {
                  await passService.revokePass(pass.id);
                  if (context.mounted) {
                    Navigator.pop(context);
                    showSnack(context, 'Pass revoked successfully.');
                  }
                } catch (e) {
                  if (context.mounted)
                    showSnack(context, errorText(e), isError: true);
                }
              },
              icon: const Icon(Icons.block, color: AppColors.danger),
              label: const Text('Revoke Pass',
                  style: TextStyle(color: AppColors.danger)),
            ),
        ],
      ),
    );
  }
}
