import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thermoforming_roll_worker/core/api/api_client.dart';
import 'package:thermoforming_roll_worker/core/api/api_paths.dart';
import 'package:thermoforming_roll_worker/core/api/biometric_attempt_token.dart';
import 'package:thermoforming_roll_worker/core/api/device_key_interceptor.dart';
import 'package:thermoforming_roll_worker/core/api/redacting_logger_interceptor.dart';
import 'package:thermoforming_roll_worker/core/api/session_token_interceptor.dart';
import 'package:thermoforming_roll_worker/core/config/app_config.dart';
import 'package:thermoforming_roll_worker/features/biometric_login/data/biometric_attempt_api.dart';
import 'package:thermoforming_roll_worker/features/biometric_login/data/biometric_attempt_repository_impl.dart';
import 'package:thermoforming_roll_worker/features/biometric_login/domain/biometric_attempt_repository.dart';
import 'package:thermoforming_roll_worker/features/biometric_login/domain/entities/biometric_attempt_status.dart';

const String _token = 'q3Jx8d6cYt0H1m0yF3kZ0wS9gQx8B7nV2rP5aL4eK1c';

/// Answers every request with a canned status + JSON body (or throws the
/// given transport error) and records what the real interceptor chain sent.
class _Adapter implements HttpClientAdapter {
  _Adapter({this.statusCode = 200, this.body, this.error});

