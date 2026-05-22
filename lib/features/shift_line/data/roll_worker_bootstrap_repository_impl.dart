import '../../../core/api/api_error_parser.dart';
import '../domain/entities/roll_worker_bootstrap_line.dart';
import '../domain/roll_worker_bootstrap_repository.dart';
import 'dto/roll_worker_bootstrap_response.dart';
import 'roll_worker_bootstrap_api.dart';

class RollWorkerBootstrapRepositoryImpl implements RollWorkerBootstrapRepository {
  RollWorkerBootstrapRepositoryImpl({required RollWorkerBootstrapApi api})
    : _api = api;

  final RollWorkerBootstrapApi _api;

  @override
  Future<RollWorkerBootstrapResult> fetch() async {
    try {
      final List<RollWorkerBootstrapLineDto> dtos = await _api.fetch();
      final List<RollWorkerBootstrapLine> lines = dtos
          .map((dto) => dto.toEntity())
          .toList(growable: false);
      return RollWorkerBootstrapSuccess(lines);
    } catch (error, stack) {
      return RollWorkerBootstrapFailure(ApiErrorParser.parse(error, stack));
    }
  }
}
