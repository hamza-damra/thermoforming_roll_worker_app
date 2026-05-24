import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:qr/qr.dart';

import '../domain/entities/label_preset.dart';
import '../domain/entities/roll_label_data.dart';
import 'unit_converter.dart';

/// Geometry of one label (legacy 4-side text path). Adapted verbatim from
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

/// Rasterises a label to monochrome bytes that can be sent verbatim to a
/// TSPL `BITMAP` or ZPL `^GFA` command.
///
/// Two layouts are supported:
///   * **Structured (new)** — used when [labelData] is non-null. Mirrors
///     the validated `RollProductionApp` design: QR top-left, large
///     machine number top-right, 12-digit serial in the middle band, and
///     weekday | date | time at the bottom. Grinding remainders
///     ([RollLabelData.isScrap] = `true`) get the reference scrap icon
///     next to the serial.
///   * **Legacy** — 4-side text layout kept as a private fallback for any
///     surface that still passes plain `topText` / `bottomText` /
///     `sideText` (smoke tests, the operator-settings preview).
class LabelRenderer {
  Future<LabelRenderResult> render({
    required String value,
    required LabelPreset preset,
    RollLabelData? labelData,
    // Legacy params — ignored when labelData is non-null.
    String? topText,
    String? bottomText,
    String? sideText,
  }) async {
    if (labelData != null) {
      return _renderNewLayout(
        value: value,
        preset: preset,
        labelData: labelData,
      );
    }
    return _renderLegacyLayout(
      value: value,
      preset: preset,
      topText: topText,
      bottomText: bottomText,
      sideText: sideText,
    );
  }

  // ── New structured layout ─────────────────────────────────────────────────

  /// Minimum safe inset (in dots) applied even when the preset asks for
  /// zero margin. Thermal printers have ~1–2 mm of hardware "dead zone"
  /// near the edges, so a tiny floor prevents the outer border from
  /// printing as a half-line / clipped stroke. 8 dots ≈ 1 mm at 203 DPI.
  static const int _minSafeMarginDots = 8;

