import 'dart:developer' as developer;

import 'package:dio/dio.dart';

import 'biometric_attempt_token.dart';
import 'device_key_interceptor.dart';
import 'session_token_interceptor.dart';

/// Where [RedactingLoggerInterceptor] writes. Defaults to `dart:developer`'s
/// `log`; tests pass a capturing sink to assert secrets never reach it.
typedef HttpLogSink = void Function(String message);

void _developerLogSink(String message) =>
    developer.log(message, name: 'roll_worker.http');

/// Lightweight HTTP logger that redacts every secret before printing.
///
/// Headers redacted (matched case-insensitively):
///   - `X-Device-Key`
///   - `X-Session-Token`
///   - `X-Biometric-Attempt-Token`
///   - `Authorization`
///   - `Cookie` / `Set-Cookie`
///
/// Body fields redacted (top-level only — payloads of these endpoints don't
/// nest secrets):
///   - `pin`
///   - `sessionToken`
///   - `password`
///
/// Disabled by default; enable in debug builds via the constructor flag.
class RedactingLoggerInterceptor extends Interceptor {
  RedactingLoggerInterceptor({this.enabled = false, HttpLogSink? sink})
    : _sink = sink ?? _developerLogSink;

  /// Toggle by build mode (e.g. `kDebugMode`). Off by default for safety.
  final bool enabled;

  final HttpLogSink _sink;

  static const String _redacted = '<redacted>';

  /// Lower-cased: header names are case-insensitive on the wire.
  static final Set<String> _redactedHeaders = <String>{
    DeviceKeyInterceptor.headerName,
    SessionTokenInterceptor.headerName,
    BiometricAttemptToken.headerName,
    'Authorization',
    'Cookie',
    'Set-Cookie',
  }.map((String h) => h.toLowerCase()).toSet();

  static const Set<String> _redactedBodyFields = <String>{
    'pin',
    'sessionToken',
    'password',
  };

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (enabled) {
      _sink(
        '→ ${options.method} ${options.uri}\n'
        '  headers: ${_redactHeaders(options.headers)}\n'
        '  body:    ${_redactBody(options.data)}',
      );
    }
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    if (enabled) {
      _sink('← ${response.statusCode} ${response.requestOptions.uri}');
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (enabled) {
      _sink(
        '✗ ${err.response?.statusCode ?? '-'} ${err.requestOptions.uri} '
        '(${err.type.name})',
      );
    }
    handler.next(err);
  }

  static Map<String, Object?> _redactHeaders(Map<String, dynamic> headers) {
    final Map<String, Object?> out = <String, Object?>{};
    headers.forEach((String key, dynamic value) {
      out[key] = _redactedHeaders.contains(key.toLowerCase())
          ? _redacted
          : value;
    });
    return out;
  }

  static Object? _redactBody(Object? body) {
    if (body is! Map) return body;
    final Map<String, Object?> out = <String, Object?>{};
    body.forEach((dynamic key, dynamic value) {
      final String k = key?.toString() ?? '';
      out[k] = _redactedBodyFields.contains(k) ? _redacted : value;
    });
    return out;
  }
}
