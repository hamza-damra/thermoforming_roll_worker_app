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
/// single configured instance — REST and SSE share it.
class ApiClientFactory {
  ApiClientFactory._();

  /// Default timeouts. Tuned for production-floor networks (slow LTE, busy
  /// switches). Aligned with the Operator app config pattern.
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 30);

  static Dio create(AppConfig config) {
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

    dio.interceptors
      ..add(DeviceKeyInterceptor(config.deviceKey))
      ..add(SessionTokenInterceptor())
      ..add(RedactingLoggerInterceptor(enabled: kDebugMode));

    return dio;
  }
}
