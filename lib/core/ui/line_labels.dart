/// User-facing line labels for the Roll Worker app: `خط أ`, `خط ب`, …
///
/// The shop floor speaks in *lines* (`خط`), never machines — so this app must
/// never surface `ماكينة A/B/1/2`, `خط 1/2`, or raw backend codes like
/// `TF_LINE_1`. Labels are derived from the backend **line number** (e.g. the
/// bootstrap row's `machineNumber`), falling back to the 1-based tab position
/// only when the backend supplies no number — never by tab index alone when a
/// real line number is available.
class LineLabels {
  LineLabels._();

  /// Arabic ordinal letters, alphabetical order: أ، ب، ت، ث، ج، ح …
  static const List<String> _letters = <String>[
    'أ',
    'ب',
    'ت',
    'ث',
    'ج',
    'ح',
    'خ',
    'د',
  ];

  /// Resolves a line label.
  ///
  /// Prefers the backend [lineNumber] (1 → `خط أ`, 2 → `خط ب`, …). When it is
  /// null/≤0, falls back to [fallbackIndex] (the 1-based tab position) so the
  /// label is always present and stable. Numbers beyond the letter table fall
  /// back to `خط N`.
  static String label({int? lineNumber, int? fallbackIndex}) {
    final int n = (lineNumber != null && lineNumber > 0)
        ? lineNumber
        : ((fallbackIndex != null && fallbackIndex > 0) ? fallbackIndex : 1);
    final int i = n - 1;
    if (i >= 0 && i < _letters.length) return 'خط ${_letters[i]}';
    return 'خط $n';
  }
}
