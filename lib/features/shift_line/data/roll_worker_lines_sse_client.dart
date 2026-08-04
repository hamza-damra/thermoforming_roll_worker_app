import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/api/api_paths.dart';
import '../../operator_dashboard_sse/data/sse_frame_parser.dart';
import '../domain/entities/roll_worker_lines_event.dart';

/// Thin transport seam — abstracts the SSE byte stream so tests can feed
/// fake data without touching Dio or sockets.
///
/// Unlike the in-session operator-dashboard channel this takes no `lineId`
/// and no `sessionToken`: the pre-login `/events` stream is global and
/// device-key authenticated only.
abstract class RollWorkerEventsByteStreamSource {
  /// Opens a fresh SSE byte stream. Throws on transport failures so the
  /// client can schedule a reconnect.
  Future<Stream<List<int>>> open();
}

/// Production [RollWorkerEventsByteStreamSource] — opens a streamed `GET`
/// against `ApiPaths.rollWorkerEvents` via Dio.
///
/// `responseType: stream` keeps the body as a chunked `ResponseBody`. The
/// Dio receive-timeout is set to [Duration.zero] so the long-lived SSE
/// channel is not killed after the normal receive window.
///
/// The request is **not** tagged with a session token, so
/// `SessionTokenInterceptor` leaves it alone — only `X-Device-Key` (added
/// globally by `DeviceKeyInterceptor`) is sent. This is required: the
/// stream must be reachable before roll-worker PIN login.
class DioRollWorkerEventsByteStreamSource
    implements RollWorkerEventsByteStreamSource {
  DioRollWorkerEventsByteStreamSource(this._dio);

  final Dio _dio;

  @override
  Future<Stream<List<int>>> open() async {
    final Response<ResponseBody> response = await _dio.get<ResponseBody>(
      ApiPaths.rollWorkerEvents,
      options: Options(
        responseType: ResponseType.stream,
        receiveTimeout: Duration.zero,
        headers: <String, String>{
          'Accept': 'text/event-stream',
          'Cache-Control': 'no-cache',
        },
      ),
    );
    final ResponseBody? body = response.data;
    if (body == null) {
      throw StateError('roll-worker /events SSE response had no body');
    }
    return body.stream;
  }
}

/// Translates a [RawSseEvent] from the pre-login `/events` channel.
///
/// `connected` is the handshake; every other named frame
/// (`roll-worker-lines-changed`, …) is a plain "refresh now" trigger — the
/// exact name does not matter. The JSON body is decoded best-effort for
/// diagnostic fields only; a missing / malformed body still produces a
/// refresh trigger.
class RollWorkerLinesFrameParser {
  RollWorkerLinesFrameParser._();

  static const String handshakeName = 'connected';

  /// Additive event (handoff §SSE nudge): a sanitized urgent-manager
  /// announcement was created. Distinct from the refresh-trigger frames — it
  /// must NOT be treated as a `/bootstrap` refresh.
  static const String urgentAnnouncementName = 'urgent-manager-announcement';

  static bool isHandshake(RawSseEvent raw) => raw.name == handshakeName;

  static bool isUrgentAnnouncement(RawSseEvent raw) =>
      raw.name == urgentAnnouncementName;

  /// Decodes the (sanitized) urgent-announcement nudge. The JSON body carries
  /// only diagnostic fields (`announcementId`, `priority`, `action`) — never a
  /// body or sender; the `/pending` endpoint remains authoritative.
  ///
  /// `action` is additive (handoff §4.1). A missing key (older backend) or a
  /// malformed body still yields a nudge — every action means "refetch".
  static PickerSseUrgentAnnouncement parseUrgentAnnouncement(RawSseEvent raw) {
    final Object? decoded = _safeJsonDecode(raw.data);
    final Map<String, dynamic> map = decoded is Map<String, dynamic>
        ? decoded
        : const <String, dynamic>{};
    return PickerSseUrgentAnnouncement(
      announcementId: map['announcementId'] is num
          ? (map['announcementId'] as num).toInt()
          : null,
      priority: map['priority'] is String ? map['priority'] as String : null,
      action: UrgentAnnouncementAction.fromWire(
        map['action'] is String ? map['action'] as String : null,
      ),
    );
  }

