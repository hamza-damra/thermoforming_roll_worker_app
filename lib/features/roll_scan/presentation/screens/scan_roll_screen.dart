import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/errors/error_code.dart';
import '../../../../core/errors/error_messages_ar.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_secondary_button.dart';
import '../../../../core/widgets/inline_error.dart';
import '../../domain/entities/roll_scan_warning.dart';
import '../controllers/roll_scan_controller.dart';
import '../controllers/roll_scan_state.dart';
import '../widgets/curing_max_warning_dialog.dart';
import '../widgets/curing_min_violation_dialog.dart';
import '../widgets/manual_roll_input_dialog.dart';
import '../widgets/qr_scanner_view.dart';
import '../widgets/roll_scan_blocked_dialog.dart';

/// Full-screen scan/mount flow. Camera-first; falls back to manual entry
/// per requirements §9.
class ScanRollScreen extends ConsumerStatefulWidget {
  const ScanRollScreen({
    super.key,
    required this.shiftLineId,
    this.accentColor,
  });

  final int shiftLineId;

  /// Active line accent forwarded from the home screen so the scan screen's
  /// app bar, manual-entry dialog and curing dialogs follow the same line
  /// color. Falls back to the brand primary when null.
  final Color? accentColor;

  static const String title = 'تركيب رول';
  static const String scanQr = 'مسح QR';
  static const String manualEntry = 'إدخال رقم الرول';
  static const String helperText = 'وجّه الكاميرا نحو رمز QR على الرول لتركيبه';
  static const String successMessage = 'تم تركيب الرول بنجاح';
  static const String submittingMessage = 'جاري تركيب الرول…';

  static const String curingMaxWarningCode = 'ROLL_CURING_MAXIMUM_EXCEEDED';

  /// Maps a business code to the blocked-roll dialog kind, or null when the
  /// failure should fall through to the inline error.
  ///
  /// Note the `_ => null` arm: a code missing from this switch silently falls
  /// through to the inline-error + camera-re-arm retry path — it compiles and
  /// passes every other test. Every code that is terminal for mounting must be
  /// listed here, and covered by the table test in `scan_roll_screen_test.dart`.
  @visibleForTesting
  static RollScanBlockedKind? blockedKindFor(ErrorCode code) => switch (code) {
    ErrorCode.rollSentToGrindingNotReusable => RollScanBlockedKind.grinding,
    ErrorCode.rollAlreadyConsumed => RollScanBlockedKind.consumed,
    ErrorCode.rollAdminCancelled => RollScanBlockedKind.adminCancelled,
    ErrorCode.rollReconciledOutOfStock =>
      RollScanBlockedKind.reconciledOutOfStock,
    _ => null,
  };

  @override
  ConsumerState<ScanRollScreen> createState() => _ScanRollScreenState();
}

class _ScanRollScreenState extends ConsumerState<ScanRollScreen> {
  /// Force-rebuilds the scanner view (and re-creates the controller) after
  /// a failed attempt so the camera resumes for the next scan.
  int _scannerKey = 0;

  /// The most recently attempted roll number (scanned or typed). Surfaced in
  /// the curing-violation dialog when `error.details` omits the roll id.
  String? _lastScannedCode;

  void _resetScanner() {
    setState(() => _scannerKey++);
  }

  Future<void> _openManualInput() async {
    final String? code = await showManualRollInputDialog(
      context,
      accent: widget.accentColor,
    );
    if (code == null || !mounted) return;
    _lastScannedCode = code;
    await ref
        .read(rollScanControllerProvider(widget.shiftLineId).notifier)
        .mountRoll(code);
  }

  Future<void> _onCodeScanned(String code) async {
    _lastScannedCode = code;
    await ref
        .read(rollScanControllerProvider(widget.shiftLineId).notifier)
        .mountRoll(code);
  }

  Future<void> _handleMounted(RollScanMounted next) async {
    final RollScanWarning? maxWarning = _firstCuringMaxWarning(next.warnings);
    if (maxWarning != null) {
      await showCuringMaxWarningDialog(
        context,
        warning: maxWarning,
        accent: widget.accentColor,
      );
      if (!mounted) return;
    } else {
      ScaffoldMessenger.maybeOf(context)
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text(ScanRollScreen.successMessage)),
        );
    }
    if (mounted) Navigator.of(context).maybePop();
  }

  Future<void> _handleFailure(RollScanFailureState next) async {
    final AppFailure failure = next.failure;
    if (failure is BusinessFailure) {
      if (failure.code == ErrorCode.rollCuringMinimumNotMet) {
        // Re-arm the camera under the dialog so the worker can scan a
        // different roll after acknowledging.
        _resetScanner();
        await showCuringMinViolationDialog(
          context,
          failure: failure,
          accent: widget.accentColor,
          rollNumber: _lastScannedCode,
        );
        return;
      }
      // Terminally-blocked rolls (grinding-recommended / consumed /
      // admin-cancelled / reconciled-out-of-inventory) get a rich modal built
      // from `error.details` instead of the generic inline error.
      final RollScanBlockedKind? blockedKind = ScanRollScreen.blockedKindFor(
        failure.code,
      );
      if (blockedKind != null) {
        _resetScanner();
        await showRollScanBlockedDialog(
          context,
          kind: blockedKind,
          failure: failure,
          accent: widget.accentColor,
        );
        return;
      }
    }
    // Default failure path: inline error + re-open camera for retry.
    _resetScanner();
  }

  static RollScanWarning? _firstCuringMaxWarning(
    List<RollScanWarning> warnings,
  ) {
    for (final RollScanWarning w in warnings) {
      if (w.code == ScanRollScreen.curingMaxWarningCode) return w;
    }
    return null;
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
      if (next is RollScanMounted && prev is! RollScanMounted) {
        _handleMounted(next);
      } else if (next is RollScanFailureState) {
        _handleFailure(next);
      }
    });

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(ScanRollScreen.title),
        backgroundColor: widget.accentColor ?? AppColors.primary,
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
          if (scanState is RollScanFailureState &&
              !_isHandledByDialog(scanState.failure))
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
              color: widget.accentColor,
              onPressed: scanState is RollScanSubmitting
                  ? null
                  : _openManualInput,
            ),
          ),
        ],
      ),
    );
  }

  /// `true` when the failure is surfaced through a modal dialog (curing-min or
  /// any [RollScanBlockedKind]) and must NOT also show the inline error card.
  static bool _isHandledByDialog(AppFailure failure) {
    if (failure is! BusinessFailure) return false;
    return failure.code == ErrorCode.rollCuringMinimumNotMet ||
        ScanRollScreen.blockedKindFor(failure.code) != null;
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
