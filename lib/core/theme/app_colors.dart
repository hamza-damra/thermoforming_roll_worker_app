import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF2D8A5E);
  static const Color primaryDark = Color(0xFF206B47);
  static const Color primaryLight = Color(0xFFE8F4ED);

  static const Color accent = Color(0xFFFF9C00);
  static const Color accentDark = Color(0xFFE08800);

  static const Color scaffold = Color(0xFFFAFAFA);
  static const Color surface = Colors.white;
  static const Color surfaceMuted = Color(0xFFF5F5F5);
  static const Color border = Color(0xFFE0E0E0);
  static const Color divider = Color(0xFFEEEEEE);

  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textOnPrimary = Colors.white;

  static const Color success = Color(0xFF2D8A5E);
  static const Color warning = Color(0xFFFF9C00);
  static const Color error = Color(0xFFD32F2F);
  static const Color errorBg = Color(0xFFFDECEC);

  static const Color offline = Color(0xFFB45309);
  static const Color offlineBg = Color(0xFFFFF7E6);

  // ─── Per-line accent palette ────────────────────────────────────────────
  //
  // Six accessibility-tuned colors picked to remain readable on the white /
  // light-grey surface backgrounds used by the home shell. Mapped from a
  // line's stable identity so the same line gets the same color across app
  // launches — see [accentForLine].
  static const Color lineAccent1 = Color(0xFF2D8A5E); // teal-green (primary)
  static const Color lineAccent2 = Color(0xFFE65100); // burnt orange
  static const Color lineAccent3 = Color(0xFF1565C0); // strong blue
  static const Color lineAccent4 = Color(0xFF6A1B9A); // deep purple
  static const Color lineAccent5 = Color(0xFFC62828); // brick red
  static const Color lineAccent6 = Color(0xFF00838F); // dark cyan

  static const List<Color> lineAccentPalette = <Color>[
    lineAccent1,
    lineAccent2,
    lineAccent3,
    lineAccent4,
    lineAccent5,
    lineAccent6,
  ];

  /// Deterministic per-line color. Fallback chain:
  ///   1. `palletizingLineId % 6`
  ///   2. `thermoformingLineId % 6`
  ///   3. stable hash of `palletizingLineCode`
  ///   4. palette[0]
  ///
  /// Always returns a non-null, non-transparent color from
  /// [lineAccentPalette].
  static Color accentForLine({
    int? palletizingLineId,
    int? thermoformingLineId,
    String? palletizingLineCode,
  }) {
    const int paletteLength = 6;
    if (palletizingLineId != null) {
      return lineAccentPalette[palletizingLineId.abs() % paletteLength];
    }
    if (thermoformingLineId != null) {
      return lineAccentPalette[thermoformingLineId.abs() % paletteLength];
    }
    if (palletizingLineCode != null && palletizingLineCode.isNotEmpty) {
      return lineAccentPalette[palletizingLineCode.hashCode.abs() %
          paletteLength];
    }
    return lineAccentPalette[0];
  }
}
