import '../../../core/errors/app_failure.dart';
import '../data/dto/roll_worker_takeover_request.dart';
import '../data/dto/roll_worker_takeover_response.dart';

/// Outcome of a takeover-with-roll-declaration call. Repositories return one of
/// these instead of throwing — the controller maps to UI states.
sealed class TakeoverResult {
  const TakeoverResult();
}

class TakeoverSuccess extends TakeoverResult {
  const TakeoverSuccess(this.response);
  final RollWorkerTakeoverResponse response;
}

class TakeoverFailure extends TakeoverResult {
  const TakeoverFailure(this.failure);
  final AppFailure failure;
}

/// Repository contract for resolving an abandoned mounted roll and claiming the
/// line for the incoming worker (V104). Idempotent on
/// [RollWorkerTakeoverRequest.clientRequestId].
abstract class TakeoverRepository {
  Future<TakeoverResult> takeover(RollWorkerTakeoverRequest request);
}
