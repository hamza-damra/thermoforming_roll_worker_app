/// Centralized Arabic labels for the backend roll-lifecycle **wire enums** that
/// the Roll Worker app renders to the operator (consumed-roll badges, expanded
/// metadata rows, …).
///
/// The operator must NEVER see a raw backend enum string such as
/// `GRINDING_REJECTED_TO_RETURN`. Every renderer routes its wire value through
/// these helpers, which fall back to [unknownRollStatusLabelAr] — a safe Arabic
/// string — instead of echoing the raw code. This mirrors the localization
/// pattern already used for backend error codes in `error_messages_ar.dart`
/// (`arabicForErrorCode`) and for line-lifecycle tokens in `LineWaitingStatus`.
///
/// Add new wire values here when the backend introduces them; never render the
/// raw code at a call site.
library;

/// Safe Arabic fallback for any wire value not explicitly mapped below (an
/// unknown / future backend code, or an empty string). Keeps a raw enum from
/// ever reaching the operator.
const String unknownRollStatusLabelAr = 'حالة غير معروفة';

/// Arabic label for `consumedRolls[].closedReason` (the badge on each closed
/// roll, and the "سبب الإغلاق" row in the expanded card).
///
/// Wire values (backend V127): `FULL_CONSUMPTION`, `PARTIAL_RETURN`,
/// `PARTIAL_GRINDING`, `GRINDING_REJECTED_TO_RETURN` (a grinding recommendation
/// the management rejected, so the roll was returned instead).
String closedReasonLabelAr(String wire) => switch (wire) {
  'FULL_CONSUMPTION' => 'استهلاك كامل',
  'PARTIAL_RETURN' => 'إرجاع جزئي',
  'PARTIAL_GRINDING' => 'جرش جزئي',
  'GRINDING_REJECTED_TO_RETURN' => 'التوصية بالجرش مرفوضة من قبل الإدارة',
  _ => unknownRollStatusLabelAr,
};

/// Arabic label for `consumedRolls[].remainderAction` (the "إجراء المتبقي" row
/// in the expanded card).
///
/// Wire values (backend): `NONE`, `RETURN`, `GRINDING`.
String remainderActionLabelAr(String wire) => switch (wire) {
  'NONE' => 'بدون متبقي',
  'RETURN' => 'إرجاع المتبقي',
  'GRINDING' => 'إرسال للجرش',
  _ => unknownRollStatusLabelAr,
};
