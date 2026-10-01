import '../../../core/errors/app_failure.dart';
import 'entities/production_time_input.dart';
import 'entities/roll_search_outcome.dart';

/// Outcome of a production-time search call. Repositories return one of these
/// instead of throwing — controllers map to UI states.
sealed class RollSearchResult {
  const RollSearchResult();
}

class RollSearchSuccess extends RollSearchResult {
  const RollSearchSuccess(this.outcome);
  final RollSearchOutcome outcome;
}

class RollSearchFailure extends RollSearchResult {
  const RollSearchFailure(this.failure);
  final AppFailure failure;
}

/// Read-only roll lookup by production time for a Thermoforming shift-line.
abstract class RollSearchRepository {
  /// `GET /shift-lines/{shiftLineId}/rolls/by-production-time`.
  ///
  /// Resolves the locally-stored session token for [shiftLineId] and attaches
  /// it as `X-Session-Token`; with no stored token it returns a
  /// session-required failure without a network call. A session-loss failure
  /// clears the stored token, as the scan does.
  Future<RollSearchResult> searchByProductionTime({
    required int shiftLineId,
    required ProductionTimeQuery query,
  });
}
