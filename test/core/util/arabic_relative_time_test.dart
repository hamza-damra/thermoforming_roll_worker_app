import 'package:flutter_test/flutter_test.dart';
import 'package:thermoforming_roll_worker/core/util/arabic_relative_time.dart';

void main() {
  final DateTime now = DateTime.utc(2026, 5, 29, 12, 0, 0);

  String since(Duration ago) =>
      formatArabicRelativeTime(now.subtract(ago), now: now);

  group('formatArabicRelativeTime', () {
    test('less than a minute', () {
      expect(since(const Duration(seconds: 30)), 'منذ أقل من دقيقة');
    });

    test('exactly one minute', () {
      expect(since(const Duration(minutes: 1)), 'منذ دقيقة واحدة');
    });

    test('two minutes (dual)', () {
      expect(since(const Duration(minutes: 2)), 'منذ دقيقتين');
    });

    test('30 minutes (11+ form)', () {
      expect(since(const Duration(minutes: 30)), 'منذ ٣٠ دقيقة');
    });

    test('one hour', () {
      expect(since(const Duration(hours: 1)), 'منذ ساعة واحدة');
    });

    test('5 hours and 10 minutes', () {
      expect(
        since(const Duration(hours: 5, minutes: 10)),
        'منذ ٥ ساعات و١٠ دقائق',
      );
    });

    test('2 days, 5 hours and 5 minutes', () {
      expect(
        since(const Duration(days: 2, hours: 5, minutes: 5)),
        'منذ يومين و٥ ساعات و٥ دقائق',
      );
    });

    test('future / clock-skewed timestamp clamps to "less than a minute"', () {
      expect(
        formatArabicRelativeTime(
          now.add(const Duration(hours: 1)),
          now: now,
        ),
        'منذ أقل من دقيقة',
      );
    });
  });
}