  Future<LabelRenderResult> _renderNewLayout({
    required String value,
    required LabelPreset preset,
    required RollLabelData labelData,
  }) async {
    final int widthDots = UnitConverter.mmToDots(preset.widthMm);
    final int heightDots = UnitConverter.mmToDots(preset.heightMm);
    final int alignedWidth = UnitConverter.alignToBytes(widthDots);

    final int configuredMarginDots = UnitConverter.mmToDots(preset.marginMm);
    final int marginDots =
        math.max(configuredMarginDots, _minSafeMarginDots);
    final int maxAllowedMarginDots =
        math.max(0, (math.min(widthDots, heightDots) - 16) ~/ 2);
    final int effectiveMarginDots = math.min(marginDots, maxAllowedMarginDots);

    final img.Image image =
        img.Image(width: alignedWidth, height: heightDots);
    img.fill(image, color: img.ColorRgba8(255, 255, 255, 255));

    final int left = effectiveMarginDots;
    final int top = effectiveMarginDots;
    final int right = widthDots - 1 - effectiveMarginDots;
    final int bottom = heightDots - 1 - effectiveMarginDots;
    final int innerW = right - left + 1;
    final int innerH = bottom - top + 1;

    if (kDebugMode) {
      debugPrint(
        '[LabelRenderer] preset="${preset.name}" '
        'size=${preset.widthMm}×${preset.heightMm}mm '
        'margin=${preset.marginMm}mm '
        '→ bitmap=$widthDots×${heightDots}dots, '
        'marginDots=$effectiveMarginDots '
        '(configured=$configuredMarginDots, floor=$_minSafeMarginDots), '
        'inner=$innerW×${innerH}dots',
      );
    }

    // Section geometry (inside the margin).
    // Top section (QR + roll number): 58 % of inner height
    // Mid section (serial number):    24 %
    // Bot section (3 columns):        18 %
    final int topH = (innerH * 0.58).round();
    final int midH = (innerH * 0.24).round();
    final int topDividerY = top + topH;
    final int midDividerY = topDividerY + midH;

    // Vertical split in top section: QR takes 57 % of inner width.
    final int qrColW = (innerW * 0.57).round();
    final int qrDividerX = left + qrColW;

    // Border and dividers (all inset by marginDots).
    _hLine(image, top, left, right);
    _hLine(image, bottom, left, right);
    _vLine(image, left, top, bottom);
    _vLine(image, right, top, bottom);

    _hLine(image, topDividerY, left + 1, right - 1);
    _hLine(image, midDividerY, left + 1, right - 1);

    _vLine(image, qrDividerX, top + 1, topDividerY - 1);

    final int colW = (innerW - 2) ~/ 3;
    final int col1X = left + 1 + colW;
    final int col2X = left + 1 + colW * 2;
    _vLine(image, col1X, midDividerY + 1, bottom - 1);
    _vLine(image, col2X, midDividerY + 1, bottom - 1);

    // QR code (top-left of inner area).
    const int pad = 4;
    final int qrMaxW = qrColW - 1 - pad * 2;
    final int qrMaxH = topH - 1 - pad * 2;
    final int qrSize = math.max(1, math.min(qrMaxW, qrMaxH));
    final int qrX =
        left + 1 + pad + ((qrColW - 1 - pad * 2 - qrSize) ~/ 2);
    final int qrY = top + 1 + pad + ((topH - 1 - pad * 2 - qrSize) ~/ 2);

    final QrCode qrCode = QrCode.fromData(
      data: value,
      errorCorrectLevel: QrErrorCorrectLevel.M,
    );
    _drawQr(image, QrImage(qrCode), qrX, qrY, qrSize);

    // Roll number (top-right of inner area).
    final int numAreaW = innerW - qrColW - 1;
    final int numAreaH = topH - 2;
    final double numFontSize = (numAreaH * 0.75).clamp(16.0, 600.0);
    final img.Image numBitmap = await _textBitmap(
      labelData.rollNumber,
      numFontSize,
      math.max(1, numAreaW - pad * 2),
      direction: TextDirection.ltr,
      weight: FontWeight.w900,
    );
    final int numX = qrDividerX + 1 + ((numAreaW - numBitmap.width) ~/ 2);
    final int numY = top + 1 + ((numAreaH - numBitmap.height) ~/ 2);
    _composite(image, numBitmap, numX, numY);

    // Serial number (middle band of inner area).
    //
    // The serial row is the most fragile part of the label — operators
    // type the 12 digits manually when the QR fails to scan. The previous
    // sizing (`midAreaH * 0.70`) made it edge-to-edge on the real printer;
    // this block adds a separate horizontal padding ON TOP of the global
    // margin, a smaller starting font (~0.55 of the row), dynamic shrink-
    // to-fit via `_textBitmap`, and a centered "group" layout that
    // includes the optional scrap icon.
    final int midAreaH = midH - 2;
    final int serialRowPadding = math.max(effectiveMarginDots, 16);

    final int iconSize = math.max(
      16,
      math.min((heightDots * 0.14).round(), midAreaH - 4),
    );
    const int iconGap = 12;

    final int reservedIconBudget =
        labelData.isScrap ? (iconSize + iconGap) : 0;
    final int serialAvailableW = math.max(
      1,
      innerW - serialRowPadding * 2 - reservedIconBudget,
    );

    final double serialFontSize = (midAreaH * 0.55).clamp(10.0, 140.0);
    final img.Image serialBitmap = await _textBitmap(
      labelData.serialDisplay,
      serialFontSize,
      serialAvailableW,
      direction: TextDirection.ltr,
      weight: FontWeight.w700,
    );

    final img.Image? iconBitmap =
        labelData.isScrap ? await _renderScrapIcon(iconSize) : null;

    final int groupW = serialBitmap.width +
        (iconBitmap != null ? (iconGap + iconBitmap.width) : 0);
    final int groupX = left + ((innerW - groupW) ~/ 2);
    final int serialY =
        topDividerY + 1 + ((midAreaH - serialBitmap.height) ~/ 2);
    _composite(image, serialBitmap, groupX, serialY);

    if (iconBitmap != null) {
      final int iconY =
          topDividerY + 1 + ((midAreaH - iconBitmap.height) ~/ 2);
      _composite(
        image,
        iconBitmap,
        groupX + serialBitmap.width + iconGap,
        iconY,
      );
    }

    // Bottom columns (3 cells inside the inner area).
    final int botAreaH = bottom - midDividerY - 1;
    final double botFontSize = (botAreaH * 0.62).clamp(8.0, 120.0);

    await _drawBotCell(
      image,
      labelData.timeDisplay,
      botFontSize,
      x: left + 1,
      cellW: colW,
      cellTop: midDividerY + 1,
      cellH: botAreaH,
      direction: TextDirection.ltr,
    );

    await _drawBotCell(
      image,
      labelData.dateDisplay,
      botFontSize,
      x: col1X,
      cellW: colW,
      cellTop: midDividerY + 1,
      cellH: botAreaH,
      direction: TextDirection.ltr,
    );

    await _drawBotCell(
      image,
      labelData.weekdayDisplay,
      botFontSize,
      x: col2X,
      cellW: right - col2X,
      cellTop: midDividerY + 1,
      cellH: botAreaH,
      direction: TextDirection.rtl,
    );

    return LabelRenderResult(
      monochromeBytes: _toMonochrome(image),
      widthBytes: UnitConverter.dotsToBytes(alignedWidth),
      height: heightDots,
    );
  }

