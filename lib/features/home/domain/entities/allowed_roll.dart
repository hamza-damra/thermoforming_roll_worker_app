import 'package:flutter/foundation.dart';

/// One roll type the backend marks as allowed for the line's current product,
/// returned in the `allowedRolls` array of the shift-line summary endpoint.
///
/// This list is **informational / display-only**. The backend remains the
/// authority for roll scan/mount validation — the app never uses this list to
/// bypass or pre-empt server-side checks (see the redesign brief).
///
/// All optional fields tolerate `null` from partial backend data:
///   * [displayName] is backend-composed and safe to render directly; when
///     absent it falls back to [code], then [name], then a generic Arabic
///     placeholder (see [resolvedDisplayName]).
///   * [preferred] defaults to `false` when missing.
///   * [active] defaults to `true` unless the backend explicitly says `false`.
@immutable
class AllowedRoll {
  const AllowedRoll({
    required this.id,
    this.code,
    this.name,
    this.colorName,
    this.thicknessStandardMm,
    this.displayName,
    this.preferred = false,
    this.active = true,
  });

  final int id;
  final String? code;
  final String? name;
  final String? colorName;
  final num? thicknessStandardMm;

  /// Pre-composed display string from the backend (e.g. `"TP-1 / Thin PP"`).
  /// May be `null` — use [resolvedDisplayName] for a render-safe value.
  final String? displayName;

  /// `true` when the backend orders this roll first as the preferred choice.
  final bool preferred;

  /// `false` only when the backend explicitly deactivated the roll type.
  final bool active;

  static const String unknownLabel = 'رول غير معروف';

  /// Render-safe main label: [displayName] → [code] → [name] → placeholder.
  String get resolvedDisplayName {
    final String? display = _nonEmpty(displayName);
    if (display != null) return display;
    final String? c = _nonEmpty(code);
    if (c != null) return c;
    final String? n = _nonEmpty(name);
    if (n != null) return n;
    return unknownLabel;
  }

  static String? _nonEmpty(String? v) =>
      (v != null && v.trim().isNotEmpty) ? v.trim() : null;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AllowedRoll &&
        other.id == id &&
        other.code == code &&
        other.name == name &&
        other.colorName == colorName &&
        other.thicknessStandardMm == thicknessStandardMm &&
        other.displayName == displayName &&
        other.preferred == preferred &&
        other.active == active;
  }

  @override
  int get hashCode => Object.hash(
    id,
    code,
    name,
    colorName,
    thicknessStandardMm,
    displayName,
    preferred,
    active,
  );
}

/// Single source of truth for the compact roll label shown across the app
/// (e.g. `TP-1 Black (زبدية)`). Every widget that renders an allowed-roll
/// name must go through this helper so the de-duplication fix can never
/// regress in one place while being correct in another.
///
/// Output shape: `<type+color> (<arabic category>)`, where the parenthesised
/// Arabic part is dropped when unavailable, e.g. `TP-1 Black`.
///
/// The base (type + color) is taken from the backend-composed [displayName]
/// when present (its leading segment before `/`), else built from
/// `code`(+`colorName`), then run through a word-level de-dup pass. That pass
/// collapses the repeated colour seen in production data where `code` already
/// carries the colour (`code: 'TP-1 Black'`, `colorName: 'Black'` →
/// `TP-1 Black Black` → `TP-1 Black`) — see the dashboard redesign brief §H.
String formatAllowedRollDisplayName(AllowedRoll roll) {
  final String base = _dedupeAdjacentWords(_allowedRollBaseLabel(roll));
  final String? arabic = _allowedRollArabicCategory(roll);
  if (arabic != null && !base.toLowerCase().contains(arabic.toLowerCase())) {
    return '$base ($arabic)';
  }
  return base;
}

/// The type+color portion, before de-dup. Fallback chain:
///   1. leading segment of `displayName` (before `/`)
///   2. `code colorName` (or just `code` when it already carries the colour)
///   3. `code` → `name` → generic placeholder
String _allowedRollBaseLabel(AllowedRoll roll) {
  final String? display = _trimToNull(roll.displayName);
  if (display != null) {
    final String head = display.split('/').first.trim();
    if (head.isNotEmpty) return head;
    return display;
  }
  final String? code = _trimToNull(roll.code);
  final String? color = _trimToNull(roll.colorName);
  if (code != null && color != null) {
    if (code.toLowerCase().contains(color.toLowerCase())) return code;
    return '$code $color';
  }
  if (code != null) return code;
  final String? name = _trimToNull(roll.name);
  if (name != null) return name;
  return AllowedRoll.unknownLabel;
}

/// The Arabic category/name to show in parentheses: the `displayName` tail
/// after `/` when present, else the `name` field. Returns `null` when neither
/// is available.
String? _allowedRollArabicCategory(AllowedRoll roll) {
  final String? display = _trimToNull(roll.displayName);
  if (display != null && display.contains('/')) {
    final String tail = display.split('/').skip(1).join('/').trim();
    if (tail.isNotEmpty) return tail;
  }
  return _trimToNull(roll.name);
}

/// Collapses consecutive duplicate words (case-insensitive), so
/// `TP-1 Black Black` → `TP-1 Black` while `TP-6 Black` is untouched.
String _dedupeAdjacentWords(String value) {
  final List<String> words = value
      .split(RegExp(r'\s+'))
      .where((String w) => w.isNotEmpty)
      .toList(growable: false);
  final List<String> out = <String>[];
  for (final String w in words) {
    if (out.isNotEmpty && out.last.toLowerCase() == w.toLowerCase()) continue;
    out.add(w);
  }
  return out.isEmpty ? value.trim() : out.join(' ');
}

String? _trimToNull(String? v) =>
    (v != null && v.trim().isNotEmpty) ? v.trim() : null;
