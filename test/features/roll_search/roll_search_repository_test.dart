import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:thermoforming_roll_worker/core/api/api_paths.dart';
import 'package:thermoforming_roll_worker/core/api/session_token_interceptor.dart';
import 'package:thermoforming_roll_worker/core/errors/app_failure.dart';
import 'package:thermoforming_roll_worker/core/errors/error_code.dart';
import 'package:thermoforming_roll_worker/core/storage/secure_token_storage.dart';
import 'package:thermoforming_roll_worker/features/roll_search/data/roll_search_api.dart';
import 'package:thermoforming_roll_worker/features/roll_search/data/roll_search_repository_impl.dart';
import 'package:thermoforming_roll_worker/features/roll_search/domain/entities/production_time_input.dart';
import 'package:thermoforming_roll_worker/features/roll_search/domain/entities/roll_search_outcome.dart';
import 'package:thermoforming_roll_worker/features/roll_search/domain/roll_search_repository.dart';

class _MockDio extends Mock implements Dio {}

class _MockStorage extends Mock implements FlutterSecureStorage {}

class _FakeOptions extends Fake implements Options {}

const int kShiftLineId = 800;
const String kToken = 'stored-token';
const ProductionTimeQuery kQuery = ProductionTimeQuery(
  year: 2026,
  month: 9,
  day: 30,
  hour24: 14,
  minute: 5,
);

Map<String, dynamic> _foundBody() => <String, dynamic>{
  'success': true,
  'data': <String, dynamic>{
    'status': 'FOUND',
    'searchedLocalMinute': '2026-09-30T14:05',
    'matchCount': 1,
    'roll': <String, dynamic>{
      'rollId': 9,
      'generatedRollId': '777000000009',
      'producedAt': '2026-09-30T11:05:10Z',
      'consumptionState': 'AVAILABLE',
      'mountable': true,
    },
  },
};

DioException _businessException({
  required int statusCode,
  required String code,
  Map<String, dynamic>? details,
}) => DioException(
  requestOptions: RequestOptions(path: '/x'),
  type: DioExceptionType.badResponse,
  response: Response<dynamic>(
    requestOptions: RequestOptions(path: '/x'),
    statusCode: statusCode,
    data: <String, dynamic>{
      'success': false,
      'error': <String, dynamic>{
        'code': code,
        'details': ?details,
      },
    },
  ),
);

