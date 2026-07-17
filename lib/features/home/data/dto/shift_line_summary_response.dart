import '../../domain/entities/allowed_roll.dart';
import '../../domain/entities/line_takeover.dart';
import '../../domain/entities/shift_line_summary.dart';

class SummaryMountedRollResponse {
  const SummaryMountedRollResponse({
    required this.consumptionItemId,
    required this.rollId,
    required this.generatedRollId,
    required this.rollTypeCode,
    required this.rollTypeName,
    this.lastKnownWeightKg,
  });

  factory SummaryMountedRollResponse.fromJson(Map<String, dynamic> json) {
    return SummaryMountedRollResponse(
      consumptionItemId: json['consumptionItemId'] as int,
      rollId: json['rollId'] as int,
      generatedRollId: json['generatedRollId'] as String,
      rollTypeCode: json['rollTypeCode'] as String,
      rollTypeName: json['rollTypeName'] as String,
      lastKnownWeightKg: (json['lastKnownWeightKg'] as num?)?.toDouble(),
    );
  }

  final int consumptionItemId;
  final int rollId;
  final String generatedRollId;
  final String rollTypeCode;
  final String rollTypeName;
  final double? lastKnownWeightKg;

  SummaryMountedRoll toEntity() => SummaryMountedRoll(
    consumptionItemId: consumptionItemId,
    rollId: rollId,
    generatedRollId: generatedRollId,
    rollTypeCode: rollTypeCode,
    rollTypeName: rollTypeName,
    lastKnownWeightKg: lastKnownWeightKg,
  );
}

