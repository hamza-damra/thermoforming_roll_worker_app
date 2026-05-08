import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:thermoforming_roll_worker/core/api/api_paths.dart';
import 'package:thermoforming_roll_worker/core/errors/app_failure.dart';
import 'package:thermoforming_roll_worker/core/errors/error_code.dart';
import 'package:thermoforming_roll_worker/core/storage/secure_token_storage.dart';
import 'package:thermoforming_roll_worker/features/previous_roll/data/previous_roll_api.dart';
import 'package:thermoforming_roll_worker/features/previous_roll/data/previous_roll_repository_impl.dart';
import 'package:thermoforming_roll_worker/features/previous_roll/domain/previous_roll_repository.dart';

class _MockDio extends Mock implements Dio {}

class _MockStorage extends Mock implements FlutterSecureStorage {}

class _FakeOptions extends Fake implements Options {}

const int kShiftLineId = 800;
const String kToken = 'stored-token';

Map<String, dynamic> _fullConsumeBody() => <String, dynamic>{
  'success': true,
  'data': <String, dynamic>{
    'rollId': 999,
    'generatedRollId': '777000000001',
    'finalState': 'CONSUMED',
    'consumedWeightKg': 250.0,
    'remainingWeightKg': 0.0,
    'remainderAction': 'NONE',
    'eventType': 'CLOSED_FULL',
    'reprintAvailable': false,
  },
};

Map<String, dynamic> _returnBody() => <String, dynamic>{
  'success': true,
  'data': <String, dynamic>{
    'rollId': 999,
    'generatedRollId': '777000000001',
    'finalState': 'PARTIALLY_RETURNED',
    'consumedWeightKg': 175.5,
    'remainingWeightKg': 75.5,
    'remainderAction': 'RETURN',
    'eventType': 'CLOSED_PARTIAL_RETURN',
    'reprintAvailable': true,
  },
};

