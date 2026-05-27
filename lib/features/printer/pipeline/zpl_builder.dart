import 'dart:typed_data';

import '../core/zpl_constants.dart';
import 'unit_converter.dart';

/// Builds a ZPL II command stream for Zebra printers (verified on the
/// ZD230t over raw TCP port 9100 in the reference Roll Production App).
/// The output is plain ASCII — unlike TSPL, the bitmap travels embedded
/// in `^GFA` as uppercase hex rather than as a raw byte block, so the
/// whole payload composes as a single string and ships in one write.
///
/// IMPORTANT: this builder is intentionally a parallel path to
/// [TsplBuilder]. The XPrinter/TSPL flow is production-tested and must
/// not be touched by Zebra-specific changes.
///
/// Bitmap polarity:
/// - [LabelRenderer] emits TSPL-friendly bytes where bit value `1` is
///   a WHITE pixel and bit value `0` is a BLACK pixel.
/// - ZPL `^GFA` expects the opposite (`1` = black, `0` = white).
/// - We therefore invert every byte before hex-encoding it. This
///   inversion lives ONLY inside [ZplBuilder] so the TSPL path keeps
///   feeding `TsplBuilder` the renderer output untouched.
class ZplBuilder {
  /// Composes a full single-label ZPL payload. The byte-width is
  /// caller-supplied because the renderer already aligns each row to
  /// a byte boundary; the row stride passed to `^GFA` must match
  /// exactly or the printer will tear the bitmap.
  Uint8List createLabelPrint({
    required double widthMm,
    required double heightMm,
    required int bitmapWidthBytes,
    required int bitmapHeight,
    required Uint8List bitmapData,
    int copies = 1,
  }) {
    final int widthDots = UnitConverter.mmToDots(widthMm);
    final int heightDots = UnitConverter.mmToDots(heightMm);
    final int effectiveCopies = copies < 1 ? 1 : copies;
    final int totalBytes = bitmapWidthBytes * bitmapHeight;

    final String hex = _toInvertedUppercaseHex(bitmapData);

    final StringBuffer buffer = StringBuffer()
      ..write(ZplConstants.startFormat)
      ..write(ZplConstants.lineEnding)
      ..write('${ZplConstants.printWidth}$widthDots')
      ..write(ZplConstants.lineEnding)
      ..write('${ZplConstants.labelLength}$heightDots')
      ..write(ZplConstants.lineEnding)
      ..write('${ZplConstants.fieldOrigin}0,0')
      ..write(ZplConstants.lineEnding)
      ..write(
        '${ZplConstants.graphicField},$totalBytes,$totalBytes,$bitmapWidthBytes,$hex',
      )
      ..write(ZplConstants.lineEnding)
      ..write(ZplConstants.fieldSeparator)
      ..write(ZplConstants.lineEnding)
      ..write('${ZplConstants.printQuantity}$effectiveCopies')
      ..write(ZplConstants.lineEnding)
      ..write(ZplConstants.endFormat)
      ..write(ZplConstants.lineEnding);

    return Uint8List.fromList(buffer.toString().codeUnits);
  }

  /// Returns a tiny smoke-test label that bypasses `^GFA` entirely.
  /// Used by the printer-settings screen's connection-test action so an
  /// operator can confirm a printer actually speaks ZPL (a TSPL printer
  /// happily accepts a TCP socket without ever printing).
  Uint8List createSmokeTestLabel({double widthMm = 50, double heightMm = 30}) {
    final int widthDots = UnitConverter.mmToDots(widthMm);
    final int heightDots = UnitConverter.mmToDots(heightMm);

    final StringBuffer buffer = StringBuffer()
      ..write(ZplConstants.startFormat)
      ..write(ZplConstants.lineEnding)
      ..write('${ZplConstants.printWidth}$widthDots')
      ..write(ZplConstants.lineEnding)
      ..write('${ZplConstants.labelLength}$heightDots')
      ..write(ZplConstants.lineEnding)
      ..write('^CF0,40')
      ..write(ZplConstants.lineEnding)
      ..write('${ZplConstants.fieldOrigin}30,30^FDZEBRA TEST^FS')
      ..write(ZplConstants.lineEnding)
      ..write('${ZplConstants.fieldOrigin}30,90^BQN,2,4^FDLA,TEST123^FS')
      ..write(ZplConstants.lineEnding)
      ..write('${ZplConstants.printQuantity}1')
      ..write(ZplConstants.lineEnding)
      ..write(ZplConstants.endFormat)
      ..write(ZplConstants.lineEnding);

    return Uint8List.fromList(buffer.toString().codeUnits);
  }

  /// Inverts every byte (so TSPL "1 = white" becomes ZPL "1 = black")
  /// and serialises the result as uppercase hex. The inverter masks
  /// with `0xFF` so trailing-padding bits stay consistent with the
  /// flip applied to the data bits — the printer treats both the same.
  String _toInvertedUppercaseHex(Uint8List bytes) {
    final StringBuffer out = StringBuffer();
    for (int i = 0; i < bytes.length; i++) {
      final int inverted = (~bytes[i]) & 0xFF;
      final String hex = inverted.toRadixString(16).toUpperCase();
      if (hex.length == 1) out.write('0');
      out.write(hex);
    }
    return out.toString();
  }
}
