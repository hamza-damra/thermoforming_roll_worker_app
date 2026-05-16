import 'package:flutter_test/flutter_test.dart';
import 'package:thermoforming_roll_worker/features/roll_scan/data/dto/thermoforming_roll_scan_response.dart';

void main() {
  group('ThermoformingRollScanResponse', () {
    test('fromJson parses every documented field', () {
      final ThermoformingRollScanResponse dto =
          ThermoformingRollScanResponse.fromJson(const <String, dynamic>{
            'rollId': 999,
            'generatedRollId': '777000000001',
            'rollTypeId': 70,
            'rollTypeRollCode': 'TT-1S B250 White',
            'rollTypeDisplayName': 'TT-1S B250',
            'colorName': 'White',
            'productTypeId': 5,
            'productTypeName': 'أحمر 20 كغ',
            'consumptionItemId': 5000,
            'activeSegmentId': 6000,
            'state': 'IN_CONSUMPTION',
            'lastKnownWeightKg': 250.000,
          });

      expect(dto.rollId, 999);
      expect(dto.generatedRollId, '777000000001');
      expect(dto.rollTypeId, 70);
      expect(dto.rollTypeRollCode, 'TT-1S B250 White');
      expect(dto.rollTypeDisplayName, 'TT-1S B250');
      expect(dto.colorName, 'White');
      expect(dto.productTypeId, 5);
      expect(dto.productTypeName, 'أحمر 20 كغ');
      expect(dto.consumptionItemId, 5000);
      expect(dto.activeSegmentId, 6000);
      expect(dto.state, 'IN_CONSUMPTION');
      expect(dto.lastKnownWeightKg, 250.0);
    });

    test('toEntity copies every field into MountedRoll', () {
      final ThermoformingRollScanResponse dto =
          ThermoformingRollScanResponse.fromJson(const <String, dynamic>{
            'rollId': 1,
            'generatedRollId': '777000000001',
            'rollTypeId': 70,
            'rollTypeRollCode': 'TT-1S B250 White',
            'rollTypeDisplayName': 'TT-1S B250',
            'colorName': 'White',
            'productTypeId': 5,
            'productTypeName': 'أحمر',
            'consumptionItemId': 5000,
            'activeSegmentId': 6000,
            'state': 'IN_CONSUMPTION',
            'lastKnownWeightKg': 250.0,
          });

      final entity = dto.toEntity();
      expect(entity.rollId, 1);
      expect(entity.generatedRollId, '777000000001');
      expect(entity.isInConsumption, isTrue);
    });

    test('warnings defaults to empty when the field is absent', () {
      final ThermoformingRollScanResponse dto =
          ThermoformingRollScanResponse.fromJson(const <String, dynamic>{
            'rollId': 1,
            'generatedRollId': '777000000001',
            'rollTypeId': 1,
            'rollTypeRollCode': 'x',
            'rollTypeDisplayName': 'x',
            'colorName': 'x',
            'productTypeId': 1,
            'productTypeName': 'x',
            'consumptionItemId': 1,
            'activeSegmentId': 1,
            'state': 'IN_CONSUMPTION',
            'lastKnownWeightKg': 250.0,
          });
      expect(dto.warnings, isEmpty);
    });

    test('warnings parses ROLL_CURING_MAXIMUM_EXCEEDED payload', () {
      final ThermoformingRollScanResponse dto =
          ThermoformingRollScanResponse.fromJson(const <String, dynamic>{
            'rollId': 1,
            'generatedRollId': '777000000001',
            'rollTypeId': 1,
            'rollTypeRollCode': 'x',
            'rollTypeDisplayName': 'x',
            'colorName': 'x',
            'productTypeId': 1,
            'productTypeName': 'x',
            'consumptionItemId': 1,
            'activeSegmentId': 1,
            'state': 'IN_CONSUMPTION',
            'lastKnownWeightKg': 250.0,
            'warnings': <Map<String, Object?>>[
              <String, Object?>{
                'code': 'ROLL_CURING_MAXIMUM_EXCEEDED',
                'severity': 'WARNING',
                'message': 'تنبيه: عمر هذا الرول تجاوز الحد الأعلى للحضانة.',
                'payload': <String, Object?>{
                  'rollCode': '777000000001',
                  'maxCuringDays': 7,
                  'actualAgeDays': 13.13,
                },
              },
            ],
          });

      expect(dto.warnings, hasLength(1));
      expect(dto.warnings.first.code, 'ROLL_CURING_MAXIMUM_EXCEEDED');
      expect(dto.warnings.first.severity, 'WARNING');
      expect(
        dto.warnings.first.message,
        'تنبيه: عمر هذا الرول تجاوز الحد الأعلى للحضانة.',
      );
      expect(dto.warnings.first.payload['maxCuringDays'], 7);
      expect(dto.warnings.first.payload['actualAgeDays'], 13.13);
    });

    test('warning entries with missing code/message are skipped', () {
      final ThermoformingRollScanResponse dto =
          ThermoformingRollScanResponse.fromJson(const <String, dynamic>{
            'rollId': 1,
            'generatedRollId': '777000000001',
            'rollTypeId': 1,
            'rollTypeRollCode': 'x',
            'rollTypeDisplayName': 'x',
            'colorName': 'x',
            'productTypeId': 1,
            'productTypeName': 'x',
            'consumptionItemId': 1,
            'activeSegmentId': 1,
            'state': 'IN_CONSUMPTION',
            'lastKnownWeightKg': 250.0,
            'warnings': <Object?>[
              <String, Object?>{'code': 'ONLY_CODE'},
              <String, Object?>{'message': 'only message'},
              'not-an-object',
              <String, Object?>{
                'code': 'OK',
                'message': 'm',
              },
            ],
          });
      expect(dto.warnings, hasLength(1));
      expect(dto.warnings.first.code, 'OK');
      expect(dto.warnings.first.severity, 'WARNING');
    });

    test('integer-typed lastKnownWeightKg is coerced to double', () {
      final ThermoformingRollScanResponse dto =
          ThermoformingRollScanResponse.fromJson(const <String, dynamic>{
            'rollId': 1,
            'generatedRollId': '777000000001',
            'rollTypeId': 1,
            'rollTypeRollCode': 'x',
            'rollTypeDisplayName': 'x',
            'colorName': 'x',
            'productTypeId': 1,
            'productTypeName': 'x',
            'consumptionItemId': 1,
            'activeSegmentId': 1,
            'state': 'IN_CONSUMPTION',
            'lastKnownWeightKg': 250,
          });
      expect(dto.lastKnownWeightKg, 250.0);
    });
  });
}
