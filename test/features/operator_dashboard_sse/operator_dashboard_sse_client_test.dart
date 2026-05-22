import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:thermoforming_roll_worker/features/operator_dashboard_sse/data/operator_dashboard_sse_client.dart';
import 'package:thermoforming_roll_worker/features/operator_dashboard_sse/domain/entities/operator_dashboard_event.dart';

/// Programmable byte stream source — each call to `open()` pops a queue
/// entry. Tests drive disconnects/reconnects by enqueueing finite streams
/// that close themselves.
class FakeSseSource implements SseByteStreamSource {
  final List<Future<Stream<List<int>>> Function()> _scripts =
      <Future<Stream<List<int>>> Function()>[];
  int openCount = 0;

  void enqueue(Stream<List<int>> Function() builder) {
    _scripts.add(() async => builder());
  }

  void enqueueChunks(List<List<int>> chunks) {
    enqueue(() {
      final c = StreamController<List<int>>();
      Future.microtask(() async {
        for (final chunk in chunks) {
          c.add(chunk);
        }
        await c.close();
      });
      return c.stream;
    });
  }

  void enqueueText(String text) =>
      enqueueChunks(<List<int>>[utf8.encode(text)]);

  void enqueueError(Object error) {
    _scripts.add(() => Future<Stream<List<int>>>.error(error));
  }

  @override
  Future<Stream<List<int>>> open({
    required int lineId,
    required String sessionToken,
  }) {
    openCount++;
    if (_scripts.isEmpty) {
      throw StateError(
        'FakeSseSource exhausted (openCount=$openCount, no more scripts)',
      );
    }
    return _scripts.removeAt(0)();
  }
}

void main() {
  group('OperatorDashboardSseClient', () {
    test(
      'first handshake emits SseConnected; subsequent are SseReconnected',
      () async {
        final source = FakeSseSource();
        source.enqueueText(
          'event: connected\ndata: {}\n\n'
          'event: operator-dashboard-changed\n'
          'data: {"lineId":10,"reason":"PRODUCT_CHANGED","eventId":"id-1",'
          '"data":{"machineId":10,"newProductId":6,"newProductName":"Blue"}}'
          '\n\n',
        );
        // Second open: after reconnect, another handshake.
        source.enqueueText('event: connected\ndata: {}\n\n');

        final client = OperatorDashboardSseClient(
          source: source,
          tokenLookup: () async => 'token',
          initialBackoff: const Duration(milliseconds: 5),
          maxBackoff: const Duration(milliseconds: 10),
        );
        final sub = client.subscribe(lineId: 10);

        final items = <OperatorDashboardStreamItem>[];
        final completer = Completer<void>();
        final s = sub.listen(items.add);
        // Wait long enough for both opens to happen.
        Timer(const Duration(milliseconds: 80), () {
          if (!completer.isCompleted) completer.complete();
        });
        await completer.future;
        await s.cancel();

        expect(items.whereType<SseConnected>(), hasLength(1));
        expect(
          items.whereType<SseReconnected>().length,
          greaterThanOrEqualTo(1),
        );
        expect(items.whereType<SseEventReceived>(), hasLength(1));
      },
    );

    test('duplicate event ids are deduped — UI sees the event once', () async {
      final source = FakeSseSource();
      const String dupBody =
          'event: operator-dashboard-changed\n'
          'data: {"lineId":10,"reason":"PRODUCT_CHANGED","eventId":"dup-1",'
          '"data":{"machineId":10,"newProductId":6,"newProductName":"X"}}\n\n';
      source.enqueueText('event: connected\ndata: {}\n\n$dupBody$dupBody');
      source.enqueue(() {
        final c = StreamController<List<int>>();
        // Keep open indefinitely so the test can cancel before reconnect.
        return c.stream;
      });

      final client = OperatorDashboardSseClient(
        source: source,
        tokenLookup: () async => 'token',
        initialBackoff: const Duration(milliseconds: 5),
      );
      final received = <SseEventReceived>[];
      final sub = client.subscribe(lineId: 10).listen((item) {
        if (item is SseEventReceived) received.add(item);
      });
      await Future<void>.delayed(const Duration(milliseconds: 30));
      await sub.cancel();

      expect(received, hasLength(1));
      expect(received.single.event.eventId, 'dup-1');
    });

    test(
      'transport error before any handshake → next handshake still surfaces, '
      'and prior error is reported',
      () async {
        final source = FakeSseSource();
        source.enqueueError(const _FakeNetError('boom'));
        source.enqueueText('event: connected\ndata: {}\n\n');
        source.enqueue(() {
          // Stay open after the recovery handshake so the test settles.
          final c = StreamController<List<int>>();
          return c.stream;
        });

        final client = OperatorDashboardSseClient(
          source: source,
          tokenLookup: () async => 'token',
          initialBackoff: const Duration(milliseconds: 5),
          maxBackoff: const Duration(milliseconds: 10),
        );
        final items = <OperatorDashboardStreamItem>[];
        final sub = client.subscribe(lineId: 10).listen(items.add);
        await Future<void>.delayed(const Duration(milliseconds: 60));
        await sub.cancel();

        expect(items.whereType<SseTransportError>(), isNotEmpty);
        // No prior successful handshake → the recovery handshake counts as
        // the FIRST connect (SseConnected). The sync controller treats
        // SseConnected and SseReconnected identically for refresh, so this
        // distinction is intentional: we use SseReconnected only when we
        // know the consumer had a prior in-sync state worth re-syncing.
        expect(items.whereType<SseConnected>(), hasLength(1));
      },
    );

    test(
      'drop after successful handshake → next handshake is SseReconnected',
      () async {
        final source = FakeSseSource();
        source.enqueueText('event: connected\ndata: {}\n\n');
        source.enqueueText('event: connected\ndata: {}\n\n');
        source.enqueue(() {
          final c = StreamController<List<int>>();
          return c.stream;
        });

        final client = OperatorDashboardSseClient(
          source: source,
          tokenLookup: () async => 'token',
          initialBackoff: const Duration(milliseconds: 5),
          maxBackoff: const Duration(milliseconds: 10),
        );
        final items = <OperatorDashboardStreamItem>[];
        final sub = client.subscribe(lineId: 10).listen(items.add);
        await Future<void>.delayed(const Duration(milliseconds: 60));
        await sub.cancel();

        expect(items.whereType<SseConnected>(), hasLength(1));
        expect(items.whereType<SseReconnected>(), isNotEmpty);
      },
    );

    test('missing token surfaces SseTransportError and backs off', () async {
      final source = FakeSseSource();
      // No script enqueued — the client should never reach `open`.
      final client = OperatorDashboardSseClient(
        source: source,
        tokenLookup: () async => null,
        initialBackoff: const Duration(milliseconds: 5),
        maxBackoff: const Duration(milliseconds: 5),
      );
      final items = <OperatorDashboardStreamItem>[];
      final sub = client.subscribe(lineId: 10).listen(items.add);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      await sub.cancel();

      expect(items.whereType<SseTransportError>(), isNotEmpty);
      expect(source.openCount, 0);
    });
  });
}

class _FakeNetError implements Exception {
  const _FakeNetError(this.message);
  final String message;

  @override
  String toString() => 'FakeNetError($message)';
}
