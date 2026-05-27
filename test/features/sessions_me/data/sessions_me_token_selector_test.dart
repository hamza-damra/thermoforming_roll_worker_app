import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:thermoforming_roll_worker/core/storage/secure_token_storage.dart';
import 'package:thermoforming_roll_worker/core/storage/session_index_storage.dart';
import 'package:thermoforming_roll_worker/features/sessions_me/data/sessions_me_token_selector.dart';

class _MockSecure extends Mock implements FlutterSecureStorage {}

void main() {
  group('SessionsMeTokenSelector', () {
    late _MockSecure secure;
    late SessionsMeTokenSelector selector;

    setUp(() {
      secure = _MockSecure();
      selector = SessionsMeTokenSelector(
        tokenStorage: SecureTokenStorage.withStorage(secure),
        indexStorage: SessionIndexStorage.withStorage(secure),
      );
    });

    test('returns null when no sessions are active', () async {
      when(() => secure.read(key: any(named: 'key')))
          .thenAnswer((_) async => null);
      expect(await selector.resolveAnyToken(), isNull);
    });

    test('returns a token from any active session', () async {
      // Index returns 2 ids; the first read for line 100 returns a token.
      when(() => secure.read(key: 'roll_worker_active_shift_line_ids'))
          .thenAnswer((_) async => '[100, 200]');
      when(() => secure.read(key: 'roll_worker_session_token_100'))
          .thenAnswer((_) async => 'TOKEN-100');
      when(() => secure.read(key: 'roll_worker_session_token_200'))
          .thenAnswer((_) async => 'TOKEN-200');

      final token = await selector.resolveAnyToken();
      expect(token, anyOf('TOKEN-100', 'TOKEN-200'));
    });

    test('prefers the last-used id on subsequent calls', () async {
      when(() => secure.read(key: 'roll_worker_active_shift_line_ids'))
          .thenAnswer((_) async => '[100, 200]');
      when(() => secure.read(key: 'roll_worker_session_token_100'))
          .thenAnswer((_) async => 'TOKEN-100');
      when(() => secure.read(key: 'roll_worker_session_token_200'))
          .thenAnswer((_) async => 'TOKEN-200');

      final first = await selector.resolveAnyToken();
      final second = await selector.resolveAnyToken();
      expect(second, first, reason: 'should reuse the cached last-used id');
    });

    test('reset() drops the cached last-used hint', () async {
      when(() => secure.read(key: 'roll_worker_active_shift_line_ids'))
          .thenAnswer((_) async => '[100]');
      when(() => secure.read(key: 'roll_worker_session_token_100'))
          .thenAnswer((_) async => 'TOKEN-100');
      await selector.resolveAnyToken();
      selector.reset();
      // After reset and the line is gone from the index → null.
      when(() => secure.read(key: 'roll_worker_active_shift_line_ids'))
          .thenAnswer((_) async => null);
      expect(await selector.resolveAnyToken(), isNull);
    });
  });
}