Map<String, dynamic> _grindingBody() => <String, dynamic>{
  'success': true,
  'data': <String, dynamic>{
    'rollId': 999,
    'generatedRollId': '777000000001',
    'finalState': 'SENT_TO_GRINDING',
    'consumedWeightKg': 210.0,
    'remainingWeightKg': 40.0,
    'remainderAction': 'GRINDING',
    'eventType': 'CLOSED_PARTIAL_GRINDING',
    'reprintAvailable': true,
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
  late PreviousRollRepository repo;

  setUp(() {
    dio = _MockDio();
    rawStorage = _MockStorage();
    storage = SecureTokenStorage.withStorage(rawStorage);
    repo = PreviousRollRepositoryImpl(
      api: PreviousRollApi(dio),
      storage: storage,
    );
  });

  void stubReadToken(String? value) {
    when(
      () => rawStorage.read(key: 'roll_worker_session_token_$kShiftLineId'),
    ).thenAnswer((_) async => value);
  }

  group('fullConsume', () {
    test('with no stored token short-circuits to SESSION_REQUIRED', () async {
      stubReadToken(null);
      final result = await repo.fullConsume(shiftLineId: kShiftLineId);
      expect(result, isA<PreviousRollFailure>());
      expect(
        ((result as PreviousRollFailure).failure as BusinessFailure).code,
        ErrorCode.rollWorkerSessionRequired,
      );
      verifyNever(
        () => dio.post<dynamic>(
          any<String>(),
          data: any<Object?>(named: 'data'),
          options: any<Options>(named: 'options'),
        ),
      );
    });

    test('on success returns the resolution', () async {
      stubReadToken(kToken);
      when(
        () => dio.post<dynamic>(
          ApiPaths.previousRollFullConsume(kShiftLineId),
          data: any<Object?>(named: 'data'),
          options: any<Options>(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response<dynamic>(
          requestOptions: RequestOptions(path: '/x'),
          statusCode: 200,
          data: _fullConsumeBody(),
        ),
      );
      final result = await repo.fullConsume(shiftLineId: kShiftLineId);
      expect(result, isA<PreviousRollSuccess>());
      final res = (result as PreviousRollSuccess).resolution;
      expect(res.consumedWeightKg, 250.0);
      expect(res.reprintAvailable, isFalse);
    });
  });

  group('returnRemaining', () {
    test('on success surfaces RETURN remainderAction + reprint=true', () async {
      stubReadToken(kToken);
      when(
        () => dio.post<dynamic>(
          ApiPaths.previousRollReturn(kShiftLineId),
          data: any<Object?>(named: 'data'),
          options: any<Options>(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response<dynamic>(
          requestOptions: RequestOptions(path: '/x'),
          statusCode: 200,
          data: _returnBody(),
        ),
      );
      final result = await repo.returnRemaining(
        shiftLineId: kShiftLineId,
        remainingWeightKg: 75.5,
      );
      expect(result, isA<PreviousRollSuccess>());
      final res = (result as PreviousRollSuccess).resolution;
      expect(res.remainingWeightKg, 75.5);
      expect(res.reprintAvailable, isTrue);
    });

    test(
      'on INVALID_REMAINING_ROLL_WEIGHT preserves the locally stored token',
      () async {
        stubReadToken(kToken);
        when(
          () => dio.post<dynamic>(
            ApiPaths.previousRollReturn(kShiftLineId),
            data: any<Object?>(named: 'data'),
            options: any<Options>(named: 'options'),
          ),
        ).thenThrow(
          _businessException(
            statusCode: 400,
            code: 'INVALID_REMAINING_ROLL_WEIGHT',
          ),
        );
        final result = await repo.returnRemaining(
          shiftLineId: kShiftLineId,
          remainingWeightKg: 1000.0,
        );
        expect(result, isA<PreviousRollFailure>());
        expect(
          ((result as PreviousRollFailure).failure as BusinessFailure).code,
          ErrorCode.invalidRemainingRollWeight,
        );
        verifyNever(() => rawStorage.delete(key: any<String>(named: 'key')));
      },
    );

    test(
      'on ROLL_WORKER_SESSION_REQUIRED clears the locally stored token',
      () async {
        stubReadToken(kToken);
        when(
          () => dio.post<dynamic>(
            ApiPaths.previousRollReturn(kShiftLineId),
            data: any<Object?>(named: 'data'),
            options: any<Options>(named: 'options'),
          ),
        ).thenThrow(
          _businessException(
            statusCode: 401,
            code: 'ROLL_WORKER_SESSION_REQUIRED',
          ),
        );
        when(
          () => rawStorage.delete(key: any<String>(named: 'key')),
        ).thenAnswer((_) async {});
        final result = await repo.returnRemaining(
          shiftLineId: kShiftLineId,
          remainingWeightKg: 75.5,
        );
        expect(result, isA<PreviousRollFailure>());
        verify(
          () =>
              rawStorage.delete(key: 'roll_worker_session_token_$kShiftLineId'),
        ).called(1);
      },
    );
  });

  group('sendToGrinding', () {
    test(
      'on success surfaces GRINDING remainderAction + reprint=true',
      () async {
        stubReadToken(kToken);
        when(
          () => dio.post<dynamic>(
            ApiPaths.previousRollGrinding(kShiftLineId),
            data: any<Object?>(named: 'data'),
            options: any<Options>(named: 'options'),
          ),
        ).thenAnswer(
          (_) async => Response<dynamic>(
            requestOptions: RequestOptions(path: '/x'),
            statusCode: 200,
            data: _grindingBody(),
          ),
        );
        final result = await repo.sendToGrinding(
          shiftLineId: kShiftLineId,
          remainingWeightKg: 40.0,
        );
        expect(result, isA<PreviousRollSuccess>());
        final res = (result as PreviousRollSuccess).resolution;
        expect(res.remainingWeightKg, 40.0);
        expect(res.reprintAvailable, isTrue);
      },
    );

    test(
      'on THERMOFORMING_SHIFT_LINE_NOT_ACTIVE clears the locally stored token',
      () async {
        stubReadToken(kToken);
        when(
          () => dio.post<dynamic>(
            ApiPaths.previousRollGrinding(kShiftLineId),
            data: any<Object?>(named: 'data'),
            options: any<Options>(named: 'options'),
          ),
        ).thenThrow(
          _businessException(
            statusCode: 409,
            code: 'THERMOFORMING_SHIFT_LINE_NOT_ACTIVE',
          ),
        );
        when(
          () => rawStorage.delete(key: any<String>(named: 'key')),
        ).thenAnswer((_) async {});
        final result = await repo.sendToGrinding(
          shiftLineId: kShiftLineId,
          remainingWeightKg: 40.0,
        );
        expect(result, isA<PreviousRollFailure>());
        verify(
          () =>
              rawStorage.delete(key: 'roll_worker_session_token_$kShiftLineId'),
        ).called(1);
      },
    );

    test('network failure preserves the locally stored token', () async {
      stubReadToken(kToken);
      when(
        () => dio.post<dynamic>(
          any<String>(),
          data: any<Object?>(named: 'data'),
          options: any<Options>(named: 'options'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/x'),
          type: DioExceptionType.connectionError,
        ),
      );
      final result = await repo.sendToGrinding(
        shiftLineId: kShiftLineId,
        remainingWeightKg: 40.0,
      );
      expect(result, isA<PreviousRollFailure>());
      expect((result as PreviousRollFailure).failure, isA<NetworkFailure>());
      verifyNever(() => rawStorage.delete(key: any<String>(named: 'key')));
    });
  });
}
