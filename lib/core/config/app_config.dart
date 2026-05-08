/// Build-time application configuration.
///
/// Values are populated via `--dart-define` at build / run time:
/// - `API_BASE_URL` — backend root, e.g. `https://api.taleeb.ps`.
/// - `DEVICE_KEY`   — shared device API key (transport secret).
///
/// There is no worker-facing settings screen for these values. Both must be
/// provided at build time; otherwise the app blocks all network activity and
/// shows a fatal Arabic message ([missingConfigMessage]).
class AppConfig {
  const AppConfig({required this.apiBaseUrl, required this.deviceKey});

  /// Reads the build-time configuration. Both values default to empty strings
  /// when unset so [isMissing] / [isComplete] can detect that.
  factory AppConfig.fromEnvironment() => const AppConfig(
    apiBaseUrl: String.fromEnvironment('API_BASE_URL'),
    deviceKey: String.fromEnvironment('DEVICE_KEY'),
  );

  final String apiBaseUrl;
  final String deviceKey;

  bool get isComplete => apiBaseUrl.isNotEmpty && deviceKey.isNotEmpty;
  bool get isMissing => !isComplete;

  static const String missingConfigMessage =
      'إعدادات التطبيق غير مكتملة، يرجى التواصل مع المسؤول';

  /// Safe debug-only representation. Never includes [deviceKey].
  @override
  String toString() =>
      'AppConfig(apiBaseUrl: '
      '${apiBaseUrl.isEmpty ? '<missing>' : apiBaseUrl}, '
      'deviceKey: ${deviceKey.isEmpty ? '<missing>' : '<redacted>'})';
}
