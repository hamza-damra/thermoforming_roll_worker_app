import 'package:flutter_test/flutter_test.dart';
import 'package:thermoforming_roll_worker/features/sessions_me/data/dto/roll_worker_me_response.dart';

void main() {
  group('RollWorkerMeResponse.fromEnvelopeData', () {
    test('parses a full payload (handoff §2.4 example)', () {
      final me = RollWorkerMeResponse.fromEnvelopeData(<String, dynamic>{
        'rollWorkerOperatorId': 7,
        'rollWorkerName': 'محمد سنتريسي',
        'lines': <Map<String, dynamic>>[
          <String, dynamic>{
            'sessionId': 41,
            'shiftLineId': 102,
            'palletizingLineId': 1,
            'palletizingLineCode': 'LINE_1',
            'palletizingLineName': 'Line-1',
            'thermoformingLineId': 1001,
            'thermoformingLineCode': 'TF_LINE_1',
            'thermoformingLineName': 'ماكينة A',
            'thermoformingShiftId': 333,
            'supervisingOperatorId': 6,
            'supervisingOperatorName': 'محمد سنتريسي',
            'currentPlanItemProductTypeId': 12,
            'currentPlanItemProductName': 'Red 20kg',
            'currentRollId': null,
            'currentRollGeneratedRollId': null,
            'currentRollTypeCode': null,
            'currentRollTypeName': null,
            'currentRollLastKnownWeightKg': null,
            'handoverPending': false,
            'takeoverRequestStatus': null,
            'takeoverIncomingOperatorName': null,
            'blocked': false,
            'blockedReason': null,
            'lineLifecycleStatus': 'ACTIVE',
            'sessionStartedAt': '2026-05-23T07:15:00+03:00',
            'sessionStartedAtDisplay': '23 أيار، 07:15 ص',
          },
        ],
      });

      expect(me.rollWorkerOperatorId, 7);
      expect(me.rollWorkerName, 'محمد سنتريسي');
      expect(me.lines.length, 1);
      final line = me.lines.single;
      expect(line.shiftLineId, 102);
      expect(line.currentPlanItemProductName, 'Red 20kg');
      expect(line.hasMountedRoll, isFalse);
      expect(line.blocked, isFalse);
      expect(line.lineLifecycleStatus, 'ACTIVE');
    });

    test('treats an absent `lines` field as zero sessions', () {
      final me = RollWorkerMeResponse.fromEnvelopeData(<String, dynamic>{
        'rollWorkerOperatorId': 7,
        'rollWorkerName': 'x',
      });
      expect(me.lines, isEmpty);
    });

    test('treats an empty `lines` array as zero sessions (logged-out)', () {
      final me = RollWorkerMeResponse.fromEnvelopeData(<String, dynamic>{
        'rollWorkerOperatorId': 7,
        'rollWorkerName': 'x',
        'lines': <dynamic>[],
      });
      expect(me.lines, isEmpty);
      expect(me.shiftLineIds, isEmpty);
    });

    test('parses a blocked line correctly', () {
      final me = RollWorkerMeResponse.fromEnvelopeData(<String, dynamic>{
        'rollWorkerOperatorId': 7,
        'rollWorkerName': 'x',
        'lines': <Map<String, dynamic>>[
          <String, dynamic>{
            'sessionId': 1,
            'shiftLineId': 100,
            'blocked': true,
            'blockedReason': 'PENDING_HANDOVER',
            'lineLifecycleStatus': 'PENDING_HANDOVER',
          },
        ],
      });
      final line = me.lines.single;
      expect(line.blocked, isTrue);
      expect(line.blockedReason, 'PENDING_HANDOVER');
      expect(line.lineLifecycleStatus, 'PENDING_HANDOVER');
    });

    test('throws on non-object envelope data', () {
      expect(
        () => RollWorkerMeResponse.fromEnvelopeData(<dynamic>[]),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws when rollWorkerOperatorId is missing', () {
      expect(
        () => RollWorkerMeResponse.fromEnvelopeData(<String, dynamic>{
          'rollWorkerName': 'x',
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('parses a mounted-roll line', () {
      final me = RollWorkerMeResponse.fromEnvelopeData(<String, dynamic>{
        'rollWorkerOperatorId': 7,
        'rollWorkerName': 'x',
        'lines': <Map<String, dynamic>>[
          <String, dynamic>{
            'sessionId': 1,
            'shiftLineId': 100,
            'currentRollId': 999,
            'currentRollGeneratedRollId': 'GRID-001',
            'currentRollLastKnownWeightKg': 180.5,
            'lineLifecycleStatus': 'ACTIVE',
          },
        ],
      });
      final line = me.lines.single;
      expect(line.hasMountedRoll, isTrue);
      expect(line.currentRollGeneratedRollId, 'GRID-001');
      expect(line.currentRollLastKnownWeightKg, 180.5);
    });

    test('parses decimal-string weight (backend wire variant)', () {
      final me = RollWorkerMeResponse.fromEnvelopeData(<String, dynamic>{
        'rollWorkerOperatorId': 7,
        'rollWorkerName': 'x',
        'lines': <Map<String, dynamic>>[
          <String, dynamic>{
            'sessionId': 1,
            'shiftLineId': 100,
            'currentRollLastKnownWeightKg': '180.500',
            'lineLifecycleStatus': 'ACTIVE',
          },
        ],
      });
      expect(me.lines.single.currentRollLastKnownWeightKg, 180.5);
    });
  });
}
