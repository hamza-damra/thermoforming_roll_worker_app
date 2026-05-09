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
  /// has not yet picked one.
  static const String defaultPresetId = 'default_50x30';
}
