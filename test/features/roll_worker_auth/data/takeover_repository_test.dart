import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:thermoforming_roll_worker/core/api/api_paths.dart';
import 'package:thermoforming_roll_worker/core/errors/app_failure.dart';
import 'package:thermoforming_roll_worker/core/errors/error_code.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/data/dto/roll_worker_takeover_request.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/data/takeover_api.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/data/takeover_repository_impl.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/domain/entities/roll_worker_takeover.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/domain/takeover_repository.dart';

class _MockDio extends Mock implements Dio {}

const RollWorkerTakeoverRequest _request = RollWorkerTakeoverRequest(
  shiftLineId: 80,
  incomingOperatorPin: '1234',
  action: RollWorkerTakeoverAction.rollRemainsMounted,
  clientRequestId: 'cid-1',
  currentWeightKg: 60.0,
);

void main() {
  late _MockDio dio;
  late TakeoverRepository repo;

  setUp(() {
    dio = _MockDio();
    repo = TakeoverRepositoryImpl(api: TakeoverApi(dio));
  });

  test('on success maps the response', () async {
    when(
      () => dio.post<dynamic>(
        ApiPaths.sessionsTakeoverWithRollDeclaration,
        data: any<Object?>(named: 'data'),
      ),
    ).thenAnswer(
      (_) async => Response<dynamic>(
        requestOptions: RequestOptions(path: '/x'),
        statusCode: 200,
        data: <String, dynamic>{
          'success': true,
          'data': <String, dynamic>{
            'alreadyProcessed': false,
            'sessionToken': 'tok',
            'action': 'ROLL_REMAINS_MOUNTED',
            'rollClosed': false,
            'rollRemainsMounted': true,
            'currentWeightKg': 60.0,
            'previousWorkerName': 'محمد',
          },
        },
      ),
    );

    final TakeoverResult result = await repo.takeover(_request);
    expect(result, isA<TakeoverSuccess>());
    final res = (result as TakeoverSuccess).response;
    expect(res.sessionToken, 'tok');
    expect(res.rollRemainsMounted, isTrue);
  });

  test('maps a business error code to BusinessFailure', () async {
    when(
      () => dio.post<dynamic>(
        ApiPaths.sessionsTakeoverWithRollDeclaration,
        data: any<Object?>(named: 'data'),
      ),
    ).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: '/x'),
        type: DioExceptionType.badResponse,
        response: Response<dynamic>(
          requestOptions: RequestOptions(path: '/x'),
          statusCode: 409,
          data: <String, dynamic>{
            'success': false,
            'error': <String, dynamic>{'code': 'ROLL_WORKER_SESSION_REQUIRED'},
          },
        ),
      ),
    );

    final TakeoverResult result = await repo.takeover(_request);
    expect(result, isA<TakeoverFailure>());
    final AppFailure failure = (result as TakeoverFailure).failure;
    expect(
      (failure as BusinessFailure).code,
      ErrorCode.rollWorkerSessionRequired,
    );
  });

  test('maps a transport error to NetworkFailure', () async {
    when(
      () => dio.post<dynamic>(
        ApiPaths.sessionsTakeoverWithRollDeclaration,
        data: any<Object?>(named: 'data'),
      ),
    ).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: '/x'),
        type: DioExceptionType.connectionError,
      ),
    );

    final TakeoverResult result = await repo.takeover(_request);
    expect(result, isA<TakeoverFailure>());
    expect((result as TakeoverFailure).failure, isA<NetworkFailure>());
  });
}
