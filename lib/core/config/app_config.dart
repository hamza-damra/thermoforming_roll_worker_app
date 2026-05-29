import 'package:flutter/foundation.dart';

/// Build-time environment selector.
///
/// `--dart-define=APP_ENV=production|staging|debug`. When unset, the app
/// defaults to **staging** so the testing APK boots straight into the
/// staging backend without any dart-defines. Production builds MUST pass
/// `APP_ENV=production` explicitly — see
/// `scripts/build_production_arm64_release.ps1`.
enum AppEnvironment {
  production,
  staging,
  debug;

  static AppEnvironment fromName(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'production':
      case 'prod':
        return AppEnvironment.production;
      case 'staging':
      case 'stage':
        return AppEnvironment.staging;
      case 'debug':
      case 'dev':
        return AppEnvironment.debug;
      default:
        // Default-to-staging: the testing branch never wants to talk to
        // production by accident, and `MissingConfigScreen` must not
        // appear just because dart-defines were forgotten. Production
        // builds are required to set APP_ENV explicitly.
        return AppEnvironment.staging;
    }
  }

  bool get isProduction => this == AppEnvironment.production;
  bool get isStaging => this == AppEnvironment.staging;
  bool get isDebug => this == AppEnvironment.debug;
}

/// Build-time application configuration.
///
/// Values are populated via `--dart-define`:
/// - `APP_ENV`                          — `production` | `staging` | `debug`
///                                        (defaults to `staging` when unset).
/// - `API_BASE_URL`                     — backend root (defaults per env).
/// - `DEVICE_KEY`                       — shared device API key
///                                        (defaults to a safe testing key).
/// - `ALLOW_STAGING_SELF_SIGNED_CERT`   — `true` | `false`
///                                        (defaults true on staging/debug,
///                                        always false on production).
///
/// Production-safety guard: constructing an [AppConfig] with
/// `environment == production` AND a baseUrl host in [stagingTlsHosts]
/// throws [StateError] at startup — production builds cannot accidentally
/// point at the staging host.
class AppConfig {
  AppConfig({
    required this.apiBaseUrl,
    required this.deviceKey,
    this.environment = AppEnvironment.production,
    String? rawAllowStagingSelfSignedCert,
  }) : _rawAllowStagingSelfSignedCert =
            (rawAllowStagingSelfSignedCert ?? '').trim().toLowerCase() {
    _assertProductionDoesNotPointAtStagingHost();
  }

  /// Reads the build-time configuration. When dart-defines are missing,
  /// safe staging defaults are filled in so the app always boots into a
  /// usable state on this testing branch.
  factory AppConfig.fromEnvironment() {
    const String envName = String.fromEnvironment('APP_ENV');
    const String envBaseUrl = String.fromEnvironment('API_BASE_URL');
    const String envDeviceKey = String.fromEnvironment(
      'DEVICE_KEY',
      defaultValue: defaultDeviceKey,
    );
    const String envAllowSelfSigned = String.fromEnvironment(
      'ALLOW_STAGING_SELF_SIGNED_CERT',
    );

    final AppEnvironment env = AppEnvironment.fromName(envName);

    String baseUrl = envBaseUrl;
    if (baseUrl.isEmpty) {
      switch (env) {
        case AppEnvironment.production:
          baseUrl = productionBaseUrl;
          break;
        case AppEnvironment.staging:
          baseUrl = stagingBaseUrl;
          break;
        case AppEnvironment.debug:
          baseUrl = debugBaseUrl;
          break;
      }
    }

    // Belt-and-suspenders: even if the dart-define was passed as the empty
    // string at build time, fall back to the bundled testing key so the
    // app never lands on MissingConfigScreen for a missing device key.
    final String deviceKey =
        envDeviceKey.isEmpty ? defaultDeviceKey : envDeviceKey;

    return AppConfig(
      environment: env,
      apiBaseUrl: baseUrl,
      deviceKey: deviceKey,
      rawAllowStagingSelfSignedCert: envAllowSelfSigned,
    );
  }

  /// Production backend root. Must never be paired with cert overrides.
  static const String productionBaseUrl = 'https://taleeb.me';

  /// Staging backend root (self-signed TLS).
  static const String stagingBaseUrl = 'https://138.68.66.215';

  /// Debug backend root (local DDNS, plain HTTP).
  static const String debugBaseUrl = 'http://hamzadamra.ddns.net:8080';

  /// Shared testing device key. Safe to bake in: this key is the same
  /// value the device-key interceptor expects on the staging backend and
  /// the production backend rotates a separate value via build script.
  static const String defaultDeviceKey = 'taleeb-device-key-2025-default';

  /// Hosts where a self-signed certificate may be honoured. Production
  /// hosts must NOT appear in this list.
  static const List<String> stagingTlsHosts = <String>[
    '138.68.66.215',
    'taleeb-staging.local',
  ];

  final AppEnvironment environment;
  final String apiBaseUrl;
  final String deviceKey;

  /// Raw lowercased value of `ALLOW_STAGING_SELF_SIGNED_CERT`.
  /// Empty string ⇒ "not provided".
  final String _rawAllowStagingSelfSignedCert;

  bool get isConfigured => apiBaseUrl.isNotEmpty && deviceKey.isNotEmpty;

  /// Legacy aliases retained so older call sites keep compiling.
  bool get isComplete => isConfigured;
  bool get isMissing => !isConfigured;

  bool get isProduction => environment.isProduction;
  bool get isStaging => environment.isStaging;
  bool get isDebugEnv => environment.isDebug;

  /// Effective self-signed cert allowance.
  ///
  /// `true` only when ALL hold:
  ///   - environment is `staging` or `debug` (NEVER production),
  ///   - baseUrl host is in [stagingTlsHosts],
  ///   - the raw flag is not explicitly `false`.
  ///
  /// Defaults to allowed on staging/debug + known staging host; explicit
  /// `false` always wins.
  bool get allowStagingSelfSignedCert {
    if (isProduction) return false;
    final String? host = Uri.tryParse(apiBaseUrl)?.host;
    if (host == null || host.isEmpty) return false;
    if (!stagingTlsHosts.contains(host)) return false;
    if (_rawAllowStagingSelfSignedCert == 'false') return false;
    return isStaging || isDebugEnv;
  }

  static const String missingConfigMessage =
      'إعدادات التطبيق غير مكتملة، يرجى التواصل مع المسؤول';

  /// Safe debug representation — never includes [deviceKey] or any other
  /// secret. Suitable for the startup banner.
  @override
  String toString() =>
      'AppConfig('
      'env: ${environment.name}, '
      'apiBaseUrl: ${apiBaseUrl.isEmpty ? '<missing>' : apiBaseUrl}, '
      'deviceKey: ${deviceKey.isEmpty ? '<missing>' : '<redacted>'}, '
      'allowStagingSelfSignedCert: $allowStagingSelfSignedCert, '
      'isConfigured: $isConfigured)';

  void _assertProductionDoesNotPointAtStagingHost() {
    if (!environment.isProduction) return;
    final String? host = Uri.tryParse(apiBaseUrl)?.host;
    if (host == null) return;
    if (stagingTlsHosts.contains(host)) {
      throw StateError(
        'AppConfig refused to start: APP_ENV=production must not point at '
        'staging host "$host". Production baseUrl must be '
        '$productionBaseUrl (or another real production URL).',
      );
    }
  }
}

/// Compile-time `kDebugMode` re-export so callers don't need a flutter
/// import just to ask "are we in a Flutter debug binary?". Distinct from
/// `AppEnvironment.debug`, which is a build-time flag.
bool get isFlutterDebugMode => kDebugMode;