  Future<void> _drawBotCell(
    img.Image image,
    String text,
    double fontSize, {
    required int x,
    required int cellW,
    required int cellTop,
    required int cellH,
    required TextDirection direction,
  }) async {
    final img.Image bmp = await _textBitmap(
      text,
      fontSize,
      cellW - 4,
      direction: direction,
      weight: FontWeight.w600,
    );
    final int bx = x + (cellW - bmp.width) ~/ 2;
    final int by = cellTop + (cellH - bmp.height) ~/ 2;
    _composite(image, bmp, bx, by);
  }

  /// Renders the generic line-art creature icon used as the scrap (جرش)
  /// marker on the printed label.
  ///
  /// Drawing rules (kept simple so it prints cleanly on a 203 DPI thermal
  /// head AND so the icon is obviously not a copy of any copyrighted
  /// character):
  ///   * black strokes only, no gray fills
  ///   * stroke width scales with icon size
  ///   * silhouette = round body + two tiny ear stubs + two dot eyes +
  ///     a small smile, plus two little foot bumps
  Future<img.Image> _renderScrapIcon(int sizeDots) async {
    final double size = sizeDots.toDouble();

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas =
        Canvas(recorder, Rect.fromLTWH(0, 0, size, size));
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size, size),
      Paint()..color = const Color(0xFFFFFFFF),
    );

    final double stroke = (size * 0.08).clamp(2.0, 7.0);
    final Paint outline = Paint()
      ..color = const Color(0xFF000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final Paint filled = Paint()
      ..color = const Color(0xFF000000)
      ..style = PaintingStyle.fill;

    final double cx = size / 2;
    final double cy = size / 2;

    final Rect body = Rect.fromCenter(
      center: Offset(cx, cy + size * 0.05),
      width: size * 0.74,
      height: size * 0.68,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, Radius.circular(size * 0.30)),
      outline,
    );

    final Path earL = Path()
      ..moveTo(cx - size * 0.20, cy - size * 0.27)
      ..lineTo(cx - size * 0.28, cy - size * 0.44)
      ..lineTo(cx - size * 0.10, cy - size * 0.30)
      ..close();
    final Path earR = Path()
      ..moveTo(cx + size * 0.20, cy - size * 0.27)
      ..lineTo(cx + size * 0.28, cy - size * 0.44)
      ..lineTo(cx + size * 0.10, cy - size * 0.30)
      ..close();
    canvas.drawPath(earL, outline);
    canvas.drawPath(earR, outline);

    canvas.drawCircle(
      Offset(cx - size * 0.16, cy - size * 0.05),
      size * 0.055,
      filled,
    );
    canvas.drawCircle(
      Offset(cx + size * 0.16, cy - size * 0.05),
      size * 0.055,
      filled,
    );

    final Rect mouth = Rect.fromCenter(
      center: Offset(cx, cy + size * 0.10),
      width: size * 0.22,
      height: size * 0.14,
    );
    canvas.drawArc(mouth, 0, math.pi, false, outline);

    canvas.drawCircle(
      Offset(cx - size * 0.18, cy + size * 0.40),
      size * 0.065,
      outline,
    );
    canvas.drawCircle(
      Offset(cx + size * 0.18, cy + size * 0.40),
      size * 0.065,
      outline,
    );

    final ui.Image uiImage =
        await recorder.endRecording().toImage(sizeDots, sizeDots);
    final ByteData? byteData = await uiImage.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    if (byteData == null) return img.Image(width: 1, height: 1);

    final img.Image result =
        img.Image(width: sizeDots, height: sizeDots);
    final Uint8List pixels = byteData.buffer.asUint8List();
    for (int y = 0; y < sizeDots; y++) {
      for (int x = 0; x < sizeDots; x++) {
        final int i = (y * sizeDots + x) * 4;
        result.setPixel(
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
    return result;
  }

  // ── Legacy 4-side text layout ─────────────────────────────────────────────

  Future<LabelRenderResult> _renderLegacyLayout({
    required String value,
    required LabelPreset preset,
    String? topText,
    String? bottomText,
    String? sideText,
  }) async {
    final bool hasText =
        topText != null || bottomText != null || sideText != null;
    final LabelLayout layout =
        LabelLayout.fromPreset(preset, hasText: hasText);

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
      await _drawLegacyText(
        image,
        layout,
        topText: topText,
        bottomText: bottomText,
        sideText: sideText,
      );
    }

    _drawQr(image, qrImage, layout.qrX, layout.qrY, layout.qrSize);

    return LabelRenderResult(
      monochromeBytes: _toMonochrome(image),
      widthBytes: layout.widthBytes,
      height: layout.heightDots,
    );
  }

  Future<void> _drawLegacyText(
    img.Image image,
    LabelLayout layout, {
    String? topText,
    String? bottomText,
    String? sideText,
  }) async {
    final double fontSize = layout.mainFontHeight * 0.72;
    final int maxHorizWidth = image.width - (layout.marginDots * 2);

    if (topText != null) {
      final img.Image bitmap =
          await _textBitmap(topText, fontSize, maxHorizWidth);
      final int centerX = (image.width - bitmap.width) ~/ 2;
      _composite(image, bitmap, centerX, layout.topTextY);
    }

    if (bottomText != null) {
      final img.Image bitmap =
          await _textBitmap(bottomText, fontSize, maxHorizWidth);
      final int centerX = (image.width - bitmap.width) ~/ 2;
      _composite(image, bitmap, centerX, layout.bottomTextY);
    }

    final String? resolvedSide = sideText ?? topText ?? bottomText;
    final int sideAvailable = layout.sideBandBottom - layout.sideBandTop;
    if (sideAvailable > 0 && resolvedSide != null) {
      img.Image bitmap =
          await _textBitmap(resolvedSide, fontSize, sideAvailable);
      if (bitmap.width > sideAvailable) {
        final double scale = sideAvailable / bitmap.width;
        bitmap = img.copyResize(
          bitmap,
          width: sideAvailable,
          height: (bitmap.height * scale).round().clamp(1, bitmap.height),
          interpolation: img.Interpolation.average,
        );
      }
      final img.Image left = img.copyRotate(bitmap, angle: -90);
      final int leftY = (sideAvailable - left.height) ~/ 2;
      final int leftX = (layout.mainFontHeight - left.width) ~/ 2;
      _composite(
        image,
        left,
        layout.marginDots + leftX,
        layout.sideBandTop + leftY,
      );
      final img.Image right = img.copyRotate(bitmap, angle: 90);
      final int rightY = (sideAvailable - right.height) ~/ 2;
      final int rightX = (layout.mainFontHeight - right.width) ~/ 2;
      _composite(
        image,
        right,
        layout.widthDots -
            layout.marginDots -
            layout.mainFontHeight +
            rightX,
        layout.sideBandTop + rightY,
      );
    }
  }

  // ── Primitive helpers ─────────────────────────────────────────────────────

  /// Rasterises [text] using Flutter's `TextPainter` so Arabic and Unicode
  /// shape correctly. Returns a monochrome-friendly RGB image (black on
  /// white).
  Future<img.Image> _textBitmap(
    String text,
    double fontSize,
    num maxWidth, {
    TextDirection? direction,
    FontWeight weight = FontWeight.w600,
  }) async {
    final bool isRtl = RegExp(r'[؀-ۿݐ-ݿࢠ-ࣿ]').hasMatch(text);
    final TextDirection dir =
        direction ?? (isRtl ? TextDirection.rtl : TextDirection.ltr);
    final double mw = maxWidth.toDouble().clamp(1.0, 4096.0);

    TextPainter makePainter(double fs) => TextPainter(
          text: TextSpan(
            text: text,
            style: TextStyle(
              color: const Color(0xFF000000),
              fontSize: fs,
              fontWeight: weight,
            ),
          ),
          textDirection: dir,
          maxLines: 1,
        )..layout();

    TextPainter painter = makePainter(fontSize);

    if (painter.width > mw && mw > 0) {
      painter = makePainter(fontSize * (mw / painter.width));
    }

    final int w = painter.width.ceil().clamp(1, mw.toInt());
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

  void _composite(img.Image dest, img.Image src, int destX, int destY) {
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

  void _drawQr(img.Image image, QrImage qrImage, int qrX, int qrY, int qrSize) {
    final int moduleCount = qrImage.moduleCount;
    final int moduleSize = qrSize ~/ moduleCount;
    if (moduleSize < 1) return;

    for (int y = 0; y < moduleCount; y++) {
      for (int x = 0; x < moduleCount; x++) {
        if (qrImage.isDark(y, x)) {
          final int px = qrX + (x * moduleSize);
          final int py = qrY + (y * moduleSize);
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

  void _hLine(img.Image image, int y, int x1, int x2) {
    for (int x = x1; x <= x2; x++) {
      if (x >= 0 && x < image.width && y >= 0 && y < image.height) {
        image.setPixel(x, y, img.ColorRgba8(0, 0, 0, 255));
      }
    }
  }

  void _vLine(img.Image image, int x, int y1, int y2) {
    for (int y = y1; y <= y2; y++) {
      if (x >= 0 && x < image.width && y >= 0 && y < image.height) {
        image.setPixel(x, y, img.ColorRgba8(0, 0, 0, 255));
      }
    }
  }

  Uint8List _toMonochrome(img.Image image) {
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
