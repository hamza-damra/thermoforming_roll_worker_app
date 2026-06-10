import '../../../core/api/api_error_parser.dart';
import '../../../core/errors/app_failure.dart';
import '../domain/takeover_repository.dart';
import 'dto/roll_worker_takeover_request.dart';
import 'takeover_api.dart';

class TakeoverRepositoryImpl implements TakeoverRepository {
  TakeoverRepositoryImpl({required TakeoverApi api}) : _api = api;

  final TakeoverApi _api;

  @override
  Future<TakeoverResult> takeover(RollWorkerTakeoverRequest request) async {
    try {
      return TakeoverSuccess(await _api.takeover(request));
    } catch (error, stack) {
      final AppFailure failure = ApiErrorParser.parse(error, stack);
      return TakeoverFailure(failure);
    }
  }
}
