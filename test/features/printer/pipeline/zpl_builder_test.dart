import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:thermoforming_roll_worker/features/printer/pipeline/zpl_builder.dart';

void main() {
  group('ZplBuilder.createLabelPrint', () {
    test('emits the ZPL envelope and core fields for a 100×100 mm label', () {
      // 100 mm × 203 dpi / 25.4 mm/in ≈ 799 dots.
      final Uint8List bitmap = Uint8List.fromList(<int>[0xFF, 0x00]);
      final Uint8List payload = ZplBuilder().createLabelPrint(
        widthMm: 100,
        heightMm: 100,
        bitmapWidthBytes: 1,
        bitmapHeight: 2,
        bitmapData: bitmap,
        copies: 2,
      );
      final String text = String.fromCharCodes(payload);

      expect(text, contains('^XA'));
      expect(text, contains('^XZ'));
      expect(text, contains('^PW799'));
      expect(text, contains('^LL799'));
      expect(text, contains('^FO0,0'));
      expect(text, contains('^GFA,2,2,1,'));
      expect(text, contains('^FS'));
      expect(text, contains('^PQ2'));
    });

    test('inverts bitmap bytes when hex-encoding (TSPL→ZPL polarity flip)',
        () {
      // 0xFF (all-white in TSPL) → 0x00 (all-white in ZPL after inversion).
      // 0x00 (all-black in TSPL) → 0xFF (all-black in ZPL).
      final Uint8List bitmap = Uint8List.fromList(<int>[0xFF, 0x00, 0xA5]);
      final Uint8List payload = ZplBuilder().createLabelPrint(
        widthMm: 50,
        heightMm: 50,
        bitmapWidthBytes: 1,
        bitmapHeight: 3,
        bitmapData: bitmap,
      );
      final String text = String.fromCharCodes(payload);

      // The bitmap section ends just before the line-ending after the hex
      // payload — the assertion is that the inverted hex sequence appears.
      // (~0xFF & 0xFF == 0x00, ~0x00 & 0xFF == 0xFF, ~0xA5 & 0xFF == 0x5A).
      expect(text, contains('00FF5A'));
      // The literal raw bitmap hex should NOT appear (proves inversion).
      expect(text.contains('FF005A'), isFalse);
    });

    test('copies < 1 is normalised to ^PQ1', () {
      final Uint8List payload = ZplBuilder().createLabelPrint(
        widthMm: 40,
        heightMm: 30,
        bitmapWidthBytes: 1,
        bitmapHeight: 1,
        bitmapData: Uint8List(1),
        copies: 0,
      );
      final String text = String.fromCharCodes(payload);
      expect(text, contains('^PQ1'));
    });

    test('payload is pure ASCII (no raw binary blobs unlike TSPL)', () {
      final Uint8List payload = ZplBuilder().createLabelPrint(
        widthMm: 50,
        heightMm: 30,
        bitmapWidthBytes: 1,
        bitmapHeight: 1,
        bitmapData: Uint8List.fromList(<int>[0xAB]),
      );
      for (final int byte in payload) {
        expect(byte, lessThan(128),
            reason: 'ZPL output must be 7-bit ASCII');
      }
    });
  });
}
