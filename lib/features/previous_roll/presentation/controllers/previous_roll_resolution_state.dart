import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_failure.dart';
import '../../domain/entities/previous_roll_resolution.dart';

/// Previous-roll resolution state for a single shift-line. Sealed so the UI
/// must handle every branch via a `switch` expression.
@immutable
sealed class PreviousRollResolutionState {
  const PreviousRollResolutionState();
}

/// First-paint / no close in progress / no recent close to display.
class PreviousRollIdle extends PreviousRollResolutionState {
  const PreviousRollIdle();
}

/// One of the three close calls is in flight. Confirm buttons disabled,
/// duplicate submits suppressed.
class PreviousRollResolving extends PreviousRollResolutionState {
  const PreviousRollResolving();
}

/// Last close succeeded. The home screen swaps the mount card for the
/// summary card; the worker can mount a new roll (which transitions back
/// to [PreviousRollIdle]).
class PreviousRollResolved extends PreviousRollResolutionState {
  const PreviousRollResolved(this.resolution);
  final PreviousRollResolution resolution;
}

/// Last close failed. The dialog/inline error shows the Arabic message;
/// retry transitions back to [PreviousRollResolving].
class PreviousRollFailureState extends PreviousRollResolutionState {
  const PreviousRollFailureState(this.failure);
  final AppFailure failure;
}
