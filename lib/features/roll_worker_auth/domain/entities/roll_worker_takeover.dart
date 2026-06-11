import 'package:flutter/foundation.dart';

/// The two ways an incoming worker can resolve an abandoned mounted roll when
/// taking over a line (V104). Serialized as the exact uppercase wire strings.
enum RollWorkerTakeoverAction {
  /// The previous worker is credited the whole `lastKnownWeightKg`, the roll is
  /// closed, and the incoming worker starts clean (no mounted roll). No weight
  /// declaration required.
  fullConsumptionAndClose('FULL_CONSUMPTION_AND_CLOSE'),

  /// The previous worker is credited `lastKnownWeightKg − currentWeightKg`, the
  /// roll stays mounted, and the incoming worker continues from
  /// `currentWeightKg`. Requires a `currentWeightKg` declaration.
  rollRemainsMounted('ROLL_REMAINS_MOUNTED');

  const RollWorkerTakeoverAction(this.wireValue);

  /// Backend-side string (e.g. `"ROLL_REMAINS_MOUNTED"`).
  final String wireValue;

  /// Resolves a backend action string to a [RollWorkerTakeoverAction], or
  /// `null` if it is not recognised.
  static RollWorkerTakeoverAction? fromWire(String? wire) {
    if (wire == null) return null;
    for (final RollWorkerTakeoverAction value
        in RollWorkerTakeoverAction.values) {
      if (value.wireValue == wire) return value;
    }
    return null;
  }
}

/// Parsed from `error.details` when login/session-start fails with
/// `ROLL_WORKER_TAKEOVER_REQUIRED`. Drives the takeover screen.
///
/// `lastKnownWeightKg` and `generatedRollId` can be `null` on legacy data —
/// treat null as "unknown" and fall back gracefully.
@immutable
class RollWorkerTakeoverRequiredDetails {
  const RollWorkerTakeoverRequiredDetails({
    required this.shiftLineId,
    required this.previousWorkerName,
    this.previousWorkerOperatorId,
    this.lastKnownWeightKg,
    this.generatedRollId,
  });

  final int shiftLineId;
  final String previousWorkerName;
  final int? previousWorkerOperatorId;
  final double? lastKnownWeightKg;
  final String? generatedRollId;

  /// Builds the details from a `BusinessFailure.details` map. Returns `null`
  /// when the required `shiftLineId` is absent/malformed. Missing
  /// `previousWorkerName` falls back to an empty string (the UI shows a generic
  /// "السابق" label in that case).
  static RollWorkerTakeoverRequiredDetails? fromDetails(
    Map<String, Object?>? details,
  ) {
    if (details == null) return null;
    final Object? rawShiftLineId = details['shiftLineId'];
    if (rawShiftLineId is! num) return null;
    final Object? name = details['previousWorkerName'];
    final Object? operatorId = details['previousWorkerOperatorId'];
    final Object? weight = details['lastKnownWeightKg'];
    final Object? rollId = details['generatedRollId'];
    return RollWorkerTakeoverRequiredDetails(
      shiftLineId: rawShiftLineId.toInt(),
      previousWorkerName: name is String ? name : '',
      previousWorkerOperatorId: operatorId is num ? operatorId.toInt() : null,
      lastKnownWeightKg: weight is num ? weight.toDouble() : null,
      generatedRollId: rollId is String && rollId.isNotEmpty ? rollId : null,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RollWorkerTakeoverRequiredDetails &&
        other.shiftLineId == shiftLineId &&
        other.previousWorkerName == previousWorkerName &&
        other.previousWorkerOperatorId == previousWorkerOperatorId &&
        other.lastKnownWeightKg == lastKnownWeightKg &&
        other.generatedRollId == generatedRollId;
  }

  @override
  int get hashCode => Object.hash(
    shiftLineId,
    previousWorkerName,
    previousWorkerOperatorId,
    lastKnownWeightKg,
    generatedRollId,
  );
}
