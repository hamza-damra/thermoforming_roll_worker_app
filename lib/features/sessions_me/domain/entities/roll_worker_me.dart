import 'package:flutter/foundation.dart';

import 'roll_worker_active_line.dart';

/// Unified post-login state returned by
/// `GET /api/v1/thermoforming-roll-app/sessions/me`.
///
/// One round-trip per refresh — replaces the per-line `/current` loop.
@immutable
class RollWorkerMe {
  const RollWorkerMe({
    required this.rollWorkerOperatorId,
    required this.rollWorkerName,
    required this.lines,
  });

  final int rollWorkerOperatorId;
  final String rollWorkerName;

  /// One entry per ACTIVE session, ordered by session start time ASC.
  /// Empty when the worker has zero active sessions (treat as logged-out).
  final List<RollWorkerActiveLine> lines;

  /// Stable set of shift-line ids the backend says the worker currently
  /// owns. Used by [SessionsMeController] for cascade diffing against the
  /// local registry.
  Set<int> get shiftLineIds =>
      lines.map((l) => l.shiftLineId).toSet();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RollWorkerMe &&
        other.rollWorkerOperatorId == rollWorkerOperatorId &&
        other.rollWorkerName == rollWorkerName &&
        listEquals(other.lines, lines);
  }

  @override
  int get hashCode => Object.hash(
    rollWorkerOperatorId,
    rollWorkerName,
    Object.hashAll(lines),
  );
}
