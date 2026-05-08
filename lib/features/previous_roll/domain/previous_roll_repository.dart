import '../../../core/errors/app_failure.dart';
import 'entities/previous_roll_resolution.dart';

/// Outcome of a previous-roll close call. Repositories return one of these
/// instead of throwing — controllers map to UI states.
sealed class PreviousRollResult {
  const PreviousRollResult();
}

class PreviousRollSuccess extends PreviousRollResult {
  const PreviousRollSuccess(this.resolution);
  final PreviousRollResolution resolution;
}

class PreviousRollFailure extends PreviousRollResult {
  const PreviousRollFailure(this.failure);
  final AppFailure failure;
}

/// Repository contract for closing the previous roll on a Thermoforming
/// shift-line. All three flows return the same response shape; the chosen
/// flow is reflected in [PreviousRollResolution.remainderAction] and
/// [PreviousRollResolution.eventType].
abstract class PreviousRollRepository {
  /// `POST /shift-lines/{shiftLineId}/previous-roll/full-consume`. No body.
  Future<PreviousRollResult> fullConsume({required int shiftLineId});

  /// `POST /shift-lines/{shiftLineId}/previous-roll/return` with body
  /// `{"remainingWeightKg": <num>}`.
  ///
  /// Caller is responsible for client-side bounds (`>= 0` and
  /// `<= activeSegment startWeight`); the backend re-validates and returns
  /// `INVALID_REMAINING_ROLL_WEIGHT` if the value is out of bounds.
  Future<PreviousRollResult> returnRemaining({
    required int shiftLineId,
    required double remainingWeightKg,
  });

  /// `POST /shift-lines/{shiftLineId}/previous-roll/grinding` with body
  /// `{"remainingWeightKg": <num>}`. Same bounds as
  /// [returnRemaining].
  Future<PreviousRollResult> sendToGrinding({
    required int shiftLineId,
    required double remainingWeightKg,
  });
}
