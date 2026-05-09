/// Static fragments of the TSPL command stream. Adapted from
/// `roll_production_app`'s validated production pipeline.
class TsplConstants {
  TsplConstants._();

  static const String direction = 'DIRECTION 0';
  static const String offset = 'OFFSET 0 mm';
  static const String shift = 'SHIFT 0';
  static const String reference = 'REFERENCE 0,0';
  static const String setPeelOff = 'SET PEEL OFF';
  static const String setTearOff = 'SET TEAR OFF';
  static const String setTearOn = 'SET TEAR ON';
  static const String setCutterOff = 'SET CUTTER OFF';
  static const String cls = 'CLS';
  static const String lineEnding = '\r\n';
}
