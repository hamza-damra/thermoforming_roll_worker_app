import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thermoforming_roll_worker/core/api/api_client.dart';
import 'package:thermoforming_roll_worker/core/api/api_paths.dart';
import 'package:thermoforming_roll_worker/core/api/device_key_interceptor.dart';
import 'package:thermoforming_roll_worker/core/api/session_token_interceptor.dart';
import 'package:thermoforming_roll_worker/core/config/app_config.dart';
import 'package:thermoforming_roll_worker/features/shift_line/data/roll_worker_lines_sse_client.dart';
import 'package:thermoforming_roll_worker/features/urgent_announcements/data/urgent_announcements_api.dart';

/// Captures the [RequestOptions] Dio produces *after* the real interceptor
/// chain has run, and answers with a canned success envelope.
///
/// Going through `ApiClientFactory.create` rather than hand-assembling the
/// headers is the point: it proves the wiring the app actually ships with.
class _CapturingAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode(<String, dynamic>{
        'success': true,
        'data': <Object?>[],
        'error': null,
      }),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Same, but answers with an SSE byte stream so the streamed `GET` completes.
class _CapturingSseAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody(
      Stream<Uint8List>.value(
        Uint8List.fromList(utf8.encode('event: connected\ndata: {}\n\n')),
      ),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>['text/event-stream'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio _dio() => ApiClientFactory.create(
  AppConfig(
    apiBaseUrl: 'https://example.test',
    deviceKey: 'device-key-under-test',
    environment: AppEnvironment.debug,
  ),
);

String? _device(RequestOptions r) =>
    r.headers[DeviceKeyInterceptor.headerName] as String?;

String? _session(RequestOptions r) =>
    r.headers[SessionTokenInterceptor.headerName] as String?;

void main() {
  group('announcement endpoints send BOTH auth headers (§4.0 / §14)', () {
    test('GET /urgent-announcements/pending', () async {
      final Dio dio = _dio();
      final _CapturingAdapter adapter = _CapturingAdapter();
      dio.httpClientAdapter = adapter;

      await UrgentAnnouncementsApi(dio).fetchPending(sessionToken: 'sess-1');

      final RequestOptions sent = adapter.requests.single;
      expect(sent.path, ApiPaths.urgentAnnouncementsPending);
      expect(_device(sent), 'device-key-under-test');
      expect(_session(sent), 'sess-1');
    });

    test('POST /urgent-announcements/{id}/ack', () async {
      final Dio dio = _dio();
      final _CapturingAdapter adapter = _CapturingAdapter();
      dio.httpClientAdapter = adapter;

      await UrgentAnnouncementsApi(dio).ack(id: 99, sessionToken: 'sess-2');

      final RequestOptions sent = adapter.requests.single;
      expect(sent.path, ApiPaths.urgentAnnouncementAck(99));
      expect(sent.method, 'POST');
      expect(_device(sent), 'device-key-under-test');
      expect(_session(sent), 'sess-2');
    });

    test('the session token never lingers in `extra` after being attached', () async {
      final Dio dio = _dio();
      final _CapturingAdapter adapter = _CapturingAdapter();
      dio.httpClientAdapter = adapter;

      await UrgentAnnouncementsApi(dio).fetchPending(sessionToken: 'sess-3');

      expect(
        adapter.requests.single.extra.containsKey(
          SessionTokenInterceptor.extraKey,
        ),
        isFalse,
      );
    });
  });

  group('the SSE stream is device-authenticated only (§4.0 exception)', () {
    test('GET /events sends X-Device-Key and NO X-Session-Token', () async {
      final Dio dio = _dio();
      final _CapturingSseAdapter adapter = _CapturingSseAdapter();
      dio.httpClientAdapter = adapter;

      await DioRollWorkerEventsByteStreamSource(dio).open();

      final RequestOptions sent = adapter.requests.single;
      expect(sent.path, ApiPaths.rollWorkerEvents);
      expect(_device(sent), 'device-key-under-test');
      // The pre-login channel must connect before the worker has any session —
      // a session-scoped stream would never open on the line picker.
      expect(
        sent.headers.containsKey(SessionTokenInterceptor.headerName),
        isFalse,
      );
      expect(sent.headers['Accept'], 'text/event-stream');
      // The long-lived stream must not be killed by the normal receive window.
      expect(sent.receiveTimeout, Duration.zero);
    });
  });
}
