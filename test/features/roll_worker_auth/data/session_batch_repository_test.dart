import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:thermoforming_roll_worker/core/api/api_paths.dart';
import 'package:thermoforming_roll_worker/core/errors/app_failure.dart';
import 'package:thermoforming_roll_worker/core/errors/error_code.dart';
import 'package:thermoforming_roll_worker/core/storage/secure_token_storage.dart';
import 'package:thermoforming_roll_worker/core/storage/session_index_storage.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/data/session_batch_api.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/data/session_batch_repository_impl.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/domain/session_batch_repository.dart';

class _MockDio extends Mock implements Dio {}

class _MockTokenStorageRaw extends Mock implements FlutterSecureStorage {}

class _MockIndexStorageRaw extends Mock implements FlutterSecureStorage {}

Map<String, dynamic> _entry({
  int shiftLineId = 101,
  String token = 'raw-token',
}) => <String, dynamic>{
  'shiftLineId': shiftLineId,
  'sessionId': 1,
  'sessionToken': token,
  'thermoformingShiftId': 9001,
  'thermoformingLineId': shiftLineId + 100,
  'palletizingLineId': shiftLineId + 200,
  'startedAt': '2026-05-10T10:00:12.123+03:00',
  'startedAtDisplay': '2026-05-10، 10:00 صباحاً',
};

Map<String, dynamic> _successBody(List<Map<String, dynamic>> entries) =>
    <String, dynamic>{
      'success': true,
      'data': <String, dynamic>{
        'rollWorkerOperatorId': 77,
        'rollWorkerName': 'Yusuf',
        'sessions': entries,
      },
    };

DioException _failureException({
  required int statusCode,
  required String code,
  Map<String, Object?>? details,
}) => DioException(
  requestOptions: RequestOptions(path: ApiPaths.sessionsStartBatch),
  type: DioExceptionType.badResponse,
  response: Response<dynamic>(
    requestOptions: RequestOptions(path: ApiPaths.sessionsStartBatch),
    statusCode: statusCode,
    data: <String, dynamic>{
      'success': false,
      'error': <String, dynamic>{
        'code': code,
        if (details != null) 'details': details,
      },
    },
  ),
);

