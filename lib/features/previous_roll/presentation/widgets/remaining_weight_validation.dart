/// Shared validation for the remaining / current weight entered on the
/// "the roll still has material" actions: keep-mounted handover, return
/// remaining, send-to-grinding, and the takeover "remains mounted" option.
///
/// Business rule: weight = 0 is valid ONLY for full consumption (which takes
/// no weight input). For these actions the declared weight must be strictly
/// greater than 0 and must not exceed the roll's last known weight:
///
///     0 < enteredWeightKg <= lastKnownWeightKg
///
/// If the roll is actually finished the worker must pick "استهلاك كامل"
/// instead of entering 0 here. The same rule is enforced server-side
/// (see docs/backend-handoffs/BACKEND_HANDOFF_ROLL_WORKER_REMAINING_WEIGHT_GT_ZERO.md).
class RemainingWeightValidation {
  RemainingWeightValidation._();

  /// Shown when the field is empty / unparseable.
  static const String empty = 'أدخل الوزن المتبقي على الرول.';

  /// Shown when the entered value is 0 or negative — points the worker to
  /// full consumption.
  static const String mustBePositive =
      'يجب أن يكون الوزن المتبقي أكبر من 0 كغ. إذا انتهى الرول اختر استهلاك كامل.';

  /// Shown when the entered value exceeds the last known roll weight.
  static const String overflow =
      'لا يمكن أن يكون الوزن أكبر من آخر وزن معروف للرول.';

  /// Returns the Arabic error message for [rawText], or `null` when it is a
  /// valid remaining weight (`0 < value <= maxAllowedKg`). When [maxAllowedKg]
  /// is null the upper bound is not enforced client-side (the backend still
  /// validates it).
  static String? validate(String rawText, {double? maxAllowedKg}) {
    final String text = rawText.trim();
    if (text.isEmpty) return empty;
    final double? value = double.tryParse(text);
    if (value == null) return empty;
    if (value <= 0) return mustBePositive;
    if (maxAllowedKg != null && value > maxAllowedKg) return overflow;
    return null;
  }

  /// `true` when [rawText] is a valid remaining weight.
  static bool isValid(String rawText, {double? maxAllowedKg}) =>
      validate(rawText, maxAllowedKg: maxAllowedKg) == null;
}
