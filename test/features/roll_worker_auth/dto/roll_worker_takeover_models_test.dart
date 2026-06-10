import 'package:flutter_test/flutter_test.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/data/dto/roll_worker_takeover_request.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/data/dto/roll_worker_takeover_response.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/domain/entities/roll_worker_takeover.dart';

void main() {
  group('RollWorkerTakeoverAction', () {
    test('serializes the exact uppercase wire strings', () {
      expect(
        RollWorkerTakeoverAction.fullConsumptionAndClose.wireValue,
        'FULL_CONSUMPTION_AND_CLOSE',
      );
      expect(
        RollWorkerTakeoverAction.rollRemainsMounted.wireValue,
        'ROLL_REMAINS_MOUNTED',
      );
    });

    test('fromWire resolves known strings and null otherwise', () {
      expect(
        RollWorkerTakeoverAction.fromWire('ROLL_REMAINS_MOUNTED'),
        RollWorkerTakeoverAction.rollRemainsMounted,
      );
      expect(RollWorkerTakeoverAction.fromWire('NOPE'), isNull);
      expect(RollWorkerTakeoverAction.fromWire(null), isNull);
    });
  });

  group('RollWorkerTakeoverRequest.toJson', () {
    test('omits currentWeightKg for FULL_CONSUMPTION_AND_CLOSE', () {
      const RollWorkerTakeoverRequest request = RollWorkerTakeoverRequest(
        shiftLineId: 80,
        incomingOperatorPin: '1234',
        action: RollWorkerTakeoverAction.fullConsumptionAndClose,
        clientRequestId: 'abc-123',
      );
      final Map<String, dynamic> json = request.toJson();
      expect(json['shiftLineId'], 80);
      expect(json['incomingOperatorPin'], '1234');
      expect(json['action'], 'FULL_CONSUMPTION_AND_CLOSE');
      expect(json['clientRequestId'], 'abc-123');
      expect(json.containsKey('currentWeightKg'), isFalse);
    });

    test('includes currentWeightKg for ROLL_REMAINS_MOUNTED', () {
      const RollWorkerTakeoverRequest request = RollWorkerTakeoverRequest(
        shiftLineId: 80,
        incomingOperatorPin: '1234',
        action: RollWorkerTakeoverAction.rollRemainsMounted,
        clientRequestId: 'abc-123',
        currentWeightKg: 60.0,
      );
      final Map<String, dynamic> json = request.toJson();
      expect(json['action'], 'ROLL_REMAINS_MOUNTED');
      expect(json['currentWeightKg'], 60.0);
    });
  });

  group('RollWorkerTakeoverResponse.fromJson', () {
    test('maps a fresh remains-mounted success', () {
      final RollWorkerTakeoverResponse res = RollWorkerTakeoverResponse.fromJson(
        const <String, dynamic>{
          'alreadyProcessed': false,
          'sessionId': 950,
          'sessionToken': 'raw-uuid-token',
          'rollWorkerOperatorId': 5,
          'rollWorkerName': 'باسم راضي',
          'thermoformingShiftLineId': 80,
          'palletizingLineId': 21,
          'action': 'ROLL_REMAINS_MOUNTED',
          'rollClosed': false,
          'rollRemainsMounted': true,
          'currentWeightKg': 60.0,
          'previousWorkerName': 'محمد سنتريسي',
        },
      );
      expect(res.alreadyProcessed, isFalse);
      expect(res.sessionToken, 'raw-uuid-token');
      expect(res.rollRemainsMounted, isTrue);
      expect(res.rollClosed, isFalse);
      expect(res.currentWeightKg, 60.0);
      expect(res.previousWorkerName, 'محمد سنتريسي');
    });

    test('maps an alreadyProcessed duplicate (no token)', () {
      final RollWorkerTakeoverResponse res = RollWorkerTakeoverResponse.fromJson(
        const <String, dynamic>{
          'alreadyProcessed': true,
          'action': 'FULL_CONSUMPTION_AND_CLOSE',
          'rollClosed': true,
          'rollRemainsMounted': false,
        },
      );
      expect(res.alreadyProcessed, isTrue);
      expect(res.sessionToken, isNull);
      expect(res.rollClosed, isTrue);
      expect(res.currentWeightKg, isNull);
    });
  });

  group('RollWorkerTakeoverRequiredDetails.fromDetails', () {
    test('parses a complete details map', () {
      final RollWorkerTakeoverRequiredDetails? details =
          RollWorkerTakeoverRequiredDetails.fromDetails(<String, Object?>{
            'shiftLineId': 80,
            'previousWorkerName': 'محمد سنتريسي',
            'previousWorkerOperatorId': 99,
            'lastKnownWeightKg': 100.0,
            'generatedRollId': '777000000001',
          });
      expect(details, isNotNull);
      expect(details!.shiftLineId, 80);
      expect(details.previousWorkerName, 'محمد سنتريسي');
      expect(details.previousWorkerOperatorId, 99);
      expect(details.lastKnownWeightKg, 100.0);
      expect(details.generatedRollId, '777000000001');
    });

    test('returns null when shiftLineId is missing/malformed', () {
      expect(
        RollWorkerTakeoverRequiredDetails.fromDetails(<String, Object?>{
          'previousWorkerName': 'x',
        }),
        isNull,
      );
      expect(RollWorkerTakeoverRequiredDetails.fromDetails(null), isNull);
    });

    test('tolerates missing optional fields (legacy data)', () {
      final RollWorkerTakeoverRequiredDetails? details =
          RollWorkerTakeoverRequiredDetails.fromDetails(<String, Object?>{
            'shiftLineId': 80,
          });
      expect(details, isNotNull);
      expect(details!.previousWorkerName, '');
      expect(details.lastKnownWeightKg, isNull);
      expect(details.generatedRollId, isNull);
    });
  });
}
