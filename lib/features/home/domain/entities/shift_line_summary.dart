import 'package:flutter/foundation.dart';

import 'allowed_roll.dart';
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

/// One closed roll the worker contributed to within the current operator
/// shift-line/session, returned by the `/shift-lines/{shiftLineId}/summary`
/// endpoint in the `consumedRolls` list (capped at 10, newest-first). V123:
/// `consumedWeightKg` is the worker's per-interval contribution, not
/// necessarily the whole roll's `startWeightKg − endWeightKg`.
///
/// `closedReason` and `remainderAction` are raw wire codes
/// (`FULL_CONSUMPTION` / `PARTIAL_RETURN` / `PARTIAL_GRINDING` and
/// `NONE` / `RETURN` / `GRINDING`); Arabic translation happens at render
/// time. `endedAtDisplay` is already Arabic-formatted by the backend.
@immutable
class ConsumedRoll {
  const ConsumedRoll({
    required this.consumptionItemId,
    required this.rollId,
    required this.generatedRollId,
    required this.rollTypeCode,
    required this.rollTypeName,
    required this.startWeightKg,
    required this.endWeightKg,
    required this.consumedWeightKg,
    required this.closedReason,
    required this.remainderAction,
    required this.endedAt,
    required this.endedAtDisplay,
    this.remainingWeightKg,
    this.reprintAvailable,
    this.reprintLabelType,
    this.labelTimestamp,
  });

  final int consumptionItemId;
  final int rollId;
  final String generatedRollId;
  final String rollTypeCode;
  final String rollTypeName;
  final double startWeightKg;
  final double endWeightKg;
  final double consumedWeightKg;
  final double? remainingWeightKg;
  final String closedReason;
  final String remainderAction;
  final DateTime endedAt;
  final String endedAtDisplay;

  /// Backend authoritative reprint flag. `null` on older backends — the
  /// UI falls back to a `remainderAction`-based inference in that case.
  final bool? reprintAvailable;

  /// `RETURN_REMAINING` | `GRINDING_REMAINING`. Drives the GRINDING scrap-
  /// icon switch in the renderer. `null` on older backends or for non-
  /// remainder rolls.
  final String? reprintLabelType;

  /// Backend-authoritative timestamp to print on the label's
  /// weekday/date/time band. Never replace with device time.
  final DateTime? labelTimestamp;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ConsumedRoll &&
        other.consumptionItemId == consumptionItemId &&
        other.rollId == rollId &&
        other.generatedRollId == generatedRollId &&
        other.rollTypeCode == rollTypeCode &&
        other.rollTypeName == rollTypeName &&
        other.startWeightKg == startWeightKg &&
        other.endWeightKg == endWeightKg &&
        other.consumedWeightKg == consumedWeightKg &&
        other.remainingWeightKg == remainingWeightKg &&
        other.closedReason == closedReason &&
        other.remainderAction == remainderAction &&
        other.endedAt == endedAt &&
        other.endedAtDisplay == endedAtDisplay &&
        other.reprintAvailable == reprintAvailable &&
        other.reprintLabelType == reprintLabelType &&
        other.labelTimestamp == labelTimestamp;
  }

  @override
  int get hashCode => Object.hash(
    consumptionItemId,
    rollId,
    generatedRollId,
    rollTypeCode,
    rollTypeName,
    startWeightKg,
    endWeightKg,
    consumedWeightKg,
    remainingWeightKg,
    closedReason,
    remainderAction,
    endedAt,
    endedAtDisplay,
    reprintAvailable,
    reprintLabelType,
    labelTimestamp,
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
    required this.completedRollsInSession,
    required this.completedRollsByCurrentWorker,
    this.consumedWeightKgInSession,
    this.rollsContributedInSession = 0,
    this.consumedRolls = const <ConsumedRoll>[],
    this.allowedRolls = const <AllowedRoll>[],
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

  /// Rolls closed in the current `RollWorkerSession` (session-scoped).
  /// Resets to 0 on each new login to the same shift-line.
  final int completedRollsInSession;

  /// Kept for backend contract continuity — currently equal to
  /// [completedRollsInSession] since a session is by definition tied to one
  /// worker. The UI may hide the "منك" sub-line when both are equal.
  final int completedRollsByCurrentWorker;

  /// V123: the roll worker's consumed kg inside the **current operator
  /// shift-line/session** — the sum of their CLOSED blocks on this `shiftLineId`
  /// PLUS a live provisional estimate from the open block on the currently
  /// mounted roll (`mountedRoll.lastKnownWeightKg`). Scoped by operator identity
  /// + `shiftLineId`, so it survives a plain logout/login while the same
  /// `shiftLineId` stays active; a new operator session (new `shiftLineId`)
  /// starts a fresh scope. `null` ⇒ a backend that does not compute the metric
  /// (the kg card is then hidden — never a fabricated figure).
  final double? consumedWeightKgInSession;

  /// V123: distinct rolls the worker contributed > 0 kg to within the current
  /// operator shift-line/session (zero-consumption handovers excluded). Same
  /// scope/continuity as [consumedWeightKgInSession].
  final int rollsContributedInSession;

  /// The worker's latest closed rolls within the current operator shift-line/
  /// session (V123: scoped by operator identity + `shiftLineId`), newest-first,
  /// capped at 10 by the backend. Each entry's `consumedWeightKg` is the
  /// worker's per-interval contribution. Always taken straight from the freshest
  /// REST response — never accumulated or cached across `shiftLineId` scopes.
  final List<ConsumedRoll> consumedRolls;

  /// Roll types the backend marks as allowed for the line's current product,
  /// in backend order (`preferred` first). Informational/display-only —
  /// the backend still validates scan/mount server-side. Empty when there is
  /// no current product, no configured allowed rolls, or the backend predates
  /// this field.
  final List<AllowedRoll> allowedRolls;

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
    int? completedRollsInSession,
    int? completedRollsByCurrentWorker,
    double? consumedWeightKgInSession,
    int? rollsContributedInSession,
    List<ConsumedRoll>? consumedRolls,
    List<AllowedRoll>? allowedRolls,
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
      completedRollsInSession:
          completedRollsInSession ?? this.completedRollsInSession,
      completedRollsByCurrentWorker:
          completedRollsByCurrentWorker ?? this.completedRollsByCurrentWorker,
      consumedWeightKgInSession:
          consumedWeightKgInSession ?? this.consumedWeightKgInSession,
      rollsContributedInSession:
          rollsContributedInSession ?? this.rollsContributedInSession,
      consumedRolls: consumedRolls ?? this.consumedRolls,
      allowedRolls: allowedRolls ?? this.allowedRolls,
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
        other.completedRollsInSession == completedRollsInSession &&
        other.completedRollsByCurrentWorker == completedRollsByCurrentWorker &&
        other.consumedWeightKgInSession == consumedWeightKgInSession &&
        other.rollsContributedInSession == rollsContributedInSession &&
        listEquals(other.consumedRolls, consumedRolls) &&
        listEquals(other.allowedRolls, allowedRolls) &&
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
    completedRollsInSession,
    completedRollsByCurrentWorker,
    consumedWeightKgInSession,
    rollsContributedInSession,
    Object.hashAll(consumedRolls),
    Object.hashAll(allowedRolls),
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
