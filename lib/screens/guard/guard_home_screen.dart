import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app.dart';
import '../../core/constants.dart';
import '../../core/helpers.dart';
import '../../core/models.dart';
import '../../data/repositories.dart';
import 'scanner_screen.dart';

class GuardHomeScreen extends StatefulWidget {
  const GuardHomeScreen({super.key});

  @override
  State<GuardHomeScreen> createState() => _GuardHomeScreenState();
}

class _GuardHomeScreenState extends State<GuardHomeScreen> {
  Profile? _profile;
  List<ScanRecord> _recentScans = [];
  bool _isLoading = true;
  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _loadData();
    _setupRealtime();
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  void _setupRealtime() {
    _realtimeChannel = Supabase.instance.client
        .channel('guard_scans_feed')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'scans',
          callback: (payload) {
            // Refresh the feed when a new scan happens (by this guard or another)
            _loadScans();
          },
        )
        .subscribe();
  }

  Future<void> _loadData() async {
    try {
      _profile = await authService.loadProfile();
      await _loadScans();
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadScans() async {
    try {
      final scans = await scanService.recentScans(limit: 30);
      if (mounted) {
        setState(() => _recentScans = scans);
      }
    } catch (_) {
      // Silently fail for background refresh, or show a subtle banner
    }
  }

  Future<void> _openScanner() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ScannerScreen(),
      ),
    );
    _loadScans(); // Refresh on return
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
                title: const Text('End Shift (Sign Out)',
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
    // Guards should default to Dark Mode, so we enforce a dark scaffold
    // if the system is currently light, or respect the user's choice.
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F0F0F) : AppColors.background;
    final surfaceColor = isDark ? const Color(0xFF1E1E1E) : AppColors.surface;
    final textColor = isDark ? Colors.white : AppColors.textPrimary;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: AppColors.primary,
          child: CustomScrollView(
            slivers: [
              // 1. Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'On Duty',
                            style: AppTextStyles.bodyMedium
                                .copyWith(color: AppColors.primary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _profile?.fullName ?? 'Guard',
                            style: AppTextStyles.h1.copyWith(color: textColor),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.location_on_rounded,
                                  size: 14, color: AppColors.textSecondary),
                              const SizedBox(width: 4),
                              Text(
                                'Gate: ${_profile?.gateName ?? 'Main Gate'}',
                                style: AppTextStyles.bodySmall
                                    .copyWith(color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: _openSettings,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: surfaceColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black
                                    .withOpacity(isDark ? 0.5 : 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(Icons.settings_rounded, color: textColor),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 2. Big Scan Button
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: GestureDetector(
                    onTap: _openScanner,
                    child: Container(
                      height: 200,
                      decoration: BoxDecoration(
                        gradient: AppColors.premiumGradient,
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.4),
                            blurRadius: 30,
                            offset: const Offset(0, 15),
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Background Pattern
                          Positioned(
                            right: -20,
                            bottom: -20,
                            child: Icon(Icons.qr_code_scanner_rounded,
                                size: 180,
                                color: Colors.white.withOpacity(0.1)),
                          ),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                    Icons.center_focus_strong_rounded,
                                    color: Colors.white,
                                    size: 48),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'SCAN PASS',
                                style: AppTextStyles.h2.copyWith(
                                    color: Colors.white, letterSpacing: 2),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Tap to open camera',
                                style: AppTextStyles.bodySmall
                                    .copyWith(color: Colors.white70),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // 3. Recent Scans Header
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Recent Scans',
                          style: AppTextStyles.h3.copyWith(color: textColor)),
                      IconButton(
                        onPressed: _loadScans,
                        icon: const Icon(Icons.refresh_rounded,
                            color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),

              // 4. Recent Scans List
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: _isLoading
                    ? const SliverToBoxAdapter(
                        child: Center(
                            child: CircularProgressIndicator(
                                color: AppColors.primary)))
                    : _recentScans.isEmpty
                        ? SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                children: [
                                  Icon(Icons.history_rounded,
                                      size: 48,
                                      color: AppColors.textSecondary
                                          .withOpacity(0.5)),
                                  const SizedBox(height: 16),
                                  Text('No scans yet',
                                      style: AppTextStyles.bodyMedium.copyWith(
                                          color: AppColors.textSecondary)),
                                ],
                              ),
                            ),
                          )
                        : SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final scan = _recentScans[index];
                                return _ScanLogCard(
                                  scan: scan,
                                  isDark: isDark,
                                );
                              },
                              childCount: _recentScans.length,
                            ),
                          ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// SCAN LOG CARD (Shift Handover)
// ============================================================================

class _ScanLogCard extends StatelessWidget {
  final ScanRecord scan;
  final bool isDark;

  const _ScanLogCard({required this.scan, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final isAllowed = scan.result == ScanResult.allowed;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isAllowed
              ? (isDark
                  ? AppColors.success.withOpacity(0.3)
                  : AppColors.successLight)
              : (isDark
                  ? AppColors.danger.withOpacity(0.3)
                  : AppColors.dangerLight),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isAllowed
                  ? (isDark
                      ? AppColors.success.withOpacity(0.1)
                      : AppColors.successLight)
                  : (isDark
                      ? AppColors.danger.withOpacity(0.1)
                      : AppColors.dangerLight),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isAllowed ? Icons.check_rounded : Icons.close_rounded,
              color: isAllowed ? AppColors.success : AppColors.danger,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  scan.visitorName ?? 'Unknown Visitor',
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: isDark ? Colors.white : AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  scan.visitorType ?? 'Guest',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatTime(scan.scannedAt),
                style: AppTextStyles.bodyMedium.copyWith(
                  color: isDark ? Colors.white70 : AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                scan.gateName ?? 'Main Gate',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
