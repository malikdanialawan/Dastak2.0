import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/constants.dart';
import '../../core/helpers.dart';
import '../../core/models.dart';
import '../../data/repositories.dart';
import '../../widgets/pass_ticket.dart';
import '../../widgets/shared_widgets.dart';

class PassDetailsScreen extends StatefulWidget {
  final String passId;
  final bool canRevoke;
  final String? eventName;

  const PassDetailsScreen({
    super.key,
    required this.passId,
    this.canRevoke = true,
    this.eventName,
  });

  @override
  State<PassDetailsScreen> createState() => _PassDetailsScreenState();
}

class _PassDetailsScreenState extends State<PassDetailsScreen> {
  bool _isLoading = true;
  bool _isSharing = false;
  Pass? _pass;
  String? _photoUrl;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final pass = await passService.getPass(widget.passId);
      if (pass == null) throw const AppException('Pass not found.');

      String? photo;
      if (pass.photoPath != null) {
        photo = await passService.getPhotoUrl(pass.photoPath);
      }

      if (mounted) {
        setState(() {
          _pass = pass;
          _photoUrl = photo;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _share() async {
    if (_pass == null) return;
    setState(() => _isSharing = true);
    try {
      await shareService.sharePass(_pass!, eventName: widget.eventName);
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), isError: true);
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  Future<void> _openWhatsApp() async {
    if (_pass == null) return;
    final ok =
        await shareService.openWhatsApp(_pass!, eventName: widget.eventName);
    if (!mounted) return;
    showSnack(context, ok ? 'Opened WhatsApp' : 'Could not open WhatsApp',
        isError: !ok);
  }

  Future<void> _openEmail() async {
    if (_pass == null) return;
    final ok =
        await shareService.openEmail(_pass!, eventName: widget.eventName);
    if (!mounted) return;
    showSnack(context, ok ? 'Opened mail app' : 'Could not open mail app',
        isError: !ok);
  }

  Future<void> _revoke() async {
    if (_pass == null) return;
    final yes = await ConfirmDialog.show(
      context,
      title: 'Revoke this pass?',
      message:
          '${_pass!.visitorName} will no longer be allowed in with this pass.',
      confirmLabel: 'Revoke',
      isDestructive: true,
    );
    if (!yes) return;

    try {
      await passService.revokePass(_pass!.id);
      if (mounted) {
        showSnack(context, 'Pass revoked successfully.');
        _loadData(); // Refresh status
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
        title: const Text('Pass Details'),
        actions: [
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _isLoading
          ? const LoadingView()
          : _error != null
              ? EmptyState(
                  icon: Icons.error_outline_rounded,
                  title: 'Could not load pass',
                  message: _error!,
                  actionLabel: 'Retry',
                  onAction: _loadData,
                )
              : _pass == null
                  ? const EmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'Pass not found',
                      message: 'This pass may have been deleted.',
                    )
                  : _buildBody(_pass!),
    );
  }

  Widget _buildBody(Pass pass) {
    final status = pass.effectiveStatus;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // 1. Premium Header
        Center(
          child: Column(
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surfaceMuted,
                  border: Border.all(
                      color: AppColors.primary.withOpacity(0.2), width: 4),
                  image: _photoUrl != null
                      ? DecorationImage(
                          image: NetworkImage(_photoUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: _photoUrl == null
                    ? Center(
                        child: Text(
                          initials(pass.visitorName),
                          style: AppTextStyles.h1
                              .copyWith(color: AppColors.textSecondary),
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: 16),
              Text(pass.visitorName,
                  style: AppTextStyles.h2, textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text(
                pass.typeLabel,
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              // Status Badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: status == PassStatus.active
                      ? AppColors.successLight
                      : AppColors.dangerLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status.label.toUpperCase(),
                  style: AppTextStyles.label.copyWith(
                    color: status == PassStatus.active
                        ? AppColors.success
                        : AppColors.danger,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // 2. Information Card
        PremiumCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              if (widget.eventName != null)
                _DetailRow(
                    icon: Icons.event_rounded,
                    label: 'Event',
                    value: widget.eventName!),
              if (pass.apartment != null)
                _DetailRow(
                    icon: Icons.home_rounded,
                    label: 'Visiting',
                    value: pass.apartment!),
              _DetailRow(
                icon: Icons.schedule_rounded,
                label: 'Schedule',
                value: pass.recurrenceDays.isNotEmpty
                    ? formatRecurrenceSchedule(
                        pass.recurrenceDays, pass.windowStart, pass.windowEnd)
                    : formatRange(pass.validFrom, pass.validUntil),
              ),
              if (pass.vehicle != null)
                _DetailRow(
                    icon: Icons.directions_car_rounded,
                    label: 'Vehicle',
                    value: pass.vehicle!),
              _DetailRow(
                icon: Icons.login_rounded,
                label: 'Entries',
                value: pass.multipleEntries
                    ? '${pass.entriesUsed} (Multiple allowed)'
                    : '${pass.entriesUsed} (Single entry)',
              ),
              if (pass.company != null)
                _DetailRow(
                    icon: Icons.business_rounded,
                    label: 'Company',
                    value: pass.company!),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // 3. QR Code
        Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                QrImageView(
                  data: pass.qrData,
                  version: QrVersions.auto,
                  size: 220,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: AppColors.textPrimary),
                  dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: AppColors.textPrimary),
                ),
                const SizedBox(height: 16),
                Text(
                  'SCAN AT GATE',
                  style: AppTextStyles.label.copyWith(
                      letterSpacing: 2, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),

        // 4. Actions
        AppButton(
          label: 'Share Pass (Image)',
          icon: Icons.share_rounded,
          isLoading: _isSharing,
          onPressed: _share,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            if (pass.visitorPhone != null)
              Expanded(
                child: AppButton(
                  label: 'WhatsApp',
                  icon: Icons.chat_rounded,
                  isSecondary: true,
                  onPressed: _openWhatsApp,
                ),
              ),
            if (pass.visitorPhone != null && pass.visitorEmail != null)
              const SizedBox(width: 12),
            if (pass.visitorEmail != null)
              Expanded(
                child: AppButton(
                  label: 'Email',
                  icon: Icons.mail_rounded,
                  isSecondary: true,
                  onPressed: _openEmail,
                ),
              ),
          ],
        ),

        // 5. Revoke Action
        if (widget.canRevoke && status != PassStatus.revoked) ...[
          const SizedBox(height: 24),
          AppButton(
            label: 'Revoke Pass',
            icon: Icons.block_rounded,
            isSecondary: true,
            onPressed: _revoke,
          ),
        ],
        const SizedBox(height: 48),
      ],
    );
  }
}

// ============================================================================
// HELPER WIDGET
// ============================================================================

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(label, style: AppTextStyles.bodySmall),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: AppTextStyles.bodyMedium
                  .copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
