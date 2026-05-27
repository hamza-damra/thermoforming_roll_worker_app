import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Cadence config for the pre-login bootstrap picker.
///
/// Contract (realtime + line-management handoff §4):
///   - **SSE connected** → NO poll runs at all. Zero. The picker updates via
///     SSE refresh triggers debounced into a `/bootstrap` refetch.
///   - **SSE disconnected** → poll `/bootstrap` every 2 seconds. This is
///     the only recovery path until SSE reconnects.
@immutable
class RollWorkerBootstrapPollConfig {
  const RollWorkerBootstrapPollConfig({
    this.safetyNetInterval = const Duration(seconds: 2),
    this.eventDebounce = const Duration(milliseconds: 250),
  });

  /// Fallback poll cadence while the SSE link is down — the only recovery
  /// path until SSE is healthy again. Fixed at 2 s per handoff §4.
  final Duration safetyNetInterval;

  /// A burst of SSE frames collapses into one `/bootstrap` refetch after
  /// this debounce window.
  final Duration eventDebounce;
}

/// Production cadence. Overridden in tests with sub-second intervals.
final rollWorkerBootstrapPollConfigProvider =
    Provider<RollWorkerBootstrapPollConfig>(
      (ref) => const RollWorkerBootstrapPollConfig(),
    );
