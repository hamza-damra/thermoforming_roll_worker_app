/// Typed printing failures with prescribed Arabic display messages.
class PrintingException implements Exception {
  PrintingException({
    required this.code,
    required this.message,
    this.originalError,
  });

  final String code;
  final String message;
  final Object? originalError;

  factory PrintingException.noPrinterSelected() => PrintingException(
    code: 'NO_PRINTER_SELECTED',
    message: 'لم يتم اختيار طابعة',
  );

  factory PrintingException.noPresetSelected() => PrintingException(
    code: 'NO_PRESET_SELECTED',
    message: 'لم يتم اختيار حجم الملصق',
  );

  factory PrintingException.connectionFailed({Object? error}) =>
      PrintingException(
        code: 'CONNECTION_FAILED',
        message: 'فشل الاتصال بالطابعة',
        originalError: error,
      );

  factory PrintingException.connectionTimeout() => PrintingException(
    code: 'CONNECTION_TIMEOUT',
    message: 'انتهت مهلة الاتصال بالطابعة',
  );

  factory PrintingException.sendFailed({Object? error}) => PrintingException(
    code: 'SEND_FAILED',
    message: 'فشل إرسال البيانات للطابعة',
    originalError: error,
  );

  factory PrintingException.renderFailed({Object? error}) => PrintingException(
    code: 'RENDER_FAILED',
    message: 'فشل في إنشاء صورة الباركود',
    originalError: error,
  );

  factory PrintingException.printerNotFound() => PrintingException(
    code: 'PRINTER_NOT_FOUND',
    message: 'الطابعة غير موجودة',
  );

  factory PrintingException.presetNotFound() => PrintingException(
    code: 'PRESET_NOT_FOUND',
    message: 'حجم الملصق غير موجود',
  );

  /// Hard precondition for the new structured layout: the renderer needs a
  /// backend-authoritative roll creation / label timestamp. Surfaces when
  /// none of the available sources (`consumedRoll.labelTimestamp`,
  /// `/reprint-label.createdAt`, close-response `labelTimestamp`) supplied
  /// one. We never substitute device time.
  factory PrintingException.missingLabelTimestamp() => PrintingException(
    code: 'MISSING_LABEL_TIMESTAMP',
    message:
        'تعذّر طباعة الملصق: لم يصل تاريخ الرول من الخادم. الرجاء تحديث '
        'الخادم ليرسل تاريخ الرول قبل الطباعة.',
  );

  String get displayMessage => message;

  @override
  String toString() => 'PrintingException: [$code] $message';
}
