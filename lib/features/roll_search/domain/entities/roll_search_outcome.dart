import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_failure.dart';

/// How many rolls the backend found in the searched minute.
enum RollSearchStatus {
  /// Exactly one roll — it is the only entry in [RollSearchOutcome.matches].
  found,

  /// No roll was produced in that minute.
  notFound,

  /// Several rolls share the minute. The backend never picks one; the worker
  /// chooses the one whose number and weight match the label.
  multipleMatches,
}

/// One roll produced in the searched minute, with the backend's answer to
/// "can it be mounted on this line right now?".
@immutable
class RollSearchMatch {
  const RollSearchMatch({
    required this.rollId,
    required this.generatedRollId,
    required this.consumptionState,
    required this.mountable,
    this.producedAt,
    this.rollTypeRollCode,
    this.rollTypeDisplayName,
    this.colorName,
    this.productionKind,
    this.producedWeightKg,
    this.currentWeightKg,
    this.consumptionStateLabel,
    this.mountRefusal,
  });

  final int rollId;

  /// The 12-digit roll number; mounting uses it through the normal scan.
  final String generatedRollId;

  /// Production instant (UTC). Render with `toFactoryTime`, never device time.
  final DateTime? producedAt;

  final String? rollTypeRollCode;
  final String? rollTypeDisplayName;
  final String? colorName;

  /// `NORMAL` or `SCRAP`.
  final String? productionKind;

  final double? producedWeightKg;
  final double? currentWeightKg;

  /// Wire state (`AVAILABLE`, `PARTIALLY_RETURNED`, …).
  final String consumptionState;

  /// Backend Arabic label for [consumptionState].
  final String? consumptionStateLabel;

  final bool mountable;

  /// The exact refusal the scan would return — same code and details — so it
  /// is rendered with the scan's Arabic text and dialogs. `null` when
  /// [mountable].
  final BusinessFailure? mountRefusal;
}

/// Result of one production-time search.
@immutable
class RollSearchOutcome {
  const RollSearchOutcome({
    required this.status,
    required this.matchCount,
    required this.matches,
    this.searchedLocalMinute,
  });

  final RollSearchStatus status;

  /// Every roll produced in the minute; may exceed [matches] (the backend
  /// lists at most ten).
  final int matchCount;

  /// [RollSearchStatus.found]: the one roll. [RollSearchStatus.multipleMatches]:
  /// the candidates, oldest first. [RollSearchStatus.notFound]: empty.
  final List<RollSearchMatch> matches;

  /// Echo of the searched factory-time minute (`yyyy-MM-ddTHH:mm`).
  final String? searchedLocalMinute;

  bool get isTruncated => matchCount > matches.length;
}
