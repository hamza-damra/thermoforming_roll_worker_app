import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_failure.dart';
import '../../domain/entities/roll_worker_bootstrap_line.dart';

/// State for the pre-login bootstrap picker. Sealed so the UI must handle
/// every branch via a `switch` expression.
@immutable
sealed class RollWorkerBootstrapState {
  const RollWorkerBootstrapState();
}

/// Initial state before the first fetch resolves.
class RollWorkerBootstrapInitial extends RollWorkerBootstrapState {
  const RollWorkerBootstrapInitial();
}

/// A foreground fetch is in flight (initial load / pull-to-refresh). The
/// previous list (if any) is preserved so the UI can keep rendering it.
///
/// Background refreshes (SSE-triggered, poll, app-resume) never enter this
/// state — they transition `Loaded → Loaded` directly so rows update in
/// place with no full-screen loader.
class RollWorkerBootstrapLoading extends RollWorkerBootstrapState {
  const RollWorkerBootstrapLoading({this.previous = const []});

  final List<RollWorkerBootstrapLine> previous;
}

/// Last fetch succeeded. An empty list means the backend reported no active
/// thermoforming machines at all.
class RollWorkerBootstrapLoaded extends RollWorkerBootstrapState {
  const RollWorkerBootstrapLoaded(this.lines);

  final List<RollWorkerBootstrapLine> lines;

  bool get isEmpty => lines.isEmpty;
}

/// Last foreground fetch failed. The previous list (if any) is preserved so
/// the UI can offer retry without losing context.
class RollWorkerBootstrapFailureState extends RollWorkerBootstrapState {
  const RollWorkerBootstrapFailureState({
    required this.failure,
    this.previous = const [],
  });

  final AppFailure failure;
  final List<RollWorkerBootstrapLine> previous;
}
