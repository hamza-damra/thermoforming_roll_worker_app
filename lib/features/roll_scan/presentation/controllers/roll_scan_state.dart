import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_failure.dart';
import '../../domain/entities/mounted_roll.dart';
import '../../domain/entities/roll_scan_warning.dart';

/// Scan / mount state for a single shift-line. Sealed so the UI must
/// handle every branch via a `switch` expression.
@immutable
sealed class RollScanState {
  const RollScanState();
}

/// First-paint / no roll currently mounted. The home screen exposes the
/// "تركيب رول" CTA from this state.
class RollScanIdle extends RollScanState {
  const RollScanIdle();
}

/// Submission in flight. Scan controls are disabled and the primary button
/// shows a spinner; further taps are suppressed by the controller
/// (duplicate-submit guard).
class RollScanSubmitting extends RollScanState {
  const RollScanSubmitting();
}

/// A roll is currently mounted on the line.
class RollScanMounted extends RollScanState {
  const RollScanMounted(
    this.roll, {
    this.warnings = const <RollScanWarning>[],
  });
  final MountedRoll roll;

  /// Transient warnings emitted alongside this fresh mount (e.g. over-cured
  /// roll). Always present; empty when no warnings. Only carries fresh
  /// warnings from the most recent scan — never re-surfaced after
  /// `clearError`.
  final List<RollScanWarning> warnings;
}

/// Last submit failed; the error is shown inline. The state holds the
/// previously mounted roll (if any) so a transient error doesn't wipe the
/// home view — a retry can proceed against the same roll context.
class RollScanFailureState extends RollScanState {
  const RollScanFailureState({required this.failure, this.previous});

  final AppFailure failure;
  final MountedRoll? previous;
}
