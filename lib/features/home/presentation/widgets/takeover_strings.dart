/// Exact Arabic copy for the Line Takeover feature (spec §9). Kept in one
/// place because the dialog, banner, and blocked card share it.
class TakeoverStrings {
  TakeoverStrings._();

  /// Dialog title and banner heading.
  static const String title = 'طلب استلام الخط';

  /// Dialog / pending-banner body.
  static const String body =
      'الرجاء إخبار المشغّل المناوب الحالي أن المشغّل القادم قام بطلب استلام الخط.';

  /// Acknowledge button label.
  static const String acknowledge = 'حسناً';

  /// Banner body once the request is `ACCEPTED`.
  static const String acceptedBanner =
      'المشغّل الحالي يقوم بإكمال التسليم، الرجاء الانتظار…';

  /// Banner body once the request auto-releases on timeout.
  static const String autoReleasedBanner =
      'انتهت المهلة — بانتظار استلام المشغّل القادم للخط.';

  /// Blocked-work message shown when roll actions are not allowed.
  static const String blockedWork =
      'لا يمكن تنفيذ عمليات الرولات الآن — الخط في وضع تسليم. الرجاء الانتظار حتى يكمل المشغّل استلام الخط.';

  /// Shown when no thermoforming operator currently owns the line — the
  /// Roll Worker app is a passive observer and simply waits.
  static const String noActiveOperator =
      'لا يوجد مشغّل تشكيل على الخط حاليًا. الرجاء الانتظار حتى يستلم مشغّل الخط.';
}
