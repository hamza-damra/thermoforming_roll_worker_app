import '../../../core/errors/app_failure.dart';
import 'entities/mounted_roll.dart';

/// Outcome of a scan-roll call. Repositories return one of these instead of
/// throwing — controllers map to UI states.
sealed class RollScanResult {
  const RollScanResult();
}

class RollScanSuccess extends RollScanResult {
  const RollScanSuccess(this.mounted);
  final MountedRoll mounted;
}

class RollScanFailure extends RollScanResult {
  const RollScanFailure(this.failure);
  final AppFailure failure;
}

/// Repository contract for mounting a roll on a Thermoforming shift-line.
abstract class RollScanRepository {
  /// `POST /shift-lines/{shiftLineId}/scan-roll` with body
  /// `{"generatedRollId": "..."}`.
  ///
  /// Resolves the locally-stored roll-worker session token and attaches it
  /// as `X-Session-Token`. If no token is stored, returns a session-required
  /// failure without making a network call.
  ///
  /// On `ROLL_WORKER_SESSION_REQUIRED` the impl clears the local token for
  /// `shiftLineId` so the caller's UI can route back to PIN.
  Future<RollScanResult> mountRoll({
    required int shiftLineId,
    required String generatedRollId,
  });
}
