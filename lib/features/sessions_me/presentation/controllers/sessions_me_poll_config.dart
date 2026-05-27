import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Cadence config for the post-login `/sessions/me` controller.
///
/// Contract (handoff §4 — the most important behaviour change):
///   - **SSE connected** → NO poll runs at all. Zero. Updates flow via the
///     SSE refresh trigger followed by a debounced `/sessions/me` refetch.
///   - **SSE disconnected** → poll `/sessions/me` every 2 seconds. This is
///     the only recovery path until SSE reconnects.
///   - **SSE reconnect** → ONE catch-up `/sessions/me` immediately, then
///     stop the fallback poll.
///
/// The SSE reconnect-attempt backoff is owned by the SSE client itself —
/// this config governs only the post-login REST poll cadence and the
/// event-coalescing debounce window.
@immutable
class SessionsMePollConfig {
  const SessionsMePollConfig({
    this.fallbackPollInterval = const Duration(seconds: 2),
    this.eventDebounce = const Duration(milliseconds: 250),
  });

  /// Fallback REST poll cadence — runs ONLY while SSE is reported
  /// disconnected. Fixed at 2 s per handoff §4.
  final Duration fallbackPollInterval;

  /// A burst of SSE frames collapses into one `/sessions/me` refetch after
  /// this debounce window.
  final Duration eventDebounce;
}

/// Production cadence. Overridden in tests with sub-second intervals.
final Provider<SessionsMePollConfig> sessionsMePollConfigProvider =
    Provider<SessionsMePollConfig>(
      (ref) => const SessionsMePollConfig(),
    );
