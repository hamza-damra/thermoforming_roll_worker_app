import 'package:flutter_test/flutter_test.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/data/dto/roll_worker_session_response.dart';

void main() {
  group('RollWorkerSessionResponse', () {
    test('fromJson parses every documented field', () {
      final RollWorkerSessionResponse dto =
          RollWorkerSessionResponse.fromJson(const <String, dynamic>{
            'sessionId': 999,
            'rollWorkerOperatorId': 42,
            'rollWorkerName': 'Ahmad',
            'thermoformingShiftId': 700,
            'thermoformingShiftLineId': 800,
            'thermoformingLineId': 200,
            'palletizingLineId': 10,
            'status': 'ACTIVE',
            'startedAt': '2026-05-08T13:00:00.000+03:00',
            'startedAtDisplay': '2026-05-08، 1:00 مساءً',
            'lastUsedAt': '2026-05-08T13:42:18.512+03:00',
            'lastUsedAtDisplay': '2026-05-08، 1:42 مساءً',
          });

      expect(dto.sessionId, 999);
      expect(dto.status, 'ACTIVE');
      expect(dto.rollWorkerName, 'Ahmad');
      expect(dto.thermoformingShiftLineId, 800);
      expect(dto.lastUsedAt, isNotNull);
      expect(dto.lastUsedAtDisplay, '2026-05-08، 1:42 مساءً');
    });

    test('fromJson tolerates missing optional fields', () {
      final RollWorkerSessionResponse dto =
          RollWorkerSessionResponse.fromJson(const <String, dynamic>{
            'sessionId': 1,
            'rollWorkerOperatorId': 1,
            'rollWorkerName': 'x',
            'thermoformingShiftId': 1,
            'thermoformingShiftLineId': 1,
            'thermoformingLineId': 1,
            'palletizingLineId': 1,
            'status': 'ACTIVE',
            'startedAt': '2026-05-08T13:00:00.000+03:00',
          });
      expect(dto.startedAtDisplay, isNull);
      expect(dto.lastUsedAt, isNull);
      expect(dto.lastUsedAtDisplay, isNull);
    });

    test('response payload never declares a sessionToken field', () {
      // Sanity check on the contract: `current` MUST NOT include a token.
      const Map<String, dynamic> payload = <String, dynamic>{
        'sessionId': 1,
        'rollWorkerOperatorId': 1,
        'rollWorkerName': 'x',
        'thermoformingShiftId': 1,
        'thermoformingShiftLineId': 1,
        'thermoformingLineId': 1,
        'palletizingLineId': 1,
        'status': 'ACTIVE',
        'startedAt': '2026-05-08T13:00:00.000+03:00',
      };
      expect(payload.containsKey('sessionToken'), isFalse);
      // No way to access a token on the dto either:
      final RollWorkerSessionResponse dto = RollWorkerSessionResponse.fromJson(
        payload,
      );
      expect(
        dto.toString().toLowerCase().contains('sessiontoken'),
        isFalse,
        reason: 'session/current DTO must not surface sessionToken anywhere',
      );
    });
  });
}
