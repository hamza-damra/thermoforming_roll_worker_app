import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:thermoforming_roll_worker/core/api/api_paths.dart';
import 'package:thermoforming_roll_worker/core/errors/app_failure.dart';
import 'package:thermoforming_roll_worker/core/storage/secure_token_storage.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/data/roll_worker_auth_api.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/data/roll_worker_auth_repository_impl.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/domain/roll_worker_auth_repository.dart';

class _MockDio extends Mock implements Dio {}

class _MockStorage extends Mock implements FlutterSecureStorage {}

class _FakeOptions extends Fake implements Options {}

const int kShiftLineId = 800;

Map<String, dynamic> _sessionBody({String status = 'ACTIVE'}) =>
    <String, dynamic>{
      'success': true,
      'data': <String, dynamic>{
        'sessionId': 999,
        'rollWorkerOperatorId': 42,
        'rollWorkerName': 'Ahmad',
        'thermoformingShiftId': 700,
        'thermoformingShiftLineId': 800,
        'thermoformingLineId': 200,
        'palletizingLineId': 10,
        'status': status,
        'startedAt': '2026-05-08T13:00:00.000+03:00',
      },
    };

DioException _businessException({
  required int statusCode,
  required String code,
}) {
  return DioException(
    requestOptions: RequestOptions(path: '/x'),
    type: DioExceptionType.badResponse,
    response: Response<dynamic>(
      requestOptions: RequestOptions(path: '/x'),
      statusCode: statusCode,
      data: <String, dynamic>{
        'success': false,
        'error': <String, dynamic>{'code': code},
      },
    ),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeOptions());
  });

  late _MockDio dio;
  late _MockStorage rawStorage;
  late SecureTokenStorage storage;
  late RollWorkerAuthRepository repo;

  setUp(() {
    dio = _MockDio();
    rawStorage = _MockStorage();
    storage = SecureTokenStorage.withStorage(rawStorage);
    repo = RollWorkerAuthRepositoryImpl(
      api: RollWorkerAuthApi(dio),
      storage: storage,
    );
  });

  group('getCurrentSession', () {
    test('on success, returns the active session', () async {
      when(
        () => dio.get<dynamic>(ApiPaths.rollWorkerSessionCurrent(kShiftLineId)),
      ).thenAnswer(
        (_) async => Response<dynamic>(
          requestOptions: RequestOptions(path: '/x'),
          statusCode: 200,
          data: _sessionBody(),
        ),
      );

      final result = await repo.getCurrentSession(kShiftLineId);

      expect(result, isA<RollWorkerAuthSuccess>());
      final session = (result as RollWorkerAuthSuccess).session;
      expect(session.status, 'ACTIVE');
      expect(session.thermoformingShiftLineId, 800);
    });

    test(
      'on SESSION_REQUIRED, clears stored token and surfaces BusinessFailure',
      () async {
        when(
          () =>
              dio.get<dynamic>(ApiPaths.rollWorkerSessionCurrent(kShiftLineId)),
        ).thenThrow(
          _businessException(
            statusCode: 404,
            code: 'ROLL_WORKER_SESSION_REQUIRED',
          ),
        );
        when(
          () => rawStorage.delete(key: any<String>(named: 'key')),
        ).thenAnswer((_) async {});

        final result = await repo.getCurrentSession(kShiftLineId);

        expect(result, isA<RollWorkerAuthFailure>());
        verify(
          () =>
              rawStorage.delete(key: 'roll_worker_session_token_$kShiftLineId'),
        ).called(1);
      },
    );

    test(
      'on SHIFT_LINE_NOT_ACTIVE, clears stored token (cascade-on-end)',
      () async {
        when(
          () =>
              dio.get<dynamic>(ApiPaths.rollWorkerSessionCurrent(kShiftLineId)),
        ).thenThrow(
          _businessException(
            statusCode: 409,
            code: 'THERMOFORMING_SHIFT_LINE_NOT_ACTIVE',
          ),
        );
        when(
          () => rawStorage.delete(key: any<String>(named: 'key')),
        ).thenAnswer((_) async {});

        final result = await repo.getCurrentSession(kShiftLineId);

        expect(result, isA<RollWorkerAuthFailure>());
        verify(
          () =>
              rawStorage.delete(key: 'roll_worker_session_token_$kShiftLineId'),
        ).called(1);
      },
    );

    test('on network failure, does NOT clear stored token', () async {
      when(
        () => dio.get<dynamic>(ApiPaths.rollWorkerSessionCurrent(kShiftLineId)),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/x'),
          type: DioExceptionType.connectionError,
        ),
      );

      final result = await repo.getCurrentSession(kShiftLineId);

      expect(result, isA<RollWorkerAuthFailure>());
      expect((result as RollWorkerAuthFailure).failure, isA<NetworkFailure>());
      verifyNever(() => rawStorage.delete(key: any<String>(named: 'key')));
    });
  });

  group('logout', () {
    test('clears local token before calling backend', () async {
      when(
        () => rawStorage.read(key: 'roll_worker_session_token_$kShiftLineId'),
      ).thenAnswer((_) async => 'stored-token');
      when(
        () => rawStorage.delete(key: any<String>(named: 'key')),
      ).thenAnswer((_) async {});
      when(
        () => dio.post<dynamic>(
          ApiPaths.rollWorkerLogout(kShiftLineId),
          data: any<Object?>(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => Response<dynamic>(
          requestOptions: RequestOptions(path: '/x'),
          statusCode: 200,
          data: <String, dynamic>{'success': true, 'data': null},
        ),
      );

      await repo.logout(kShiftLineId);

      // Read first, then delete, then call backend logout with the token.
      verify(
        () => rawStorage.read(key: 'roll_worker_session_token_$kShiftLineId'),
      ).called(1);
      verify(
        () => rawStorage.delete(key: 'roll_worker_session_token_$kShiftLineId'),
      ).called(1);
      verify(
        () => dio.post<dynamic>(
          ApiPaths.rollWorkerLogout(kShiftLineId),
          data: <String, dynamic>{'sessionToken': 'stored-token'},
        ),
      ).called(1);
    });

    test(
      'with no stored token, does not call backend (idempotent no-op)',
      () async {
        when(
          () => rawStorage.read(key: 'roll_worker_session_token_$kShiftLineId'),
        ).thenAnswer((_) async => null);
        when(
          () => rawStorage.delete(key: any<String>(named: 'key')),
        ).thenAnswer((_) async {});

        await repo.logout(kShiftLineId);

        verifyNever(
          () => dio.post<dynamic>(
            any<String>(),
            data: any<Object?>(named: 'data'),
          ),
        );
      },
    );

    test(
      'swallows backend logout errors but still clears local token',
      () async {
        when(
          () => rawStorage.read(key: 'roll_worker_session_token_$kShiftLineId'),
        ).thenAnswer((_) async => 'stored-token');
        when(
          () => rawStorage.delete(key: any<String>(named: 'key')),
        ).thenAnswer((_) async {});
        when(
          () => dio.post<dynamic>(
            ApiPaths.rollWorkerLogout(kShiftLineId),
            data: any<Object?>(named: 'data'),
          ),
        ).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: '/x'),
            type: DioExceptionType.connectionError,
          ),
        );

        await repo.logout(kShiftLineId);

        verify(
          () =>
              rawStorage.delete(key: 'roll_worker_session_token_$kShiftLineId'),
        ).called(1);
      },
    );
  });
}
