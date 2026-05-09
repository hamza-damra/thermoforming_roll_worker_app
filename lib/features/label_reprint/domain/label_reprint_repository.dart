import '../../../core/errors/app_failure.dart';
import 'entities/roll_label.dart';

sealed class LabelReprintResult {
  const LabelReprintResult();
}

class LabelReprintSuccess extends LabelReprintResult {
  const LabelReprintSuccess(this.label);
  final RollLabel label;
}

class LabelReprintFailureResult extends LabelReprintResult {
  const LabelReprintFailureResult(this.failure);
  final AppFailure failure;
}

/// Reprint flow contract. The backend endpoint is keyed by
/// `generatedRollId` (not by shift-line) and accepts any active
/// roll-worker session token (looser session check).
abstract class LabelReprintRepository {
  /// `GET /api/v1/thermoforming-roll-app/rolls/{generatedRollId}/reprint-label`
  /// scoped to the worker's session on [shiftLineId].
  ///
  /// Strict eligibility (handled by the backend): `PARTIALLY_RETURNED` or
  /// `SENT_TO_GRINDING` only — anything else returns
  /// `ROLL_LABEL_REPRINT_NOT_AVAILABLE`.
  Future<LabelReprintResult> fetchLabel({
    required int shiftLineId,
    required String generatedRollId,
  });
}
