import 'package:flutter_test/flutter_test.dart';
import 'package:thermoforming_roll_worker/features/printer/domain/entities/roll_label_data.dart';

/// A printed label is permanent, so a zone slip here is unrecoverable: it can
/// shift an instant across midnight and print the wrong weekday and date on the
/// sticker. `createdAt` is backend-authoritative and must always render in
/// factory (`Asia/Hebron`) time regardless of the printing device's zone.
///
/// Inputs are explicit instants, so these assertions are device-zone
/// independent.
RollLabelData labelAt(String iso) => RollLabelData.fromParts(
  generatedRollId: '123456789012',
  rollTypeRollCode: 'TP-9 White',
  isScrap: false,
  createdAt: DateTime.parse(iso),
);

void main() {
  group('RollLabelData factory-time rendering', () {
    test('renders factory time, not UTC', () {
      // 20:09Z -> 23:09 in Hebron. Rendering the raw instant prints 08:09 مساء.
      final label = labelAt('2026-05-17T20:09:00Z');
      expect(label.timeDisplay, '11:09 مساء');
      expect(label.dateDisplay, '17-05-2026');
    });

    test('legacy +03:00 wire format prints identically to Z', () {
      final legacy = labelAt('2026-05-17T23:09:00.000+03:00');
      final modern = labelAt('2026-05-17T20:09:00Z');
      expect(legacy.timeDisplay, modern.timeDisplay);
      expect(legacy.dateDisplay, modern.dateDisplay);
      expect(legacy.weekdayDisplay, modern.weekdayDisplay);
    });

    test('a late-evening UTC instant prints the NEXT factory day', () {
      // 22:30Z Wed 2026-07-15 -> 01:30 Thu 2026-07-16 in Hebron.
      // The weekday word, not just the date, is wrong if the zone slips.
      final label = labelAt('2026-07-15T22:30:00Z');
      expect(label.dateDisplay, '16-07-2026');
      expect(label.timeDisplay, '01:30 صباحاً');
      expect(label.weekdayDisplay, 'الخميس');
    });

    test('winter instants honour the +02:00 offset', () {
      // 15:30Z -> 17:30 in Hebron (standard time), not 18:30.
      expect(labelAt('2026-02-25T15:30:12Z').timeDisplay, '05:30 مساء');
    });

    test('weekday word matches the factory-time weekday', () {
      // 2026-05-17 09:00Z is a Sunday in Hebron (12:00 local).
      expect(labelAt('2026-05-17T09:00:00Z').weekdayDisplay, 'الأحد');
      expect(labelAt('2026-05-17T09:00:00Z').timeDisplay, '12:00 مساء');
    });

    test('noon and midnight period words', () {
      // 21:00Z -> 00:00 next day in Hebron.
      expect(labelAt('2026-06-22T21:00:00Z').timeDisplay, '12:00 صباحاً');
      // 09:00Z -> 12:00 in Hebron.
      expect(labelAt('2026-06-23T09:00:00Z').timeDisplay, '12:00 مساء');
    });

    // Asia/Hebron and Asia/Jerusalem switch DST on different dates and diverge
    // for about a day, twice a year (Hebron +02:00, Jerusalem +03:00). Factory
    // devices in the region are commonly set to Israel time, so on these days a
    // `.toLocal()` label prints the wrong hour onto a permanent sticker. These
    // fixtures fail against `.toLocal()` even on a Palestine/Israel machine.
    test('prints Hebron time on days when Israel time diverges', () {
      // Jerusalem would print 03:00 مساء on both of these.
      expect(labelAt('2026-03-27T12:00:00Z').timeDisplay, '02:00 مساء');
      expect(labelAt('2026-10-24T12:00:00Z').timeDisplay, '02:00 مساء');
    });
  });
}
