import 'package:dio/dio.dart';

/// Adds the `X-Device-Key` header to every request.
///
/// `DeviceApiKeyFilter` on the backend rejects (401) any request without it on
/// the `/api/v1/thermoforming-roll-app/**` namespace.
///
/// The header name and value are NEVER logged by [RedactingLoggerInterceptor].
class DeviceKeyInterceptor extends Interceptor {
  DeviceKeyInterceptor(this._deviceKey);

  static const String headerName = 'X-Device-Key';

  final String _deviceKey;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers[headerName] = _deviceKey;
    handler.next(options);
  }
}
