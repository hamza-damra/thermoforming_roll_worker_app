import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// IANA zone of the factory floor. Every backend instant is rendered in this
/// zone, never in the device's zone.
const String factoryTimeZoneName = 'Asia/Hebron';

tz.Location? _cachedZone;

/// Resolves (and caches) the factory [tz.Location], loading the IANA database
/// on first use.
///
/// Lazily initialised on purpose: the pre-login picker SSE stream and the
/// printing pipeline both format instants, and neither is guaranteed to run
/// after an explicit startup hook. Callers therefore never have to remember
/// to bootstrap this.
tz.Location get factoryZone {
  final tz.Location? cached = _cachedZone;
  if (cached != null) return cached;
  tzdata.initializeTimeZones();
  final tz.Location zone = tz.getLocation(factoryTimeZoneName);
  _cachedZone = zone;
  return zone;
}

/// Converts a backend instant to factory (`Asia/Hebron`) wall-clock time.
///
/// This is the only sanctioned way to render a backend timestamp. Formatting a
/// raw [DateTime] — or one passed through `.toLocal()` — renders the *device's*
/// zone, which is wrong on any device not set to Palestine time and can shift
/// an instant across midnight (printing the wrong weekday/date on a label).
///
/// [dt] may be UTC or local; `.toUtc()` normalises both. Dart's
/// `DateTime.parse` already returns `isUtc == true` for any string carrying a
/// zone designator — both `2026-05-17T20:09:00Z` and
/// `2026-05-17T23:09:00.000+03:00` parse to the same value — so this is
/// correct for both the current and legacy backend wire formats.
///
/// Uses the IANA database rather than a fixed offset because `Asia/Hebron` is
/// `+02:00` in winter and `+03:00` in summer.
tz.TZDateTime toFactoryTime(DateTime dt) =>
    tz.TZDateTime.from(dt.toUtc(), factoryZone);
