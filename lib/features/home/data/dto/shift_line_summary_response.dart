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

class ShiftLineSummaryResponse {
  const ShiftLineSummaryResponse({
    required this.shiftLineId,
    required this.thermoformingLineCode,
    required this.thermoformingLineName,
    required this.completedRollsInShift,
    required this.completedRollsByCurrentWorker,
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
      completedRollsInShift: json['completedRollsInShift'] as int,
      completedRollsByCurrentWorker:
          json['completedRollsByCurrentWorker'] as int,
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
  final int completedRollsInShift;
  final int completedRollsByCurrentWorker;
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
    completedRollsInShift: completedRollsInShift,
    completedRollsByCurrentWorker: completedRollsByCurrentWorker,
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

  static String? _asString(Object? v) =>
      v is String && v.isNotEmpty ? v : null;

  static DateTime? _asDateTime(Object? v) =>
      v is String ? DateTime.tryParse(v) : null;
}
