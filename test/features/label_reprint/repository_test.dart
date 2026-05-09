import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:thermoforming_roll_worker/core/api/api_paths.dart';
import 'package:thermoforming_roll_worker/core/errors/app_failure.dart';
import 'package:thermoforming_roll_worker/core/errors/error_code.dart';
import 'package:thermoforming_roll_worker/core/storage/secure_token_storage.dart';
import 'package:thermoforming_roll_worker/features/label_reprint/data/label_reprint_api.dart';
import 'package:thermoforming_roll_worker/features/label_reprint/data/label_reprint_repository_impl.dart';
import 'package:thermoforming_roll_worker/features/label_reprint/domain/label_reprint_repository.dart';

class _MockDio extends Mock implements Dio {}

class _MockStorage extends Mock implements FlutterSecureStorage {}

class _FakeOptions extends Fake implements Options {}

const int kShiftLineId = 800;
const String kRollId = '777000000001';
const String kToken = 'stored-token';

Map<String, dynamic> _successBody() => <String, dynamic>{
  'success': true,
  'data': <String, dynamic>{
    'generatedRollId': kRollId,
    'prefixSnapshot': '777',
    'serialNumber': 1,
    'rollTypeId': 70,
    'rollTypeRollCode': 'TT-1S B250 White',
    'rollTypeDisplayName': 'TT-1S B250',
    'colorName': 'White',
    'standardLengthM': 100.0,
    'standardWeightKg': 250.0,
    'actualLengthM': 99.5,
    'actualWeightKg': 248.0,
    'actualThicknessMm': 0.250,
    'productionKind': 'NORMAL',
    'consumptionState': 'PARTIALLY_RETURNED',
    'lastKnownWeightKg': 75.5,
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
  late LabelReprintRepository repo;

  setUp(() {
    dio = _MockDio();
    rawStorage = _MockStorage();
    storage = SecureTokenStorage.withStorage(rawStorage);
    repo = LabelReprintRepositoryImpl(
      api: LabelReprintApi(dio),
      storage: storage,
    );
  });

  test('with no stored token short-circuits to SESSION_REQUIRED', () async {
    when(
      () => rawStorage.read(key: 'roll_worker_session_token_$kShiftLineId'),
    ).thenAnswer((_) async => null);

    final result = await repo.fetchLabel(
      shiftLineId: kShiftLineId,
      generatedRollId: kRollId,
    );
    expect(result, isA<LabelReprintFailureResult>());
    expect(
      ((result as LabelReprintFailureResult).failure as BusinessFailure).code,
      ErrorCode.rollWorkerSessionRequired,
    );
    verifyNever(
      () => dio.get<dynamic>(
        any<String>(),
        options: any<Options>(named: 'options'),
      ),
    );
  });

  test('on success returns the label', () async {
    when(
      () => rawStorage.read(key: 'roll_worker_session_token_$kShiftLineId'),
    ).thenAnswer((_) async => kToken);
    when(
      () => dio.get<dynamic>(
        ApiPaths.reprintRollLabel(kRollId),
        options: any<Options>(named: 'options'),
      ),
    ).thenAnswer(
      (_) async => Response<dynamic>(
        requestOptions: RequestOptions(path: '/x'),
        statusCode: 200,
        data: _successBody(),
      ),
    );

    final result = await repo.fetchLabel(
      shiftLineId: kShiftLineId,
      generatedRollId: kRollId,
    );
    expect(result, isA<LabelReprintSuccess>());
    final label = (result as LabelReprintSuccess).label;
    expect(label.generatedRollId, kRollId);
    expect(label.lastKnownWeightKg, 75.5);
  });

  test(
    'ROLL_LABEL_REPRINT_NOT_AVAILABLE preserves the locally stored token',
    () async {
      when(
        () => rawStorage.read(key: 'roll_worker_session_token_$kShiftLineId'),
      ).thenAnswer((_) async => kToken);
      when(
        () => dio.get<dynamic>(
          ApiPaths.reprintRollLabel(kRollId),
          options: any<Options>(named: 'options'),
        ),
      ).thenThrow(
        _businessException(
          statusCode: 409,
          code: 'ROLL_LABEL_REPRINT_NOT_AVAILABLE',
        ),
      );

      final result = await repo.fetchLabel(
        shiftLineId: kShiftLineId,
        generatedRollId: kRollId,
      );

      expect(result, isA<LabelReprintFailureResult>());
      verifyNever(() => rawStorage.delete(key: any<String>(named: 'key')));
    },
  );

  test(
    'ROLL_WORKER_SESSION_REQUIRED clears the locally stored token',
    () async {
      when(
        () => rawStorage.read(key: 'roll_worker_session_token_$kShiftLineId'),
      ).thenAnswer((_) async => kToken);
      when(
        () => dio.get<dynamic>(
          ApiPaths.reprintRollLabel(kRollId),
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

      final result = await repo.fetchLabel(
        shiftLineId: kShiftLineId,
        generatedRollId: kRollId,
      );

      expect(result, isA<LabelReprintFailureResult>());
      verify(
        () => rawStorage.delete(key: 'roll_worker_session_token_$kShiftLineId'),
      ).called(1);
    },
  );
}
