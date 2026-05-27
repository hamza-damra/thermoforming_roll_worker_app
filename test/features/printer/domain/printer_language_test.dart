import 'package:flutter_test/flutter_test.dart';
import 'package:thermoforming_roll_worker/features/printer/domain/entities/printer_language.dart';

void main() {
  group('PrinterLanguage', () {
    test('wireToken / displayNameAr / shortBadge are stable', () {
      expect(PrinterLanguage.tspl.wireToken, 'tspl');
      expect(PrinterLanguage.zpl.wireToken, 'zpl');
      expect(PrinterLanguage.tspl.displayNameAr, 'Xprinter / TSPL');
      expect(PrinterLanguage.zpl.displayNameAr, 'Zebra / ZPL');
      expect(PrinterLanguage.tspl.shortBadge, 'TSPL');
      expect(PrinterLanguage.zpl.shortBadge, 'ZPL');
    });

    test('fromWireToken round-trips known tokens', () {
      for (final PrinterLanguage v in PrinterLanguage.values) {
        expect(PrinterLanguage.fromWireToken(v.wireToken), v);
      }
    });

    test('fromWireToken(null) → tspl (back-compat for legacy 6-field records)',
        () {
      expect(PrinterLanguage.fromWireToken(null), PrinterLanguage.tspl);
    });

    test('fromWireToken(unknown) → tspl (defensive fallback)', () {
      expect(PrinterLanguage.fromWireToken('UNKNOWN_FUTURE_TOKEN'),
          PrinterLanguage.tspl);
      expect(PrinterLanguage.fromWireToken(''), PrinterLanguage.tspl);
    });
  });
}
