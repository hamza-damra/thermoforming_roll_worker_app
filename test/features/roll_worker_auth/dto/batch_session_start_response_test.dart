import 'package:flutter_test/flutter_test.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/data/dto/batch_session_start_response.dart';

Map<String, dynamic> _entry({int shiftLineId = 101, String token = 'tok-1'}) =>
    <String, dynamic>{
      'shiftLineId': shiftLineId,
      'sessionId': 1,
      'sessionToken': token,
      'thermoformingShiftId': 9001,
      'thermoformingLineId': 11,
      'palletizingLineId': 21,
      'startedAt': '2026-05-10T10:00:12.123+03:00',
      'startedAtDisplay': '2026-05-10، 10:00 صباحاً',
    };

void main() {
  group('BatchSessionStartResponse.fromJson', () {
    test('parses operator info and the sessions list in order', () {
      final dto = BatchSessionStartResponse.fromJson(<String, dynamic>{
        'rollWorkerOperatorId': 77,
        'rollWorkerName': 'يوسف',
        'sessions': <Map<String, dynamic>>[
          _entry(shiftLineId: 101, token: 'tok-101'),
          _entry(shiftLineId: 102, token: 'tok-102'),
        ],
      });

      expect(dto.rollWorkerOperatorId, 77);
      expect(dto.rollWorkerName, 'يوسف');
      expect(dto.sessions, hasLength(2));
      expect(dto.sessions.first.shiftLineId, 101);
      expect(dto.sessions.first.sessionToken, 'tok-101');
      expect(dto.sessions.last.shiftLineId, 102);
    });

    test('throws FormatException when sessions is missing or wrong shape', () {
      expect(
        () => BatchSessionStartResponse.fromJson(const <String, dynamic>{
          'rollWorkerOperatorId': 1,
          'rollWorkerName': 'X',
          'sessions': null,
        }),
        throwsFormatException,
      );
    });

    test('toString redacts every per-entry token', () {
      final dto = BatchSessionStartResponse.fromJson(<String, dynamic>{
        'rollWorkerOperatorId': 77,
        'rollWorkerName': 'X',
        'sessions': <Map<String, dynamic>>[_entry(token: 'super-secret')],
      });
      final s = dto.toString();
      expect(s.contains('super-secret'), isFalse);
      expect(s.contains('redacted'), isTrue);
    });
  });
}
