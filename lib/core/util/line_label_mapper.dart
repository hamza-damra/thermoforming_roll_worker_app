/// Display-only friendly labels for thermoforming lines.
///
/// The backend remains authoritative for wire codes (`TF_LINE_1`,
/// `TF_LINE_2`, ...); this mapper only controls what factory workers see
/// in the bottom navigation, top header, and similar user-facing surfaces.
///
/// Wire codes flow through registry, SSE, and API contracts unchanged —
/// never substitute the friendly label upstream.
class LineLabelMapper {
  LineLabelMapper._();

  /// Friendly Arabic line label for the bottom navigation and tab strips.
  ///
  /// Resolution order:
  ///   1. Hardcoded mapping for known thermoforming codes
  ///      (`TF_LINE_1` → `خط 1`, `TF_LINE_2` → `خط 2`).
  ///   2. Backend-supplied display name when present.
  ///   3. `خط N` where N is the 1-based tab index (last-resort).
  static String friendlyLineLabel({
    required String? thermoformingLineCode,
    required String? thermoformingLineName,
    required int oneBasedIndex,
  }) {
    final String? mapped = _knownLineLabel(thermoformingLineCode);
    if (mapped != null) return mapped;
    if (thermoformingLineName != null && thermoformingLineName.isNotEmpty) {
      return thermoformingLineName;
    }
    return 'خط $oneBasedIndex';
  }

  /// Friendly Arabic machine name for the centered top header.
  ///
  /// Resolution order:
  ///   1. Hardcoded mapping for known thermoforming codes
  ///      (`TF_LINE_1` → `ماكينة A`, `TF_LINE_2` → `ماكينة B`).
  ///   2. Backend-supplied display name when present.
  ///   3. Fall back to [friendlyLineLabel].
  static String friendlyMachineName({
    required String? thermoformingLineCode,
    required String? thermoformingLineName,
    required int oneBasedIndex,
  }) {
    final String? mapped = _knownMachineName(thermoformingLineCode);
    if (mapped != null) return mapped;
    if (thermoformingLineName != null && thermoformingLineName.isNotEmpty) {
      return thermoformingLineName;
    }
    return friendlyLineLabel(
      thermoformingLineCode: thermoformingLineCode,
      thermoformingLineName: thermoformingLineName,
      oneBasedIndex: oneBasedIndex,
    );
  }

  static String? _knownLineLabel(String? code) {
    switch (code) {
      case 'TF_LINE_1':
        return 'خط 1';
      case 'TF_LINE_2':
        return 'خط 2';
      default:
        return null;
    }
  }

  static String? _knownMachineName(String? code) {
    switch (code) {
      case 'TF_LINE_1':
        return 'ماكينة A';
      case 'TF_LINE_2':
        return 'ماكينة B';
      default:
        return null;
    }
  }
}
