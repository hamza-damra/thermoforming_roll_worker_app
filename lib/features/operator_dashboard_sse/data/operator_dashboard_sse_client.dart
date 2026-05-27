import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../core/api/api_paths.dart';
import '../../../core/api/session_token_interceptor.dart';
import '../domain/entities/operator_dashboard_event.dart';
import 'sse_frame_parser.dart';

/// Thin transport seam — abstracts the SSE byte stream so tests can feed
/// fake data without touching Dio or sockets.
abstract class SseByteStreamSource {
  /// Opens a fresh SSE byte stream. Throws (or completes with an error
  /// event) on transport failures so the client can schedule a reconnect.
  Future<Stream<List<int>>> open({
    required int lineId,
    required String sessionToken,
  });
}

/// Production [SseByteStreamSource] that opens a streamed `GET` via Dio.
///
/// `responseType: stream` keeps the response body as a chunked
/// `ResponseBody`, from which we hand the caller a `Stream<List<int>>`.
/// The Dio receive-timeout is replaced with [Duration.zero] (no timeout)
/// for this specific request so the long-lived SSE channel is not killed
/// after the normal receive window.
class DioSseByteStreamSource implements SseByteStreamSource {
  DioSseByteStreamSource(this._dio);

  final Dio _dio;

  @override
  Future<Stream<List<int>>> open({
    required int lineId,
    required String sessionToken,
  }) async {
    final Response<ResponseBody> response = await _dio.get<ResponseBody>(
      ApiPaths.operatorDashboardEvents(lineId),
      options: Options(
        responseType: ResponseType.stream,
        receiveTimeout: Duration.zero,
        headers: <String, String>{
          'Accept': 'text/event-stream',
          'Cache-Control': 'no-cache',
        },
        extra: SessionTokenInterceptor.attach(sessionToken),
      ),
    );
    final ResponseBody? body = response.data;
    if (body == null) {
      throw StateError('SSE response had no body for lineId=$lineId');
    }
    return body.stream;
  }
}

typedef SessionTokenLookup = Future<String?> Function();

/// Long-lived SSE consumer for the operator-dashboard channel.
///
/// Behaviour (handoff §2 / §6 / §7):
///   - Opens a `text/event-stream` GET against
///     `ApiPaths.operatorDashboardEvents(lineId)`.
///   - Parses the wire format incrementally via [SseFrameParser] and
///     emits one [OperatorDashboardStreamItem] per relevant record:
///       • [SseConnected] when the handshake `connected` event arrives on
///         a fresh connection.
///       • [SseReconnected] when the handshake arrives after a prior
///         disconnect (caller should refetch state).
///       • [SseEventReceived] for each `operator-dashboard-changed` frame
///         that survives client-side dedupe (`eventId` LRU, capacity 64).
///       • [SseTransportError] for non-fatal transport errors — the
///         client continues reconnecting in the background.
///   - On stream end / error, automatically reconnects with exponential
///     backoff (1s, 2s, 4s, capped at 30s) until the caller cancels.
///   - Deduplicates by `eventId` (handoff §6) using a small LRU.
class OperatorDashboardSseClient {
  OperatorDashboardSseClient({
    required SseByteStreamSource source,
    required SessionTokenLookup tokenLookup,
    Duration initialBackoff = const Duration(seconds: 1),
    Duration maxBackoff = const Duration(seconds: 30),
    int dedupeCapacity = 64,
  }) : _source = source,
       _tokenLookup = tokenLookup,
       _initialBackoff = initialBackoff,
       _maxBackoff = maxBackoff,
       _dedupeCapacity = math.max(1, dedupeCapacity);

  final SseByteStreamSource _source;
  final SessionTokenLookup _tokenLookup;
  final Duration _initialBackoff;
  final Duration _maxBackoff;
  final int _dedupeCapacity;

  /// Opens an SSE subscription for the given palletizing line. The stream
  /// transparently reconnects on drop/timeout. Cancel the subscription to
  /// tear down the underlying connection.
  Stream<OperatorDashboardStreamItem> subscribe({required int lineId}) {
    final _SseSubscription session = _SseSubscription(
      source: _source,
      tokenLookup: _tokenLookup,
      lineId: lineId,
      initialBackoff: _initialBackoff,
      maxBackoff: _maxBackoff,
      dedupeCapacity: _dedupeCapacity,
    );
    return session.stream;
  }
}

class _SseSubscription {
  _SseSubscription({
    required SseByteStreamSource source,
    required SessionTokenLookup tokenLookup,
    required this.lineId,
    required this.initialBackoff,
    required this.maxBackoff,
    required this.dedupeCapacity,
  }) : _source = source,
       _tokenLookup = tokenLookup {
    _controller = StreamController<OperatorDashboardStreamItem>(
      onListen: _start,
      onCancel: _stop,
    );
  }

