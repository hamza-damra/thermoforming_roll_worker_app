import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_failure.dart';
import '../../domain/entities/roll_worker_me.dart';

/// Sealed state for [SessionsMeController].
@immutable
sealed class SessionsMeState {
  const SessionsMeState();
}

/// Pre-login or post-logout — the controller has nothing to fetch yet
/// because the worker holds zero session tokens.
class SessionsMeIdle extends SessionsMeState {
  const SessionsMeIdle();
}

/// First foreground load is in flight. Background refreshes (SSE event,
/// poll, reconnect catch-up) keep the previous [SessionsMeLoaded] state.
class SessionsMeLoading extends SessionsMeState {
  const SessionsMeLoading({this.previous});

  /// Previous good payload, kept so the UI can keep rendering across the
  /// load — null on the very first foreground load.
  final RollWorkerMe? previous;
}

/// Last fetch succeeded. The UI reads [me] for the line list and per-line
/// headline data; the controller diffs [me.shiftLineIds] against the
/// registry to detect cascade-lost lines.
class SessionsMeLoaded extends SessionsMeState {
  const SessionsMeLoaded({
    required this.me,
    required this.fetchedAt,
    this.isRefreshing = false,
  });

  final RollWorkerMe me;
  final DateTime fetchedAt;

  /// `true` while a background refresh is in flight on top of the loaded
  /// data — the UI can show a subtle indicator without losing the page.
  final bool isRefreshing;

  SessionsMeLoaded copyWith({
    RollWorkerMe? me,
    DateTime? fetchedAt,
    bool? isRefreshing,
  }) => SessionsMeLoaded(
    me: me ?? this.me,
    fetchedAt: fetchedAt ?? this.fetchedAt,
    isRefreshing: isRefreshing ?? this.isRefreshing,
  );
}

/// Last foreground fetch failed. [previous] (if any) is kept so the UI can
/// offer retry without losing the last good snapshot.
class SessionsMeError extends SessionsMeState {
  const SessionsMeError({required this.failure, this.previous});

  final AppFailure failure;
  final RollWorkerMe? previous;
}
