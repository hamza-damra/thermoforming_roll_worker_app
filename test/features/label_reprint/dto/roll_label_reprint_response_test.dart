import 'package:flutter_test/flutter_test.dart';
import 'package:thermoforming_roll_worker/features/label_reprint/data/dto/roll_label_reprint_response.dart';
import 'package:thermoforming_roll_worker/features/label_reprint/domain/entities/roll_label.dart';

Map<String, dynamic> _payload({String state = 'PARTIALLY_RETURNED'}) =>
    <String, dynamic>{
      'generatedRollId': '777000000001',
      'prefixSnapshot': '777',
      'serialNumber': 1,
      'rollTypeId': 70,
      'rollTypeRollCode': 'TT-1S B250 White',
      'rollTypeDisplayName': 'TT-1S B250',
      'colorName': 'White',
      'standardLengthM': 100.0,
      'standardWeightKg': 250.0,
      'actualLengthM': 99.5,
      'actualWeightKg': 248.0,
      'actualThicknessMm': 0.250,
      'productionKind': 'NORMAL',
      'consumptionState': state,
      'lastKnownWeightKg': 75.5,
    };

void main() {
  group('RollLabelReprintResponse.fromJson', () {
    test('parses every documented field with PARTIALLY_RETURNED', () {
      final RollLabelReprintResponse dto = RollLabelReprintResponse.fromJson(
        _payload(),
      );
      expect(dto.generatedRollId, '777000000001');
      expect(dto.prefixSnapshot, '777');
      expect(dto.serialNumber, 1);
      expect(dto.rollTypeRollCode, 'TT-1S B250 White');
      expect(dto.rollTypeDisplayName, 'TT-1S B250');
      expect(dto.colorName, 'White');
      expect(dto.standardLengthM, 100.0);
      expect(dto.actualWeightKg, 248.0);
      expect(dto.consumptionState, RollConsumptionState.partiallyReturned);
      expect(dto.lastKnownWeightKg, 75.5);
    });

    test('parses SENT_TO_GRINDING', () {
      final RollLabelReprintResponse dto = RollLabelReprintResponse.fromJson(
        _payload(state: 'SENT_TO_GRINDING'),
      );
      expect(dto.consumptionState, RollConsumptionState.sentToGrinding);
    });

    test('rejects unknown consumption state with FormatException', () {
      expect(
        () => RollLabelReprintResponse.fromJson(
          _payload(state: 'BRAND_NEW_STATE'),
        ),
        throwsFormatException,
      );
    });

    test('toEntity copies every field into RollLabel', () {
      final RollLabel entity = RollLabelReprintResponse.fromJson(
        _payload(),
      ).toEntity();
      expect(entity.generatedRollId, '777000000001');
      expect(entity.isPartiallyReturned, isTrue);
      expect(entity.isSentToGrinding, isFalse);
    });
  });

  group('RollConsumptionState', () {
    test('fromWire round-trips every documented value', () {
      const Map<String, RollConsumptionState> wire =
          <String, RollConsumptionState>{
            'AVAILABLE': RollConsumptionState.available,
            'IN_CONSUMPTION': RollConsumptionState.inConsumption,
            'CONSUMED': RollConsumptionState.consumed,
            'PARTIALLY_RETURNED': RollConsumptionState.partiallyReturned,
            'SENT_TO_GRINDING': RollConsumptionState.sentToGrinding,
            'BLOCKED': RollConsumptionState.blocked,
          };
      wire.forEach((String w, RollConsumptionState e) {
        expect(RollConsumptionState.fromWire(w), e, reason: w);
      });
    });

    test('fromWire returns null for unknown / null', () {
      expect(RollConsumptionState.fromWire(null), isNull);
      expect(RollConsumptionState.fromWire('UNRELEASED'), isNull);
    });
  });
}