void main() {
  setUpAll(() => registerFallbackValue(_FakeOptions()));

  late _MockDio dio;
  late _MockStorage rawStorage;
  late RollSearchRepository repo;

  setUp(() {
    dio = _MockDio();
    rawStorage = _MockStorage();
    repo = RollSearchRepositoryImpl(
      api: RollSearchApi(dio),
      storage: SecureTokenStorage.withStorage(rawStorage),
    );
  });

  void stubToken(String? value) {
    when(
      () => rawStorage.read(key: 'roll_worker_session_token_$kShiftLineId'),
    ).thenAnswer((_) async => value);
  }

  void stubGet(Future<Response<dynamic>> Function() answer) {
    when(
      () => dio.get<dynamic>(
        any<String>(),
        queryParameters: any<Map<String, dynamic>?>(named: 'queryParameters'),
        options: any<Options>(named: 'options'),
      ),
    ).thenAnswer((_) => answer());
  }

  void verifyNoCall() => verifyNever(
    () => dio.get<dynamic>(
      any<String>(),
      queryParameters: any<Map<String, dynamic>?>(named: 'queryParameters'),
      options: any<Options>(named: 'options'),
    ),
  );

  Response<dynamic> ok(Object? body) => Response<dynamic>(
    requestOptions: RequestOptions(path: '/x'),
    statusCode: 200,
    data: body,
  );

  test('no stored token → session-required, backend never called', () async {
    stubToken(null);
    final result = await repo.searchByProductionTime(
      shiftLineId: kShiftLineId,
      query: kQuery,
    );
    expect(result, isA<RollSearchFailure>());
    final failure = (result as RollSearchFailure).failure as BusinessFailure;
    expect(failure.code, ErrorCode.rollWorkerSessionRequired);
    verifyNoCall();
  });

  test('an empty stored token behaves like no token', () async {
    stubToken('');
    final result = await repo.searchByProductionTime(
      shiftLineId: kShiftLineId,
      query: kQuery,
    );
    expect(result, isA<RollSearchFailure>());
    verifyNoCall();
  });

  test('success returns the parsed outcome', () async {
    stubToken(kToken);
    stubGet(() async => ok(_foundBody()));
    final result = await repo.searchByProductionTime(
      shiftLineId: kShiftLineId,
      query: kQuery,
    );
    expect(result, isA<RollSearchSuccess>());
    final RollSearchOutcome o = (result as RollSearchSuccess).outcome;
    expect(o.status, RollSearchStatus.found);
    expect(o.matches.single.generatedRollId, '777000000009');
  });

  test('sends 24-hour query parameters, the path, and the session token',
      () async {
    stubToken(kToken);
    stubGet(() async => ok(_foundBody()));
    await repo.searchByProductionTime(
      shiftLineId: kShiftLineId,
      query: kQuery,
    );
    final List<dynamic> captured = verify(
      () => dio.get<dynamic>(
        captureAny<String>(),
        queryParameters: captureAny<Map<String, dynamic>?>(
          named: 'queryParameters',
        ),
        options: captureAny<Options>(named: 'options'),
      ),
    ).captured;
    // Captured order is not guaranteed to be argument order; pick by type.
    final String path = captured.whereType<String>().single;
    final Map<dynamic, dynamic> query =
        captured.whereType<Map<dynamic, dynamic>>().single;
    final Options options = captured.whereType<Options>().single;
    expect(path, ApiPaths.rollsByProductionTime(kShiftLineId));
    expect(path, endsWith('/shift-lines/800/rolls/by-production-time'));
    expect(query, <String, Object>{
      'year': 2026,
      'month': 9,
      'day': 30,
      'hour': 14,
      'minute': 5,
    });
    expect(options.extra?[SessionTokenInterceptor.extraKey], kToken);
  });

  test('400 ROLL_PRODUCTION_TIME_INVALID → BusinessFailure with details, '
      'token kept', () async {
    stubToken(kToken);
    stubGet(
      () async => throw _businessException(
        statusCode: 400,
        code: 'ROLL_PRODUCTION_TIME_INVALID',
        details: <String, dynamic>{'field': 'hour', 'reason': 'OUT_OF_RANGE'},
      ),
    );
    final result = await repo.searchByProductionTime(
      shiftLineId: kShiftLineId,
      query: kQuery,
    );
    final failure = (result as RollSearchFailure).failure as BusinessFailure;
    expect(failure.code, ErrorCode.rollProductionTimeInvalid);
    expect(failure.details, <String, dynamic>{
      'field': 'hour',
      'reason': 'OUT_OF_RANGE',
    });
    verifyNever(() => rawStorage.delete(key: any<String>(named: 'key')));
  });

  const List<(int, String)> sessionLoss = <(int, String)>[
    (401, 'ROLL_WORKER_SESSION_REQUIRED'),
    (400, 'ROLL_OP_SESSION_TOKEN_MISSING'),
    (409, 'THERMOFORMING_SHIFT_LINE_NOT_ACTIVE'),
    (404, 'THERMOFORMING_SHIFT_LINE_NOT_FOUND'),
  ];
  for (final (int status, String code) in sessionLoss) {
    test('$code clears the stored token', () async {
      stubToken(kToken);
      stubGet(
        () async => throw _businessException(statusCode: status, code: code),
      );
      when(
        () => rawStorage.delete(key: any<String>(named: 'key')),
      ).thenAnswer((_) async {});
      final result = await repo.searchByProductionTime(
        shiftLineId: kShiftLineId,
        query: kQuery,
      );
      expect(result, isA<RollSearchFailure>());
      verify(
        () => rawStorage.delete(key: 'roll_worker_session_token_$kShiftLineId'),
      ).called(1);
    });
  }

  test('a device-key fault does not clear the token', () async {
    stubToken(kToken);
    stubGet(
      () async => throw _businessException(
        statusCode: 401,
        code: 'AUTH_INVALID_CREDENTIALS',
      ),
    );
    final result = await repo.searchByProductionTime(
      shiftLineId: kShiftLineId,
      query: kQuery,
    );
    expect(
      ((result as RollSearchFailure).failure as BusinessFailure).code,
      ErrorCode.authInvalidCredentials,
    );
    verifyNever(() => rawStorage.delete(key: any<String>(named: 'key')));
  });

  test('a malformed envelope becomes a failure, not a throw', () async {
    stubToken(kToken);
    stubGet(
      () async => ok(<String, dynamic>{'success': true, 'data': 'nope'}),
    );
    final result = await repo.searchByProductionTime(
      shiftLineId: kShiftLineId,
      query: kQuery,
    );
    expect(result, isA<RollSearchFailure>());
    verifyNever(() => rawStorage.delete(key: any<String>(named: 'key')));
  });

  test('a connection error is a NetworkFailure', () async {
    stubToken(kToken);
    stubGet(
      () async => throw DioException(
        requestOptions: RequestOptions(path: '/x'),
        type: DioExceptionType.connectionError,
      ),
    );
    final result = await repo.searchByProductionTime(
      shiftLineId: kShiftLineId,
      query: kQuery,
    );
    expect((result as RollSearchFailure).failure, isA<NetworkFailure>());
  });
}
