import 'package:flutter/foundation.dart';

/// A non-fatal warning attached to a successful scan-roll response (e.g.
/// over-cured rolls). Stable codes come from the backend; payload is a
/// loosely-typed bag so new warning types ship without breaking older
/// clients.
@immutable
class RollScanWarning {
  const RollScanWarning({
    required this.code,
    required this.severity,
    required this.message,
    this.payload = const <String, Object?>{},
  });

  /// Stable wire string, e.g. `ROLL_CURING_MAXIMUM_EXCEEDED`.
  final String code;

  /// `INFO`, `WARNING`, or `CRITICAL`.
  final String severity;

  /// Pre-localized Arabic message authored by the backend.
  final String message;

  /// Free-form per-warning payload. Read fields opportunistically by
  /// `code` — schemas vary across warning types.
  final Map<String, Object?> payload;
}
