import 'package:flutter/foundation.dart';

import '../../domain/entities/mounted_roll.dart';
import '../../domain/entities/roll_scan_warning.dart';

/// DTO for the response of
/// `POST /shift-lines/{shiftLineId}/scan-roll`.
///
/// All fields are server-derived; the client never sends these back.
@immutable
class ThermoformingRollScanResponse {
  const ThermoformingRollScanResponse({
    required this.rollId,
    required this.generatedRollId,
    required this.rollTypeId,
    required this.rollTypeRollCode,
    required this.rollTypeDisplayName,
    required this.colorName,
    required this.productTypeId,
    required this.productTypeName,
    required this.consumptionItemId,
    required this.activeSegmentId,
    required this.state,
    required this.lastKnownWeightKg,
    this.warnings = const <RollScanWarning>[],
  });

  factory ThermoformingRollScanResponse.fromJson(Map<String, dynamic> json) {
    return ThermoformingRollScanResponse(
      rollId: (json['rollId'] as num).toInt(),
      generatedRollId: json['generatedRollId'] as String,
      rollTypeId: (json['rollTypeId'] as num).toInt(),
      rollTypeRollCode: json['rollTypeRollCode'] as String,
      rollTypeDisplayName: json['rollTypeDisplayName'] as String,
      colorName: json['colorName'] as String,
      productTypeId: (json['productTypeId'] as num).toInt(),
      productTypeName: json['productTypeName'] as String,
      consumptionItemId: (json['consumptionItemId'] as num).toInt(),
      activeSegmentId: (json['activeSegmentId'] as num).toInt(),
      state: json['state'] as String,
      lastKnownWeightKg: (json['lastKnownWeightKg'] as num).toDouble(),
      warnings: _parseWarnings(json['warnings']),
    );
  }

  final int rollId;
  final String generatedRollId;
  final int rollTypeId;
  final String rollTypeRollCode;
  final String rollTypeDisplayName;
  final String colorName;
  final int productTypeId;
  final String productTypeName;
  final int consumptionItemId;
  final int activeSegmentId;
  final String state;
  final double lastKnownWeightKg;
  final List<RollScanWarning> warnings;

  MountedRoll toEntity() => MountedRoll(
    rollId: rollId,
    generatedRollId: generatedRollId,
    rollTypeId: rollTypeId,
    rollTypeRollCode: rollTypeRollCode,
    rollTypeDisplayName: rollTypeDisplayName,
    colorName: colorName,
    productTypeId: productTypeId,
    productTypeName: productTypeName,
    consumptionItemId: consumptionItemId,
    activeSegmentId: activeSegmentId,
    state: state,
    lastKnownWeightKg: lastKnownWeightKg,
  );

  static List<RollScanWarning> _parseWarnings(Object? raw) {
    if (raw is! List) return const <RollScanWarning>[];
    final List<RollScanWarning> out = <RollScanWarning>[];
    for (final Object? item in raw) {
      if (item is! Map) continue;
      final Object? code = item['code'];
      final Object? message = item['message'];
      if (code is! String || message is! String) continue;
      final Object? severity = item['severity'];
      final Object? payload = item['payload'];
      out.add(
        RollScanWarning(
          code: code,
          severity: severity is String ? severity : 'WARNING',
          message: message,
          payload: payload is Map
              ? Map<String, Object?>.from(payload)
              : const <String, Object?>{},
        ),
      );
    }
    return List<RollScanWarning>.unmodifiable(out);
  }
}
