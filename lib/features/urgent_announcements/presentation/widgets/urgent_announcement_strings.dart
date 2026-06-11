/// Fixed Arabic copy for the sanitized urgent-manager notice.
///
/// PRIVACY: the [title] and [message] are the ONLY content ever rendered for
/// an announcement — they are hard-coded constants, never sourced from the
/// backend payload. The real manager body/sender is never shown.
class UrgentAnnouncementStrings {
  UrgentAnnouncementStrings._();

  static const String title = 'ملاحظة عاجلة من المدير';
  static const String message =
      'أرسل المدير ملاحظة عاجلة للمشغل. يجب فتح تطبيق المشغل لقراءتها.';

  /// Primary (and only) action — acknowledges the notice.
  static const String ackButton = 'فهمت';

  /// Inline error shown when the ack call fails; the worker retries by tapping
  /// [ackButton] again.
  static const String ackError = 'تعذّر تأكيد الاستلام، حاول مرة أخرى';
}
