import 'package:intl/intl.dart';

import '../../../../core/util/factory_time.dart';

/// Data required to render a roll QR label in the structured 100×100 mm
/// layout (ported from `RollProductionApp/.../roll_label_data.dart`).
///
/// Layout (matches the reference label image):
///   Top-left  : QR code  (value = [generatedRollId])
///   Top-right : [rollNumber] — digit extracted from rollCode, e.g. "9"
///   Middle    : 12-digit serial display. For [isScrap] = true (grinding
///               remainders in this app's context) the renderer paints a
///               small generic line-art creature icon to the right of the
///               serial. The Arabic word "جرش" is never printed.
///   Bottom    : [weekdayDisplay] | [dateDisplay] | [timeDisplay]
class RollLabelData {
  const RollLabelData({
    required this.generatedRollId,
    required this.rollNumber,
    required this.isScrap,
    required this.createdAt,
  });

  /// Builds a [RollLabelData] from a 12-digit serial + a roll-type code
  /// (e.g. "TP-9 White" → rollNumber = "9"). When the code carries no
  /// `-DIGITS` segment the full code is used so the slot is never blank.
  factory RollLabelData.fromParts({
    required String generatedRollId,
    required String rollTypeRollCode,
    required bool isScrap,
    required DateTime createdAt,
  }) {
    final RegExpMatch? match = RegExp(r'-(\d+)').firstMatch(rollTypeRollCode);
    final String rollNumber = match?.group(1) ?? rollTypeRollCode;
    return RollLabelData(
      generatedRollId: generatedRollId,
      rollNumber: rollNumber,
      isScrap: isScrap,
      createdAt: createdAt,
    );
  }

  final String generatedRollId;

  /// Numeric machine-label digits shown large on the top-right cell.
  final String rollNumber;

  /// `true` for GRINDING_REMAINING labels — the renderer paints the
  /// reference's scrap creature icon next to the serial.
  final bool isScrap;

  /// Backend-authoritative timestamp. Never substitute device time.
  final DateTime createdAt;

  // ── Computed display getters (verbatim from RollProductionApp) ────────────

  /// Bare 12-digit serial line. Always plain digits.
  String get serialDisplay => generatedRollId;

  /// Arabic weekday name derived from [createdAt] in factory time.
  String get weekdayDisplay {
    const List<String> days = <String>[
      'الإثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
      'الأحد',
    ];
    return days[toFactoryTime(createdAt).weekday - 1];
  }

  /// Date formatted as dd-MM-yyyy (e.g. "11-05-2026").
  String get dateDisplay =>
      DateFormat('dd-MM-yyyy').format(toFactoryTime(createdAt));

  /// 12-hour clock with Arabic period name. Rendered with TextDirection.ltr
  /// so output reads "09:14 مساء", not "مساء 09:14".
  String get timeDisplay {
    final DateTime factory = toFactoryTime(createdAt);
    final int hour12 = factory.hour % 12 == 0 ? 12 : factory.hour % 12;
    final String minute = factory.minute.toString().padLeft(2, '0');
    final String period = factory.hour < 12 ? 'صباحاً' : 'مساء';
    return '${hour12.toString().padLeft(2, '0')}:$minute $period';
  }
}
