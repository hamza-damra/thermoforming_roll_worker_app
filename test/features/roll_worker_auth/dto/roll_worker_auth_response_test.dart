import 'package:flutter_test/flutter_test.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/data/dto/roll_worker_auth_response.dart';

void main() {
  group('RollWorkerAuthResponse', () {
    test('fromJson parses every required field', () {
      final RollWorkerAuthResponse dto =
          RollWorkerAuthResponse.fromJson(const <String, dynamic>{
            'sessionId': 999,
            'sessionToken': 'raw-uuid-token-shown-once',
            'rollWorkerOperatorId': 42,
            'rollWorkerName': 'Ahmad',
            'thermoformingShiftId': 700,
            'thermoformingShiftLineId': 800,
            'thermoformingLineId': 200,
            'palletizingLineId': 10,
            'startedAt': '2026-05-08T13:00:00.000+03:00',
            'startedAtDisplay': '2026-05-08، 1:00 مساءً',
          });

      expect(dto.sessionId, 999);
      expect(dto.sessionToken, 'raw-uuid-token-shown-once');
      expect(dto.rollWorkerOperatorId, 42);
      expect(dto.rollWorkerName, 'Ahmad');
      expect(dto.thermoformingShiftId, 700);
      expect(dto.thermoformingShiftLineId, 800);
      expect(dto.thermoformingLineId, 200);
      expect(dto.palletizingLineId, 10);
      expect(dto.startedAt.toIso8601String(), contains('2026-05-08'));
      expect(dto.startedAtDisplay, '2026-05-08، 1:00 مساءً');
    });

    test('fromJson rejects missing sessionToken', () {
      expect(
        () => RollWorkerAuthResponse.fromJson(const <String, dynamic>{
          'sessionId': 1,
          'rollWorkerOperatorId': 1,
          'rollWorkerName': 'x',
          'thermoformingShiftId': 1,
          'thermoformingShiftLineId': 1,
          'thermoformingLineId': 1,
          'palletizingLineId': 1,
          'startedAt': '2026-05-08T13:00:00.000+03:00',
        }),
        throwsFormatException,
      );
    });

    test('toString redacts the session token', () {
      final RollWorkerAuthResponse dto =
          RollWorkerAuthResponse.fromJson(const <String, dynamic>{
            'sessionId': 1,
            'sessionToken': 'super-secret-uuid-token',
            'rollWorkerOperatorId': 1,
            'rollWorkerName': 'x',
            'thermoformingShiftId': 1,
            'thermoformingShiftLineId': 1,
            'thermoformingLineId': 1,
            'palletizingLineId': 1,
            'startedAt': '2026-05-08T13:00:00.000+03:00',
          });
      final String s = dto.toString();
      expect(s, contains('<redacted>'));
      expect(s, isNot(contains('super-secret-uuid-token')));
    });
  });
}
