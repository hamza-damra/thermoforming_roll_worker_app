import 'package:intl/intl.dart';

import 'factory_time.dart';

/// Formats a backend timestamp as a readable Arabic absolute date + time,
/// e.g. `23-06-2026، 10:30 صباحًا`.
///
/// Used by the scan-blocked dialogs to render `recommendedAt` / `consumedAt` /
/// `cancelledAt` from the error `details`. The timestamp is rendered in factory
/// (`Asia/Hebron`) time via [toFactoryTime], never in the device's zone; the
/// 12-hour clock + Arabic period (`صباحًا` / `مساءً`) matches the roll-label
/// formatting elsewhere in the app.
///
/// Returns `null` for a `null` input so callers can drop the whole row when the
/// backend did not supply the field.
String? formatArabicDateTime(DateTime? dt) {
  if (dt == null) return null;
  final DateTime factory = toFactoryTime(dt);
  final String date = DateFormat('dd-MM-yyyy').format(factory);
  final int hour12 = factory.hour % 12 == 0 ? 12 : factory.hour % 12;
  final String minute = factory.minute.toString().padLeft(2, '0');
  final String period = factory.hour < 12 ? 'صباحًا' : 'مساءً';
  return '$date، ${hour12.toString().padLeft(2, '0')}:$minute $period';
}

/// Tolerant ISO-8601 parser for backend timestamps such as
/// `2026-06-23T10:30:00.000+03:00`. Returns `null` when [raw] is missing or
/// unparseable, so dialogs never crash on a malformed/absent value.
DateTime? tryParseTimestamp(Object? raw) {
  if (raw is DateTime) return raw;
  if (raw is! String || raw.trim().isEmpty) return null;
  return DateTime.tryParse(raw.trim());
}
