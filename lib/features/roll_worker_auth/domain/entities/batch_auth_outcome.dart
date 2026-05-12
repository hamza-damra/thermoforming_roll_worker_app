import 'package:flutter/foundation.dart';

import 'roll_worker_session.dart';

/// Domain wrapper around a successful batch session-start.
///
/// Carries the operator info (same across every entry — PIN validated once)
/// and the per-shift-line [RollWorkerSession]s. The raw `sessionToken` for
/// each entry was already persisted by the repository before this object
/// reached the controller layer.
@immutable
class BatchAuthOutcome {
  const BatchAuthOutcome({
    required this.rollWorkerOperatorId,
    required this.rollWorkerName,
    required this.sessions,
  });

  final int rollWorkerOperatorId;
  final String rollWorkerName;

  /// One [RollWorkerSession] per requested shift-line, keyed by
  /// `thermoformingShiftLineId`.
  final Map<int, RollWorkerSession> sessions;
}
