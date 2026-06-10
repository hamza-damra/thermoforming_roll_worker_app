import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:thermoforming_roll_worker/features/shift_line/data/roll_worker_lines_sse_client.dart';
import 'package:thermoforming_roll_worker/features/shift_line/domain/entities/roll_worker_lines_event.dart';

/// Feeds scripted byte streams to the client. The Nth `open()` returns the
/// Nth scripted stream; once exhausted it returns a stream that stays open
/// and emits nothing (so the client stops reconnecting).
class _ScriptedSource implements RollWorkerEventsByteStreamSource {
  _ScriptedSource(this._streams);

  final List<Stream<List<int>>> _streams;
  final List<StreamController<List<int>>> _idle = <StreamController<List<int>>>[];
  int openCount = 0;

  @override
  Future<Stream<List<int>>> open() async {
    final int i = openCount++;
    if (i < _streams.length) return _streams[i];
    final StreamController<List<int>> idle = StreamController<List<int>>();
    _idle.add(idle);
    return idle.stream;
  }

  void dispose() {
    for (final StreamController<List<int>> c in _idle) {
      c.close();
    }
  }
}

/// A byte stream that emits [text] as one chunk, then completes (done).
Stream<List<int>> _frame(String text) =>
    Stream<List<int>>.value(utf8.encode(text));

Future<List<RollWorkerLinesStreamItem>> _collect(
  RollWorkerLinesSseClient client, {
  Duration wait = const Duration(milliseconds: 60),
}) async {
  final items = <RollWorkerLinesStreamItem>[];
  final StreamSubscription<RollWorkerLinesStreamItem> sub = client
      .subscribe()
      .listen(items.add);
  await Future<void>.delayed(wait);
  await sub.cancel();
  return items;
}

