import 'package:dio/dio.dart';
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
///
/// Will be exposed through `apiProviders.dart` so the rest of the app gets
/// a single configured instance.
class ApiClientFactory {
  ApiClientFactory._();

  /// Default timeouts tuned for production-floor networks (slow LTE, busy
  /// switches). Keep modest so the connectivity banner can surface fast.
  static const Duration connectTimeout = Duration(seconds: 8);
  static const Duration receiveTimeout = Duration(seconds: 12);
  static const Duration sendTimeout = Duration(seconds: 12);

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
        // Default validateStatus (2xx → success). 4xx/5xx surface as
        // DioException(type: badResponse) and are routed through
        // ApiErrorParser, which reads the `{success:false, error:{...}}`
        // envelope and produces a BusinessFailure / ServerFailure.
        headers: <String, String>{'Accept': 'application/json'},
      ),
    );

    dio.interceptors
      ..add(DeviceKeyInterceptor(config.deviceKey))
      ..add(SessionTokenInterceptor())
      ..add(RedactingLoggerInterceptor(enabled: kDebugMode));

    return dio;
  }
}
