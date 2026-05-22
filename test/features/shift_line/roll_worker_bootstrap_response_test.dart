import 'package:flutter_test/flutter_test.dart';
import 'package:thermoforming_roll_worker/features/shift_line/data/dto/roll_worker_bootstrap_response.dart';
import 'package:thermoforming_roll_worker/features/shift_line/domain/entities/roll_worker_bootstrap_line.dart';

void main() {
  group('RollWorkerBootstrapLineDto.fromJson', () {
    test('parses a fully-populated active row', () {
      final dto = RollWorkerBootstrapLineDto.fromJson(const <String, dynamic>{
        'thermoformingLineId': 1,
        'lineCode': 'TH-01',
        'lineName': 'خط التشكيل 1',
        'palletizingLineId': 20,
        'productionLineId': 20,
        'palletizingLineCode': 'PL-01',
        'palletizingLineName': 'Palletizer 1',
        'machineNumber': 1,
        'shiftLineId': 101,
        'thermoformingShiftId': 42,
        'currentProductTypeId': 50,
        'currentProductTypeName': 'TBS-13 Cup',
        'activeOperatorId': 7,
        'activeOperatorName': 'Hamza',
        'currentRollId': 12345,
        'currentRollGeneratedRollId': '001000000123',
        'currentRollTypeCode': 'TP-1',
        'currentRollTypeName': 'White',
        'currentRollLastKnownWeightKg': 180.5,
        'selectable': true,
        'canStartRollWorkerSession': true,
        'blocked': false,
        'blockedReason': null,
        'handoverPending': false,
        'takeoverRequestStatus': null,
        'takeoverIncomingOperatorName': null,
        'lineLifecycleStatus': 'ACTIVE',
        'updatedAt': '2026-05-17T12:30:00Z',
      });

      final RollWorkerBootstrapLine line = dto.toEntity();
      expect(line.thermoformingLineId, 1);
      expect(line.shiftLineId, 101);
      expect(line.selectable, isTrue);
      expect(line.canStartRollWorkerSession, isTrue);
      expect(line.currentRollLastKnownWeightKg, 180.5);
      expect(line.lineLifecycleStatus, 'ACTIVE');
      expect(line.updatedAt, DateTime.utc(2026, 5, 17, 12, 30));
      expect(line.hasMountedRoll, isTrue);
      expect(line.hasActiveOperator, isTrue);
    });

    test('tolerates an idle machine row with absent nullable fields', () {
      final dto = RollWorkerBootstrapLineDto.fromJson(const <String, dynamic>{
        'thermoformingLineId': 2,
        'lineCode': 'TH-02',
        'lineName': 'خط التشكيل 2',
        'machineNumber': 2,
        'selectable': false,
        'lineLifecycleStatus': 'NO_ACTIVE_SHIFT',
      });

      final RollWorkerBootstrapLine line = dto.toEntity();
      expect(line.thermoformingLineId, 2);
      expect(line.shiftLineId, isNull);
      expect(line.selectable, isFalse);
      // `canStartRollWorkerSession` falls back to `selectable` when absent.
      expect(line.canStartRollWorkerSession, isFalse);
      expect(line.blocked, isFalse);
      expect(line.handoverPending, isFalse);
      expect(line.activeOperatorId, isNull);
      expect(line.currentRollId, isNull);
      expect(line.hasMountedRoll, isFalse);
      expect(line.updatedAt, isNull);
    });

    test('defaults lineLifecycleStatus when the field is absent', () {
      final dto = RollWorkerBootstrapLineDto.fromJson(const <String, dynamic>{
        'thermoformingLineId': 3,
        'lineCode': 'TH-03',
        'lineName': 'خط 3',
      });
      expect(dto.lineLifecycleStatus, 'NO_ACTIVE_SHIFT');
    });

    test('parses currentRollLastKnownWeightKg given as a JSON number', () {
      final dto = RollWorkerBootstrapLineDto.fromJson(const <String, dynamic>{
        'thermoformingLineId': 4,
        'lineCode': 'TH-04',
        'lineName': 'خط 4',
        'currentRollLastKnownWeightKg': 95,
      });
      expect(dto.currentRollLastKnownWeightKg, 95.0);
    });

    test('parses currentRollLastKnownWeightKg given as a decimal string', () {
      final dto = RollWorkerBootstrapLineDto.fromJson(const <String, dynamic>{
        'thermoformingLineId': 5,
        'lineCode': 'TH-05',
        'lineName': 'خط 5',
        'currentRollLastKnownWeightKg': '180.500',
      });
      expect(dto.currentRollLastKnownWeightKg, 180.5);
    });

    test('productionLineId falls back to palletizingLineId when absent', () {
      final dto = RollWorkerBootstrapLineDto.fromJson(const <String, dynamic>{
        'thermoformingLineId': 6,
        'lineCode': 'TH-06',
        'lineName': 'خط 6',
        'palletizingLineId': 77,
      });
      expect(dto.productionLineId, 77);
    });
  });

  group('RollWorkerBootstrapResponse.linesFromEnvelopeData', () {
    test('unwraps the { lines: [...] } data object', () {
      final lines = RollWorkerBootstrapResponse.linesFromEnvelopeData(
        const <String, dynamic>{
          'lines': <Object?>[
            <String, dynamic>{
              'thermoformingLineId': 1,
              'lineCode': 'TH-01',
              'lineName': 'خط 1',
              'selectable': true,
            },
            <String, dynamic>{
              'thermoformingLineId': 2,
              'lineCode': 'TH-02',
              'lineName': 'خط 2',
              'selectable': false,
            },
          ],
        },
      );
      expect(lines, hasLength(2));
      expect(lines.first.thermoformingLineId, 1);
      expect(lines.last.selectable, isFalse);
    });

    test('throws FormatException when `lines` is missing', () {
      expect(
        () => RollWorkerBootstrapResponse.linesFromEnvelopeData(
          const <String, dynamic>{},
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException when the envelope data is not a map', () {
      expect(
        () => RollWorkerBootstrapResponse.linesFromEnvelopeData(
          const <Object?>[],
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