  final SseByteStreamSource _source;
  final SessionTokenLookup _tokenLookup;
  final int lineId;
  final Duration initialBackoff;
  final Duration maxBackoff;
  final int dedupeCapacity;

  late final StreamController<OperatorDashboardStreamItem> _controller;
  StreamSubscription<List<int>>? _inner;
  Timer? _reconnectTimer;
  bool _closed = false;
  bool _hasEverConnected = false;
  Duration _backoff = const Duration(milliseconds: 0);

  /// Dedup LRU — insertion-ordered set, oldest evicted when over capacity.
  final Set<String> _seenEventIds = <String>{};

  Stream<OperatorDashboardStreamItem> get stream => _controller.stream;

  void _start() {
    _backoff = initialBackoff;
    _scheduleConnect(Duration.zero);
  }

  Future<void> _stop() async {
    _closed = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _inner?.cancel();
    _inner = null;
    if (!_controller.isClosed) {
      await _controller.close();
    }
  }

  void _scheduleConnect(Duration delay) {
    if (_closed) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, _connect);
  }

  Future<void> _connect() async {
    if (_closed) return;
    final SseFrameParser parser = SseFrameParser();
    const Utf8Decoder decoder = Utf8Decoder(allowMalformed: true);
    bool handshakeSeen = false;
    String? token;
    try {
      token = await _tokenLookup();
    } catch (error) {
      _emit(SseTransportError(error));
      _scheduleBackoff();
      return;
    }
    if (token == null || token.isEmpty) {
      // No session token — surface a transport error and back off; the
      // sync controller may have torn down by the time we retry.
      _emit(const SseTransportError('missing session token'));
      _scheduleBackoff();
      return;
    }

    Stream<List<int>> bytes;
    try {
      bytes = await _source.open(lineId: lineId, sessionToken: token);
    } catch (error) {
      _emit(SseTransportError(error));
      _scheduleBackoff();
      return;
    }

    _inner = bytes.listen(
      (List<int> chunk) {
        if (_closed) return;
        final String text = decoder.convert(
          chunk is Uint8List ? chunk : Uint8List.fromList(chunk),
        );
        for (final RawSseEvent raw in parser.feed(text)) {
          if (OperatorDashboardFrameParser.isHandshake(raw)) {
            if (!handshakeSeen) {
              handshakeSeen = true;
              _backoff = initialBackoff;
              _emit(
                _hasEverConnected
                    ? const SseReconnected()
                    : const SseConnected(),
              );
              _hasEverConnected = true;
            }
            continue;
          }
          final OperatorDashboardEvent? event =
              OperatorDashboardFrameParser.parse(raw);
          if (event == null) continue;
          if (event.eventId != null) {
            if (!_admit(event.eventId!)) continue;
          }
          _emit(SseEventReceived(event));
        }
      },
      onError: (Object error, StackTrace _) {
        if (_closed) return;
        _emit(SseTransportError(error));
        _onUpstreamGone();
      },
      onDone: () {
        if (_closed) return;
        _onUpstreamGone();
      },
      cancelOnError: true,
    );
  }

  void _onUpstreamGone() {
    _inner = null;
    _scheduleBackoff();
  }

  void _scheduleBackoff() {
    if (_closed) return;
    final Duration delay = _backoff == Duration.zero
        ? initialBackoff
        : _backoff;
    final Duration nextBackoff = _backoff < initialBackoff
        ? initialBackoff
        : Duration(milliseconds: _backoff.inMilliseconds * 2);
    _backoff = nextBackoff > maxBackoff ? maxBackoff : nextBackoff;
    _scheduleConnect(delay);
  }

  void _emit(OperatorDashboardStreamItem item) {
    if (_closed || _controller.isClosed) return;
    if (!_controller.hasListener) {
      // Stream was paused / canceled between callbacks; drop silently.
      if (kDebugMode) {
        // ignore: avoid_print
        print('[SSE] dropped item with no listener: $item');
      }
      return;
    }
    _controller.add(item);
  }

  bool _admit(String eventId) {
    if (_seenEventIds.contains(eventId)) {
      // Move-to-front semantics: refresh LRU position so noisy duplicates
      // do not evict newer ids.
      _seenEventIds
        ..remove(eventId)
        ..add(eventId);
      return false;
    }
    _seenEventIds.add(eventId);
    if (_seenEventIds.length > dedupeCapacity) {
      _seenEventIds.remove(_seenEventIds.first);
    }
    return true;
  }
}
