import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:thermoforming_roll_worker/features/shift_line/data/dto/roll_worker_bootstrap_response.dart';
import 'package:thermoforming_roll_worker/features/shift_line/data/roll_worker_bootstrap_api.dart';
import 'package:thermoforming_roll_worker/features/shift_line/data/roll_worker_bootstrap_repository_impl.dart';
import 'package:thermoforming_roll_worker/features/shift_line/domain/roll_worker_bootstrap_repository.dart';

class _MockApi extends Mock implements RollWorkerBootstrapApi {}

RollWorkerBootstrapLineDto _dto(int id) =>
    RollWorkerBootstrapLineDto.fromJson(<String, dynamic>{
      'thermoformingLineId': id,
      'lineCode': 'TH-0$id',
      'lineName': 'خط $id',
      'selectable': true,
      'shiftLineId': id + 1000,
    });

void main() {
  test('maps API DTOs to entities on success', () async {
    final api = _MockApi();
    when(api.fetch).thenAnswer(
      (_) async => <RollWorkerBootstrapLineDto>[_dto(1), _dto(2)],
    );
    final repo = RollWorkerBootstrapRepositoryImpl(api: api);

    final RollWorkerBootstrapResult result = await repo.fetch();

    expect(result, isA<RollWorkerBootstrapSuccess>());
    final lines = (result as RollWorkerBootstrapSuccess).lines;
    expect(lines, hasLength(2));
    expect(lines.first.thermoformingLineId, 1);
    expect(lines.last.shiftLineId, 1002);
  });

  test('routes a DioException through ApiErrorParser into a Failure', () async {
    final api = _MockApi();
    when(api.fetch).thenThrow(
      DioException(requestOptions: RequestOptions(path: '/bootstrap')),
    );
    final repo = RollWorkerBootstrapRepositoryImpl(api: api);

    final RollWorkerBootstrapResult result = await repo.fetch();

    expect(result, isA<RollWorkerBootstrapFailure>());
  });
}
