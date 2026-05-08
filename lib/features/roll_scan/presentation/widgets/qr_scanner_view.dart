import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Wraps `mobile_scanner` with a fixed reticle, duplicate-submit guard, and
/// proper controller lifecycle. Calls [onCode] at most once for a given
/// successful scan; further detections are ignored until the parent rebuilds
/// the view.
class QrScannerView extends StatefulWidget {
  const QrScannerView({super.key, required this.onCode, this.helperText});

  /// Invoked with the raw decoded value (the 12-digit generatedRollId)
  /// on the first successful detection. The view stops the camera before
  /// firing, so the callback is guaranteed to be called once per session.
  final void Function(String code) onCode;

  /// Optional Arabic helper line shown beneath the reticle.
  final String? helperText;

  @override
  State<QrScannerView> createState() => _QrScannerViewState();
}

class _QrScannerViewState extends State<QrScannerView> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const <BarcodeFormat>[BarcodeFormat.qrCode],
  );
  bool _consumed = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_consumed) return;
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    final String? value = barcodes.first.rawValue;
    if (value == null || value.isEmpty) return;
    _consumed = true;
    await _controller.stop();
    if (!mounted) return;
    widget.onCode(value);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(controller: _controller, onDetect: _onDetect),
        const _ReticleOverlay(),
        if (widget.helperText != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                widget.helperText!,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyLarge.copyWith(color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }
}

class _ReticleOverlay extends StatelessWidget {
  const _ReticleOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Container(
          width: 240,
          height: 240,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.accent, width: 3),
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}