  static PickerSseRefreshTriggered parseRefresh(RawSseEvent raw) {
    final Object? decoded = _safeJsonDecode(raw.data);
    final Map<String, dynamic> map = decoded is Map<String, dynamic>
        ? decoded
        : const <String, dynamic>{};
    return PickerSseRefreshTriggered(
      type: map['type'] is String ? map['type'] as String : null,
      palletizingLineId: map['palletizingLineId'] is num
          ? (map['palletizingLineId'] as num).toInt()
          : null,
      version: map['version'] is num ? (map['version'] as num).toInt() : null,
      eventId: map['eventId'] is String ? map['eventId'] as String : null,
      occurredAt: map['occurredAt'] is String
          ? DateTime.tryParse(map['occurredAt'] as String)
          : null,
    );
  }

  static Object? _safeJsonDecode(String body) {
    if (body.isEmpty) return null;
    try {
      return jsonDecode(body);
    } on FormatException {
      return null;
    }
  }
}

/// Long-lived SSE consumer for the pre-login roll-worker lines channel.
///
/// Behaviour (Line State Refresh handoff §2):
///   - Opens a `text/event-stream` GET against `ApiPaths.rollWorkerEvents`.
///   - Parses the wire format incrementally via [SseFrameParser] and emits
///     one [RollWorkerLinesStreamItem] per relevant record:
///       • [PickerSseConnected] on the first `connected` handshake.
///       • [PickerSseReconnected] when the handshake arrives after a prior
///         disconnect (caller should refetch `/bootstrap`).
///       • [PickerSseRefreshTriggered] for each non-handshake frame.
///       • [PickerSseTransportError] for non-fatal transport errors.
///   - On stream end / error, reconnects with exponential backoff
///     (1s, 2s, 4s, capped at 30s) until the caller cancels.
///   - Watches for a stale connection: if no frame (event *or* heartbeat
///     comment) arrives within `staleTimeout` the link is treated as
///     silently dead — the byte stream is dropped and a reconnect is
///     scheduled immediately. This covers half-open sockets that emit no
///     `onDone` / `onError` (handoff §6).
///   - Deduplicates by `eventId` (when present) using a small LRU.
///
/// NOTE: this duplicates the reconnect/backoff machinery of
/// `OperatorDashboardSseClient`. A future refactor could extract a generic
/// SSE-core; today the two channels differ enough (no lineId, no token,
/// trigger-only frames) that the duplication is the simpler choice.
class RollWorkerLinesSseClient {
  RollWorkerLinesSseClient({
    required RollWorkerEventsByteStreamSource source,
    Duration initialBackoff = const Duration(seconds: 1),
    Duration maxBackoff = const Duration(seconds: 30),
    Duration staleTimeout = const Duration(seconds: 40),
    int dedupeCapacity = 64,
  }) : _source = source,
       _initialBackoff = initialBackoff,
       _maxBackoff = maxBackoff,
       _staleTimeout = staleTimeout,
       _dedupeCapacity = dedupeCapacity < 1 ? 1 : dedupeCapacity;

  final RollWorkerEventsByteStreamSource _source;
  final Duration _initialBackoff;
  final Duration _maxBackoff;

  /// No frame (event or heartbeat) within this window ⇒ the connection is
  /// treated as dead. The backend heartbeats every 25 s, so 40 s of total
  /// silence is unambiguous (handoff §6).
  final Duration _staleTimeout;

  final int _dedupeCapacity;

  /// Opens an SSE subscription for the global pre-login lines channel. The
  /// stream transparently reconnects on drop / timeout. Cancel the
  /// subscription to tear down the underlying connection.
  Stream<RollWorkerLinesStreamItem> subscribe() {
    return _RollWorkerLinesSseSubscription(
      source: _source,
      initialBackoff: _initialBackoff,
      maxBackoff: _maxBackoff,
      staleTimeout: _staleTimeout,
      dedupeCapacity: _dedupeCapacity,
    ).stream;
  }
}

class _RollWorkerLinesSseSubscription {
  _RollWorkerLinesSseSubscription({
    required RollWorkerEventsByteStreamSource source,
    required this.initialBackoff,
    required this.maxBackoff,
    required this.staleTimeout,
    required this.dedupeCapacity,
  }) : _source = source {
    _controller = StreamController<RollWorkerLinesStreamItem>(
      onListen: _start,
      onCancel: _stop,
    );
  }

