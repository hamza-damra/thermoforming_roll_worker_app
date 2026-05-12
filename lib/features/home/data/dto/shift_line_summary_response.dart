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
    );
  }

  final int shiftLineId;
  final String thermoformingLineCode;
  final String thermoformingLineName;
  final int completedRollsInShift;
  final int completedRollsByCurrentWorker;
  final SummaryMountedRollResponse? mountedRoll;

  ShiftLineSummary toEntity() => ShiftLineSummary(
    shiftLineId: shiftLineId,
    thermoformingLineCode: thermoformingLineCode,
    thermoformingLineName: thermoformingLineName,
    completedRollsInShift: completedRollsInShift,
    completedRollsByCurrentWorker: completedRollsByCurrentWorker,
    mountedRoll: mountedRoll?.toEntity(),
  );
}
