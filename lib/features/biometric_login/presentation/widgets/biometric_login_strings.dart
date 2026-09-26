/// Dialog chrome for the fingerprint login gate (biometric handoff §10).
///
/// These cover only the states the server does not word. Every 403 shows the
/// server's own `message` verbatim instead.
class BiometricLoginStrings {
  BiometricLoginStrings._();

  static const String title = 'التحقق بالبصمة';
  static const String waiting = 'مرّر إصبعك على جهاز البصمة';
  static const String waitingSecondary =
      'سيكتمل تسجيل الدخول تلقائيًا بعد التحقق';
  static const String verifying = 'جارٍ تسجيل الدخول…';
  static const String deviceOffline =
      'جهاز البصمة غير متصل حاليًا. انتظر قليلًا أو أبلغ المسؤول.';
  static const String retry = 'انتهت مهلة المحاولة. مرّر البصمة ثم أعد المحاولة.';
  static const String network = 'تعذّر الاتصال بالخادم، جارٍ إعادة المحاولة…';

  static const String cancelButton = 'إلغاء';
  static const String retryButton = 'إعادة المحاولة';
  static const String okButton = 'حسنًا';
}
