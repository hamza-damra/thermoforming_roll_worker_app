import 'app_failure.dart';
import 'error_code.dart';

/// Arabic UI strings for every backend [ErrorCode] documented in
/// `THERMOFORMING_ROLL_WORKER_APP_FRONTEND_REQUIREMENTS.md` §17 and the
/// realtime + line-management handoff §7.
const Map<ErrorCode, String> _arabicByCode = <ErrorCode, String>{
  // Auth / session
  ErrorCode.rollWorkerNotAllowed: 'هذا الموظف غير مخوّل للعمل كموظف رولات.',
  ErrorCode.rollWorkerSessionRequired:
      'انتهت الجلسة. يرجى تسجيل الدخول من جديد.',
  ErrorCode.operatorPinInvalid: 'رمز PIN غير صحيح.',
  ErrorCode.operatorPinLocked:
      'تم قفل الحساب لعدد كبير من المحاولات الخاطئة. يرجى مراجعة المشرف.',
  ErrorCode.operatorLocked:
      'تم قفل الحساب لعدد كبير من المحاولات الخاطئة. يرجى مراجعة المشرف.',

  // Multi-line batch session-start (handoff §7.3)
  ErrorCode.rollWorkerSessionBatchEmpty: 'يجب اختيار خط واحد على الأقل.',
  ErrorCode.rollWorkerSessionLineDuplicate: 'تم اختيار نفس الخط أكثر من مرة.',
  ErrorCode.rollWorkerSessionLineInactive:
      'أحد الخطوط المختارة لم يعد نشطاً.',
  // Generic fallback when no `ownerOperatorName` is present; the
  // [arabicMessageFor] helper below interpolates the owner name when the
  // backend includes one in `details`.
  ErrorCode.rollWorkerSessionLineUsedByOtherWorker:
      'أحد الخطوط مستخدم بالفعل من قبل موظف آخر.',

  // Shift-line state
  ErrorCode.thermoformingShiftLineNotFound:
      'الخط غير موجود. يرجى تحديث الشاشة.',
  ErrorCode.thermoformingShiftLineNotActive:
      'هذا الخط لم يعد نشطاً. يرجى تحديث الشاشة.',
  ErrorCode.noCurrentProductOnLine:
      'لا يوجد منتج محدد حالياً على خط الطبليات المرتبط. حدد المنتج قبل تحميل الرول.',
  ErrorCode.productionPlanItemRequired:
      'لا يوجد منتج نشط على هذا الخط. يرجى مراجعة المشرف لإضافة عنصر إلى خطة الإنتاج.',

  // Roll lifecycle (handoff §7.1)
  ErrorCode.rollNotFound: 'الرول غير موجود. تأكد من رقم الرول.',
  ErrorCode.rollAlreadyConsumed: 'هذا الرول مستهلك بالفعل.',
  ErrorCode.rollSentToGrindingNotReusable:
      'تم إرسال هذا الرول للجرش ولا يمكن تركيبه كمتبقي صالح.',
  ErrorCode.rollActiveOnAnotherLine: 'هذا الرول مركّب حالياً على خط آخر.',
  ErrorCode.rollBlocked: 'هذا الرول محظور إدارياً ولا يمكن استخدامه.',
  ErrorCode.rollTypeNotAllowedForProduct:
      'نوع الرول غير مسموح للمنتج الحالي على هذا الخط.',
  ErrorCode.rollCuringMinimumNotMet:
      'هذا الرول لم يكتمل فترة الحضانة الدنيا بعد.',
  ErrorCode.noActiveRollOnLine: 'لا يوجد رول مركب حالياً على هذا الخط.',
  ErrorCode.noOpenSegmentOnItem:
      'خطأ داخلي في حالة الرول. يرجى تحديث الشاشة وإعادة المحاولة.',

  // Weight inputs (handoff §7.2)
  ErrorCode.invalidRemainingRollWeight:
      'الوزن المتبقي غير صالح. يجب أن يكون بين صفر ووزن الرول الحالي.',
  ErrorCode.currentRollWeightRequired:
      'وزن الرول الحالي مطلوب قبل تغيير المنتج.',
  ErrorCode.invalidCurrentRollWeight:
      'وزن الرول الحالي غير صالح. يجب أن يكون صفراً أو موجباً ولا يتجاوز وزن بداية الجزء.',

  // Product switch (legacy — manual product-switch removed; codes kept
  // because /scan-roll can still surface them indirectly).
  ErrorCode.productTypeNotFound: 'لم يتم العثور على المنتج المطلوب.',
  ErrorCode.productTypeInactive: 'هذا المنتج غير نشط.',

  // Reprint
  ErrorCode.rollLabelReprintNotAvailable:
      'إعادة طباعة ملصق الرول متاحة فقط بعد الإرجاع الجزئي أو إغلاق الجرش.',

  // Urgent manager announcements (fallback only — the notice controller
  // treats this code as already-acknowledged and dismisses the modal).
  ErrorCode.rollAnnouncementNotFound: 'لم تعد هذه الملاحظة متاحة.',

  // Generic
  ErrorCode.validationError: 'حدث خطأ، حاول مرة أخرى.',
};

/// Generic Arabic fallback for unknown / unmapped errors.
const String genericRetryArabic = 'حدث خطأ، حاول مرة أخرى.';

/// Connectivity banner string (also used for [NetworkFailure]).
const String noConnectionArabic =
    'لا يوجد اتصال بالخادم، سيتم إعادة المحاولة تلقائيًا';

/// Persistent server-failure banner (handoff §7.4 — shown after repeated
/// 5xx on `/sessions/me`).
const String serverUnreachableRetryingArabic =
    'تعذّر الاتصال بالخادم. يتم إعادة المحاولة…';

/// Returns the Arabic message for an [ErrorCode], or the generic retry text
/// for [ErrorCode.unknown] / unmapped codes.
String arabicForErrorCode(ErrorCode code) =>
    _arabicByCode[code] ?? genericRetryArabic;

/// Maps any [AppFailure] to a user-facing Arabic message. For
/// [BusinessFailure] with code [ErrorCode.rollWorkerSessionLineUsedByOtherWorker],
/// interpolates `details.ownerOperatorName` when the backend supplied it
/// (handoff §7.3) so the worker sees *who* owns the conflicting line.
String arabicMessageFor(AppFailure failure) {
  return switch (failure) {
    NetworkFailure() => noConnectionArabic,
    BusinessFailure(:final ErrorCode code, :final Map<String, Object?>? details)
        when code == ErrorCode.rollWorkerSessionLineUsedByOtherWorker =>
      _ownerOperatorMessage(details),
    BusinessFailure(:final ErrorCode code) => arabicForErrorCode(code),
    ServerFailure() => genericRetryArabic,
    UnknownFailure() => genericRetryArabic,
  };
}

String _ownerOperatorMessage(Map<String, Object?>? details) {
  final Object? owner = details?['ownerOperatorName'];
  if (owner is String && owner.trim().isNotEmpty) {
    return 'أحد الخطوط مستخدم بالفعل من قبل الموظف: ${owner.trim()}.';
  }
  return arabicForErrorCode(ErrorCode.rollWorkerSessionLineUsedByOtherWorker);
}
