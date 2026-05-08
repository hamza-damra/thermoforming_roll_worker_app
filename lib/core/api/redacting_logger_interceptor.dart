import 'dart:developer' as developer;

import 'package:dio/dio.dart';

import 'device_key_interceptor.dart';
import 'session_token_interceptor.dart';

/// Lightweight HTTP logger that redacts every secret before printing.
///
/// Headers redacted:
///   - `X-Device-Key`
///   - `X-Session-Token`
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
  RedactingLoggerInterceptor({this.enabled = false});

  /// Toggle by build mode (e.g. `kDebugMode`). Off by default for safety.
  final bool enabled;

  static const String _redacted = '<redacted>';

  static const Set<String> _redactedHeaders = <String>{
    DeviceKeyInterceptor.headerName,
    SessionTokenInterceptor.headerName,
    'Authorization',
    'authorization',
    'Cookie',
    'cookie',
    'Set-Cookie',
    'set-cookie',
  };

  static const Set<String> _redactedBodyFields = <String>{
    'pin',
    'sessionToken',
    'password',
  };

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (enabled) {
      developer.log(
        '→ ${options.method} ${options.uri}\n'
        '  headers: ${_redactHeaders(options.headers)}\n'
        '  body:    ${_redactBody(options.data)}',
        name: 'roll_worker.http',
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
      developer.log(
        '← ${response.statusCode} ${response.requestOptions.uri}',
        name: 'roll_worker.http',
      );
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (enabled) {
      developer.log(
        '✗ ${err.response?.statusCode ?? '-'} ${err.requestOptions.uri} '
        '(${err.type.name})',
        name: 'roll_worker.http',
      );
    }
    handler.next(err);
  }

  static Map<String, Object?> _redactHeaders(Map<String, dynamic> headers) {
    final Map<String, Object?> out = <String, Object?>{};
    headers.forEach((String key, dynamic value) {
      out[key] = _redactedHeaders.contains(key) ? _redacted : value;
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
