import 'app_failure.dart';
import 'error_code.dart';

/// Arabic UI strings for every backend [ErrorCode] documented in
/// `THERMOFORMING_ROLL_WORKER_APP_FRONTEND_REQUIREMENTS.md` §17.
const Map<ErrorCode, String> _arabicByCode = <ErrorCode, String>{
  // Auth / session
  ErrorCode.rollWorkerNotAllowed: 'هذا المشغّل غير مفعّل لتطبيق عامل الرولات.',
  ErrorCode.rollWorkerSessionRequired:
      'انتهت الجلسة، يُرجى تسجيل الدخول مجددًا.',
  ErrorCode.operatorPinInvalid: 'رقم تعريف غير صحيح.',
  ErrorCode.operatorPinLocked:
      'تم قفل رقم التعريف بسبب محاولات خاطئة، حاول لاحقًا.',
  ErrorCode.operatorLocked:
      'تم قفل رقم التعريف بسبب محاولات خاطئة، حاول لاحقًا.',

  // Multi-line batch session-start
  ErrorCode.rollWorkerSessionBatchEmpty: 'اختر خطًا واحدًا على الأقل.',
  ErrorCode.rollWorkerSessionLineDuplicate: 'تم تكرار خط في الطلب.',
  ErrorCode.rollWorkerSessionLineInactive:
      'أحد الخطوط لم يعد نشطًا، حدّث القائمة.',
  ErrorCode.rollWorkerSessionLineUsedByOtherWorker:
      'أحد الخطوط قيد الاستخدام من قبل عامل آخر.',

  // Shift-line state
  ErrorCode.thermoformingShiftLineNotFound:
      'تخصيص مناوبة خط التشكيل الحراري غير موجود.',
  ErrorCode.thermoformingShiftLineNotActive:
      'تخصيص مناوبة خط التشكيل الحراري غير نشط.',
  ErrorCode.noCurrentProductOnLine:
      'لا يوجد منتج محدد حالياً على خط الطبليات المرتبط. حدد المنتج قبل تحميل الرول.',

  // Roll lifecycle
  ErrorCode.rollNotFound: 'الرول غير موجود.',
  ErrorCode.rollAlreadyConsumed:
      'تم استهلاك هذا الرول بالفعل ولا يمكن تحميله مرة أخرى.',
  ErrorCode.rollActiveOnAnotherLine:
      'هذا الرول مُحمَّل بالفعل على خط تشكيل حراري آخر.',
  ErrorCode.rollBlocked: 'هذا الرول محظور ولا يمكن استخدامه.',
  ErrorCode.rollTypeNotAllowedForProduct: 'نوع الرول غير مسموح لهذا المنتج.',
  ErrorCode.noActiveRollOnLine: 'لا يوجد رول مُحمَّل حالياً على هذا الخط.',
  ErrorCode.noOpenSegmentOnItem: 'حدث خطأ تقني، يُرجى التواصل مع الدعم.',

  // Weight inputs
  ErrorCode.invalidRemainingRollWeight:
      'الوزن المتبقي غير صالح. يجب أن يكون صفراً أو موجباً ولا يتجاوز وزن بداية الجزء.',
  ErrorCode.currentRollWeightRequired:
      'وزن الرول الحالي مطلوب قبل تغيير المنتج.',
  ErrorCode.invalidCurrentRollWeight:
      'وزن الرول الحالي غير صالح. يجب أن يكون صفراً أو موجباً ولا يتجاوز وزن بداية الجزء.',

  // Product switch
  ErrorCode.productTypeNotFound: 'لم يتم العثور على المنتج المطلوب.',
  ErrorCode.productTypeInactive: 'هذا المنتج غير نشط.',

  // Reprint
  ErrorCode.rollLabelReprintNotAvailable:
      'إعادة طباعة ملصق الرول متاحة فقط بعد الإرجاع الجزئي أو إغلاق الجرش.',

  // Generic
  ErrorCode.validationError: 'حدث خطأ، حاول مرة أخرى.',
};

/// Generic Arabic fallback for unknown / unmapped errors.
const String genericRetryArabic = 'حدث خطأ، حاول مرة أخرى.';

/// Connectivity banner string (also used for [NetworkFailure]).
const String noConnectionArabic =
    'لا يوجد اتصال بالخادم، سيتم إعادة المحاولة تلقائيًا';

/// Returns the Arabic message for an [ErrorCode], or the generic retry text
/// for [ErrorCode.unknown] / unmapped codes.
String arabicForErrorCode(ErrorCode code) =>
    _arabicByCode[code] ?? genericRetryArabic;

/// Maps any [AppFailure] to a user-facing Arabic message.
String arabicMessageFor(AppFailure failure) {
  return switch (failure) {
    NetworkFailure() => noConnectionArabic,
    BusinessFailure(:final ErrorCode code) => arabicForErrorCode(code),
    ServerFailure() => genericRetryArabic,
    UnknownFailure() => genericRetryArabic,
  };
}
