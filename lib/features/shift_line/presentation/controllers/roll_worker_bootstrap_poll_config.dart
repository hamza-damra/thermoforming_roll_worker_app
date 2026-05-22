import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Cadence config for the pre-login bootstrap picker.
///
/// The picker is driven by the global `/events` SSE channel: every frame is
/// a "refresh now" trigger and a debounced `/bootstrap` refetch follows. A
/// periodic `/bootstrap` poll exists **only as a slow safety net** for
/// missed events (the in-memory broker has no replay) — it is never the
/// primary update mechanism (Line State Refresh handoff).
@immutable
class RollWorkerBootstrapPollConfig {
  const RollWorkerBootstrapPollConfig({
    this.safetyNetInterval = const Duration(seconds: 30),
    this.safetyNetSlowInterval = const Duration(seconds: 60),
    this.eventDebounce = const Duration(milliseconds: 250),
  });

  /// Safety-net poll cadence while the SSE link is down / reconnecting —
  /// the only recovery path until SSE is healthy again.
  final Duration safetyNetInterval;

  /// Safety-net poll cadence while SSE is connected — slow, since SSE is
  /// then the primary update path.
  final Duration safetyNetSlowInterval;

  /// A burst of SSE frames collapses into one `/bootstrap` refetch after
  /// this debounce window.
  final Duration eventDebounce;
}

/// Production cadence. Overridden in tests with sub-second intervals.
final rollWorkerBootstrapPollConfigProvider =
    Provider<RollWorkerBootstrapPollConfig>(
      (ref) => const RollWorkerBootstrapPollConfig(),
    );
