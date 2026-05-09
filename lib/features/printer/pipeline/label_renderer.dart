import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:qr/qr.dart';

import '../domain/entities/label_preset.dart';
import 'unit_converter.dart';

/// Geometry of one label: total dots, printable area, QR placement, and
/// optional 4-side text bands. Adapted verbatim from
/// `roll_production_app`'s validated pipeline.
class LabelLayout {
  LabelLayout({
    required this.widthDots,
    required this.heightDots,
    required this.marginDots,
    required this.printableWidthDots,
    required this.printableHeightDots,
    required this.qrSize,
    required this.qrX,
    required this.qrY,
    this.hasText = false,
    this.useLargeFont = false,
    this.mainFontHeight = 0,
    this.topTextY = 0,
    this.bottomTextY = 0,
    this.sideBandWidth = 0,
    this.sideBandTop = 0,
    this.sideBandBottom = 0,
  });

  final int widthDots;
  final int heightDots;
  final int marginDots;
  final int printableWidthDots;
  final int printableHeightDots;
  final int qrSize;
  final int qrX;
  final int qrY;

  // 4-side text layout fields
  final bool hasText;
  final bool useLargeFont;
  final int mainFontHeight;
  final int topTextY;
  final int bottomTextY;
  final int sideBandWidth;
  final int sideBandTop;
  final int sideBandBottom;

  static const int _gap = 6;
  static const int _minQrDots = 80;

  factory LabelLayout.fromPreset(LabelPreset preset, {bool hasText = false}) {
    final int widthDots = UnitConverter.mmToDots(preset.widthMm);
    final int heightDots = UnitConverter.mmToDots(preset.heightMm);
    final int marginDots = UnitConverter.mmToDots(preset.marginMm);

    final int printableWidthDots = widthDots - (marginDots * 2);
    final int printableHeightDots = heightDots - (marginDots * 2);

    if (!hasText) {
      final int qrSize = math.min(printableWidthDots, printableHeightDots);
      final int qrX = marginDots + ((printableWidthDots - qrSize) ~/ 2);
      final int qrY = marginDots + ((printableHeightDots - qrSize) ~/ 2);
      return LabelLayout(
        widthDots: widthDots,
        heightDots: heightDots,
        marginDots: marginDots,
        printableWidthDots: printableWidthDots,
        printableHeightDots: printableHeightDots,
        qrSize: qrSize,
        qrX: qrX,
        qrY: qrY,
      );
    }

    final int arial48H = img.arial48.lineHeight;
    final int arial24H = img.arial24.lineHeight;
    final bool useLarge =
        printableHeightDots - 2 * (arial48H + _gap) >= _minQrDots;
    final int mainFontH = useLarge ? arial48H : arial24H;

    final int topTextY = marginDots;
    final int bottomTextY = heightDots - marginDots - mainFontH;

    final int qrZoneTop = marginDots + mainFontH + _gap;
    final int qrZoneBottom = heightDots - marginDots - mainFontH - _gap;
    final int qrZoneHeight = qrZoneBottom - qrZoneTop;

    final int sideBandW = mainFontH + _gap;
    final int qrZoneLeft = marginDots + sideBandW;
    final int qrZoneRight = widthDots - marginDots - sideBandW;
    final int qrZoneWidth = qrZoneRight - qrZoneLeft;

    final int qrSize = math.min(qrZoneWidth, qrZoneHeight);
    final int qrX = qrZoneLeft + ((qrZoneWidth - qrSize) ~/ 2);
    final int qrY = qrZoneTop + ((qrZoneHeight - qrSize) ~/ 2);

    return LabelLayout(
      widthDots: widthDots,
      heightDots: heightDots,
      marginDots: marginDots,
      printableWidthDots: printableWidthDots,
      printableHeightDots: printableHeightDots,
      qrSize: qrSize,
      qrX: qrX,
      qrY: qrY,
      hasText: true,
      useLargeFont: useLarge,
      mainFontHeight: mainFontH,
      topTextY: topTextY,
      bottomTextY: bottomTextY,
      sideBandWidth: sideBandW,
      sideBandTop: qrZoneTop,
      sideBandBottom: qrZoneBottom,
    );
  }

  int get widthBytes =>
      UnitConverter.dotsToBytes(UnitConverter.alignToBytes(widthDots));
  int get alignedWidthDots => UnitConverter.alignToBytes(widthDots);
}

class LabelRenderResult {
  LabelRenderResult({
    required this.monochromeBytes,
    required this.widthBytes,
    required this.height,
  });

  final Uint8List monochromeBytes;
  final int widthBytes;
  final int height;
}

