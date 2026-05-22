import 'package:flutter/foundation.dart';

import 'line_takeover.dart';

/// Snapshot of a mounted roll as returned by the shift-line summary endpoint.
///
/// `lastKnownWeightKg` is `null` when no weight has been recorded yet for the
/// active consumption state — never substitute the roll's start weight.
@immutable
class SummaryMountedRoll {
  const SummaryMountedRoll({
    required this.consumptionItemId,
    required this.rollId,
    required this.generatedRollId,
    required this.rollTypeCode,
    required this.rollTypeName,
    this.lastKnownWeightKg,
  });

  final int consumptionItemId;
  final int rollId;
  final String generatedRollId;
  final String rollTypeCode;
  final String rollTypeName;
  final double? lastKnownWeightKg;

  SummaryMountedRoll copyWith({double? lastKnownWeightKg}) =>
      SummaryMountedRoll(
        consumptionItemId: consumptionItemId,
        rollId: rollId,
        generatedRollId: generatedRollId,
        rollTypeCode: rollTypeCode,
        rollTypeName: rollTypeName,
        lastKnownWeightKg: lastKnownWeightKg ?? this.lastKnownWeightKg,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SummaryMountedRoll &&
        other.consumptionItemId == consumptionItemId &&
        other.rollId == rollId &&
        other.generatedRollId == generatedRollId &&
        other.rollTypeCode == rollTypeCode &&
        other.rollTypeName == rollTypeName &&
        other.lastKnownWeightKg == lastKnownWeightKg;
  }

  @override
  int get hashCode => Object.hash(
    consumptionItemId,
    rollId,
    generatedRollId,
    rollTypeCode,
    rollTypeName,
    lastKnownWeightKg,
  );
}

/// Active product on the line — usually hydrated from operator-dashboard SSE
/// because the REST summary snapshot may not yet expose it.
@immutable
class SummaryActiveProduct {
  const SummaryActiveProduct({required this.productId, required this.name});

  final int productId;
  final String name;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SummaryActiveProduct &&
        other.productId == productId &&
        other.name == name;
  }

  @override
  int get hashCode => Object.hash(productId, name);
}

/// Operator-driven incompatible switch: mount cleared, remainder returned.
@immutable
class ReturnedRemainingRoll {
  const ReturnedRemainingRoll({
    required this.generatedRollId,
    required this.returnedWeightKg,
    required this.canPrintLabel,
    this.oldProductName,
    this.newProductName,
  });

  final String generatedRollId;
  final double returnedWeightKg;
  final bool canPrintLabel;
  final String? oldProductName;
  final String? newProductName;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ReturnedRemainingRoll &&
        other.generatedRollId == generatedRollId &&
        other.returnedWeightKg == returnedWeightKg &&
        other.canPrintLabel == canPrintLabel &&
        other.oldProductName == oldProductName &&
        other.newProductName == newProductName;
  }

  @override
  int get hashCode => Object.hash(
    generatedRollId,
    returnedWeightKg,
    canPrintLabel,
    oldProductName,
    newProductName,
  );
}

/// Aggregated shift-line summary from the backend.
///
/// All roll counts come from the backend — never computed locally.
@immutable
class ShiftLineSummary {
  const ShiftLineSummary({
    required this.shiftLineId,
    required this.thermoformingLineCode,
    required this.thermoformingLineName,
    required this.completedRollsInShift,
    required this.completedRollsByCurrentWorker,
    this.mountedRoll,
    this.activeProduct,
    this.returnedRemainingRoll,
    this.blocked = false,
    this.blockedReason,
    this.takeover,
    this.activeOperatorId,
    this.activeOperatorName,
    this.handoverPending = false,
    this.lineLifecycleStatus,
  });

  final int shiftLineId;

  /// Short factory-readable code shown in the compact header and bottom nav.
  /// e.g. `"TH-01"`.
  final String thermoformingLineCode;

  /// Human-readable line name. e.g. `"خط التشكيل 1"`.
  final String thermoformingLineName;

  /// Total rolls closed on this shift-line in the current operator shift,
  /// regardless of which worker closed them.
  final int completedRollsInShift;

  /// Subset of [completedRollsInShift] closed by the current session's worker.
  final int completedRollsByCurrentWorker;

  /// Currently mounted roll, or `null` when nothing is mounted.
  final SummaryMountedRoll? mountedRoll;

  /// Current product on the line (SSE overlay when absent from REST).
  final SummaryActiveProduct? activeProduct;

  /// Banner after operator incompatible product switch (SSE-driven).
  final ReturnedRemainingRoll? returnedRemainingRoll;

  /// Backend verdict on whether roll work is allowed right now. When `true`
  /// the app blocks roll actions and shows [blockedReason] — it never decides
  /// this locally (spec §8).
  final bool blocked;

  /// Human-readable Arabic reason for [blocked], when the backend supplies one.
  final String? blockedReason;

