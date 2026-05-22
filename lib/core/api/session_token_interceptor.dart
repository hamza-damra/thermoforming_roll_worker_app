import 'package:dio/dio.dart';

/// Adds the `X-Session-Token` header when a request is explicitly tagged with
/// the roll-worker session token via [Options.extra].
///
/// Convention:
/// ```
/// dio.post(
///   path,
///   options: Options(extra: SessionTokenInterceptor.attach(token)),
/// );
/// ```
///
/// Only roll-operation endpoints carry the session token (scan, previous-roll,
/// reprint). Auth (`roll-worker-auth`), session discovery
/// (`roll-worker-session/current`), and logout (token in body) MUST NOT use
/// this — they don't tag the request, so the header is omitted.
///
/// The header value is NEVER logged by [RedactingLoggerInterceptor].
class SessionTokenInterceptor extends Interceptor {
  SessionTokenInterceptor();

  static const String headerName = 'X-Session-Token';
  static const String extraKey = 'roll_worker_session_token';

  /// Returns an `extra` map that this interceptor will recognise.
  static Map<String, dynamic> attach(String token) => <String, dynamic>{
    extraKey: token,
  };

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final Object? value = options.extra[extraKey];
    if (value is String && value.isNotEmpty) {
      options.headers[headerName] = value;
      // Strip the secret from `extra` so it cannot be picked up by other
      // interceptors / loggers downstream.
      options.extra.remove(extraKey);
    }
    handler.next(options);
  }
}
