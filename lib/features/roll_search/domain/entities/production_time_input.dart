import 'package:flutter/foundation.dart';

/// Half of the 12-hour clock printed on the roll label (`09:14 مساء`).
enum ClockPeriod {
  am('صباحاً'),
  pm('مساء');

  const ClockPeriod(this.labelText);

  /// Exactly as the roll label prints it.
  final String labelText;
}

/// The fields of the «بحث بوقت الإنتاج» form.
enum ProductionTimeField { year, month, day, hour, minute, period }

/// A factory-time minute as the backend expects it: 24-hour clock, factory
/// (`Asia/Hebron`) wall time. The backend matches it against the roll's
/// production timestamp over `[minute, next minute)`.
@immutable
class ProductionTimeQuery {
  const ProductionTimeQuery({
    required this.year,
    required this.month,
    required this.day,
    required this.hour24,
    required this.minute,
  });

  final int year;
  final int month;
  final int day;
  final int hour24;
  final int minute;

  Map<String, Object> toQueryParameters() => <String, Object>{
    'year': year,
    'month': month,
    'day': day,
    'hour': hour24,
    'minute': minute,
  };

  @override
  bool operator ==(Object other) =>
      other is ProductionTimeQuery &&
      other.year == year &&
      other.month == month &&
      other.day == day &&
      other.hour24 == hour24 &&
      other.minute == minute;

  @override
  int get hashCode => Object.hash(year, month, day, hour24, minute);

  @override
  String toString() =>
      'ProductionTimeQuery($year-$month-$day $hour24:$minute)';
}

/// What the worker typed, before validation. The hour is on the 12-hour clock
/// with [period], the way the roll label prints it; [toQuery] converts it.
@immutable
class ProductionTimeInput {
  const ProductionTimeInput({
    this.year = '',
    this.month = '',
    this.day = '',
    this.hour = '',
    this.minute = '',
    this.period,
  });

  static const int minYear = 2000;
  static const int maxYear = 2099;

  final String year;
  final String month;
  final String day;
  final String hour;
  final String minute;
  final ClockPeriod? period;

  ProductionTimeInput copyWith({
    String? year,
    String? month,
    String? day,
    String? hour,
    String? minute,
    ClockPeriod? period,
  }) {
    return ProductionTimeInput(
      year: year ?? this.year,
      month: month ?? this.month,
      day: day ?? this.day,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      period: period ?? this.period,
    );
  }

  /// One Arabic message per invalid field, in form order; empty when the
  /// input names a real calendar minute. The backend re-validates — this only
  /// saves a round-trip and points at the field to fix.
  Map<ProductionTimeField, String> validate() {
    final Map<ProductionTimeField, String> errors =
        <ProductionTimeField, String>{};
    final int? y = _checkRange(
      errors,
      ProductionTimeField.year,
      year,
      minYear,
      maxYear,
      'السنة',
    );
    final int? m = _checkRange(
      errors,
      ProductionTimeField.month,
      month,
      1,
      12,
      'الشهر',
    );
    final int? d = _checkRange(
      errors,
      ProductionTimeField.day,
      day,
      1,
      31,
      'اليوم',
    );
    _checkRange(errors, ProductionTimeField.hour, hour, 1, 12, 'الساعة');
    _checkRange(errors, ProductionTimeField.minute, minute, 0, 59, 'الدقيقة');
    if (y != null && m != null && d != null && d > daysInMonth(y, m)) {
      errors[ProductionTimeField.day] = 'هذا اليوم غير موجود في هذا الشهر';
    }
    if (period == null) {
      errors[ProductionTimeField.period] = 'اختر صباحاً أو مساء';
    }
    return errors;
  }

  /// The backend query, or `null` while [validate] reports an error.
  ProductionTimeQuery? toQuery() {
    if (validate().isNotEmpty) return null;
    return ProductionTimeQuery(
      year: int.parse(year),
      month: int.parse(month),
      day: int.parse(day),
      hour24: to24Hour(int.parse(hour), period!),
      minute: int.parse(minute),
    );
  }

  /// How the entered minute reads on the roll label — weekday, `dd-MM-yyyy`
  /// and `hh:mm صباحاً|مساء`, formatted as the label formats them — so the
  /// worker can compare it with the sticker before searching. `null` while the
  /// input is invalid.
  ({String weekday, String date, String time})? labelPreview() {
    final ProductionTimeQuery? q = toQuery();
    if (q == null) return null;
    return (
      weekday: _weekdays[DateTime.utc(q.year, q.month, q.day).weekday - 1],
      date: '${_two(q.day)}-${_two(q.month)}-${q.year}',
      time: '${_two(int.parse(hour))}:${_two(q.minute)} ${period!.labelText}',
    );
  }

  /// 12-hour clock to 24-hour: 12 صباحاً is 00, 12 مساء is 12.
  static int to24Hour(int hour12, ClockPeriod period) {
    final int h = hour12 % 12;
    return period == ClockPeriod.pm ? h + 12 : h;
  }

  static int daysInMonth(int year, int month) =>
      DateTime.utc(year, month + 1, 0).day;

  static int? _checkRange(
    Map<ProductionTimeField, String> errors,
    ProductionTimeField field,
    String raw,
    int min,
    int max,
    String name,
  ) {
    final String text = raw.trim();
    if (text.isEmpty) {
      errors[field] = 'أدخل $name';
      return null;
    }
    final int? value = int.tryParse(text);
    if (value == null || value < min || value > max) {
      errors[field] = '$name من $min إلى $max';
      return null;
    }
    return value;
  }

  static String _two(int v) => v.toString().padLeft(2, '0');

  /// Same names, same order, as the roll label (`RollLabelData`).
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
