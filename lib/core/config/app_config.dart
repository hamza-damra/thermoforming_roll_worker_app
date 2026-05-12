import 'package:flutter/foundation.dart';

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
  ///
  /// In **debug** builds, missing values fall back to local dev defaults so
  /// devs don't need `--dart-define` every run. In profile and release
  /// builds the empty values surface as a fatal-config screen — fail closed.
  factory AppConfig.fromEnvironment() {
    const String envBaseUrl = String.fromEnvironment('API_BASE_URL');
    const String envDeviceKey = String.fromEnvironment('DEVICE_KEY');
    if (kDebugMode) {
      return AppConfig(
        apiBaseUrl: envBaseUrl.isEmpty ? _debugBaseUrl : envBaseUrl,
        deviceKey: envDeviceKey.isEmpty ? _debugDeviceKey : envDeviceKey,
      );
    }
    return const AppConfig(apiBaseUrl: envBaseUrl, deviceKey: envDeviceKey);
  }

  // Debug-only defaults. The kDebugMode branch above means these are never
  // referenced in profile/release, so tree-shaking strips them from
  // production binaries.
  static const String _debugBaseUrl = 'http://taleeb.ddns.net:8080';
  static const String _debugDeviceKey = 'taleeb-device-key-2025-default';

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
