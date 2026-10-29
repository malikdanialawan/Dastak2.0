import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants.dart';
import '../../core/helpers.dart';
import '../../core/models.dart';
import '../../data/repositories.dart';
import '../../widgets/pass_ticket.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController _cameraController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );

  bool _isProcessing = false;
  LookupResult? _lookupResult;

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }

  Future<void> _handleBarcode(BarcodeCapture capture) async {
    if (_isProcessing || _lookupResult != null) return;
    if (capture.barcodes.isEmpty) return;

    final barcode = capture.barcodes.first;
    final rawValue = barcode.rawValue;
    if (rawValue == null) return;

    await _processCode(rawValue);
  }

  Future<void> _processCode(String code) async {
    setState(() => _isProcessing = true);
    await _cameraController.stop(); // Freeze camera

    try {
      final result = await scanService.lookupPass(code);
      if (mounted) {
        setState(() {
          _lookupResult = result;
          _isProcessing = false;
        });
        _showResultSheet();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _lookupResult = LookupResult(
            status: LookupStatus.unavailable,
            errorMessage: errorText(e),
          );
          _isProcessing = false;
        });
        _showResultSheet();
      }
    }
  }

  void _resetScanner() {
    setState(() {
      _lookupResult = null;
      _isProcessing = false;
    });
    _cameraController.start();
  }

  void _showResultSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        if (_lookupResult == null) return const SizedBox.shrink();

        if (_lookupResult!.status == LookupStatus.unavailable) {
          return _NetworkErrorSheet(
            message: _lookupResult!.errorMessage ?? 'Network unavailable.',
            onRetry: () {
              Navigator.pop(ctx);
              _resetScanner();
            },
            onCancel: () {
              Navigator.pop(ctx);
              _resetScanner();
            },
          );
        }

        if (_lookupResult!.status == LookupStatus.notFound) {
          return _NotFoundSheet(
            onClose: () {
              Navigator.pop(ctx);
              _resetScanner();
            },
          );
        }

        // Found
        final pass = _lookupResult!.pass!;
        return _PassResultSheet(
          pass: pass,
          onClose: () {
            Navigator.pop(ctx);
            _resetScanner();
          },
          onScanNext: () {
            Navigator.pop(ctx);
            _resetScanner();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Scan Pass', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on_rounded),
            onPressed: () => _cameraController.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.keyboard_rounded),
            onPressed: () => _showManualEntry(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // 1. Camera View
          MobileScanner(
            controller: _cameraController,
            onDetect: _handleBarcode,
            errorBuilder: (context, error, child) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.camera_alt_outlined,
                          color: Colors.white54, size: 64),
                      const SizedBox(height: 16),
                      Text(
                        'Camera access denied.\nPlease enable permissions in settings.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyMedium
                            .copyWith(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // 2. Scanner Overlay
          _buildScannerOverlay(),

          // 3. Processing Indicator
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(
                    color: AppColors.primary, strokeWidth: 4),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScannerOverlay() {
    return ColorFiltered(
      colorFilter: ColorFilter.mode(
        Colors.black.withOpacity(0.6),
        BlendMode.srcOut,
      ),
      child: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              color: Colors.black,
              backgroundBlendMode: BlendMode.dstOut,
            ),
          ),
          Center(
            child: Container(
              height: 280,
              width: 280,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(32),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScannerFrame() {
    return Center(
      child: Container(
        height: 280,
        width: 280,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.primary, width: 4),
          borderRadius: BorderRadius.circular(32),
        ),
        child: Stack(
          children: [
            // Corner brackets
            Positioned(
              top: -4,
              left: -4,
              child: _buildCorner(),
            ),
            Positioned(
              top: -4,
              right: -4,
              child: _buildCorner(isRight: true),
            ),
            Positioned(
              bottom: -4,
              left: -4,
              child: _buildCorner(isBottom: true),
            ),
            Positioned(
              bottom: -4,
              right: -4,
              child: _buildCorner(isBottom: true, isRight: true),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCorner({bool isBottom = false, bool isRight = false}) {
    return Container(
      height: 40,
      width: 40,
      decoration: BoxDecoration(
        border: Border(
          top: isBottom
              ? BorderSide.none
              : const BorderSide(color: Colors.white, width: 6),
          bottom: isBottom
              ? const BorderSide(color: Colors.white, width: 6)
              : BorderSide.none,
          left: isRight
              ? BorderSide.none
              : const BorderSide(color: Colors.white, width: 6),
          right: isRight
              ? const BorderSide(color: Colors.white, width: 6)
              : BorderSide.none,
        ),
        borderRadius: BorderRadius.only(
          topLeft:
              (!isBottom && !isRight) ? const Radius.circular(32) : Radius.zero,
          topRight:
              (!isBottom && isRight) ? const Radius.circular(32) : Radius.zero,
          bottomLeft:
              (isBottom && !isRight) ? const Radius.circular(32) : Radius.zero,
          bottomRight:
              (isBottom && isRight) ? const Radius.circular(32) : Radius.zero,
        ),
      ),
    );
  }

  void _showManualEntry() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Manual Entry'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Enter Pass ID or Code'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (controller.text.isNotEmpty) {
                _processCode(controller.text.trim());
              }
            },
            child: const Text('Verify'),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// RESULT SHEETS (Overlays)
// ============================================================================

class _PassResultSheet extends StatefulWidget {
  final Pass pass;
  final VoidCallback onClose;
  final VoidCallback onScanNext;

  const _PassResultSheet({
    required this.pass,
    required this.onClose,
    required this.onScanNext,
  });

  @override
  State<_PassResultSheet> createState() => _PassResultSheetState();
}

class _PassResultSheetState extends State<_PassResultSheet> {
  bool _isRecording = false;
  final _reasonController = TextEditingController();
  String? _selectedRejectReason;

  bool get _isBlocked => scanService.entryBlockReason(widget.pass) != null;

  Future<void> _recordDecision(ScanResult result, {String? reason}) async {
    setState(() => _isRecording = true);
    try {
      await scanService.recordScan(
        pass: widget.pass,
        result: result,
        reason: reason,
        gateName: (await authService.loadProfile())?.gateName,
      );

      if (mounted) {
        if (result == ScanResult.allowed) {
          _showSuccessOverlay();
        } else {
          widget.onScanNext(); // Just close on reject
        }
      }
    } catch (e) {
      if (mounted) {
        showSnack(context, errorText(e), isError: true);
        setState(() => _isRecording = false);
      }
    }
  }

  void _showSuccessOverlay() {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.8),
      pageBuilder: (ctx, _, __) => Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: AppColors.successLight,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.success.withOpacity(0.5),
                        blurRadius: 40,
                        spreadRadius: 10),
                  ],
                ),
                child: const Icon(Icons.check_rounded,
                    color: AppColors.success, size: 80),
              ),
              const SizedBox(height: 32),
              Text(
                'ENTRY ALLOWED',
                style: AppTextStyles.h1
                    .copyWith(color: Colors.white, letterSpacing: 2),
              ),
              const SizedBox(height: 8),
              Text(
                widget.pass.visitorName,
                style: AppTextStyles.h3.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: 200,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx); // Close overlay
                    widget.onScanNext(); // Reset scanner
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Scan Next'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRejectOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Reason for Rejection', style: AppTextStyles.h3),
            const SizedBox(height: 16),
            ...kRejectReasons.map((r) => RadioListTile<String>(
                  title: Text(r),
                  value: r,
                  groupValue: _selectedRejectReason,
                  activeColor: AppColors.danger,
                  onChanged: (val) {
                    setState(() => _selectedRejectReason = val);
                    Navigator.pop(ctx);
                    _recordDecision(ScanResult.rejected, reason: val);
                  },
                )),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _callResident() async {
    final phone = widget.pass.visitorPhone;
    if (phone == null) {
      showSnack(context, 'No phone number available for this visitor.',
          isError: true);
      return;
    }
    final uri = Uri.parse('tel:${normalizePhone(phone)}');
    try {
      await launchUrl(uri);
    } catch (e) {
      if (mounted) showSnack(context, 'Could not open dialer.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final blockReason = scanService.entryBlockReason(widget.pass);
    final isAllowed = blockReason == null;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Scan Result', style: AppTextStyles.h2),
              IconButton(
                onPressed: widget.onClose,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Status Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isAllowed ? AppColors.successLight : AppColors.dangerLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: isAllowed ? AppColors.success : AppColors.danger,
                  width: 2),
            ),
            child: Row(
              children: [
                Icon(
                  isAllowed ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  color: isAllowed ? AppColors.success : AppColors.danger,
                  size: 32,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isAllowed ? 'VALID PASS' : 'ENTRY BLOCKED',
                        style: AppTextStyles.h3.copyWith(
                          color:
                              isAllowed ? AppColors.success : AppColors.danger,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (!isAllowed)
                        Text(
                          blockReason,
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.danger),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Compact Ticket Info
          PassTicket(pass: widget.pass, isCompact: true),

          const SizedBox(height: 24),

          // Actions
          if (_isRecording)
            const Center(
                child: CircularProgressIndicator(color: AppColors.primary))
          else
            Row(
              children: [
                // Call Button
                if (widget.pass.visitorPhone != null) ...[
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: OutlinedButton.icon(
                        onPressed: _callResident,
                        icon: const Icon(Icons.phone_rounded),
                        label: const Text('Call'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],

                // Reject Button
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: OutlinedButton(
                      onPressed: _showRejectOptions,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        side:
                            const BorderSide(color: AppColors.danger, width: 2),
                      ),
                      child: const Text('Reject'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Allow Button
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: isAllowed
                          ? () => _recordDecision(ScanResult.allowed)
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isAllowed
                            ? AppColors.success
                            : AppColors.surfaceMuted,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.surfaceMuted,
                        disabledForegroundColor: AppColors.textSecondary,
                      ),
                      child: const Text('ALLOW ENTRY'),
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ============================================================================
// NETWORK ERROR SHEET
// ============================================================================

class _NetworkErrorSheet extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onCancel;

  const _NetworkErrorSheet({
    required this.message,
    required this.onRetry,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: AppColors.warningLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.wifi_off_rounded,
                color: AppColors.warning, size: 48),
          ),
          const SizedBox(height: 24),
          Text('Verification Unavailable',
              style: AppTextStyles.h2, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            message,
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: OutlinedButton(
                    onPressed: onCancel,
                    child: const Text('Cancel'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: onRetry,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.warning),
                    child: const Text('RETRY'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ============================================================================
// NOT FOUND SHEET
// ============================================================================

class _NotFoundSheet extends StatelessWidget {
  final VoidCallback onClose;

  const _NotFoundSheet({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: AppColors.dangerLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.qr_code_scanner_rounded,
                color: AppColors.danger, size: 48),
          ),
          const SizedBox(height: 24),
          Text('Invalid Pass',
              style: AppTextStyles.h2, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            'This QR code is invalid, corrupted, or the pass has been re-issued.',
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: onClose,
              child: const Text('Scan Again'),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
