/// Pipeline-wide constants for the TSPL/socket printing path.
///
/// Adapted from `roll_production_app` (READ-ONLY reference). Values match
/// the production-validated defaults so the same Zebra-class thermal
/// printers work without retuning.
class PrintingConstants {
  PrintingConstants._();

  /// Native dot density of the supported thermal printers.
  static const int printerDpi = 203;

  /// TSPL default TCP port.
  static const int defaultPort = 9100;

  static const int connectionTimeoutMs = 3000;
  static const int sendTimeoutMs = 5000;

  static const double defaultGapMm = 2.0;
  static const double defaultMarginMm = 2.0;
  static const int defaultCopies = 1;

  /// First built-in preset id; used as the boot-time fallback if the worker
  /// has not yet picked one. Bumped from 50×30 to 100×100 — the factory
  /// standardized on 100×100 mm label stock; see the one-shot preset
  /// migration in `printing_local_storage.dart` (`preset_migration_v1`).
  static const String defaultPresetId = 'default_100x100';

  /// Pre-migration default preset id. Used by the one-shot migration in
  /// `printing_local_storage.dart` to decide whether the existing
  /// `lastPresetId` was an unchanged default (safe to bump to 100×100)
  /// vs a deliberate user choice (must not be overridden).
  static const String legacyDefaultPresetId = 'default_50x30';
}