/// One entry in the operator-shift-line-scoped `consumedRolls` list returned by
/// `/shift-lines/{shiftLineId}/summary` (V123). Capped at 10 newest-first by the
/// backend; `consumedWeightKg` is the worker's per-interval contribution. The
/// wire codes for `closedReason` / `remainderAction` are translated to Arabic
/// at render time.
class ConsumedRollResponse {
  const ConsumedRollResponse({
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

  factory ConsumedRollResponse.fromJson(Map<String, dynamic> json) {
    return ConsumedRollResponse(
      consumptionItemId: json['consumptionItemId'] as int,
      rollId: json['rollId'] as int,
      generatedRollId: json['generatedRollId'] as String,
      rollTypeCode: json['rollTypeCode'] as String,
      rollTypeName: json['rollTypeName'] as String,
      startWeightKg: (json['startWeightKg'] as num).toDouble(),
      endWeightKg: (json['endWeightKg'] as num).toDouble(),
      consumedWeightKg: (json['consumedWeightKg'] as num).toDouble(),
      remainingWeightKg: (json['remainingWeightKg'] as num?)?.toDouble(),
      closedReason: json['closedReason'] as String,
      remainderAction: json['remainderAction'] as String,
      endedAt: DateTime.parse(json['endedAt'] as String),
      endedAtDisplay: json['endedAtDisplay'] as String,
      reprintAvailable: ShiftLineSummaryResponse._asBool(
        json['reprintAvailable'],
      ),
      reprintLabelType: ShiftLineSummaryResponse._asString(
        json['reprintLabelType'],
      ),
      labelTimestamp: ShiftLineSummaryResponse._asDateTime(
        json['labelTimestamp'],
      ),
    );
  }

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

  /// Label-template hint from the backend: `RETURN_REMAINING` |
  /// `GRINDING_REMAINING`. Drives the GRINDING scrap-icon switch in the
  /// renderer. `null` on older backends.
  final String? reprintLabelType;

  /// Stable timestamp the backend wants printed on the label's
  /// weekday/date/time band. Never substitute device time when this is null;
  /// the auto-print path aborts instead.
  final DateTime? labelTimestamp;

  ConsumedRoll toEntity() => ConsumedRoll(
    consumptionItemId: consumptionItemId,
    rollId: rollId,
    generatedRollId: generatedRollId,
    rollTypeCode: rollTypeCode,
    rollTypeName: rollTypeName,
    startWeightKg: startWeightKg,
    endWeightKg: endWeightKg,
    consumedWeightKg: consumedWeightKg,
    remainingWeightKg: remainingWeightKg,
    closedReason: closedReason,
    remainderAction: remainderAction,
    endedAt: endedAt,
    endedAtDisplay: endedAtDisplay,
    reprintAvailable: reprintAvailable,
    reprintLabelType: reprintLabelType,
    labelTimestamp: labelTimestamp,
  );
}

/// One entry in the `allowedRolls` array returned by
/// `/shift-lines/{shiftLineId}/summary`. All fields except `id` tolerate
/// `null`/missing values; see [AllowedRoll] for the display fallbacks.
class AllowedRollResponse {
  const AllowedRollResponse({
    required this.id,
    this.code,
    this.name,
    this.colorName,
    this.thicknessStandardMm,
    this.displayName,
    this.preferred = false,
    this.active = true,
  });

  factory AllowedRollResponse.fromJson(Map<String, dynamic> json) {
    return AllowedRollResponse(
      id: ShiftLineSummaryResponse._asInt(json['id']) ?? 0,
      code: ShiftLineSummaryResponse._asString(json['code']),
      name: ShiftLineSummaryResponse._asString(json['name']),
      colorName: ShiftLineSummaryResponse._asString(json['colorName']),
      thicknessStandardMm: ShiftLineSummaryResponse._asNum(
        json['thicknessStandardMm'],
      ),
      displayName: ShiftLineSummaryResponse._asString(json['displayName']),
      // preferred missing/null -> false; active missing/null -> true unless
      // the backend explicitly says false.
      preferred: ShiftLineSummaryResponse._asBool(json['preferred']) ?? false,
      active: ShiftLineSummaryResponse._asBool(json['active']) ?? true,
    );
  }

  final int id;
  final String? code;
  final String? name;
  final String? colorName;
  final num? thicknessStandardMm;
  final String? displayName;
  final bool preferred;
  final bool active;

  AllowedRoll toEntity() => AllowedRoll(
    id: id,
    code: code,
    name: name,
    colorName: colorName,
    thicknessStandardMm: thicknessStandardMm,
    displayName: displayName,
    preferred: preferred,
    active: active,
  );
}

class ShiftLineSummaryResponse {
  const ShiftLineSummaryResponse({
    required this.shiftLineId,
    required this.thermoformingLineCode,
    required this.thermoformingLineName,
    required this.completedRollsInSession,
    required this.completedRollsByCurrentWorker,
    this.consumedWeightKgInSession,
    this.rollsContributedInSession = 0,
    this.consumedRolls = const <ConsumedRollResponse>[],
    this.allowedRolls = const <AllowedRollResponse>[],
    this.mountedRoll,
    this.blocked = false,
    this.blockedReason,
    this.takeover,
    this.activeOperatorId,
    this.activeOperatorName,
    this.currentProductTypeId,
    this.currentProductName,
    this.handoverPending = false,
    this.lineLifecycleStatus,
  });

  factory ShiftLineSummaryResponse.fromJson(Map<String, dynamic> json) {
    final Object? mountedRollJson = json['mountedRoll'];
    return ShiftLineSummaryResponse(
      shiftLineId: json['shiftLineId'] as int,
      thermoformingLineCode: json['thermoformingLineCode'] as String,
      thermoformingLineName: json['thermoformingLineName'] as String,
      completedRollsInSession: json['completedRollsInSession'] as int,
      completedRollsByCurrentWorker:
          json['completedRollsByCurrentWorker'] as int,
      // V123 operator-shift-line-scoped consumption metrics (additive;
      // null/absent on a backend that does not compute them).
      consumedWeightKgInSession: _asDouble(json['consumedWeightKgInSession']),
      rollsContributedInSession:
          _asInt(json['rollsContributedInSession']) ?? 0,
      consumedRolls: _parseConsumedRolls(json['consumedRolls']),
      // allowedRolls is additive: a missing/null/malformed value yields [] so
      // older backends never crash the client (compat handled here, not in UI).
      allowedRolls: _parseAllowedRolls(json['allowedRolls']),
      mountedRoll: mountedRollJson is Map<String, dynamic>
          ? SummaryMountedRollResponse.fromJson(mountedRollJson)
          : null,
      // Takeover / line-state fields are parsed defensively: any absent or
      // malformed field leaves the line unblocked and the takeover null.
      blocked: _asBool(json['blocked']) ?? false,
      blockedReason: _asString(json['blockedReason']),
      takeover: _parseTakeover(json),
      // Line-state fields (handoff: Line State Refresh Events). All nullable
      // and additive — older backends simply omit them.
      activeOperatorId: _asInt(json['activeOperatorId']),
      activeOperatorName: _asString(json['activeOperatorName']),
      currentProductTypeId: _asInt(json['currentProductTypeId']),
      currentProductName: _asString(json['currentProductName']),
      handoverPending: _asBool(json['handoverPending']) ?? false,
      lineLifecycleStatus: _asString(json['lineLifecycleStatus']),
    );
  }

  final int shiftLineId;
  final String thermoformingLineCode;
  final String thermoformingLineName;
  final int completedRollsInSession;
  final int completedRollsByCurrentWorker;

  /// V123: the worker's consumed kg in the current operator shift-line/session
  /// (CLOSED blocks on this `shiftLineId` + live provisional from the mounted
  /// roll). `null`/absent on a backend that does not compute it.
  final double? consumedWeightKgInSession;

  /// V123: distinct rolls the worker contributed > 0 kg to in the current
  /// operator shift-line/session. `0` when absent.
  final int rollsContributedInSession;
  final List<ConsumedRollResponse> consumedRolls;
  final List<AllowedRollResponse> allowedRolls;
  final SummaryMountedRollResponse? mountedRoll;
  final bool blocked;
  final String? blockedReason;
  final LineTakeover? takeover;
  final int? activeOperatorId;
  final String? activeOperatorName;
  final int? currentProductTypeId;
  final String? currentProductName;
  final bool handoverPending;
  final String? lineLifecycleStatus;

  /// Current product as a [SummaryActiveProduct], or `null` when the backend
  /// did not supply a current product on the line. The roll-app summary is
  /// the source of truth for the active-product chip; the SSE overlay only
  /// fills the gap when REST omits it (see `_mergeRestWithSseOverlays`).
  SummaryActiveProduct? get _currentProduct {
    final int? id = currentProductTypeId;
    final String? name = currentProductName;
    if (id == null || name == null) return null;
    return SummaryActiveProduct(productId: id, name: name);
  }

  ShiftLineSummary toEntity() => ShiftLineSummary(
    shiftLineId: shiftLineId,
    thermoformingLineCode: thermoformingLineCode,
    thermoformingLineName: thermoformingLineName,
    completedRollsInSession: completedRollsInSession,
    completedRollsByCurrentWorker: completedRollsByCurrentWorker,
    consumedWeightKgInSession: consumedWeightKgInSession,
    rollsContributedInSession: rollsContributedInSession,
    consumedRolls: consumedRolls.map((e) => e.toEntity()).toList(),
    allowedRolls: allowedRolls.map((e) => e.toEntity()).toList(),
    mountedRoll: mountedRoll?.toEntity(),
    activeProduct: _currentProduct,
    blocked: blocked,
    blockedReason: blockedReason,
    takeover: takeover,
    activeOperatorId: activeOperatorId,
    activeOperatorName: activeOperatorName,
    handoverPending: handoverPending,
    lineLifecycleStatus: lineLifecycleStatus,
  );

  /// Parses the `consumedRolls` JSON array. Returns an empty list when the
  /// key is missing or malformed so older backends don't crash the client.
  static List<ConsumedRollResponse> _parseConsumedRolls(Object? raw) {
    if (raw is! List) return const <ConsumedRollResponse>[];
    return <ConsumedRollResponse>[
      for (final Object? item in raw)
        if (item is Map<String, dynamic>) ConsumedRollResponse.fromJson(item),
    ];
  }

  /// Parses the `allowedRolls` JSON array. Returns an empty list when the key
  /// is missing, null, or malformed so older backends (and "no current
  /// product" / "no configured rolls") never crash the client. Individual
  /// items with partial data are tolerated by [AllowedRollResponse.fromJson].
  static List<AllowedRollResponse> _parseAllowedRolls(Object? raw) {
    if (raw is! List) return const <AllowedRollResponse>[];
    return <AllowedRollResponse>[
      for (final Object? item in raw)
        if (item is Map<String, dynamic>) AllowedRollResponse.fromJson(item),
    ];
  }

  /// Builds a [LineTakeover] from the shift-line summary JSON.
  ///
  /// Reads the nested `pendingTakeoverRequest` object when present and falls
  /// back to the flat `takeover*` fields. Returns `null` when there is no
  /// takeover status at all. An unrecognised status maps to
  /// [TakeoverStatus.unknown] — never throws.
  static LineTakeover? _parseTakeover(Map<String, dynamic> json) {
    final Object? nestedRaw = json['pendingTakeoverRequest'];
    final Map<String, dynamic>? nested = nestedRaw is Map<String, dynamic>
        ? nestedRaw
        : null;

    final String? statusWire =
        _asString(json['takeoverRequestStatus']) ??
        _asString(nested?['status']);
    if (statusWire == null && nested == null) return null;

    return LineTakeover(
      status: TakeoverStatus.fromWire(statusWire),
      observedAt: DateTime.now(),
      requestId: _asInt(nested?['id']),
      requestedByOperatorName:
          _asString(nested?['requestedByOperatorName']) ??
          _asString(json['takeoverRequestedByOperatorName']),
      currentOperatorName:
          _asString(nested?['currentOperatorName']) ??
          _asString(json['takeoverCurrentOperatorName']),
      expiresAt: _asDateTime(nested?['expiresAt']),
      handoverExpiresAt: _asDateTime(nested?['handoverExpiresAt']),
      remainingSeconds:
          _asInt(nested?['remainingSeconds']) ??
          _asInt(json['takeoverRemainingSeconds']),
      handoverRemainingSeconds:
          _asInt(nested?['handoverRemainingSeconds']) ??
          _asInt(json['takeoverHandoverRemainingSeconds']),
    );
  }

  static bool? _asBool(Object? v) => v is bool ? v : null;

  static int? _asInt(Object? v) => v is num ? v.toInt() : null;

  static double? _asDouble(Object? v) => v is num ? v.toDouble() : null;

  static num? _asNum(Object? v) => v is num ? v : null;

  static String? _asString(Object? v) =>
      v is String && v.isNotEmpty ? v : null;

  static DateTime? _asDateTime(Object? v) =>
      v is String ? DateTime.tryParse(v) : null;
}
