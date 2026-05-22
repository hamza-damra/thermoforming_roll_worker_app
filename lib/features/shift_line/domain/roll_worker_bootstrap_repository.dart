import '../../../core/errors/app_failure.dart';
import 'entities/roll_worker_bootstrap_line.dart';

/// Outcome of a fetch against `GET /api/v1/thermoforming-roll-app/bootstrap`.
sealed class RollWorkerBootstrapResult {
  const RollWorkerBootstrapResult();
}

class RollWorkerBootstrapSuccess extends RollWorkerBootstrapResult {
  const RollWorkerBootstrapSuccess(this.lines);
  final List<RollWorkerBootstrapLine> lines;
}

class RollWorkerBootstrapFailure extends RollWorkerBootstrapResult {
  const RollWorkerBootstrapFailure(this.failure);
  final AppFailure failure;
}

/// Repository contract for the pre-login bootstrap picker. The endpoint is
/// reachable before roll-worker authentication, so the impl attaches only the
/// `X-Device-Key` header — never an `X-Session-Token`.
abstract class RollWorkerBootstrapRepository {
  /// `GET /api/v1/thermoforming-roll-app/bootstrap`.
  Future<RollWorkerBootstrapResult> fetch();
}
