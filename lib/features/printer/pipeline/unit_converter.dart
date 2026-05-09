import '../core/printing_constants.dart';

/// mm ↔ dots conversion at 203 DPI (the default for Zebra-class thermal
/// printers). Mirrors `roll_production_app`'s validated math.
class UnitConverter {
  UnitConverter._();

  static int mmToDots(double mm) =>
      (mm * PrintingConstants.printerDpi / 25.4).round();

  static double dotsToMm(int dots) =>
      dots * 25.4 / PrintingConstants.printerDpi;

  static int dotsToBytes(int dots) => (dots + 7) ~/ 8;

  static int bytesToDots(int bytes) => bytes * 8;

  static int alignToBytes(int dots) => dotsToBytes(dots) * 8;
}
