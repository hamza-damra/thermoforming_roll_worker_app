import 'package:flutter_test/flutter_test.dart';
import 'package:thermoforming_roll_worker/core/util/factory_time.dart';
import 'package:thermoforming_roll_worker/features/printer/domain/entities/roll_label_data.dart';
import 'package:thermoforming_roll_worker/features/roll_search/domain/entities/production_time_input.dart';
import 'package:timezone/timezone.dart' as tz;

ProductionTimeInput _valid({
  String year = '2026',
  String month = '9',
  String day = '30',
  String hour = '2',
  String minute = '5',
  ClockPeriod? period = ClockPeriod.pm,
}) => ProductionTimeInput(
  year: year,
  month: month,
  day: day,
  hour: hour,
  minute: minute,
  period: period,
);

void main() {
  group('ProductionTimeInput.validate', () {
    test('a real minute has no errors', () {
      expect(_valid().validate(), isEmpty);
    });

    test('an empty form reports every field, in form order', () {
      final errors = const ProductionTimeInput().validate();
      expect(errors.keys.toList(), <ProductionTimeField>[
        ProductionTimeField.year,
        ProductionTimeField.month,
        ProductionTimeField.day,
        ProductionTimeField.hour,
        ProductionTimeField.minute,
        ProductionTimeField.period,
      ]);
    });

    for (final ProductionTimeField f in ProductionTimeField.values) {
      test('${f.name} is required', () {
        final ProductionTimeInput input = switch (f) {
          ProductionTimeField.year => _valid(year: ''),
          ProductionTimeField.month => _valid(month: ''),
          ProductionTimeField.day => _valid(day: ''),
          ProductionTimeField.hour => _valid(hour: ''),
          ProductionTimeField.minute => _valid(minute: ''),
          ProductionTimeField.period => _valid(period: null),
        };
        final errors = input.validate();
        expect(errors.keys, <ProductionTimeField>[f]);
        expect(errors[f], isNotEmpty);
        expect(input.toQuery(), isNull);
      });
    }

    test('whitespace-only text counts as empty', () {
      expect(_valid(year: '  ').validate().keys, [ProductionTimeField.year]);
    });

    test('non-numeric text is out of range', () {
      expect(_valid(day: 'ab').validate().keys, [ProductionTimeField.day]);
    });

    test('year range 2000..2099 edges', () {
      expect(_valid(year: '2000').validate(), isEmpty);
      expect(_valid(year: '2099').validate(), isEmpty);
      expect(_valid(year: '1999').validate().keys, [ProductionTimeField.year]);
      expect(_valid(year: '2100').validate().keys, [ProductionTimeField.year]);
    });

    test('month range 1..12 edges', () {
      expect(_valid(month: '1').validate(), isEmpty);
      expect(_valid(month: '12').validate(), isEmpty);
      expect(_valid(month: '0').validate().keys, [ProductionTimeField.month]);
      expect(_valid(month: '13').validate().keys, [ProductionTimeField.month]);
    });

    test('day range 1..31 edges', () {
      expect(_valid(day: '1').validate(), isEmpty);
      expect(_valid(day: '31', month: '12').validate(), isEmpty);
      expect(_valid(day: '0').validate().keys, [ProductionTimeField.day]);
      expect(_valid(day: '32').validate().keys, [ProductionTimeField.day]);
    });

    test('hour range 1..12 edges (12-hour clock)', () {
      expect(_valid(hour: '1').validate(), isEmpty);
      expect(_valid(hour: '12').validate(), isEmpty);
      expect(_valid(hour: '0').validate().keys, [ProductionTimeField.hour]);
      expect(_valid(hour: '13').validate().keys, [ProductionTimeField.hour]);
    });

    test('minute range 0..59 edges', () {
      expect(_valid(minute: '0').validate(), isEmpty);
      expect(_valid(minute: '59').validate(), isEmpty);
      expect(
        _valid(minute: '60').validate().keys,
        [ProductionTimeField.minute],
      );
      expect(
        _valid(minute: '-1').validate().keys,
        [ProductionTimeField.minute],
      );
    });

    test('valid extremes together', () {
      expect(
        _valid(
          year: '2000',
          month: '1',
          day: '1',
          hour: '12',
          minute: '0',
          period: ClockPeriod.am,
        ).validate(),
        isEmpty,
      );
      expect(
        _valid(
          year: '2099',
          month: '12',
          day: '31',
          hour: '12',
          minute: '59',
        ).validate(),
        isEmpty,
      );
    });

    test('31 April is not a real date', () {
      final errors = _valid(month: '4', day: '31').validate();
      expect(errors.keys, [ProductionTimeField.day]);
      expect(errors[ProductionTimeField.day], contains('غير موجود'));
    });

    test('29 Feb 2026 invalid, 29 Feb 2028 valid', () {
      expect(
        _valid(year: '2026', month: '2', day: '29').validate().keys,
        [ProductionTimeField.day],
      );
      expect(_valid(year: '2028', month: '2', day: '29').validate(), isEmpty);
      expect(_valid(year: '2027', month: '2', day: '28').validate(), isEmpty);
    });

    test('an out-of-range month does not add a misleading day error', () {
      final errors = _valid(month: '13', day: '31').validate();
      expect(errors.keys, [ProductionTimeField.month]);
    });
  });

  group('ProductionTimeInput.to24Hour', () {
    test('12-hour to 24-hour conversion', () {
      expect(ProductionTimeInput.to24Hour(12, ClockPeriod.am), 0);
      expect(ProductionTimeInput.to24Hour(12, ClockPeriod.pm), 12);
      expect(ProductionTimeInput.to24Hour(1, ClockPeriod.pm), 13);
      expect(ProductionTimeInput.to24Hour(1, ClockPeriod.am), 1);
      expect(ProductionTimeInput.to24Hour(11, ClockPeriod.am), 11);
      expect(ProductionTimeInput.to24Hour(11, ClockPeriod.pm), 23);
    });
  });

  group('ProductionTimeInput.daysInMonth', () {
    test('lengths incl. leap years', () {
      expect(ProductionTimeInput.daysInMonth(2026, 4), 30);
      expect(ProductionTimeInput.daysInMonth(2026, 12), 31);
      expect(ProductionTimeInput.daysInMonth(2026, 2), 28);
      expect(ProductionTimeInput.daysInMonth(2028, 2), 29);
    });
  });

  group('ProductionTimeInput.toQuery', () {
    test('converts to a 24-hour backend query', () {
      final q = _valid(hour: '2', minute: '05').toQuery()!;
      expect(q.toQueryParameters(), <String, Object>{
        'year': 2026,
        'month': 9,
        'day': 30,
        'hour': 14,
        'minute': 5,
      });
    });

    test('12 صباحاً is hour 0 and 12 مساء is hour 12', () {
      expect(_valid(hour: '12', period: ClockPeriod.am).toQuery()!.hour24, 0);
      expect(_valid(hour: '12', period: ClockPeriod.pm).toQuery()!.hour24, 12);
    });

    test('equality and hashCode', () {
      final a = _valid().toQuery()!;
      final b = _valid().toQuery()!;
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(_valid(minute: '6').toQuery()));
    });

    test('copyWith keeps untouched fields', () {
      final c = _valid().copyWith(minute: '9');
      expect(c.minute, '9');
      expect(c.year, '2026');
      expect(c.period, ClockPeriod.pm);
    });
  });

  group('ProductionTimeInput.labelPreview', () {
    test('null while invalid', () {
      expect(_valid(day: '31', month: '4').labelPreview(), isNull);
      expect(const ProductionTimeInput().labelPreview(), isNull);
    });

    test('reads exactly like the roll label for the same factory minute', () {
      // Every hour/period edge plus dates that would shift weekday if a zone
      // conversion were applied to the calendar value.
      final List<({int y, int mo, int d, int h24, int mi})> cases =
          <({int y, int mo, int d, int h24, int mi})>[
            (y: 2026, mo: 9, d: 30, h24: 14, mi: 5),
            (y: 2026, mo: 9, d: 30, h24: 0, mi: 0),
            (y: 2026, mo: 9, d: 30, h24: 12, mi: 0),
            (y: 2026, mo: 1, d: 1, h24: 23, mi: 59),
            (y: 2028, mo: 2, d: 29, h24: 9, mi: 14),
            (y: 2026, mo: 12, d: 6, h24: 11, mi: 30),
          ];
      for (final c in cases) {
        final tz.TZDateTime instant = tz.TZDateTime(
          factoryZone,
          c.y,
          c.mo,
          c.d,
          c.h24,
          c.mi,
        );
        final label = RollLabelData(
          generatedRollId: '777000000001',
          rollNumber: '1',
          isScrap: false,
          createdAt: instant.toUtc(),
        );
        final int h12 = c.h24 % 12 == 0 ? 12 : c.h24 % 12;
        final input = ProductionTimeInput(
          year: '${c.y}',
          month: '${c.mo}',
          day: '${c.d}',
          hour: '$h12',
          minute: '${c.mi}',
          period: c.h24 < 12 ? ClockPeriod.am : ClockPeriod.pm,
        );
        final preview = input.labelPreview()!;
        expect(preview.weekday, label.weekdayDisplay, reason: '$c');
        expect(preview.date, label.dateDisplay, reason: '$c');
        expect(preview.time, label.timeDisplay, reason: '$c');
        // And the query's 24-hour value is that same factory hour.
        expect(input.toQuery()!.hour24, c.h24, reason: '$c');
      }
    });
  });

  group('ClockPeriod', () {
    test('label text matches the roll label', () {
      expect(ClockPeriod.am.labelText, 'صباحاً');
      expect(ClockPeriod.pm.labelText, 'مساء');
    });
  });
}
