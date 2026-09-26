import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:thermoforming_roll_worker/core/api/api_paths.dart';
import 'package:thermoforming_roll_worker/core/errors/biometric_denial.dart';
import 'package:thermoforming_roll_worker/core/storage/secure_token_storage.dart';
import 'package:thermoforming_roll_worker/core/storage/session_index_storage.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/data/session_batch_api.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/data/session_batch_repository_impl.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/domain/session_batch_repository.dart';

class _MockDio extends Mock implements Dio {}

class _MockRawStorage extends Mock implements FlutterSecureStorage {}

const String _token = 'q3Jx8d6cYt0H1m0yF3kZ0wS9gQx8B7nV2rP5aL4eK1c';

DioException _biometric403() => DioException(
  requestOptions: RequestOptions(path: ApiPaths.sessionsStartBatch),
  type: DioExceptionType.badResponse,
  response: Response<dynamic>(
    requestOptions: RequestOptions(path: ApiPaths.sessionsStartBatch),
    statusCode: 403,
    data: <String, dynamic>{
      'success': false,
      'error': <String, dynamic>{
        'code': 'BIOMETRIC_VERIFICATION_REQUIRED',
        'message': 'يرجى تمرير البصمة على جهاز البصمة ثم إعادة المحاولة.',
        'details': <String, dynamic>{
          'validitySeconds': 300,
          'attemptToken': _token,
          'attemptExpiresAt': '2026-09-24T08:15:00.000Z',
          'statusPath': '/api/v1/auth/biometric/login-attempts/status',
          'attemptAvailable': true,
        },
      },
    },
  ),
);

void main() {
  test(
    'a biometric 403 on start-batch is a typed denial; no session token, no '
    'line index and no attempt token is written anywhere',
    () async {
      final dio = _MockDio();
      final tokenRaw = _MockRawStorage();
      final indexRaw = _MockRawStorage();
      final repo = SessionBatchRepositoryImpl(
        api: SessionBatchApi(dio),
        tokenStorage: SecureTokenStorage.withStorage(tokenRaw),
        indexStorage: SessionIndexStorage.withStorage(indexRaw),
      );
      when(
        () => dio.post<dynamic>(
          ApiPaths.sessionsStartBatch,
          data: any<Object?>(named: 'data'),
        ),
      ).thenThrow(_biometric403());

      final BatchAuthResult result = await repo.startBatch(
        pin: '1234',
        shiftLineIds: <int>{101, 102},
      );

      expect(result, isA<BatchAuthFailureResult>());
      final failure = (result as BatchAuthFailureResult).failure;
      expect(failure, isA<BiometricDenialFailure>());
      expect((failure as BiometricDenialFailure).denial.attemptToken, _token);
      expect(result.conflictShiftLineIds, isNull);
      for (final _MockRawStorage raw in <_MockRawStorage>[tokenRaw, indexRaw]) {
        verifyNever(
          () => raw.write(
            key: any<String>(named: 'key'),
            value: any<String>(named: 'value'),
          ),
        );
      }
    },
  );
}
