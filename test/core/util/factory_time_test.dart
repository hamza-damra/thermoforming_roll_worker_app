import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:thermoforming_roll_worker/core/util/factory_time.dart';

/// These tests pin factory-time rendering to the `Asia/Hebron` zone. They are
/// written to be **device-zone independent**: every input is an explicit
/// instant (a `Z` or `+03:00` string), never a naive `DateTime(...)` literal,
/// so the assertions hold on a CI box in any timezone.
void main() {
  group('toFactoryTime', () {
    test('renders a UTC "Z" instant in factory time, not UTC', () {
      // 20:09Z is 23:09 in Hebron (+03:00 in summer).
      final result = toFactoryTime(DateTime.parse('2026-05-17T20:09:00Z'));
      expect(DateFormat('HH:mm').format(result), '23:09');
    });

    test('legacy "+03:00" form renders identically to the "Z" form', () {
      // Dart's DateTime.parse sets isUtc=true for ANY zone designator, so both
      // wire formats parse to the same value. Cached/replayed frames in the
      // old format must therefore render the same.
      final legacy = toFactoryTime(
        DateTime.parse('2026-05-17T23:09:00.000+03:00'),
      );
      final modern = toFactoryTime(DateTime.parse('2026-05-17T20:09:00Z'));
      expect(legacy, modern);
      expect(DateFormat('HH:mm').format(legacy), '23:09');
    });

    test('summer instants use the +03:00 DST offset', () {
      final result = toFactoryTime(DateTime.parse('2026-05-17T20:09:00Z'));
      expect(result.timeZoneOffset, const Duration(hours: 3));
      expect(DateFormat('HH:mm').format(result), '23:09');
    });

    test('winter instants use the +02:00 standard offset', () {
      // A hardcoded +03:00 offset would render 18:30 here and fail.
      final result = toFactoryTime(DateTime.parse('2026-02-25T15:30:12Z'));
      expect(result.timeZoneOffset, const Duration(hours: 2));
      expect(DateFormat('HH:mm').format(result), '17:30');
    });

    test('a late-evening UTC instant belongs to the NEXT factory day', () {
      // 22:30Z on 07-15 is 01:30 on 07-16 in Hebron. Slicing the UTC date
      // prefix would report the wrong production day.
      final result = toFactoryTime(DateTime.parse('2026-07-15T22:30:00Z'));
      expect(DateFormat('yyyy-MM-dd').format(result), '2026-07-16');
      expect(DateFormat('HH:mm').format(result), '01:30');
    });

    test('a local (non-UTC) DateTime is normalised via toUtc()', () {
      final instant = DateTime.parse('2026-05-17T20:09:00Z');
      // .toLocal() changes the isUtc flag but not the instant; factory
      // rendering must be identical either way.
      expect(toFactoryTime(instant.toLocal()), toFactoryTime(instant));
    });

    test('factory zone is Asia/Hebron', () {
      expect(factoryZone.name, factoryTimeZoneName);
      expect(factoryTimeZoneName, 'Asia/Hebron');
    });

    // ── The regression guard with teeth on a Palestine/Israel dev box ────────
    //
    // Asia/Hebron is NOT Asia/Jerusalem: they switch DST on different dates and
    // diverge for roughly one day twice a year. Inside those windows Hebron is
    // +02:00 while Jerusalem is +03:00.
    //
    // This matters in production: factory devices in the region are commonly
    // set to Israel time, and on these days `.toLocal()` renders an hour late.
    // Every other fixture in this suite would pass against the old `.toLocal()`
    // implementation on such a device — these two would not.
    group('Hebron/Jerusalem DST divergence (catches .toLocal() regressions)', () {
      test('spring window: Hebron is +02:00 while Jerusalem is +03:00', () {
        final result = toFactoryTime(DateTime.parse('2026-03-27T12:00:00Z'));
        expect(result.timeZoneOffset, const Duration(hours: 2));
        // Jerusalem would render 15:00 here.
        expect(DateFormat('HH:mm').format(result), '14:00');
      });

      test('autumn window: Hebron is +02:00 while Jerusalem is +03:00', () {
        final result = toFactoryTime(DateTime.parse('2026-10-24T12:00:00Z'));
        expect(result.timeZoneOffset, const Duration(hours: 2));
        // Jerusalem would render 15:00 here.
        expect(DateFormat('HH:mm').format(result), '14:00');
      });
    });
  });
}
