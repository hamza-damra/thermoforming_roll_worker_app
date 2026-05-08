import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/error_messages_ar.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_secondary_button.dart';
import '../../../../core/widgets/inline_error.dart';
import '../controllers/roll_scan_controller.dart';
import '../controllers/roll_scan_state.dart';
import '../widgets/manual_roll_input_dialog.dart';
import '../widgets/qr_scanner_view.dart';

/// Full-screen scan/mount flow. Camera-first; falls back to manual entry
/// per requirements §9.
class ScanRollScreen extends ConsumerStatefulWidget {
  const ScanRollScreen({super.key, required this.shiftLineId});

  final int shiftLineId;

  static const String title = 'تركيب رول';
  static const String scanQr = 'مسح QR';
  static const String manualEntry = 'إدخال رقم الرول';
  static const String helperText = 'وجّه الكاميرا نحو رمز QR على الرول لتركيبه';
  static const String successMessage = 'تم تركيب الرول بنجاح';
  static const String submittingMessage = 'جاري تركيب الرول…';

  @override
  ConsumerState<ScanRollScreen> createState() => _ScanRollScreenState();
}

class _ScanRollScreenState extends ConsumerState<ScanRollScreen> {
  /// Force-rebuilds the scanner view (and re-creates the controller) after
  /// a failed attempt so the camera resumes for the next scan.
  int _scannerKey = 0;

  void _resetScanner() {
    setState(() => _scannerKey++);
  }

  Future<void> _openManualInput() async {
    final String? code = await showManualRollInputDialog(context);
    if (code == null || !mounted) return;
    await ref
        .read(rollScanControllerProvider(widget.shiftLineId).notifier)
        .mountRoll(code);
  }

  Future<void> _onCodeScanned(String code) async {
    await ref
        .read(rollScanControllerProvider(widget.shiftLineId).notifier)
        .mountRoll(code);
  }

  @override
  Widget build(BuildContext context) {
    final RollScanState scanState = ref.watch(
      rollScanControllerProvider(widget.shiftLineId),
    );

    // React to terminal states.
    ref.listen<RollScanState>(rollScanControllerProvider(widget.shiftLineId), (
      prev,
      next,
    ) {
      if (next is RollScanMounted) {
        ScaffoldMessenger.maybeOf(context)
          ?..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text(ScanRollScreen.successMessage)),
          );
        if (mounted) Navigator.of(context).maybePop();
      } else if (next is RollScanFailureState) {
        // Re-open the camera for another attempt.
        _resetScanner();
      }
    });

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(ScanRollScreen.title),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: 'إغلاق',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: scanState is RollScanSubmitting
                ? const _SubmittingPanel()
                : QrScannerView(
                    key: ValueKey<int>(_scannerKey),
                    onCode: _onCodeScanned,
                    helperText: ScanRollScreen.helperText,
                  ),
          ),
          if (scanState is RollScanFailureState)
            Padding(
              padding: const EdgeInsets.all(16),
              child: AppCard(
                child: InlineError(
                  message: arabicMessageFor(scanState.failure),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: AppSecondaryButton(
              label: ScanRollScreen.manualEntry,
              icon: Icons.keyboard_rounded,
              onPressed: scanState is RollScanSubmitting
                  ? null
                  : _openManualInput,
            ),
          ),
        ],
      ),
    );
  }
}

class _SubmittingPanel extends StatelessWidget {
  const _SubmittingPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
              ),
            ),
            SizedBox(height: 16),
            Text(
              ScanRollScreen.submittingMessage,
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
