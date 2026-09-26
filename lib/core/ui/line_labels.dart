/// User-facing line labels for the Roll Worker app: `خط أ`, `خط ب`, `خط ج`, …
///
/// The shop floor speaks in *lines* (`خط`), never machines. Owner decision D1
/// (LINE_3 handoff, option B): a machine is labelled with the server's
/// **palletizing-line name** (`palletizingLineName` on `/bootstrap` and
/// `/sessions/me`) — the same wording the Operator dashboard, the Admin App
/// and the web portal show.
///
/// Labels are **never computed on the device**: no letter table, nothing
/// derived from `machineNumber`, an id, or the tab position. A local
/// alphabetical table once rendered the third line as `خط ت` while the rest
/// of the factory calls it `خط ج`. Never surface raw backend identity either:
/// `lineCode` / `TF_LINE_n`, `lineName` (`خط التشغيل ج`), or the Roll Worker
/// machine name `lineDisplayName` (`ماكينة C`).
class LineLabels {
  LineLabels._();

  /// Neutral placeholder while no server label is known for a machine yet
  /// (e.g. a session-only tab before any `/bootstrap` or `/sessions/me` row
  /// named it). Deliberately not a letter.
  static const String unknown = '…';

  /// The server-sent [palletizingLineName], trimmed, or `null` when the
  /// server sent none (absent, `null`, or blank).
  static String? fromServer(String? palletizingLineName) {
    final String? trimmed = palletizingLineName?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }
}
