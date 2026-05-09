import 'dart:typed_data';

import '../core/printing_constants.dart';
import '../core/tspl_constants.dart';

/// Fluent TSPL command-stream assembler. Adapted from
/// `roll_production_app`'s validated pipeline.
class TsplBuilder {
  final StringBuffer _commands = StringBuffer();

  TsplBuilder size(double widthMm, double heightMm) {
    _commands.write('SIZE $widthMm mm,$heightMm mm${TsplConstants.lineEnding}');
    return this;
  }

  TsplBuilder gap(double gapMm) {
    _commands.write('GAP $gapMm mm,0.0 mm${TsplConstants.lineEnding}');
    return this;
  }

  TsplBuilder direction() {
    _commands.write('${TsplConstants.direction}${TsplConstants.lineEnding}');
    return this;
  }

  TsplBuilder offset() {
    _commands.write('${TsplConstants.offset}${TsplConstants.lineEnding}');
    return this;
  }

  TsplBuilder shift() {
    _commands.write('${TsplConstants.shift}${TsplConstants.lineEnding}');
    return this;
  }

  TsplBuilder reference() {
    _commands.write('${TsplConstants.reference}${TsplConstants.lineEnding}');
    return this;
  }

  TsplBuilder setPeelOff() {
    _commands.write('${TsplConstants.setPeelOff}${TsplConstants.lineEnding}');
    return this;
  }

  TsplBuilder setTearOn() {
    _commands.write('${TsplConstants.setTearOn}${TsplConstants.lineEnding}');
    return this;
  }

  TsplBuilder setCutterOff() {
    _commands.write('${TsplConstants.setCutterOff}${TsplConstants.lineEnding}');
    return this;
  }

  TsplBuilder cls() {
    _commands.write('${TsplConstants.cls}${TsplConstants.lineEnding}');
    return this;
  }

  /// Writes the BITMAP header. The raw bitmap bytes are appended by the
  /// caller (see [createLabelPrint]).
  TsplBuilder bitmap(int x, int y, int widthBytes, int height) {
    _commands.write('BITMAP $x,$y,$widthBytes,$height,0,');
    return this;
  }

  TsplBuilder printSet(int sets, int copies) {
    _commands.write('PRINT $sets,$copies${TsplConstants.lineEnding}');
    return this;
  }

  String build() => _commands.toString();

  /// Assembles a complete print job: setup commands → BITMAP header →
  /// raw bitmap bytes → PRINT command.
  Uint8List createLabelPrint({
    required double widthMm,
    required double heightMm,
    required int bitmapWidthBytes,
    required int bitmapHeight,
    required Uint8List bitmapData,
    int copies = 1,
    double gapMm = PrintingConstants.defaultGapMm,
  }) {
    final TsplBuilder pre = TsplBuilder()
      ..size(widthMm, heightMm)
      ..gap(gapMm)
      ..direction()
      ..offset()
      ..shift()
      ..reference()
      ..setPeelOff()
      ..setTearOn()
      ..setCutterOff()
      ..cls()
      ..bitmap(0, 0, bitmapWidthBytes, bitmapHeight);
    final Uint8List preBytes = Uint8List.fromList(pre.build().codeUnits);

    final TsplBuilder post = TsplBuilder()..printSet(1, copies);
    final Uint8List postBytes = Uint8List.fromList(post.build().codeUnits);

    final Uint8List out = Uint8List(
      preBytes.length + bitmapData.length + postBytes.length,
    );
    out.setAll(0, preBytes);
    out.setAll(preBytes.length, bitmapData);
    out.setAll(preBytes.length + bitmapData.length, postBytes);
    return out;
  }
}
