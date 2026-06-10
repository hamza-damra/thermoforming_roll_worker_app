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
const String kKey = 'roll_worker_session_token_$kShiftLineId';

Map<String, dynamic> _handoverBody() => <String, dynamic>{
  'success': true,
  'data': <String, dynamic>{
    'rollId': 12345,
    'generatedRollId': '777000000001',
    'finalState': 'IN_CONSUMPTION',
    'consumedWeightKg': 40.0,
    'currentWeightKg': 60.0,
    'rollRemainsMounted': true,
  },
};

DioException _businessException(String code, int statusCode) => DioException(
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

void main() {
  setUpAll(() => registerFallbackValue(_FakeOptions()));

  late _MockDio dio;
  late _MockStorage rawStorage;
  late PreviousRollRepository repo;

  setUp(() {
    dio = _MockDio();
    rawStorage = _MockStorage();
    repo = PreviousRollRepositoryImpl(
      api: PreviousRollApi(dio),
      storage: SecureTokenStorage.withStorage(rawStorage),
    );
  });

  void stubReadToken(String? value) {
    when(() => rawStorage.read(key: kKey)).thenAnswer((_) async => value);
  }

  test('no stored token short-circuits to SESSION_REQUIRED', () async {
    stubReadToken(null);
    final KeepMountedResult result = await repo.keepMountedHandover(
      shiftLineId: kShiftLineId,
      remainingWeightKg: 60.0,
    );
    expect(result, isA<KeepMountedFailure>());
    expect(
      ((result as KeepMountedFailure).failure as BusinessFailure).code,
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

  test('on success maps the response AND clears the session token', () async {
    stubReadToken(kToken);
    when(() => rawStorage.delete(key: any<String>(named: 'key')))
        .thenAnswer((_) async {});
    when(
      () => dio.post<dynamic>(
        ApiPaths.previousRollKeepMountedHandover(kShiftLineId),
        data: any<Object?>(named: 'data'),
        options: any<Options>(named: 'options'),
      ),
    ).thenAnswer(
      (_) async => Response<dynamic>(
        requestOptions: RequestOptions(path: '/x'),
        statusCode: 200,
        data: _handoverBody(),
      ),
    );

    final KeepMountedResult result = await repo.keepMountedHandover(
      shiftLineId: kShiftLineId,
      remainingWeightKg: 60.0,
    );

    expect(result, isA<KeepMountedSuccess>());
    final res = (result as KeepMountedSuccess).response;
    expect(res.consumedWeightKg, 40.0);
    expect(res.currentWeightKg, 60.0);
    expect(res.rollRemainsMounted, isTrue);
    // The session is ended server-side → local token must be cleared.
    verify(() => rawStorage.delete(key: kKey)).called(1);
  });

  test('on INVALID_REMAINING_ROLL_WEIGHT preserves the token', () async {
    stubReadToken(kToken);
    when(
      () => dio.post<dynamic>(
        ApiPaths.previousRollKeepMountedHandover(kShiftLineId),
        data: any<Object?>(named: 'data'),
        options: any<Options>(named: 'options'),
      ),
    ).thenThrow(_businessException('INVALID_REMAINING_ROLL_WEIGHT', 400));

    final KeepMountedResult result = await repo.keepMountedHandover(
      shiftLineId: kShiftLineId,
      remainingWeightKg: 1000.0,
    );

    expect(result, isA<KeepMountedFailure>());
    expect(
      ((result as KeepMountedFailure).failure as BusinessFailure).code,
      ErrorCode.invalidRemainingRollWeight,
    );
    verifyNever(() => rawStorage.delete(key: any<String>(named: 'key')));
  });
}
