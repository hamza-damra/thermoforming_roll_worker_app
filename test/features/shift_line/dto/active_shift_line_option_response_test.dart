import 'package:flutter_test/flutter_test.dart';
import 'package:thermoforming_roll_worker/features/shift_line/data/dto/active_shift_line_option_response.dart';

void main() {
  group('ActiveShiftLineOptionResponse.fromJson', () {
    test('parses an active line that has no roll mounted yet', () {
      final ActiveShiftLineOptionResponse dto =
          ActiveShiftLineOptionResponse.fromJson(const <String, dynamic>{
            'shiftLineId': 500,
            'thermoformingShiftId': 100,
            'thermoformingLineId': 10,
            'thermoformingLineCode': 'TH-01',
            'thermoformingLineName': 'Thermo 1',
            'palletizingLineId': 20,
            'palletizingLineCode': 'PL-01',
            'palletizingLineName': 'Palletizer 1',
            'currentProductTypeId': 50,
            'currentProductTypeName': 'Cup-200ml',
            'currentRollId': null,
            'currentRollGeneratedRollId': null,
            'currentRollTypeCode': null,
            'currentRollTypeName': null,
            'currentRollLastKnownWeightKg': null,
            'operatorId': 7,
            'operatorName': 'محمد',
            'shiftLineStatus': 'ACTIVE',
            'selectable': true,
            'blockingReason': null,
          });

      expect(dto.shiftLineId, 500);
      expect(dto.thermoformingLineCode, 'TH-01');
      expect(dto.palletizingLineName, 'Palletizer 1');
      expect(dto.currentProductTypeName, 'Cup-200ml');
      expect(dto.currentRollId, isNull);
      expect(dto.currentRollLastKnownWeightKg, isNull);
      expect(dto.selectable, isTrue);
      expect(dto.blockingReason, isNull);
    });

    test('parses an active line with mounted roll, weight as decimal string',
        () {
      final ActiveShiftLineOptionResponse dto =
          ActiveShiftLineOptionResponse.fromJson(const <String, dynamic>{
            'shiftLineId': 501,
            'thermoformingShiftId': 100,
            'thermoformingLineId': 11,
            'thermoformingLineCode': 'TH-02',
            'thermoformingLineName': 'Thermo 2',
            'palletizingLineId': 21,
            'palletizingLineCode': 'PL-02',
            'palletizingLineName': 'Palletizer 2',
            'currentProductTypeId': 50,
            'currentProductTypeName': 'Cup-200ml',
            'currentRollId': 900,
            'currentRollGeneratedRollId': '001000000123',
            'currentRollTypeCode': 'RT-A',
            'currentRollTypeName': 'Regular Black',
            'currentRollLastKnownWeightKg': '180.500',
            'operatorId': 7,
            'operatorName': 'محمد',
            'shiftLineStatus': 'ACTIVE',
            'selectable': true,
            'blockingReason': null,
          });

      expect(dto.currentRollId, 900);
      expect(dto.currentRollGeneratedRollId, '001000000123');
      expect(dto.currentRollTypeCode, 'RT-A');
      expect(dto.currentRollTypeName, 'Regular Black');
      expect(dto.currentRollLastKnownWeightKg, 180.5);
    });

    test('selectable defaults to true when missing (forward compat)', () {
      final ActiveShiftLineOptionResponse dto =
          ActiveShiftLineOptionResponse.fromJson(const <String, dynamic>{
            'shiftLineId': 1,
            'thermoformingShiftId': 1,
            'thermoformingLineId': 1,
            'thermoformingLineCode': 'TH',
            'thermoformingLineName': 'L',
            'palletizingLineId': 1,
            'palletizingLineCode': 'PL',
            'palletizingLineName': 'P',
            'currentProductTypeId': null,
            'currentProductTypeName': null,
            'currentRollId': null,
            'currentRollGeneratedRollId': null,
            'currentRollTypeCode': null,
            'currentRollTypeName': null,
            'currentRollLastKnownWeightKg': null,
            'operatorId': null,
            'operatorName': null,
            'shiftLineStatus': 'ACTIVE',
            'blockingReason': null,
          });
      expect(dto.selectable, isTrue);
    });

    test('toEntity preserves every field', () {
      final ActiveShiftLineOptionResponse dto =
          ActiveShiftLineOptionResponse.fromJson(const <String, dynamic>{
            'shiftLineId': 501,
            'thermoformingShiftId': 100,
            'thermoformingLineId': 11,
            'thermoformingLineCode': 'TH-02',
            'thermoformingLineName': 'Thermo 2',
            'palletizingLineId': 21,
            'palletizingLineCode': 'PL-02',
            'palletizingLineName': 'Palletizer 2',
            'currentProductTypeId': 50,
            'currentProductTypeName': 'Cup-200ml',
            'currentRollId': 900,
            'currentRollGeneratedRollId': '001000000123',
            'currentRollTypeCode': 'RT-A',
            'currentRollTypeName': 'Regular Black',
            'currentRollLastKnownWeightKg': '180.500',
            'operatorId': 7,
            'operatorName': 'محمد',
            'shiftLineStatus': 'ACTIVE',
            'selectable': true,
            'blockingReason': null,
          });

      final entity = dto.toEntity();
      expect(entity.shiftLineId, 501);
      expect(entity.hasMountedRoll, isTrue);
      expect(entity.currentRollLastKnownWeightKg, 180.5);
      expect(entity.operatorName, 'محمد');
    });
  });
}
