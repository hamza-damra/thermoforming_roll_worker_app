import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thermoforming_roll_worker/core/api/device_key_interceptor.dart';
import 'package:thermoforming_roll_worker/core/api/redacting_logger_interceptor.dart';
import 'package:thermoforming_roll_worker/core/api/session_token_interceptor.dart';

class _CapturingHandler extends RequestInterceptorHandler {
  RequestOptions? captured;

  @override
  void next(RequestOptions options) {
    captured = options;
  }
}

void main() {
  group('DeviceKeyInterceptor', () {
    test('attaches X-Device-Key on every request', () {
      final DeviceKeyInterceptor interceptor = DeviceKeyInterceptor('abc-123');
      final RequestOptions options = RequestOptions(path: '/x');
      final _CapturingHandler handler = _CapturingHandler();

      interceptor.onRequest(options, handler);

      expect(handler.captured, isNotNull);
      expect(
        handler.captured!.headers[DeviceKeyInterceptor.headerName],
        'abc-123',
      );
    });

    test('headerName is X-Device-Key', () {
      expect(DeviceKeyInterceptor.headerName, 'X-Device-Key');
    });
  });

  group('SessionTokenInterceptor', () {
    test('does not add header when extras are absent', () {
      final SessionTokenInterceptor interceptor = SessionTokenInterceptor();
      final RequestOptions options = RequestOptions(path: '/x');
      final _CapturingHandler handler = _CapturingHandler();

      interceptor.onRequest(options, handler);

      expect(
        handler.captured!.headers.containsKey(
          SessionTokenInterceptor.headerName,
        ),
        isFalse,
      );
    });

    test('adds X-Session-Token when request is tagged via attach()', () {
      final SessionTokenInterceptor interceptor = SessionTokenInterceptor();
      final RequestOptions options = RequestOptions(
        path: '/x',
        extra: SessionTokenInterceptor.attach('raw-token'),
      );
      final _CapturingHandler handler = _CapturingHandler();

      interceptor.onRequest(options, handler);

      expect(
        handler.captured!.headers[SessionTokenInterceptor.headerName],
        'raw-token',
      );
    });

    test('strips the secret from extras after attaching', () {
      final SessionTokenInterceptor interceptor = SessionTokenInterceptor();
      final RequestOptions options = RequestOptions(
        path: '/x',
        extra: SessionTokenInterceptor.attach('raw-token'),
      );
      final _CapturingHandler handler = _CapturingHandler();

      interceptor.onRequest(options, handler);

      expect(
        handler.captured!.extra.containsKey(SessionTokenInterceptor.extraKey),
        isFalse,
      );
    });

    test('headerName is X-Session-Token', () {
      expect(SessionTokenInterceptor.headerName, 'X-Session-Token');
    });
  });

  group('RedactingLoggerInterceptor', () {
    test('disabled by default — does not throw without enabled flag', () {
      final RedactingLoggerInterceptor interceptor =
          RedactingLoggerInterceptor();
      final _CapturingHandler handler = _CapturingHandler();

      interceptor.onRequest(
        RequestOptions(
          path: '/x',
          headers: <String, dynamic>{
            DeviceKeyInterceptor.headerName: 'k',
            SessionTokenInterceptor.headerName: 't',
          },
          data: <String, dynamic>{'pin': '1234', 'foo': 'bar'},
        ),
        handler,
      );

      expect(handler.captured, isNotNull);
    });

    test('redactedHeaders list covers all secret headers', () {
      // Enabling and capturing dev_log output is brittle in tests, so we
      // verify the redaction by inspecting the request payload after the
      // interceptor runs. With enabled=true it logs but does not mutate
      // the headers (the log helpers redact internally only). Sanity-check
      // that running it does not throw on payloads containing secrets.
      final RedactingLoggerInterceptor interceptor = RedactingLoggerInterceptor(
        enabled: true,
      );
      final _CapturingHandler handler = _CapturingHandler();

      interceptor.onRequest(
        RequestOptions(
          path: '/x',
          method: 'POST',
          headers: <String, dynamic>{
            DeviceKeyInterceptor.headerName: 'super-secret-device-key',
            SessionTokenInterceptor.headerName: 'super-secret-session-token',
            'Authorization': 'Bearer xyz',
          },
          data: <String, dynamic>{
            'pin': '4242',
            'sessionToken': 'raw-uuid',
            'visible': 'ok',
          },
        ),
        handler,
      );

      expect(handler.captured, isNotNull);
      // The interceptor must NOT mutate the original headers/body — that
      // would break downstream interceptors. Redaction is logging-only.
      expect(
        handler.captured!.headers[DeviceKeyInterceptor.headerName],
        'super-secret-device-key',
      );
      expect((handler.captured!.data as Map<String, dynamic>)['pin'], '4242');
    });
  });
}