  final int statusCode;
  final Map<String, dynamic>? body;
  final DioExceptionType? error;
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (error != null) {
      throw DioException(requestOptions: options, type: error!);
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _statusBody(String status) => <String, dynamic>{
  'success': true,
  'data': <String, dynamic>{
    'status': status,
    'attemptExpiresAt': '2026-09-24T08:15:00.000Z',
  },
};

AppConfig _config() => AppConfig(
  apiBaseUrl: 'https://example.test',
  deviceKey: 'device-key-under-test',
  environment: AppEnvironment.debug,
);

({BiometricAttemptRepository repo, _Adapter adapter}) _repo(_Adapter adapter) {
  final Dio dio = ApiClientFactory.createBiometricStatus(_config())
    ..httpClientAdapter = adapter;
  return (
    repo: BiometricAttemptRepositoryImpl(api: BiometricAttemptApi(dio)),
    adapter: adapter,
  );
}

void main() {
  group('the status client (§4.3)', () {
    test('sends ONLY the attempt token — no device key, no session token', () async {
      final (:repo, :adapter) = _repo(_Adapter(body: _statusBody('PENDING')));

      await repo.getStatus(
        statusPath: '/api/v1/auth/biometric/login-attempts/status',
        attemptToken: _token,
      );

      final RequestOptions sent = adapter.requests.single;
      expect(sent.method, 'GET');
      expect(sent.path, ApiPaths.biometricLoginAttemptStatus);
      expect(sent.headers[BiometricAttemptToken.headerName], _token);
      expect(sent.headers.containsKey(DeviceKeyInterceptor.headerName), isFalse);
      expect(
        sent.headers.containsKey(SessionTokenInterceptor.headerName),
        isFalse,
      );
      expect(sent.headers.containsKey('Authorization'), isFalse);
      // Never in the URL.
      expect(sent.uri.toString(), isNot(contains(_token)));
    });

    test('receive timeout is at least 35 s (server holds up to 25 s)', () {
      final Dio dio = ApiClientFactory.createBiometricStatus(_config());
      expect(
        dio.options.receiveTimeout,
        greaterThanOrEqualTo(const Duration(seconds: 35)),
      );
      expect(dio.options.baseUrl, 'https://example.test');
    });

    test('the regular client still carries the device key', () {
      final Dio dio = ApiClientFactory.create(_config());
      expect(
        dio.interceptors.whereType<DeviceKeyInterceptor>(),
        isNotEmpty,
      );
      final Dio status = ApiClientFactory.createBiometricStatus(_config());
      expect(status.interceptors.whereType<DeviceKeyInterceptor>(), isEmpty);
      expect(status.interceptors.whereType<SessionTokenInterceptor>(), isEmpty);
    });

    test('follows details.statusPath when it is a same-origin path', () async {
      final (:repo, :adapter) = _repo(_Adapter(body: _statusBody('PENDING')));
      await repo.getStatus(statusPath: '/api/v2/other/status', attemptToken: _token);
      expect(adapter.requests.single.path, '/api/v2/other/status');
    });

    test('never sends the token off-origin: unsafe statusPath → documented path', () {
      for (final String? unsafe in <String?>[
        null,
        '',
        'https://evil.test/steal',
        '//evil.test/steal',
        'relative/path',
      ]) {
        expect(
          BiometricAttemptApi.resolveStatusPath(unsafe),
          ApiPaths.biometricLoginAttemptStatus,
          reason: '$unsafe',
        );
      }
    });
  });

  group('status mapping', () {
    const Map<String, BiometricAttemptStatus> wire =
        <String, BiometricAttemptStatus>{
          'PENDING': BiometricAttemptStatus.pending,
          'VERIFIED': BiometricAttemptStatus.verified,
          'ENFORCEMENT_SUSPENDED': BiometricAttemptStatus.enforcementSuspended,
          'NOT_REQUIRED': BiometricAttemptStatus.notRequired,
          'DEVICE_UNAVAILABLE': BiometricAttemptStatus.deviceUnavailable,
          'MAPPING_MISSING': BiometricAttemptStatus.mappingMissing,
          'MAPPING_DISABLED': BiometricAttemptStatus.mappingDisabled,
          'SOMETHING_FROM_THE_FUTURE': BiometricAttemptStatus.pending,
        };
    wire.forEach((String raw, BiometricAttemptStatus expected) {
      test('200 $raw → $expected', () async {
        final (:repo, adapter: _) = _repo(_Adapter(body: _statusBody(raw)));
        final BiometricStatusResult result = await repo.getStatus(
          statusPath: null,
          attemptToken: _token,
        );
        expect(result, isA<BiometricStatusAnswered>());
        final BiometricAttemptStatusResponse response =
            (result as BiometricStatusAnswered).response;
        expect(response.status, expected);
        expect(response.attemptExpiresAt, DateTime.utc(2026, 9, 24, 8, 15));
      });
    });

    test('410 BIOMETRIC_LOGIN_ATTEMPT_EXPIRED → attempt expired', () async {
      final (:repo, adapter: _) = _repo(
        _Adapter(
          statusCode: 410,
          body: <String, dynamic>{
            'success': false,
            'error': <String, dynamic>{
              'code': 'BIOMETRIC_LOGIN_ATTEMPT_EXPIRED',
              'message': 'انتهت مهلة محاولة الدخول. يرجى تسجيل الدخول مرة أخرى.',
            },
          },
        ),
      );
      expect(
        await repo.getStatus(statusPath: null, attemptToken: _token),
        isA<BiometricStatusAttemptExpired>(),
      );
    });

    test('a bare 410 without our envelope still ends the attempt', () async {
      final (:repo, adapter: _) = _repo(
        _Adapter(statusCode: 410, body: <String, dynamic>{'x': 1}),
      );
      expect(
        await repo.getStatus(statusPath: null, attemptToken: _token),
        isA<BiometricStatusAttemptExpired>(),
      );
    });

    test('timeout / no connection / 5xx → unreachable (back off)', () async {
      for (final _Adapter adapter in <_Adapter>[
        _Adapter(error: DioExceptionType.receiveTimeout),
        _Adapter(error: DioExceptionType.connectionError),
        _Adapter(statusCode: 503, body: <String, dynamic>{'x': 1}),
      ]) {
        final (:repo, adapter: _) = _repo(adapter);
        expect(
          await repo.getStatus(statusPath: null, attemptToken: _token),
          isA<BiometricStatusUnreachable>(),
        );
      }
    });
  });

  group('RedactingLoggerInterceptor', () {
    test('the attempt token never reaches the log sink', () async {
      final List<String> sink = <String>[];
      final Dio dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..interceptors.add(
          RedactingLoggerInterceptor(enabled: true, sink: sink.add),
        )
        ..httpClientAdapter = _Adapter(
          statusCode: 410,
          body: <String, dynamic>{'success': false},
        );

      await expectLater(
        dio.get<dynamic>(
          '/api/v1/auth/biometric/login-attempts/status',
          options: Options(headers: BiometricAttemptToken.header(_token)),
        ),
        throwsA(isA<DioException>()),
      );

      expect(sink, isNotEmpty);
      expect(sink.join('\n'), isNot(contains(_token)));
      expect(sink.join('\n'), contains('<redacted>'));
    });

    test('header redaction is case-insensitive', () async {
      final List<String> sink = <String>[];
      final Dio dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..interceptors.add(
          RedactingLoggerInterceptor(enabled: true, sink: sink.add),
        )
        ..httpClientAdapter = _Adapter(body: _statusBody('PENDING'));

      await dio.get<dynamic>(
        '/x',
        options: Options(
          headers: <String, String>{'x-biometric-attempt-token': _token},
        ),
      );

      expect(sink.join('\n'), isNot(contains(_token)));
    });
  });
}
