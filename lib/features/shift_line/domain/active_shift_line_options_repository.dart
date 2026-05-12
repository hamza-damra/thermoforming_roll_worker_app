import '../../../core/errors/app_failure.dart';
import 'entities/active_shift_line_option.dart';

/// Outcome of a fetch against `GET /shift-lines/active-options`.
sealed class ActiveShiftLineOptionsResult {
  const ActiveShiftLineOptionsResult();
}

class ActiveShiftLineOptionsSuccess extends ActiveShiftLineOptionsResult {
  const ActiveShiftLineOptionsSuccess(this.options);
  final List<ActiveShiftLineOption> options;
}

class ActiveShiftLineOptionsFailure extends ActiveShiftLineOptionsResult {
  const ActiveShiftLineOptionsFailure(this.failure);
  final AppFailure failure;
}

/// Repository contract for the pre-login shift-line picker. The endpoint is
/// reachable before roll-worker authentication, so the impl never attaches
/// an `X-Session-Token` header.
abstract class ActiveShiftLineOptionsRepository {
  /// `GET /api/v1/thermoforming-roll-app/shift-lines/active-options`.
  Future<ActiveShiftLineOptionsResult> fetch();
}
