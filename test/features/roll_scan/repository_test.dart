import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:thermoforming_roll_worker/core/api/api_paths.dart';
import 'package:thermoforming_roll_worker/core/errors/app_failure.dart';
import 'package:thermoforming_roll_worker/core/errors/error_code.dart';
import 'package:thermoforming_roll_worker/core/storage/secure_token_storage.dart';
import 'package:thermoforming_roll_worker/features/roll_scan/data/roll_scan_api.dart';
import 'package:thermoforming_roll_worker/features/roll_scan/data/roll_scan_repository_impl.dart';
import 'package:thermoforming_roll_worker/features/roll_scan/domain/roll_scan_repository.dart';

class _MockDio extends Mock implements Dio {}

class _MockStorage extends Mock implements FlutterSecureStorage {}

class _FakeOptions extends Fake implements Options {}

const int kShiftLineId = 800;
const String kRollId = '777000000001';
const String kToken = 'stored-token';

Map<String, dynamic> _scanSuccessBody() => <String, dynamic>{
  'success': true,
  'data': <String, dynamic>{
    'rollId': 999,
    'generatedRollId': kRollId,
    'rollTypeId': 70,
    'rollTypeRollCode': 'TT-1S B250 White',
    'rollTypeDisplayName': 'TT-1S B250',
    'colorName': 'White',
    'productTypeId': 5,
    'productTypeName': 'أحمر 20 كغ',
    'consumptionItemId': 5000,
    'activeSegmentId': 6000,
    'state': 'IN_CONSUMPTION',
    'lastKnownWeightKg': 250.0,
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
  late RollScanRepository repo;

  setUp(() {
    dio = _MockDio();
    rawStorage = _MockStorage();
    storage = SecureTokenStorage.withStorage(rawStorage);
    repo = RollScanRepositoryImpl(api: RollScanApi(dio), storage: storage);
  });

  void stubReadToken(String? value) {
    when(
      () => rawStorage.read(key: 'roll_worker_session_token_$kShiftLineId'),
    ).thenAnswer((_) async => value);
  }

  test(
    'no stored token → returns SESSION_REQUIRED without calling backend',
    () async {
      stubReadToken(null);
      final result = await repo.mountRoll(
        shiftLineId: kShiftLineId,
        generatedRollId: kRollId,
      );
      expect(result, isA<RollScanFailure>());
      final failure = (result as RollScanFailure).failure;
      expect(failure, isA<BusinessFailure>());
      expect(
        (failure as BusinessFailure).code,
        ErrorCode.rollWorkerSessionRequired,
      );
      verifyNever(
        () => dio.post<dynamic>(
          any<String>(),
          data: any<Object?>(named: 'data'),
          options: any<Options>(named: 'options'),
        ),
      );
    },
  );

  test('on success returns RollScanSuccess with the mounted entity', () async {
    stubReadToken(kToken);
    when(
      () => dio.post<dynamic>(
        ApiPaths.scanRoll(kShiftLineId),
        data: any<Object?>(named: 'data'),
        options: any<Options>(named: 'options'),
      ),
    ).thenAnswer(
      (_) async => Response<dynamic>(
        requestOptions: RequestOptions(path: '/x'),
        statusCode: 201,
        data: _scanSuccessBody(),
      ),
    );

    final result = await repo.mountRoll(
      shiftLineId: kShiftLineId,
      generatedRollId: kRollId,
    );

    expect(result, isA<RollScanSuccess>());
    final mounted = (result as RollScanSuccess).mounted;
    expect(mounted.generatedRollId, kRollId);
    expect(mounted.lastKnownWeightKg, 250.0);
  });

  test(
    'ROLL_WORKER_SESSION_REQUIRED clears the locally stored token',
    () async {
      stubReadToken(kToken);
      when(
        () => dio.post<dynamic>(
          any<String>(),
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

      final result = await repo.mountRoll(
        shiftLineId: kShiftLineId,
        generatedRollId: kRollId,
      );

      expect(result, isA<RollScanFailure>());
      verify(
        () => rawStorage.delete(key: 'roll_worker_session_token_$kShiftLineId'),
      ).called(1);
    },
  );

  test(
    'THERMOFORMING_SHIFT_LINE_NOT_ACTIVE clears the locally stored token',
    () async {
      stubReadToken(kToken);
      when(
        () => dio.post<dynamic>(
          any<String>(),
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

      final result = await repo.mountRoll(
        shiftLineId: kShiftLineId,
        generatedRollId: kRollId,
      );

      expect(result, isA<RollScanFailure>());
      verify(
        () => rawStorage.delete(key: 'roll_worker_session_token_$kShiftLineId'),
      ).called(1);
    },
  );

  test(
    'ROLL_NOT_FOUND surfaces BusinessFailure WITHOUT clearing token',
    () async {
      stubReadToken(kToken);
      when(
        () => dio.post<dynamic>(
          any<String>(),
          data: any<Object?>(named: 'data'),
          options: any<Options>(named: 'options'),
        ),
      ).thenThrow(_businessException(statusCode: 404, code: 'ROLL_NOT_FOUND'));

      final result = await repo.mountRoll(
        shiftLineId: kShiftLineId,
        generatedRollId: kRollId,
      );

      expect(result, isA<RollScanFailure>());
      expect(
        ((result as RollScanFailure).failure as BusinessFailure).code,
        ErrorCode.rollNotFound,
      );
      verifyNever(() => rawStorage.delete(key: any<String>(named: 'key')));
    },
  );

  test(
    'success body with warnings[] surfaces them in RollScanSuccess.warnings',
    () async {
      stubReadToken(kToken);
      final Map<String, dynamic> body = _scanSuccessBody();
      (body['data'] as Map<String, dynamic>)['warnings'] =
          <Map<String, Object?>>[
            <String, Object?>{
              'code': 'ROLL_CURING_MAXIMUM_EXCEEDED',
              'severity': 'WARNING',
              'message': 'تنبيه: عمر هذا الرول تجاوز الحد الأعلى للحضانة.',
              'payload': <String, Object?>{
                'rollCode': kRollId,
                'maxCuringDays': 7,
                'actualAgeDays': 13.13,
              },
            },
          ];
      when(
        () => dio.post<dynamic>(
          ApiPaths.scanRoll(kShiftLineId),
          data: any<Object?>(named: 'data'),
          options: any<Options>(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response<dynamic>(
          requestOptions: RequestOptions(path: '/x'),
          statusCode: 201,
          data: body,
        ),
      );

      final result = await repo.mountRoll(
        shiftLineId: kShiftLineId,
        generatedRollId: kRollId,
      );

      expect(result, isA<RollScanSuccess>());
      final success = result as RollScanSuccess;
      expect(success.warnings, hasLength(1));
      expect(success.warnings.first.code, 'ROLL_CURING_MAXIMUM_EXCEEDED');
      expect(success.warnings.first.payload['maxCuringDays'], 7);
    },
  );

  test(
    'ROLL_CURING_MINIMUM_NOT_MET (409) surfaces BusinessFailure WITHOUT '
    'clearing the locally stored token',
    () async {
      stubReadToken(kToken);
      when(
        () => dio.post<dynamic>(
          any<String>(),
          data: any<Object?>(named: 'data'),
          options: any<Options>(named: 'options'),
        ),
      ).thenThrow(
        _businessException(
          statusCode: 409,
          code: 'ROLL_CURING_MINIMUM_NOT_MET',
        ),
      );

      final result = await repo.mountRoll(
        shiftLineId: kShiftLineId,
        generatedRollId: kRollId,
      );

      expect(result, isA<RollScanFailure>());
      final failure = (result as RollScanFailure).failure;
      expect(
        (failure as BusinessFailure).code,
        ErrorCode.rollCuringMinimumNotMet,
      );
      expect(failure.statusCode, 409);
      verifyNever(() => rawStorage.delete(key: any<String>(named: 'key')));
    },
  );

  test(
    'REGRESSION: a device-key fault (AUTH_INVALID_CREDENTIALS) PRESERVES the '
    'stored token — it is a configuration fault, not a session loss',
    () async {
      stubReadToken(kToken);
      when(
        () => dio.post<dynamic>(
          any<String>(),
          data: any<Object?>(named: 'data'),
          options: any<Options>(named: 'options'),
        ),
      ).thenThrow(
        // Same 401 status as a session loss — only the code distinguishes
        // them (handoff §4.4). Clearing the token here would log the worker
        // out of a perfectly valid session over a misconfigured device.
        _businessException(
          statusCode: 401,
          code: 'AUTH_INVALID_CREDENTIALS',
        ),
      );
      when(
        () => rawStorage.delete(key: any<String>(named: 'key')),
      ).thenAnswer((_) async {});

      final result = await repo.mountRoll(
        shiftLineId: kShiftLineId,
        generatedRollId: kRollId,
      );

      expect(result, isA<RollScanFailure>());
      expect(
        ((result as RollScanFailure).failure as BusinessFailure).code,
        ErrorCode.authInvalidCredentials,
      );
      verifyNever(() => rawStorage.delete(key: any<String>(named: 'key')));
    },
  );

  test(
    'ROLL_OP_SESSION_TOKEN_MISSING clears the locally stored token',
    () async {
      stubReadToken(kToken);
      when(
        () => dio.post<dynamic>(
          any<String>(),
          data: any<Object?>(named: 'data'),
          options: any<Options>(named: 'options'),
        ),
      ).thenThrow(
        // 400, not 401 — proof the branch is on the code, not the status.
        _businessException(
          statusCode: 400,
          code: 'ROLL_OP_SESSION_TOKEN_MISSING',
        ),
      );
      when(
        () => rawStorage.delete(key: any<String>(named: 'key')),
      ).thenAnswer((_) async {});

      final result = await repo.mountRoll(
        shiftLineId: kShiftLineId,
        generatedRollId: kRollId,
      );

      expect(result, isA<RollScanFailure>());
      verify(
        () => rawStorage.delete(key: 'roll_worker_session_token_$kShiftLineId'),
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

    final result = await repo.mountRoll(
      shiftLineId: kShiftLineId,
      generatedRollId: kRollId,
    );

    expect(result, isA<RollScanFailure>());
    expect((result as RollScanFailure).failure, isA<NetworkFailure>());
    verifyNever(() => rawStorage.delete(key: any<String>(named: 'key')));
  });
}
