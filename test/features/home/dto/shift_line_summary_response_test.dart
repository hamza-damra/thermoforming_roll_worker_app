import 'package:flutter_test/flutter_test.dart';
import 'package:thermoforming_roll_worker/features/home/data/dto/shift_line_summary_response.dart';
import 'package:thermoforming_roll_worker/features/home/domain/entities/shift_line_summary.dart';

Map<String, dynamic> _baseJson() => <String, dynamic>{
  'shiftLineId': 102,
  'thermoformingLineCode': 'TH-01',
  'thermoformingLineName': 'خط التشكيل 1',
  'completedRollsInSession': 5,
  'completedRollsByCurrentWorker': 5,
};

Map<String, dynamic> _consumedRollJson({
  int consumptionItemId = 900,
  int rollId = 12345,
  String generatedRollId = '001000000123',
  String rollTypeCode = 'TP-1',
  String rollTypeName = 'White',
  double startWeightKg = 200.0,
  double endWeightKg = 0.0,
  double consumedWeightKg = 200.0,
  double? remainingWeightKg,
  String closedReason = 'FULL_CONSUMPTION',
  String remainderAction = 'NONE',
  String endedAt = '2026-05-23T10:00:00.000Z',
  String endedAtDisplay = '23 أيار، 10:00 ص',
}) => <String, dynamic>{
  'consumptionItemId': consumptionItemId,
  'rollId': rollId,
  'generatedRollId': generatedRollId,
  'rollTypeCode': rollTypeCode,
  'rollTypeName': rollTypeName,
  'startWeightKg': startWeightKg,
  'endWeightKg': endWeightKg,
  'consumedWeightKg': consumedWeightKg,
  'remainingWeightKg': ?remainingWeightKg,
  'closedReason': closedReason,
  'remainderAction': remainderAction,
  'endedAt': endedAt,
  'endedAtDisplay': endedAtDisplay,
};

void main() {
  group('ShiftLineSummaryResponse', () {
    test('parses the renamed completedRollsInSession counter', () {
      final ShiftLineSummaryResponse dto =
          ShiftLineSummaryResponse.fromJson(_baseJson());

      expect(dto.completedRollsInSession, 5);
      expect(dto.completedRollsByCurrentWorker, 5);
      expect(dto.toEntity().completedRollsInSession, 5);
    });

    test('parses a consumedRolls array with one full-consumption item', () {
      final Map<String, dynamic> json = _baseJson()
        ..['consumedRolls'] = <Map<String, dynamic>>[_consumedRollJson()];

      final ShiftLineSummary entity =
          ShiftLineSummaryResponse.fromJson(json).toEntity();

      expect(entity.consumedRolls, hasLength(1));
      final ConsumedRoll roll = entity.consumedRolls.first;
      expect(roll.consumptionItemId, 900);
      expect(roll.rollId, 12345);
      expect(roll.generatedRollId, '001000000123');
      expect(roll.rollTypeCode, 'TP-1');
      expect(roll.startWeightKg, 200.0);
      expect(roll.consumedWeightKg, 200.0);
      expect(roll.remainingWeightKg, isNull);
      expect(roll.closedReason, 'FULL_CONSUMPTION');
      expect(roll.remainderAction, 'NONE');
      expect(roll.endedAtDisplay, '23 أيار، 10:00 ص');
      expect(roll.endedAt, DateTime.utc(2026, 5, 23, 10, 0, 0));
    });

    test('parses a partial-return item with remainingWeightKg', () {
      final Map<String, dynamic> json = _baseJson()
        ..['consumedRolls'] = <Map<String, dynamic>>[
          _consumedRollJson(
            consumptionItemId: 901,
            startWeightKg: 200.0,
            endWeightKg: 30.0,
            consumedWeightKg: 170.0,
            remainingWeightKg: 30.0,
            closedReason: 'PARTIAL_RETURN',
            remainderAction: 'RETURN',
          ),
        ];

      final ConsumedRoll roll =
          ShiftLineSummaryResponse.fromJson(json).toEntity().consumedRolls.first;

      expect(roll.consumedWeightKg, 170.0);
      expect(roll.remainingWeightKg, 30.0);
      expect(roll.closedReason, 'PARTIAL_RETURN');
      expect(roll.remainderAction, 'RETURN');
    });

    test(
      'absent consumedRolls key tolerates older backends and yields []',
      () {
        final ShiftLineSummary entity =
            ShiftLineSummaryResponse.fromJson(_baseJson()).toEntity();

        expect(entity.consumedRolls, isEmpty);
      },
    );

    test('malformed consumedRolls (non-list) is treated as empty', () {
      final Map<String, dynamic> json = _baseJson()
        ..['consumedRolls'] = 'not-a-list';

      final ShiftLineSummary entity =
          ShiftLineSummaryResponse.fromJson(json).toEntity();

      expect(entity.consumedRolls, isEmpty);
    });

    test('explicit empty consumedRolls list yields []', () {
      final Map<String, dynamic> json = _baseJson()
        ..['consumedRolls'] = <Map<String, dynamic>>[];

      final ShiftLineSummary entity =
          ShiftLineSummaryResponse.fromJson(json).toEntity();

      expect(entity.consumedRolls, isEmpty);
    });
  });
}