void main() {
  test('emits PickerSseConnected on the first `connected` handshake', () async {
    final source = _ScriptedSource(<Stream<List<int>>>[
      _frame('event: connected\ndata: {}\n\n'),
    ]);
    addTearDown(source.dispose);
    final client = RollWorkerLinesSseClient(
      source: source,
      initialBackoff: const Duration(milliseconds: 5),
    );

    final items = await _collect(client);

    expect(items.whereType<PickerSseConnected>(), hasLength(1));
  });

  test(
    'maps a roll-worker-lines-changed frame to a refresh trigger with '
    'diagnostic fields',
    () async {
      final source = _ScriptedSource(<Stream<List<int>>>[
        _frame(
          'event: roll-worker-lines-changed\n'
          'data: {"type":"LINE_STATE_CHANGED","palletizingLineId":20,'
          '"version":42,"eventId":"e1"}\n\n',
        ),
      ]);
      addTearDown(source.dispose);
      final client = RollWorkerLinesSseClient(
        source: source,
        initialBackoff: const Duration(milliseconds: 5),
      );

      final items = await _collect(client);

      final triggers = items.whereType<PickerSseRefreshTriggered>().toList();
      expect(triggers, hasLength(1));
      expect(triggers.single.type, 'LINE_STATE_CHANGED');
      expect(triggers.single.palletizingLineId, 20);
      expect(triggers.single.version, 42);
      expect(triggers.single.eventId, 'e1');
    },
  );

  test(
    'maps a urgent-manager-announcement frame to PickerSseUrgentAnnouncement '
    '(NOT a refresh trigger)',
    () async {
      final source = _ScriptedSource(<Stream<List<int>>>[
        _frame(
          'event: urgent-manager-announcement\n'
          'data: {"eventType":"URGENT_MANAGER_ANNOUNCEMENT_CREATED",'
          '"announcementId":123,"targetDomain":"THERMOFORMING",'
          '"priority":"URGENT"}\n\n',
        ),
      ]);
      addTearDown(source.dispose);
      final client = RollWorkerLinesSseClient(
        source: source,
        initialBackoff: const Duration(milliseconds: 5),
      );

      final items = await _collect(client);

      final nudges = items.whereType<PickerSseUrgentAnnouncement>().toList();
      expect(nudges, hasLength(1));
      expect(nudges.single.announcementId, 123);
      expect(nudges.single.priority, 'URGENT');
      // Critically: the additive event must NOT be misrouted as a bootstrap
      // refresh trigger (handoff: existing refresh handling unchanged).
      expect(items.whereType<PickerSseRefreshTriggered>(), isEmpty);
    },
  );

  test(
    'a refresh frame and an urgent frame on one stream route distinctly '
    '(shift-end OPERATOR_SESSION_ENDED still triggers a refresh)',
    () async {
      final source = _ScriptedSource(<Stream<List<int>>>[
        _frame(
          // The shift-end signal reaches this app as an ordinary refresh
          // trigger — it must still produce a refresh.
          'event: roll-worker-lines-changed\n'
          'data: {"type":"OPERATOR_SESSION_ENDED","eventId":"end1"}\n\n'
          'event: urgent-manager-announcement\n'
          'data: {"announcementId":9}\n\n',
        ),
      ]);
      addTearDown(source.dispose);
      final client = RollWorkerLinesSseClient(
        source: source,
        initialBackoff: const Duration(milliseconds: 5),
      );

      final items = await _collect(client);

      final triggers = items.whereType<PickerSseRefreshTriggered>().toList();
      expect(triggers, hasLength(1));
      expect(triggers.single.type, 'OPERATOR_SESSION_ENDED');
      expect(items.whereType<PickerSseUrgentAnnouncement>(), hasLength(1));
    },
  );

  test('ignores `:` heartbeat comment lines', () async {
    final source = _ScriptedSource(<Stream<List<int>>>[
      _frame(
        ': ping\n'
        ': ping\n'
        'event: roll-worker-lines-changed\ndata: {}\n\n',
      ),
    ]);
    addTearDown(source.dispose);
    final client = RollWorkerLinesSseClient(
      source: source,
      initialBackoff: const Duration(milliseconds: 5),
    );

    final items = await _collect(client);

    expect(items.whereType<PickerSseRefreshTriggered>(), hasLength(1));
  });

  test('emits PickerSseReconnected after a drop and reconnect', () async {
    final source = _ScriptedSource(<Stream<List<int>>>[
      _frame('event: connected\ndata: {}\n\n'),
      _frame('event: connected\ndata: {}\n\n'),
    ]);
    addTearDown(source.dispose);
    final client = RollWorkerLinesSseClient(
      source: source,
      initialBackoff: const Duration(milliseconds: 5),
    );

    final items = await _collect(
      client,
      wait: const Duration(milliseconds: 120),
    );

    expect(items.whereType<PickerSseConnected>(), hasLength(1));
    expect(items.whereType<PickerSseReconnected>(), hasLength(1));
  });

  test('deduplicates frames sharing the same eventId', () async {
    final source = _ScriptedSource(<Stream<List<int>>>[
      _frame(
        'event: roll-worker-lines-changed\ndata: {"eventId":"dup"}\n\n'
        'event: roll-worker-lines-changed\ndata: {"eventId":"dup"}\n\n',
      ),
    ]);
    addTearDown(source.dispose);
    final client = RollWorkerLinesSseClient(
      source: source,
      initialBackoff: const Duration(milliseconds: 5),
    );

    final items = await _collect(client);

    expect(items.whereType<PickerSseRefreshTriggered>(), hasLength(1));
  });

  test(
    'reconnects when no frame arrives within the stale timeout',
    () async {
      // A half-open socket: opens, sends the handshake, then stays open and
      // silent forever — it never completes and never errors.
      final controller = StreamController<List<int>>();
      addTearDown(() {
        if (!controller.isClosed) controller.close();
      });
      controller.add(utf8.encode('event: connected\ndata: {}\n\n'));

      final source = _ScriptedSource(<Stream<List<int>>>[controller.stream]);
      addTearDown(source.dispose);
      final client = RollWorkerLinesSseClient(
        source: source,
        initialBackoff: const Duration(milliseconds: 5),
        staleTimeout: const Duration(milliseconds: 40),
      );

      final items = await _collect(
        client,
        wait: const Duration(milliseconds: 130),
      );

      expect(items.whereType<PickerSseConnected>(), hasLength(1));
      expect(
        items.whereType<PickerSseTransportError>(),
        isNotEmpty,
        reason: 'a silent stream past the stale timeout is treated as dead',
      );
      expect(
        source.openCount,
        greaterThanOrEqualTo(2),
        reason: 'stale detection must force a reconnect',
      );
    },
  );

  test(
    'a heartbeat comment keeps the connection alive (no stale reconnect)',
    () async {
      final controller = StreamController<List<int>>();
      addTearDown(() {
        if (!controller.isClosed) controller.close();
      });
      controller.add(utf8.encode('event: connected\ndata: {}\n\n'));
      // Heartbeat comment every 20 ms — well inside the 60 ms stale window.
      final ticker = Timer.periodic(const Duration(milliseconds: 20), (_) {
        if (!controller.isClosed) controller.add(utf8.encode(': ping\n'));
      });
      addTearDown(ticker.cancel);

      final source = _ScriptedSource(<Stream<List<int>>>[controller.stream]);
      addTearDown(source.dispose);
      final client = RollWorkerLinesSseClient(
        source: source,
        initialBackoff: const Duration(milliseconds: 5),
        staleTimeout: const Duration(milliseconds: 60),
      );

      final items = await _collect(
        client,
        wait: const Duration(milliseconds: 200),
      );

      expect(items.whereType<PickerSseTransportError>(), isEmpty);
      expect(
        source.openCount,
        1,
        reason: 'heartbeats reset the watchdog — one connection stays alive',
      );
    },
  );
}