  /// Pending/active Line Takeover Request on the line behind this machine,
  /// or `null` when there is no takeover in flight.
  final LineTakeover? takeover;

  /// Id of the thermoforming operator currently owning the parent shift.
  /// `null` ⇒ no active operator — the line is in its waiting/unavailable
  /// state and the Roll Worker app shows the waiting card.
  final int? activeOperatorId;

  /// Display name of the current thermoforming operator. `null` ⇒ no active
  /// operator (see [activeOperatorId]).
  final String? activeOperatorName;

  /// `true` while a PENDING line handover exists on the parent shift. The
  /// app never decides this locally — it mirrors the backend field.
  final bool handoverPending;

  /// Coarse backend lifecycle label — `PENDING_HANDOVER` / `TAKEOVER_*` /
  /// the shift-line status (e.g. `ACTIVE`). Diagnostic only; the UI gates on
  /// [activeOperatorName] / [blocked], never on this string.
  final String? lineLifecycleStatus;

  /// `true` when there is no thermoforming operator owning the line — the
  /// Roll Worker app shows the waiting/unavailable card (handoff spec).
  bool get noActiveOperator => activeOperatorName == null;

  ShiftLineSummary copyWith({
    int? shiftLineId,
    String? thermoformingLineCode,
    String? thermoformingLineName,
    int? completedRollsInShift,
    int? completedRollsByCurrentWorker,
    SummaryMountedRoll? mountedRoll,
    SummaryActiveProduct? activeProduct,
    ReturnedRemainingRoll? returnedRemainingRoll,
    bool? blocked,
    String? blockedReason,
    LineTakeover? takeover,
    int? activeOperatorId,
    String? activeOperatorName,
    bool? handoverPending,
    String? lineLifecycleStatus,
    bool clearMountedRoll = false,
    bool clearActiveProduct = false,
    bool clearReturnedRemainingRoll = false,
    bool clearBlockedReason = false,
    bool clearTakeover = false,
    bool clearActiveOperator = false,
    bool clearLineLifecycleStatus = false,
  }) {
    return ShiftLineSummary(
      shiftLineId: shiftLineId ?? this.shiftLineId,
      thermoformingLineCode:
          thermoformingLineCode ?? this.thermoformingLineCode,
      thermoformingLineName:
          thermoformingLineName ?? this.thermoformingLineName,
      completedRollsInShift:
          completedRollsInShift ?? this.completedRollsInShift,
      completedRollsByCurrentWorker:
          completedRollsByCurrentWorker ?? this.completedRollsByCurrentWorker,
      mountedRoll: clearMountedRoll ? null : (mountedRoll ?? this.mountedRoll),
      activeProduct: clearActiveProduct
          ? null
          : (activeProduct ?? this.activeProduct),
      returnedRemainingRoll: clearReturnedRemainingRoll
          ? null
          : (returnedRemainingRoll ?? this.returnedRemainingRoll),
      blocked: blocked ?? this.blocked,
      blockedReason: clearBlockedReason
          ? null
          : (blockedReason ?? this.blockedReason),
      takeover: clearTakeover ? null : (takeover ?? this.takeover),
      activeOperatorId: clearActiveOperator
          ? null
          : (activeOperatorId ?? this.activeOperatorId),
      activeOperatorName: clearActiveOperator
          ? null
          : (activeOperatorName ?? this.activeOperatorName),
      handoverPending: handoverPending ?? this.handoverPending,
      lineLifecycleStatus: clearLineLifecycleStatus
          ? null
          : (lineLifecycleStatus ?? this.lineLifecycleStatus),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ShiftLineSummary &&
        other.shiftLineId == shiftLineId &&
        other.thermoformingLineCode == thermoformingLineCode &&
        other.thermoformingLineName == thermoformingLineName &&
        other.completedRollsInShift == completedRollsInShift &&
        other.completedRollsByCurrentWorker == completedRollsByCurrentWorker &&
        other.mountedRoll == mountedRoll &&
        other.activeProduct == activeProduct &&
        other.returnedRemainingRoll == returnedRemainingRoll &&
        other.blocked == blocked &&
        other.blockedReason == blockedReason &&
        other.takeover == takeover &&
        other.activeOperatorId == activeOperatorId &&
        other.activeOperatorName == activeOperatorName &&
        other.handoverPending == handoverPending &&
        other.lineLifecycleStatus == lineLifecycleStatus;
  }

  @override
  int get hashCode => Object.hash(
    shiftLineId,
    thermoformingLineCode,
    thermoformingLineName,
    completedRollsInShift,
    completedRollsByCurrentWorker,
    mountedRoll,
    activeProduct,
    returnedRemainingRoll,
    blocked,
    blockedReason,
    takeover,
    activeOperatorId,
    activeOperatorName,
    handoverPending,
    lineLifecycleStatus,
  );
}
