/// Wire protocol spoken by a configured printer.
///
/// The Roll Worker app supports two printer families on port 9100 TCP:
///
/// * [tspl] — Xprinter and other TSPL-compatible thermal printers.
///   The legacy default; existing fleet shipped before multi-protocol
///   support persists with this value via Hive back-compat (a `null`
///   stored language token resolves to [tspl]).
/// * [zpl]  — Zebra (ZD230t, ZT231, ...) and other ZPL II printers.
///
/// `wireToken` is the canonical short string stored in Hive — never
/// translate the localized display name back into a token, the storage
/// format is locale-independent.
enum PrinterLanguage {
  tspl(
    wireToken: 'tspl',
    displayNameAr: 'Xprinter / TSPL',
    shortBadge: 'TSPL',
  ),
  zpl(
    wireToken: 'zpl',
    displayNameAr: 'Zebra / ZPL',
    shortBadge: 'ZPL',
  );

  const PrinterLanguage({
    required this.wireToken,
    required this.displayNameAr,
    required this.shortBadge,
  });

  /// Persisted token. Stable across releases — do not rename without a
  /// migration in the Hive model.
  final String wireToken;

  /// Arabic display name shown in the printer-settings UI.
  final String displayNameAr;

  /// Short uppercase badge for the printer list rows.
  final String shortBadge;

  /// Resolves a stored token back to the enum value. Missing / unknown
  /// tokens fall back to [tspl] so existing 6-field Hive records (saved
  /// before this field was added) keep working without a migration.
  static PrinterLanguage fromWireToken(String? token) {
    if (token == null) return PrinterLanguage.tspl;
    for (final PrinterLanguage value in PrinterLanguage.values) {
      if (value.wireToken == token) return value;
    }
    return PrinterLanguage.tspl;
  }
}
