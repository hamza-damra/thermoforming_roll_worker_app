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
  /// `{"remainingWeightKg": <num>, "reasonText": <str>}`.
  ///
  /// Caller is responsible for client-side bounds (`>= 0` and
  /// `<= activeSegment startWeight`) and for a non-blank [reasonText]; the
  /// backend re-validates and returns `INVALID_REMAINING_ROLL_WEIGHT` or
  /// `ROLL_RETURN_REASON_REQUIRED` if either is invalid.
  Future<PreviousRollResult> returnRemaining({
    required int shiftLineId,
    required double remainingWeightKg,
    required String reasonText,
  });

  /// `POST /shift-lines/{shiftLineId}/previous-roll/grinding` with body
  /// `{"remainingWeightKg": <num>, "reasonText": <str>}`. Same bounds as
  /// [returnRemaining]; a blank reason returns `ROLL_GRINDING_REASON_REQUIRED`.
  Future<PreviousRollResult> sendToGrinding({
    required int shiftLineId,
    required double remainingWeightKg,
    required String reasonText,
  });
}