/// Rasterises a label (QR + optional 4-side text) to monochrome bytes that
/// can be sent verbatim to a TSPL `BITMAP` command.
///
/// Adapted from `roll_production_app`. The text path uses Flutter's
/// `TextPainter` + `Canvas` so Arabic / Unicode work correctly with
/// proper bidi handling; output is rasterised, scanned, and any sub-128
/// luminance pixel is treated as black.
class LabelRenderer {
  Future<LabelRenderResult> render({
    required String value,
    required LabelPreset preset,
    String? topText,
    String? bottomText,
    String? sideText,
  }) async {
    final bool hasText =
        topText != null || bottomText != null || sideText != null;
    final LabelLayout layout = LabelLayout.fromPreset(preset, hasText: hasText);

    final QrCode qrCode = QrCode.fromData(
      data: value,
      errorCorrectLevel: QrErrorCorrectLevel.M,
    );
    final QrImage qrImage = QrImage(qrCode);

    final img.Image image = img.Image(
      width: layout.alignedWidthDots,
      height: layout.heightDots,
    );
    img.fill(image, color: img.ColorRgba8(255, 255, 255, 255));

    if (hasText) {
      await _drawLabelText(
        image,
        layout,
        topText: topText,
        bottomText: bottomText,
        sideText: sideText,
      );
    }

    _drawQrCode(image, qrImage, layout);

    return LabelRenderResult(
      monochromeBytes: _convertToMonochrome(image),
      widthBytes: layout.widthBytes,
      height: layout.heightDots,
    );
  }

  Future<void> _drawLabelText(
    img.Image image,
    LabelLayout layout, {
    String? topText,
    String? bottomText,
    String? sideText,
  }) async {
    final double fontSize = layout.mainFontHeight * 0.72;
    final int maxHorizWidth = image.width - (layout.marginDots * 2);

    if (topText != null) {
      final img.Image bitmap = await _renderTextBitmap(
        topText,
        fontSize,
        maxHorizWidth,
      );
      final int centerX = (image.width - bitmap.width) ~/ 2;
      _compositeBlackPixels(image, bitmap, centerX, layout.topTextY);
    }

    if (bottomText != null) {
      final img.Image bitmap = await _renderTextBitmap(
        bottomText,
        fontSize,
        maxHorizWidth,
      );
      final int centerX = (image.width - bitmap.width) ~/ 2;
      _compositeBlackPixels(image, bitmap, centerX, layout.bottomTextY);
    }

    final String? resolvedSide = sideText ?? topText ?? bottomText;
    final int sideAvailable = layout.sideBandBottom - layout.sideBandTop;
    if (sideAvailable > 0 && resolvedSide != null) {
      img.Image bitmap = await _renderTextBitmap(
        resolvedSide,
        fontSize,
        sideAvailable,
      );
      if (bitmap.width > sideAvailable) {
        final double scale = sideAvailable / bitmap.width;
        bitmap = img.copyResize(
          bitmap,
          width: sideAvailable,
          height: (bitmap.height * scale).round().clamp(1, bitmap.height),
          interpolation: img.Interpolation.average,
        );
      }
      // Left side — text reads bottom-to-top (CCW 90°).
      final img.Image left = img.copyRotate(bitmap, angle: -90);
      final int leftY = (sideAvailable - left.height) ~/ 2;
      final int leftX = (layout.mainFontHeight - left.width) ~/ 2;
      _compositeBlackPixels(
        image,
        left,
        layout.marginDots + leftX,
        layout.sideBandTop + leftY,
      );
      // Right side — text reads top-to-bottom (CW 90°).
      final img.Image right = img.copyRotate(bitmap, angle: 90);
      final int rightY = (sideAvailable - right.height) ~/ 2;
      final int rightX = (layout.mainFontHeight - right.width) ~/ 2;
      _compositeBlackPixels(
        image,
        right,
        layout.widthDots - layout.marginDots - layout.mainFontHeight + rightX,
        layout.sideBandTop + rightY,
      );
    }
  }

  /// Rasterises [text] using Flutter's `TextPainter` so Arabic and Unicode
  /// shape correctly. Returns a monochrome-friendly RGB image (black on
  /// white).
  Future<img.Image> _renderTextBitmap(
    String text,
    double fontSize,
    int maxWidth,
  ) async {
    final bool isRtl = RegExp(r'[؀-ۿݐ-ݿࢠ-ࣿ]').hasMatch(text);

    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: const Color(0xFF000000),
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      maxLines: 1,
    )..layout();

