/// Human-friendly Arabic relative time for "since" phrasing, e.g.
/// `منذ ٥ ساعات و١٠ دقائق` or `منذ يومين و٥ ساعات و٥ دقائق`.
///
/// Composes the non-zero day / hour / minute parts (largest first) joined with
/// `" و"`, in Arabic-Indic digits, using the genitive dual forms
/// (`يومين` / `ساعتين` / `دقيقتين`) so the phrase reads naturally after `منذ`.
/// Under a minute → `منذ أقل من دقيقة`. A future/skewed timestamp is clamped to
/// "now" so it never shows a negative duration.
///
/// `now` is injected (no hidden `DateTime.now()`) so callers control the clock
/// and it stays unit-testable; widgets pass `DateTime.now()`.
String formatArabicRelativeTime(DateTime from, {required DateTime now}) {
  Duration diff = now.difference(from);
  if (diff.isNegative) diff = Duration.zero;

  if (diff.inMinutes < 1) return 'منذ أقل من دقيقة';

  final int days = diff.inDays;
  final int hours = diff.inHours % 24;
  final int minutes = diff.inMinutes % 60;

  final List<String> parts = <String>[];
  if (days > 0) {
    parts.add(_unit(days, 'يوم واحد', 'يومين', 'أيام', 'يوم'));
  }
  if (hours > 0) {
    parts.add(_unit(hours, 'ساعة واحدة', 'ساعتين', 'ساعات', 'ساعة'));
  }
  if (minutes > 0) {
    parts.add(_unit(minutes, 'دقيقة واحدة', 'دقيقتين', 'دقائق', 'دقيقة'));
  }

  return 'منذ ${parts.join(' و')}';
}

/// Arabic count phrasing for one time unit:
///   1 → [one] (e.g. `دقيقة واحدة`), 2 → [two] (dual, e.g. `دقيقتين`),
///   3–10 → `N [few]` (e.g. `٥ دقائق`), 11+ → `N [many]` (e.g. `٣٠ دقيقة`).
String _unit(int n, String one, String two, String few, String many) {
  if (n == 1) return one;
  if (n == 2) return two;
  final String digits = _toArabicDigits(n);
  if (n >= 3 && n <= 10) return '$digits $few';
  return '$digits $many';
}

String _toArabicDigits(int n) {
  const List<String> arabic = <String>[
    '٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩',
  ];
  final StringBuffer sb = StringBuffer();
  for (final int code in n.toString().codeUnits) {
    final int d = code - 0x30; // '0'
    sb.write(d >= 0 && d <= 9 ? arabic[d] : String.fromCharCode(code));
  }
  return sb.toString();
}
