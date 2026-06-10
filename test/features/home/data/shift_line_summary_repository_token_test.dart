import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:thermoforming_roll_worker/core/storage/secure_token_storage.dart';
import 'package:thermoforming_roll_worker/features/home/data/shift_line_summary_api.dart';
import 'package:thermoforming_roll_worker/features/home/data/shift_line_summary_repository_impl.dart';

class _MockSummaryApi extends Mock implements ShiftLineSummaryApi {}

class _MockRawStorage extends Mock implements FlutterSecureStorage {}

/// Handoff §5: the per-line summary MUST be requested with the token stored
/// for that exact `shiftLineId`. Sending line 82's token to `…/81/summary`
/// is a 403 by design — so the repository must read the per-line token and
/// never share one token across lines.
void main() {
  late _MockSummaryApi api;
  late _MockRawStorage raw;
  late ShiftLineSummaryRepositoryImpl repo;

  setUp(() {
    api = _MockSummaryApi();
    raw = _MockRawStorage();
    repo = ShiftLineSummaryRepositoryImpl(
      api: api,
      storage: SecureTokenStorage.withStorage(raw),
    );

    when(
      () => raw.read(key: 'roll_worker_session_token_81'),
    ).thenAnswer((_) async => 'tok-81');
    when(
      () => raw.read(key: 'roll_worker_session_token_82'),
    ).thenAnswer((_) async => 'tok-82');
    when(
      () => raw.delete(key: any<String>(named: 'key')),
    ).thenAnswer((_) async {});

    // The return value is irrelevant to this test — we only assert WHICH token
    // each line is summarised with — so let the API fail transiently (a
    // transport error is NOT one of the token-clearing business codes).
    when(
      () => api.fetchSummary(
        shiftLineId: any<int>(named: 'shiftLineId'),
        sessionToken: any<String>(named: 'sessionToken'),
      ),
    ).thenThrow(Exception('transport'));
  });

  test('summary 81 is requested with token81', () async {
    await repo.fetchSummary(shiftLineId: 81);

    verify(() => raw.read(key: 'roll_worker_session_token_81')).called(1);
    verify(
      () => api.fetchSummary(shiftLineId: 81, sessionToken: 'tok-81'),
    ).called(1);
    verifyNever(
      () => api.fetchSummary(shiftLineId: 81, sessionToken: 'tok-82'),
    );
    // A transport failure must NOT clear the per-line token.
    verifyNever(() => raw.delete(key: any<String>(named: 'key')));
  });

  test('summary 82 is requested with token82 (tokens never shared)', () async {
    await repo.fetchSummary(shiftLineId: 82);

    verify(() => raw.read(key: 'roll_worker_session_token_82')).called(1);
    verify(
      () => api.fetchSummary(shiftLineId: 82, sessionToken: 'tok-82'),
    ).called(1);
    verifyNever(
      () => api.fetchSummary(shiftLineId: 82, sessionToken: 'tok-81'),
    );
  });
}