    double usedFontSize = fontSize;
    if (painter.width > maxWidth && maxWidth > 0) {
      usedFontSize = fontSize * (maxWidth / painter.width);
      painter.text = TextSpan(
        text: text,
        style: TextStyle(
          color: const Color(0xFF000000),
          fontSize: usedFontSize,
          fontWeight: FontWeight.w600,
        ),
      );
      painter.layout();
    }

    final int w = painter.width.ceil().clamp(1, maxWidth.clamp(1, 4096));
    final int h = painter.height.ceil().clamp(1, 512);

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      Paint()..color = const Color(0xFFFFFFFF),
    );
    painter.paint(canvas, Offset.zero);

    final ui.Image uiImage = await recorder.endRecording().toImage(w, h);
    final ByteData? bytes = await uiImage.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    if (bytes == null) return img.Image(width: 1, height: 1);

    final img.Image out = img.Image(width: w, height: h);
    final Uint8List pixels = bytes.buffer.asUint8List();
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final int i = (y * w + x) * 4;
        out.setPixel(
          x,
          y,
          img.ColorRgba8(
            pixels[i],
            pixels[i + 1],
            pixels[i + 2],
            pixels[i + 3],
          ),
        );
      }
    }
    return out;
  }

  void _compositeBlackPixels(
    img.Image dest,
    img.Image src,
    int destX,
    int destY,
  ) {
    for (int y = 0; y < src.height; y++) {
      for (int x = 0; x < src.width; x++) {
        final img.Pixel pixel = src.getPixel(x, y);
        if (pixel.r.toInt() < 128) {
          final int dx = destX + x;
          final int dy = destY + y;
          if (dx >= 0 && dx < dest.width && dy >= 0 && dy < dest.height) {
            dest.setPixel(dx, dy, img.ColorRgba8(0, 0, 0, 255));
          }
        }
      }
    }
  }

  void _drawQrCode(img.Image image, QrImage qrImage, LabelLayout layout) {
    final int moduleCount = qrImage.moduleCount;
    final int moduleSize = layout.qrSize ~/ moduleCount;

    for (int y = 0; y < moduleCount; y++) {
      for (int x = 0; x < moduleCount; x++) {
        if (qrImage.isDark(y, x)) {
          final int px = layout.qrX + (x * moduleSize);
          final int py = layout.qrY + (y * moduleSize);
          for (int dy = 0; dy < moduleSize; dy++) {
            for (int dx = 0; dx < moduleSize; dx++) {
              final int tx = px + dx;
              final int ty = py + dy;
              if (tx < image.width && ty < image.height) {
                image.setPixel(tx, ty, img.ColorRgba8(0, 0, 0, 255));
              }
            }
          }
        }
      }
    }
  }

  Uint8List _convertToMonochrome(img.Image image) {
    final int widthBytes = (image.width + 7) ~/ 8;
    final Uint8List bytes = Uint8List(widthBytes * image.height);
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final img.Pixel pixel = image.getPixel(x, y);
        final int gray = (0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b)
            .round();
        if (gray > 127) {
          bytes[y * widthBytes + (x ~/ 8)] |= (1 << (7 - (x % 8)));
        }
      }
    }
    return bytes;
  }
}

/// Lightweight on-screen QR preview using Flutter `CustomPaint`. Reuses
/// the same `qr` package + error-correction level as the rasteriser so
/// the preview matches what the printer will emit.
class QrPreviewPainter extends CustomPainter {
  const QrPreviewPainter({required this.value});

  final String value;

  @override
  void paint(Canvas canvas, Size size) {
    try {
      final QrCode qrCode = QrCode.fromData(
        data: value,
        errorCorrectLevel: QrErrorCorrectLevel.M,
      );
      final QrImage qrImage = QrImage(qrCode);
      final int moduleCount = qrImage.moduleCount;
      final double moduleSize = size.width / moduleCount;
      final Paint paint = Paint()
        ..color = const Color(0xFF000000)
        ..style = PaintingStyle.fill;
      for (int y = 0; y < moduleCount; y++) {
        for (int x = 0; x < moduleCount; x++) {
          if (qrImage.isDark(y, x)) {
            canvas.drawRect(
              Rect.fromLTWH(
                x * moduleSize,
                y * moduleSize,
                moduleSize,
                moduleSize,
              ),
              paint,
            );
          }
        }
      }
    } catch (_) {
      // If encoding fails (extremely unlikely for the documented 12-digit
      // generatedRollId), draw a neutral fallback so the preview never
      // crashes the home.
      final TextPainter tp = TextPainter(
        text: const TextSpan(
          text: 'QR',
          style: TextStyle(color: Color(0xFF888888), fontSize: 24),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset((size.width - tp.width) / 2, (size.height - tp.height) / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant QrPreviewPainter oldDelegate) =>
      oldDelegate.value != value;
}
