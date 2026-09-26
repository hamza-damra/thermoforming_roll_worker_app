import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Cadence config for the biometric attempt-status long-poll (handoff §8).
///
/// - A long-poll answering `PENDING` / `DEVICE_UNAVAILABLE` is followed by the
///   next one immediately. The server holds each request up to 25 s, so
///   [minPollSpacing] never bites in practice; it only stops a server (or
///   proxy) that answers instantly from turning the loop into a busy spin.
/// - A failed status call backs off along [networkBackoff] (1 s, 2 s, 4 s,
///   then at most 10 s), repeating the last step until the server answers —
///   its 410 is the only authority on expiry.
@immutable
class BiometricPollConfig {
  const BiometricPollConfig({
    this.minPollSpacing = const Duration(seconds: 1),
    this.networkBackoff = const <Duration>[
      Duration(seconds: 1),
      Duration(seconds: 2),
      Duration(seconds: 4),
      Duration(seconds: 10),
    ],
  });

  final Duration minPollSpacing;
  final List<Duration> networkBackoff;

  /// Wait before the next poll after [consecutiveFailures] failed calls in a
  /// row (0-based).
  Duration backoffFor(int consecutiveFailures) =>
      networkBackoff[consecutiveFailures.clamp(0, networkBackoff.length - 1)];
}

/// Production cadence. Overridden in tests.
final Provider<BiometricPollConfig> biometricPollConfigProvider =
    Provider<BiometricPollConfig>((ref) => const BiometricPollConfig());
