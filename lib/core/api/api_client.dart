import 'dart:io' show HttpClient, X509Certificate;

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import 'device_key_interceptor.dart';
import 'redacting_logger_interceptor.dart';
import 'session_token_interceptor.dart';

/// Builds the singleton [Dio] used for every Roll Worker app HTTP call.
///
/// - Adds the `X-Device-Key` header on every request.
/// - Adds the `X-Session-Token` header only on requests tagged via
///   [SessionTokenInterceptor.attach] (roll-operation endpoints).
/// - Logs request/response metadata in debug builds with secrets redacted.
/// - When [AppConfig.allowStagingSelfSignedCert] is true (staging/debug
///   only), accepts self-signed certificates ONLY for the configured
///   staging hosts. Production hosts are never covered.
///
/// Exposed through `api_providers.dart` so the rest of the app gets a
/// single configured instance — REST and SSE share it. The one exception is
/// the unauthenticated biometric attempt-status long-poll, which gets its own
/// client from [createBiometricStatus].
class ApiClientFactory {
  ApiClientFactory._();

  /// Default timeouts. Tuned for production-floor networks (slow LTE, busy
  /// switches). Aligned with the Operator app config pattern.
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 30);

  /// Receive timeout for the biometric attempt-status long-poll. The server
  /// holds each request up to 25 s; the handoff asks for at least 35 s so a
  /// held request is never cut off client-side.
  static const Duration biometricStatusReceiveTimeout = Duration(seconds: 40);

  static Dio create(AppConfig config) {
    final Dio dio = _base(config, receiveTimeout: receiveTimeout);
    dio.interceptors
      ..add(DeviceKeyInterceptor(config.deviceKey))
      ..add(SessionTokenInterceptor())
      ..add(RedactingLoggerInterceptor(enabled: kDebugMode));
    return dio;
  }

  /// A second client for `GET /api/v1/auth/biometric/login-attempts/status`
  /// only. Same base URL (the handoff resolves `details.statusPath` against
  /// the login's base URL) and TLS policy, but that endpoint is
  /// unauthenticated: it must carry neither `X-Device-Key` nor a session
  /// token, so neither interceptor is installed. The attempt token travels in
  /// a per-request header that the logger redacts.
  static Dio createBiometricStatus(AppConfig config) {
    final Dio dio = _base(config, receiveTimeout: biometricStatusReceiveTimeout);
    dio.interceptors.add(RedactingLoggerInterceptor(enabled: kDebugMode));
    return dio;
  }

  static Dio _base(AppConfig config, {required Duration receiveTimeout}) {
    if (config.isMissing) {
      throw StateError(
        'ApiClientFactory.create called with missing config. '
        'The router must surface MissingConfigScreen before any API call.',
      );
    }

    final Dio dio = Dio(
      BaseOptions(
        baseUrl: config.apiBaseUrl,
        connectTimeout: connectTimeout,
        receiveTimeout: receiveTimeout,
        sendTimeout: sendTimeout,
        responseType: ResponseType.json,
        contentType: 'application/json',
        headers: <String, String>{'Accept': 'application/json'},
      ),
    );

    if (config.allowStagingSelfSignedCert) {
      dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          final HttpClient client = HttpClient()
            ..badCertificateCallback = (X509Certificate cert, String host,
                    int port) =>
                AppConfig.stagingTlsHosts.contains(host);
          return client;
        },
      );
    }

    return dio;
  }
}