void main() {
  late _MockDio dio;
  late _MockTokenStorageRaw rawTokenStorage;
  late _MockIndexStorageRaw rawIndexStorage;
  late SessionBatchRepository repo;

  setUp(() {
    dio = _MockDio();
    rawTokenStorage = _MockTokenStorageRaw();
    rawIndexStorage = _MockIndexStorageRaw();
    repo = SessionBatchRepositoryImpl(
      api: SessionBatchApi(dio),
      tokenStorage: SecureTokenStorage.withStorage(rawTokenStorage),
      indexStorage: SessionIndexStorage.withStorage(rawIndexStorage),
    );

    when(
      () => rawTokenStorage.write(
        key: any<String>(named: 'key'),
        value: any<String>(named: 'value'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => rawIndexStorage.write(
        key: any<String>(named: 'key'),
        value: any<String>(named: 'value'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => rawIndexStorage.read(key: any<String>(named: 'key')),
    ).thenAnswer((_) async => null);
  });

  test(
    'on success persists every per-line token + writes the active-id index',
    () async {
      when(
        () => dio.post<dynamic>(
          ApiPaths.sessionsStartBatch,
          data: any<Object?>(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => Response<dynamic>(
          requestOptions: RequestOptions(path: ApiPaths.sessionsStartBatch),
          statusCode: 201,
          data: _successBody(<Map<String, dynamic>>[
            _entry(shiftLineId: 101, token: 'tok-101'),
            _entry(shiftLineId: 102, token: 'tok-102'),
          ]),
        ),
      );

      final result = await repo.startBatch(
        pin: '1234',
        shiftLineIds: <int>{101, 102},
      );

      expect(result, isA<BatchAuthSuccessResult>());
      verify(
        () => rawTokenStorage.write(
          key: 'roll_worker_session_token_101',
          value: 'tok-101',
        ),
      ).called(1);
      verify(
        () => rawTokenStorage.write(
          key: 'roll_worker_session_token_102',
          value: 'tok-102',
        ),
      ).called(1);
      verify(
        () => rawIndexStorage.write(
          key: 'roll_worker_active_shift_line_ids',
          value: any<String>(named: 'value'),
        ),
      ).called(1);
    },
  );

  test(
    'on OPERATOR_PIN_INVALID, surfaces failure and does NOT persist any token',
    () async {
      when(
        () => dio.post<dynamic>(
          ApiPaths.sessionsStartBatch,
          data: any<Object?>(named: 'data'),
        ),
      ).thenThrow(
        _failureException(statusCode: 401, code: 'OPERATOR_PIN_INVALID'),
      );

      final result = await repo.startBatch(
        pin: '0000',
        shiftLineIds: <int>{101},
      );

      expect(result, isA<BatchAuthFailureResult>());
      final failure = (result as BatchAuthFailureResult).failure;
      expect(failure, isA<BusinessFailure>());
      expect((failure as BusinessFailure).code, ErrorCode.operatorPinInvalid);
      expect(result.conflictShiftLineIds, isNull);
      verifyNever(
        () => rawTokenStorage.write(
          key: any<String>(named: 'key'),
          value: any<String>(named: 'value'),
        ),
      );
    },
  );

  test('OPERATOR_LOCKED maps to ErrorCode.operatorLocked', () async {
    when(
      () => dio.post<dynamic>(
        ApiPaths.sessionsStartBatch,
        data: any<Object?>(named: 'data'),
      ),
    ).thenThrow(_failureException(statusCode: 423, code: 'OPERATOR_LOCKED'));

    final result = await repo.startBatch(
      pin: '0000',
      shiftLineIds: <int>{101},
    );

    expect(
      ((result as BatchAuthFailureResult).failure as BusinessFailure).code,
      ErrorCode.operatorLocked,
    );
  });

  test(
    'LINE_USED_BY_OTHER_WORKER carries the offending id in '
    'BatchAuthFailureResult.conflictShiftLineIds',
    () async {
      when(
        () => dio.post<dynamic>(
          ApiPaths.sessionsStartBatch,
          data: any<Object?>(named: 'data'),
        ),
      ).thenThrow(
        _failureException(
          statusCode: 409,
          code: 'ROLL_WORKER_SESSION_LINE_USED_BY_OTHER_WORKER',
          details: <String, Object?>{
            'shiftLineId': 102,
            'ownerOperatorId': 80,
            'ownerOperatorName': 'someone-else',
          },
        ),
      );

      final result = await repo.startBatch(
        pin: '1234',
        shiftLineIds: <int>{101, 102},
      );

      expect(result, isA<BatchAuthFailureResult>());
      expect(
        (result as BatchAuthFailureResult).conflictShiftLineIds,
        <int>{102},
      );
    },
  );

  test(
    'LINE_INACTIVE / NOT_FOUND / DUPLICATE also extract the conflict id',
    () async {
      for (final String code in const <String>[
        'ROLL_WORKER_SESSION_LINE_INACTIVE',
        'THERMOFORMING_SHIFT_LINE_NOT_FOUND',
        'ROLL_WORKER_SESSION_LINE_DUPLICATE',
      ]) {
        when(
          () => dio.post<dynamic>(
            ApiPaths.sessionsStartBatch,
            data: any<Object?>(named: 'data'),
          ),
        ).thenThrow(
          _failureException(
            statusCode: 409,
            code: code,
            details: <String, Object?>{'shiftLineId': 999},
          ),
        );

        final result = await repo.startBatch(
          pin: '1234',
          shiftLineIds: <int>{999},
        );
        expect(
          (result as BatchAuthFailureResult).conflictShiftLineIds,
          <int>{999},
          reason: 'Failed for code $code',
        );
      }
    },
  );

  test('same-worker collision overwrites the prior stored token', () async {
    when(
      () => dio.post<dynamic>(
        ApiPaths.sessionsStartBatch,
        data: any<Object?>(named: 'data'),
      ),
    ).thenAnswer(
      (_) async => Response<dynamic>(
        requestOptions: RequestOptions(path: ApiPaths.sessionsStartBatch),
        statusCode: 201,
        data: _successBody(<Map<String, dynamic>>[
          _entry(shiftLineId: 101, token: 'fresh-replacement'),
        ]),
      ),
    );

    final result = await repo.startBatch(
      pin: '1234',
      shiftLineIds: <int>{101},
    );

    expect(result, isA<BatchAuthSuccessResult>());
    verify(
      () => rawTokenStorage.write(
        key: 'roll_worker_session_token_101',
        value: 'fresh-replacement',
      ),
    ).called(1);
  });
}
