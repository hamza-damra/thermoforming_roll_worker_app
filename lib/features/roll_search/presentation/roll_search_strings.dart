import '../../../core/util/factory_time.dart';

/// Arabic copy and formatting for «بحث بوقت الإنتاج».
abstract final class RollSearchStrings {
  static const String title = 'بحث بوقت الإنتاج';
  static const String formTitle = 'وقت الإنتاج المطبوع على الملصق';
  static const String year = 'سنة';
  static const String month = 'شهر';
  static const String day = 'يوم';
  static const String hour = 'ساعة';
  static const String minute = 'دقيقة';
  static const String onLabel = 'على الملصق';
  static const String search = 'بحث';

  static const String notFound = 'لا يوجد رول مُنتَج في هذه الدقيقة';
  static const String notFoundHint =
      'تأكد من التاريخ والساعة وصباحاً/مساء كما هي على الملصق.';
  static String multipleFound(int count) =>
      'وُجد $count رولات بنفس وقت الإنتاج. اختر الرول المطابق لرقم ووزن الملصق.';
  static String truncated(int shown) => 'تظهر أول $shown رولات فقط.';

  static const String rollNumber = 'رقم الرول';
  static const String producedAt = 'وقت الإنتاج';
  static const String rollType = 'نوع الرول';
  static const String color = 'اللون';
  static const String productionKind = 'نوع الإنتاج';
  static const String producedWeight = 'الوزن عند الإنتاج';
  static const String currentWeight = 'الوزن الحالي';
  static const String state = 'الحالة';

  static const String mountable = 'يمكن تركيب هذا الرول على هذا الخط';
  static const String notMountable = 'لا يمكن تركيب هذا الرول';
  static const String details = 'عرض التفاصيل';
  static const String mount = 'تركيب الرول';
  static const String mounted = 'تم تركيب الرول بنجاح';

  static String productionKindLabel(String? wire) => switch (wire) {
    'NORMAL' => 'طبيعي',
    'SCRAP' => 'جرش',
    _ => '—',
  };

  static String kg(double v) => '${v.toStringAsFixed(3)} كغ';

  /// Production instant in factory time, to the second, with the label's
  /// weekday and 12-hour clock: `الثلاثاء 30-09-2026  02:05:37 مساء`.
  static String productionTime(DateTime instant) {
    final DateTime t = toFactoryTime(instant);
    final int hour12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final String period = t.hour < 12 ? 'صباحاً' : 'مساء';
    return '${_weekdays[t.weekday - 1]} '
        '${_two(t.day)}-${_two(t.month)}-${t.year}  '
        '${_two(hour12)}:${_two(t.minute)}:${_two(t.second)} $period';
  }

  static String _two(int v) => v.toString().padLeft(2, '0');

  static const List<String> _weekdays = <String>[
    'الإثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
    'السبت',
    'الأحد',
  ];
}
