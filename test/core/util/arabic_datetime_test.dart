import 'package:flutter_test/flutter_test.dart';
import 'package:thermoforming_roll_worker/core/util/arabic_datetime.dart';

/// Inputs are explicit instants rather than naive `DateTime(...)` literals, so
/// these assertions are device-zone independent: they pin the rendered value to
/// factory (`Asia/Hebron`) time and pass on a CI box in any timezone.
void main() {
  group('formatArabicDateTime', () {
    test('null input returns null', () {
      expect(formatArabicDateTime(null), isNull);
    });

    test('morning time uses صباحًا and 12-hour clock', () {
      // 07:30Z -> 10:30 in Hebron (+03:00, summer).
      expect(
        formatArabicDateTime(DateTime.parse('2026-06-23T07:30:00Z')),
        '23-06-2026، 10:30 صباحًا',
      );
    });

    test('afternoon time uses مساءً and wraps the hour', () {
      // 11:05Z -> 14:05 in Hebron.
      expect(
        formatArabicDateTime(DateTime.parse('2026-06-23T11:05:00Z')),
        '23-06-2026، 02:05 مساءً',
      );
    });

    test('midnight renders as 12:00 صباحًا', () {
      // 21:00Z on 06-22 -> 00:00 on 06-23 in Hebron.
      expect(
        formatArabicDateTime(DateTime.parse('2026-06-22T21:00:00Z')),
        '23-06-2026، 12:00 صباحًا',
      );
    });

    test('noon renders as 12:00 مساءً', () {
      // 09:00Z -> 12:00 in Hebron.
      expect(
        formatArabicDateTime(DateTime.parse('2026-06-23T09:00:00Z')),
        '23-06-2026، 12:00 مساءً',
      );
    });

    test('renders factory time, not UTC', () {
      // The regression this whole change exists for: formatting the raw
      // instant would render 20:09 (08:09 مساءً).
      expect(
        formatArabicDateTime(DateTime.parse('2026-05-17T20:09:00Z')),
        '17-05-2026، 11:09 مساءً',
      );
    });

    test('legacy +03:00 wire format renders identically to Z', () {
      expect(
        formatArabicDateTime(DateTime.parse('2026-05-17T23:09:00.000+03:00')),
        formatArabicDateTime(DateTime.parse('2026-05-17T20:09:00Z')),
      );
    });

    test('winter instants honour the +02:00 offset', () {
      // 15:30Z -> 17:30 in Hebron (standard time), not 18:30.
      expect(
        formatArabicDateTime(DateTime.parse('2026-02-25T15:30:12Z')),
        '25-02-2026، 05:30 مساءً',
      );
    });

    test('a late-evening UTC instant renders on the next factory day', () {
      expect(
        formatArabicDateTime(DateTime.parse('2026-07-15T22:30:00Z')),
        '16-07-2026، 01:30 صباحًا',
      );
    });
  });

  group('tryParseTimestamp', () {
    test('parses an ISO-8601 string with offset', () {
      final parsed = tryParseTimestamp('2026-06-23T10:30:00.000+03:00');
      expect(parsed, isNotNull);
      expect(parsed, DateTime.parse('2026-06-23T10:30:00.000+03:00'));
    });

    test('parses a UTC "Z" string to the same instant as its offset form', () {
      expect(
        tryParseTimestamp('2026-05-17T20:09:00Z'),
        tryParseTimestamp('2026-05-17T23:09:00.000+03:00'),
      );
    });

    test('passes a DateTime through unchanged', () {
      final dt = DateTime(2026, 6, 23, 10, 30);
      expect(tryParseTimestamp(dt), dt);
    });

    test('returns null for null / empty / garbage / wrong type', () {
      expect(tryParseTimestamp(null), isNull);
      expect(tryParseTimestamp(''), isNull);
      expect(tryParseTimestamp('   '), isNull);
      expect(tryParseTimestamp('not-a-date'), isNull);
      expect(tryParseTimestamp(12345), isNull);
    });
  });
}