  final RollWorkerEventsByteStreamSource _source;
  final Duration initialBackoff;
  final Duration maxBackoff;
  final Duration staleTimeout;
  final int dedupeCapacity;

  late final StreamController<RollWorkerLinesStreamItem> _controller;
  StreamSubscription<List<int>>? _inner;
  Timer? _reconnectTimer;

  /// Fires when no frame (event or heartbeat) has arrived for
  /// [staleTimeout] — reset on every received chunk.
  Timer? _staleTimer;

  bool _closed = false;
  bool _hasEverConnected = false;
  Duration _backoff = Duration.zero;

  /// Dedup LRU — insertion-ordered set, oldest evicted when over capacity.
  final Set<String> _seenEventIds = <String>{};

  Stream<RollWorkerLinesStreamItem> get stream => _controller.stream;

  void _start() {
    _backoff = initialBackoff;
    _scheduleConnect(Duration.zero);
  }

  Future<void> _stop() async {
    _closed = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _staleTimer?.cancel();
    _staleTimer = null;
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

    Stream<List<int>> bytes;
    try {
      bytes = await _source.open();
    } catch (error) {
      _emit(PickerSseTransportError(error));
      _scheduleBackoff();
      return;
    }

    // The stream is open — arm the stale watchdog. A connection that
    // never even sends a `connected` handshake is caught by this too.
    _resetStaleTimer();

    _inner = bytes.listen(
      (List<int> chunk) {
        if (_closed) return;
        // Any byte (frame or heartbeat comment) proves the link is alive.
        _resetStaleTimer();
        final String text = decoder.convert(
          chunk is Uint8List ? chunk : Uint8List.fromList(chunk),
        );
        for (final RawSseEvent raw in parser.feed(text)) {
          if (RollWorkerLinesFrameParser.isHandshake(raw)) {
            if (!handshakeSeen) {
              handshakeSeen = true;
              _backoff = initialBackoff;
              _emit(
                _hasEverConnected
                    ? const PickerSseReconnected()
                    : const PickerSseConnected(),
              );
              _hasEverConnected = true;
            }
            continue;
          }
          // Additive, distinct event — route to the announcement notifier and
          // do NOT fall through to the refresh-trigger path (handoff: existing
          // refresh handling stays unchanged).
          if (RollWorkerLinesFrameParser.isUrgentAnnouncement(raw)) {
            _emit(RollWorkerLinesFrameParser.parseUrgentAnnouncement(raw));
            continue;
          }
          final PickerSseRefreshTriggered trigger =
              RollWorkerLinesFrameParser.parseRefresh(raw);
          final String? eventId = trigger.eventId;
          if (eventId != null && !_admit(eventId)) continue;
          _emit(trigger);
        }
      },
      onError: (Object error, StackTrace _) {
        if (_closed) return;
        _emit(PickerSseTransportError(error));
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
    _staleTimer?.cancel();
    _staleTimer = null;
    _scheduleBackoff();
  }

  /// (Re)arms the stale-connection watchdog. Called when the byte stream
  /// opens and on every received chunk.
  void _resetStaleTimer() {
    if (_closed) return;
    _staleTimer?.cancel();
    _staleTimer = Timer(staleTimeout, _onStale);
  }

  /// No frame arrived within [staleTimeout] — the socket is silently dead
  /// (half-open: no `onDone` / `onError` will ever fire). Drop the byte
  /// stream and reconnect immediately.
  void _onStale() {
    if (_closed) return;
    _staleTimer = null;
    _emit(
      const PickerSseTransportError(
        'stale connection: no frame within timeout',
      ),
    );
    final StreamSubscription<List<int>>? inner = _inner;
    _inner = null;
    unawaited(inner?.cancel());
    _scheduleConnect(Duration.zero);
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

  void _emit(RollWorkerLinesStreamItem item) {
    if (_closed || _controller.isClosed) return;
    if (!_controller.hasListener) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('[picker-SSE] dropped item with no listener: $item');
      }
      return;
    }
    _controller.add(item);
  }

  bool _admit(String eventId) {
    if (_seenEventIds.contains(eventId)) {
      // Move-to-front: refresh LRU position so noisy duplicates do not
      // evict newer ids.
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
