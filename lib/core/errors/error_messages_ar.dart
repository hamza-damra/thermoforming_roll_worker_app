import 'app_failure.dart';
import 'biometric_denial.dart';
import 'error_code.dart';

/// Arabic UI strings for every backend [ErrorCode] documented in
/// `THERMOFORMING_ROLL_WORKER_APP_FRONTEND_REQUIREMENTS.md` §17 and the
/// realtime + line-management handoff §7.
const Map<ErrorCode, String> _arabicByCode = <ErrorCode, String>{
  // Device / transport auth — a wrong or rotated `X-Device-Key` fails EVERY
  // call on this app. Phrased as a configuration fault the worker cannot fix
  // themselves, deliberately distinct from the session message below so a
  // misconfigured device never reads as "your shift ended".
  ErrorCode.authInvalidCredentials:
      'إعدادات الجهاز غير صحيحة، يرجى التواصل مع المسؤول.',

  // Auth / session
  ErrorCode.rollWorkerNotAllowed: 'هذا الموظف غير مخوّل للعمل كموظف رولات.',
  ErrorCode.rollWorkerSessionRequired:
      'انتهت الجلسة. يرجى تسجيل الدخول من جديد.',
  // Same worker-facing text as the code above: both end in "log in again".
  // They stay separate enum entries so the logs distinguish an expired session
  // from a client bug that omitted the header.
  ErrorCode.rollOpSessionTokenMissing:
      'انتهت الجلسة. يرجى تسجيل الدخول من جديد.',
  ErrorCode.operatorPinInvalid: 'رمز PIN غير صحيح.',
  ErrorCode.operatorPinLocked:
      'تم قفل الحساب لعدد كبير من المحاولات الخاطئة. يرجى مراجعة المشرف.',
  ErrorCode.operatorLocked:
      'تم قفل الحساب لعدد كبير من المحاولات الخاطئة. يرجى مراجعة المشرف.',

  // Biometric login gate (handoff §10). Verbatim copies of the server
  // `message` — the dialog shows the server's own text when present, these
  // only cover a response that omitted it (and the status long-poll, which
  // reports MAPPING_* without any message).
  ErrorCode.biometricVerificationRequired:
      'يرجى تمرير البصمة على جهاز البصمة ثم إعادة المحاولة.',
  ErrorCode.biometricVerificationExpired:
      'انتهت صلاحية التحقق بالبصمة. يرجى تمرير البصمة مرة أخرى ثم إعادة المحاولة.',
  ErrorCode.biometricDeviceUnavailable:
      'جهاز البصمة غير متصل حاليًا. يرجى المحاولة بعد قليل أو إبلاغ المسؤول.',
  ErrorCode.biometricMappingMissing:
      'لم يتم ربط بصمتك بحسابك بعد. يرجى مراجعة مسؤول النظام.',
  ErrorCode.biometricMappingDisabled:
      'ربط البصمة الخاص بحسابك غير مفعّل. يرجى مراجعة مسؤول النظام.',
  ErrorCode.biometricLoginAttemptExpired:
      'انتهت مهلة محاولة الدخول. يرجى تسجيل الدخول مرة أخرى.',

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

  // Machine state (LINE_3 handoff §4.3)
  ErrorCode.thermoformingLineNotFound: 'الخط غير موجود. يرجى تحديث الشاشة.',
  ErrorCode.thermoformingLinePaused:
      'هذا الخط متوقف مؤقتاً من الإدارة. حاول لاحقاً.',

  // Shift-line state
  ErrorCode.thermoformingShiftLineNotFound:
      'الخط غير موجود. يرجى تحديث الشاشة.',
  ErrorCode.thermoformingShiftLineNotActive:
      'هذا الخط لم يعد نشطاً. يرجى تحديث الشاشة.',
  ErrorCode.noCurrentProductOnLine:
      'لا يوجد منتج محدد حالياً على خط الطبليات المرتبط. حدد المنتج قبل تحميل الرول.',
  ErrorCode.productionPlanItemRequired:
      'لا يوجد منتج نشط على هذا الخط. يرجى مراجعة المشرف لإضافة عنصر إلى خطة الإنتاج.',
  ErrorCode.shiftLineAlreadyHasActiveRoll:
      'يوجد رول مركّب حالياً على هذا الخط. أنزِل الرول الحالي قبل تركيب رول جديد.',
  ErrorCode.multipleActiveMountedRollsOnLine:
      'يوجد أكثر من رول مركّب مسجّل على هذا الخط. يرجى مراجعة المشرف.',

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
  ErrorCode.rollGrindingApprovalPending:
      'هذا الرول بانتظار قرار المدير على توصية الجرش ولا يمكن تركيبه الآن.',
  ErrorCode.rollScrapReservedForGrinding:
      'هذا رول جرش مخصّص للجرش المباشر ولا يمكن تركيبه على الخط.',
  ErrorCode.noActiveRollOnLine: 'لا يوجد رول مركب حالياً على هذا الخط.',
  ErrorCode.noOpenSegmentOnItem:
      'خطأ داخلي في حالة الرول. يرجى تحديث الشاشة وإعادة المحاولة.',
  // Admin-cancelled roll (V127). The scan flow shows a dedicated dialog built
  // from `details`; this is the inline/fallback phrasing.
  ErrorCode.rollAdminCancelled:
      'تم إلغاء هذا الرول من الإدارة ولا يمكن تركيبه.',
  // Reconciled out of physical inventory (V132). The scan flow shows a
  // dedicated dialog; this is the inline/fallback phrasing.
  ErrorCode.rollReconciledOutOfStock:
      'تمت تسوية هذا الرول مخزونياً ولا يمكن تركيبه.',

  // Weight inputs (handoff §7.2)
  ErrorCode.invalidRemainingRollWeight:
      'الوزن المتبقي غير صالح. يجب أن يكون بين صفر ووزن الرول الحالي.',
  ErrorCode.currentRollWeightRequired:
      'وزن الرول الحالي مطلوب قبل تغيير المنتج.',
  ErrorCode.invalidCurrentRollWeight:
      'وزن الرول الحالي غير صالح. يجب أن يكون صفراً أو موجباً ولا يتجاوز وزن بداية الجزء.',

  // Previous-roll close reasons (V127 — reason is now required server-side).
  ErrorCode.rollReturnReasonRequired: 'سبب إرجاع المتبقي مطلوب.',
  ErrorCode.rollGrindingReasonRequired: 'سبب التوصية بالجرش مطلوب.',

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

  // «بحث بوقت الإنتاج» — generic phrasing; [arabicMessageFor] names the
  // field from `details` when the backend supplied it.
  ErrorCode.rollProductionTimeInvalid:
      'وقت الإنتاج المُدخل غير صحيح. تأكد من التاريخ والوقت على الملصق.',

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
///
/// A [BiometricDenialFailure] is the one place the server's own `message` is
/// shown: the biometric handoff §5 requires it verbatim for every 403 code.
String arabicMessageFor(AppFailure failure) {
  return switch (failure) {
    NetworkFailure() => noConnectionArabic,
    BiometricDenialFailure(:final BiometricDenial denial) => denial.message,
    BusinessFailure(:final ErrorCode code, :final Map<String, Object?>? details)
        when code == ErrorCode.rollWorkerSessionLineUsedByOtherWorker =>
      _ownerOperatorMessage(details),
    BusinessFailure(:final ErrorCode code, :final Map<String, Object?>? details)
        when code == ErrorCode.rollProductionTimeInvalid =>
      _productionTimeMessage(details),
    BusinessFailure(:final ErrorCode code) => arabicForErrorCode(code),
    ServerFailure() => genericRetryArabic,
    UnknownFailure() => genericRetryArabic,
  };
}

/// Arabic text for `ROLL_PRODUCTION_TIME_INVALID`, built from
/// `details.field` / `details.reason`. Falls back to the generic phrasing for
/// any value it does not know.
String _productionTimeMessage(Map<String, Object?>? details) {
  final Object? reason = details?['reason'];
  if (reason == 'NONEXISTENT_LOCAL_TIME') {
    return 'هذا الوقت غير موجود في توقيت المصنع بسبب تغيير الساعة (التوقيت الصيفي). تأكد من الساعة على الملصق.';
  }
  if (reason == 'INVALID_DATE') {
    return 'هذا التاريخ غير موجود. تأكد من اليوم والشهر على الملصق.';
  }
  final String? field = switch (details?['field']) {
    'year' => 'السنة',
    'month' => 'الشهر',
    'day' => 'اليوم',
    'hour' => 'الساعة',
    'minute' => 'الدقيقة',
    _ => null,
  };
  if (field != null) {
    return reason == 'REQUIRED' ? 'أدخل $field.' : 'قيمة $field غير صحيحة.';
  }
  return arabicForErrorCode(ErrorCode.rollProductionTimeInvalid);
}

String _ownerOperatorMessage(Map<String, Object?>? details) {
  final Object? owner = details?['ownerOperatorName'];
  if (owner is String && owner.trim().isNotEmpty) {
    return 'أحد الخطوط مستخدم بالفعل من قبل الموظف: ${owner.trim()}.';
  }
  return arabicForErrorCode(ErrorCode.rollWorkerSessionLineUsedByOtherWorker);
}
