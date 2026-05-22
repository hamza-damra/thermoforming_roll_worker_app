import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Cadence configuration for the operator-dashboard adaptive state refresh.
///
/// The Roll Worker app is a passive observer: SSE only *triggers* a refresh
/// and a periodic poll is the safety net for events the in-memory broker
/// dropped (it has no `Last-Event-ID` replay). The three intervals below
/// implement the tiered cadence from the Line State Refresh handoff (§4):
///
///   - [stableInterval]      — SSE connected + line in a normal/active state.
///   - [disconnectedInterval]— SSE link down / reconnecting.
///   - [fastInterval]        — line mid-transition (handover / takeover /
///                             waiting / blocked / unknown lifecycle).
///
/// Defaults sit inside the handoff's recommended ranges (30–60s / 5–15s /
/// 3–5s). Tests override the provider with tiny intervals so timing-sensitive
/// behaviour can be exercised without `fakeAsync`.
@immutable
class OperatorDashboardPollConfig {
  const OperatorDashboardPollConfig({
    this.stableInterval = const Duration(seconds: 45),
    this.disconnectedInterval = const Duration(seconds: 10),
    this.fastInterval = const Duration(seconds: 4),
    this.eventDebounce = const Duration(milliseconds: 250),
  });

  /// Light safety-net poll while SSE is connected and the line is stable.
  final Duration stableInterval;

  /// Tighter poll while the SSE link is down — covers events missed during
  /// the gap before the stream reconnects.
  final Duration disconnectedInterval;

  /// Aggressive poll while the line is mid-transition and the UI must
  /// converge quickly on the committed backend state.
  final Duration fastInterval;

  /// Coalescing window for a burst of SSE events — a flurry of frames
  /// arriving together collapses into a single REST refresh (§1).
  final Duration eventDebounce;
}

/// Production cadence. Overridden in tests with sub-second intervals.
final operatorDashboardPollConfigProvider =
    Provider<OperatorDashboardPollConfig>(
      (ref) => const OperatorDashboardPollConfig(),
    );
