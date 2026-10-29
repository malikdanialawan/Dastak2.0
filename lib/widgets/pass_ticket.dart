import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/constants.dart';
import '../core/helpers.dart';
import '../core/models.dart';

/// A highly polished, dynamic ticket widget used across the app.
/// Automatically switches between a residential gate-slip and a premium event ticket.
class PassTicket extends StatelessWidget {
  final Pass pass;
  final String? eventName;
  final bool isCompact;

  const PassTicket({
    super.key,
    required this.pass,
    this.eventName,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isCompact) {
      return _CompactPassCard(pass: pass);
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: pass.kind == PassKind.event
            ? _EventTicketTemplate(pass: pass, eventName: eventName)
            : _ResidentTicketTemplate(pass: pass),
      ),
    );
  }
}

// ============================================================================
// 1. COMPACT CARD (For List Views)
// ============================================================================

class _CompactPassCard extends StatelessWidget {
  final Pass pass;

  const _CompactPassCard({required this.pass});

  @override
  Widget build(BuildContext context) {
    final status = pass.effectiveStatus;
    final isActive = status == PassStatus.active;

    return Container(
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
      child: Row(
        children: [
          // Left: Avatar/Icon
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: pass.kind == PassKind.event
                  ? AppColors.primaryLight.withOpacity(0.2)
                  : AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                initials(pass.visitorName),
                style: AppTextStyles.h3.copyWith(
                  color: pass.kind == PassKind.event
                      ? AppColors.primary
                      : AppColors.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Center: Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pass.visitorName,
                  style: AppTextStyles.h3,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  pass.typeLabel,
                  style: AppTextStyles.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 12,
                      color: AppColors.textSecondary.withOpacity(0.7),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      pass.recurrenceDays.isNotEmpty
                          ? formatRecurrence(pass.recurrenceDays)
                          : (pass.validUntil != null
                              ? formatDate(pass.validUntil!)
                              : 'No expiry'),
                      style: AppTextStyles.bodySmall.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Right: Status Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isActive ? AppColors.successLight : AppColors.dangerLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              status.label,
              style: AppTextStyles.label.copyWith(
                color: isActive ? AppColors.success : AppColors.danger,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 2. RESIDENT TEMPLATE (Gate Slip)
// ============================================================================

class _ResidentTicketTemplate extends StatelessWidget {
  final Pass pass;

  const _ResidentTicketTemplate({required this.pass});

  @override
  Widget build(BuildContext context) {
    final status = pass.effectiveStatus;
    final isActive = status == PassStatus.active;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(24),
          color: AppColors.surfaceMuted.withOpacity(0.5),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.home_work_rounded,
                      color: AppColors.primary, size: 28),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Visitor Pass', style: AppTextStyles.h3),
                      Text('Dastak Access', style: AppTextStyles.bodySmall),
                    ],
                  ),
                ],
              ),
              _StatusBadge(status: status, isActive: isActive),
            ],
          ),
        ),

        // Body
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Avatar & Name
              Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.surfaceMuted,
                          AppColors.surfaceMuted.withOpacity(0.5)
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Center(
                      child: Text(
                        initials(pass.visitorName),
                        style: AppTextStyles.h1
                            .copyWith(color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(pass.visitorName, style: AppTextStyles.h2),
                        const SizedBox(height: 4),
                        Text(pass.typeLabel,
                            style: AppTextStyles.bodyMedium
                                .copyWith(color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Details Grid
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    _DetailRow(
                        icon: Icons.location_on_rounded,
                        label: 'Visiting',
                        value: pass.apartment ?? 'Main Gate'),
                    if (pass.vehicle != null) ...[
                      const Divider(height: 24, color: AppColors.surfaceMuted),
                      _DetailRow(
                          icon: Icons.directions_car_rounded,
                          label: 'Vehicle',
                          value: pass.vehicle!),
                    ],
                    const Divider(height: 24, color: AppColors.surfaceMuted),
                    _DetailRow(
                      icon: Icons.schedule_rounded,
                      label: 'Schedule',
                      value: pass.recurrenceDays.isNotEmpty
                          ? formatRecurrenceSchedule(pass.recurrenceDays,
                              pass.windowStart, pass.windowEnd)
                          : formatRange(pass.validFrom, pass.validUntil),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // QR Code
              _QrSection(pass: pass),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// 3. EVENT TEMPLATE (Premium Ticket)
// ============================================================================

class _EventTicketTemplate extends StatelessWidget {
  final Pass pass;
  final String? eventName;

  const _EventTicketTemplate({required this.pass, this.eventName});

  @override
  Widget build(BuildContext context) {
    final status = pass.effectiveStatus;
    final isActive = status == PassStatus.active;

    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.darkGradient,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        eventName ?? 'Event Pass',
                        style: AppTextStyles.h2.copyWith(color: Colors.white),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Official Entry Ticket',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                _StatusBadge(status: status, isActive: isActive, isDark: true),
              ],
            ),
          ),
          const Divider(color: Colors.white24, height: 1),

          // Body
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Attendee Info
                Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Center(
                        child: Text(
                          initials(pass.visitorName),
                          style: AppTextStyles.h1
                              .copyWith(color: AppColors.primary),
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
                            style:
                                AppTextStyles.h3.copyWith(color: Colors.white),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              pass.visitorType ?? 'Guest',
                              style: AppTextStyles.label
                                  .copyWith(color: Colors.white, fontSize: 10),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // QR on white card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    children: [
                      QrImageView(
                        data: pass.qrData,
                        version: QrVersions.auto,
                        size: 200,
                        backgroundColor: Colors.white,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: AppColors.textPrimary,
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'SCAN AT ENTRANCE',
                        style: AppTextStyles.label.copyWith(
                          color: AppColors.textSecondary,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 4. SHARED COMPONENTS
// ============================================================================

class _QrSection extends StatelessWidget {
  final Pass pass;
  const _QrSection({required this.pass});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.surfaceMuted, width: 2),
          ),
          child: QrImageView(
            data: pass.qrData,
            version: QrVersions.auto,
            size: 200,
            backgroundColor: AppColors.surface,
            eyeStyle: const QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: AppColors.textPrimary,
            ),
            dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'SCAN AT GATE',
          style: AppTextStyles.label
              .copyWith(color: AppColors.textSecondary, letterSpacing: 2),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.textSecondary),
        const SizedBox(width: 12),
        Text(label, style: AppTextStyles.bodySmall),
        const Spacer(),
        Expanded(
          flex: 2,
          child: Text(
            value,
            style:
                AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
            textAlign: TextAlign.right,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final PassStatus status;
  final bool isActive;
  final bool isDark;

  const _StatusBadge(
      {required this.status, required this.isActive, this.isDark = false});

  @override
  Widget build(BuildContext context) {
    final bgColor = isActive
        ? (isDark ? AppColors.success : AppColors.successLight)
        : (isDark ? AppColors.danger : AppColors.dangerLight);
    final textColor = isActive
        ? (isDark ? Colors.white : AppColors.success)
        : (isDark ? Colors.white : AppColors.danger);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor.withOpacity(isDark ? 0.8 : 1.0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.label,
        style: AppTextStyles.label.copyWith(color: textColor, fontSize: 10),
      ),
    );
  }
}
