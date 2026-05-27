/// ZPL II command tokens emitted by [ZplBuilder] for Zebra printers
/// (verified against the ZD230t over raw TCP port 9100 in the reference
/// Roll Production App). These constants are intentionally isolated
/// from [TsplConstants] — the two command sets must never be cross-wired.
class ZplConstants {
  ZplConstants._();

  static const String startFormat = '^XA';
  static const String endFormat = '^XZ';
  static const String printWidth = '^PW';
  static const String labelLength = '^LL';
  static const String fieldOrigin = '^FO';
  static const String fieldSeparator = '^FS';
  static const String graphicField = '^GFA';
  static const String printQuantity = '^PQ';
  static const String lineEnding = '\r\n';
}
