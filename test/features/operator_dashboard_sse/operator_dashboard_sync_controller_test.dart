import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:thermoforming_roll_worker/features/home/data/shift_line_summary_providers.dart';
import 'package:thermoforming_roll_worker/features/home/domain/entities/shift_line_summary.dart';
import 'package:thermoforming_roll_worker/features/home/domain/shift_line_summary_repository.dart';
import 'package:thermoforming_roll_worker/features/operator_dashboard_sse/data/operator_dashboard_sse_client.dart';
import 'package:thermoforming_roll_worker/features/operator_dashboard_sse/data/operator_dashboard_sse_providers.dart';
import 'package:thermoforming_roll_worker/features/operator_dashboard_sse/presentation/controllers/operator_dashboard_poll_config.dart';
import 'package:thermoforming_roll_worker/features/operator_dashboard_sse/presentation/controllers/operator_dashboard_sync_controller.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/domain/entities/roll_worker_session.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/presentation/controllers/multi_line_session_registry.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/presentation/controllers/multi_line_session_registry_state.dart';

const int _kShiftLineId = 800;
const int _kPalletizingLineId = 10;

final RollWorkerSession _kSession = RollWorkerSession(
  sessionId: 1,
  rollWorkerOperatorId: 1,
  rollWorkerName: 'Worker',
  thermoformingShiftId: 1,
  thermoformingShiftLineId: _kShiftLineId,
  thermoformingLineId: 1,
  palletizingLineId: _kPalletizingLineId,
  startedAt: DateTime(2026),
);

class _MockSummaryRepo extends Mock implements ShiftLineSummaryRepository {}

/// Registry pinned to a single active session so the sync controller can
/// resolve [_kPalletizingLineId] without touching storage / network.
class _FakeRegistry extends MultiLineSessionRegistry {
  @override
  MultiLineSessionRegistryState build() => RegistryActive(
    sessions: <int, RollWorkerSession>{_kShiftLineId: _kSession},
    activeShiftLineId: _kShiftLineId,
    logoutStatus: const <int, LineLogoutStatus>{
      _kShiftLineId: LineLogoutStatus.idle,
    },
  );
}

/// Programmable byte-stream source. Each `open()` hands back a fresh
/// [StreamController] the test feeds wire frames into; closing one models an
/// upstream drop and forces the client to reconnect against the next.
class _ScriptedSseSource implements SseByteStreamSource {
  final List<StreamController<List<int>>> controllers =
      <StreamController<List<int>>>[];

  @override
  Future<Stream<List<int>>> open({
    required int lineId,
    required String sessionToken,
  }) async {
    final controller = StreamController<List<int>>();
    controllers.add(controller);
    return controller.stream;
  }

  StreamController<List<int>> get latest => controllers.last;

  void send(String frame, {int index = -1}) {
    final StreamController<List<int>> c = index < 0
        ? controllers.last
        : controllers[index];
    c.add(utf8.encode(frame));
  }
}

OperatorDashboardSseClient _client(_ScriptedSseSource source) =>
    OperatorDashboardSseClient(
      source: source,
      tokenLookup: () async => 'token',
      initialBackoff: const Duration(milliseconds: 5),
      maxBackoff: const Duration(milliseconds: 10),
    );

ShiftLineSummary _summary({
  String? activeOperatorName = 'مشغل التشكيل',
  bool blocked = false,
  String? lineLifecycleStatus,
}) => ShiftLineSummary(
  shiftLineId: _kShiftLineId,
  thermoformingLineCode: 'TH-01',
  thermoformingLineName: 'خط التشكيل 1',
  completedRollsInSession: 0,
  completedRollsByCurrentWorker: 0,
  activeOperatorId: activeOperatorName == null ? null : 1,
  activeOperatorName: activeOperatorName,
  blocked: blocked,
  lineLifecycleStatus: lineLifecycleStatus,
);

String _handshake() => 'event: connected\ndata: {}\n\n';

String _productChanged(String eventId) =>
    'event: operator-dashboard-changed\n'
    'data: {"lineId":10,"reason":"PRODUCT_CHANGED","eventId":"$eventId",'
    '"data":{"machineId":10,"newProductId":6,"newProductName":"Blue"}}\n\n';

String _lineStateChanged(String eventId) =>
    'event: operator-dashboard-changed\n'
    'data: {"lineId":10,"reason":"LINE_STATE_CHANGED","eventId":"$eventId"}\n\n';

/// Wide poll intervals + a short debounce — isolates event/reconnect-driven
/// refreshes from the safety-net poll, which never fires inside a test window.
const OperatorDashboardPollConfig _eventDrivenConfig =
    OperatorDashboardPollConfig(
      stableInterval: Duration(seconds: 30),
      disconnectedInterval: Duration(seconds: 30),
      fastInterval: Duration(seconds: 30),
      eventDebounce: Duration(milliseconds: 20),
    );

/// Distinct, large intervals — lets a test read back which cadence tier the
/// controller selected without any timer firing.
const OperatorDashboardPollConfig _tierConfig = OperatorDashboardPollConfig(
  stableInterval: Duration(seconds: 45),
  disconnectedInterval: Duration(seconds: 10),
  fastInterval: Duration(seconds: 4),
  eventDebounce: Duration(milliseconds: 20),
);

void main() {
  late _MockSummaryRepo repo;
  late int fetchCount;
  late ShiftLineSummary served;

  setUp(() {
    repo = _MockSummaryRepo();
    fetchCount = 0;
    served = _summary();
    when(() => repo.fetchSummary(shiftLineId: _kShiftLineId)).thenAnswer((
      _,
    ) async {
      fetchCount++;
      return SummarySuccess(served);
    });
  });

  ProviderContainer makeContainer({
    required _ScriptedSseSource source,
    OperatorDashboardPollConfig config = _eventDrivenConfig,
  }) {
    final container = ProviderContainer(
      overrides: <Override>[
        shiftLineSummaryRepositoryProvider.overrideWithValue(repo),
        multiLineSessionRegistryProvider.overrideWith(_FakeRegistry.new),
        operatorDashboardSseClientForLineProvider(
          _kShiftLineId,
        ).overrideWithValue(_client(source)),
        operatorDashboardPollConfigProvider.overrideWithValue(config),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  OperatorDashboardSyncController syncOf(ProviderContainer c) =>
      c.read(operatorDashboardSyncControllerProvider(_kShiftLineId).notifier);

  /// Starts the bridge, lets the SSE client open the stream, then feeds the
  /// `connected` handshake and waits for the immediate connect-refresh.
  Future<void> startAndConnect(
    ProviderContainer container,
    _ScriptedSseSource source,
  ) async {
    await syncOf(container).start();
    await Future<void>.delayed(const Duration(milliseconds: 30));
    source.send(_handshake());
    await Future<void>.delayed(const Duration(milliseconds: 40));
  }

  test('SSE PRODUCT_CHANGED triggers a debounced REST summary refresh', () async {
    final source = _ScriptedSseSource();
    final container = makeContainer(source: source);
    await startAndConnect(container, source);

    final int afterConnect = fetchCount;
    expect(afterConnect, greaterThanOrEqualTo(1), reason: 'connect refetches');

    source.send(_productChanged('p1'));
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(
      fetchCount,
      afterConnect + 1,
      reason: 'PRODUCT_CHANGED must refetch the REST summary exactly once',
    );
  });

  test('SSE LINE_STATE_CHANGED triggers a debounced REST summary refresh', () async {
    final source = _ScriptedSseSource();
    final container = makeContainer(source: source);
    await startAndConnect(container, source);

    final int afterConnect = fetchCount;
    source.send(_lineStateChanged('l1'));
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(fetchCount, afterConnect + 1);
  });

  test('a burst of SSE events collapses into a single refresh (debounce)', () async {
    final source = _ScriptedSseSource();
    final container = makeContainer(source: source);
    await startAndConnect(container, source);

    final int afterConnect = fetchCount;
    // Three frames inside one debounce window.
    source.send(_productChanged('b1'));
    source.send(_lineStateChanged('b2'));
    source.send(_productChanged('b3'));
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(
      fetchCount,
      afterConnect + 1,
      reason: 'coalesced burst must refetch only once',
    );
  });

  test('SSE reconnect triggers an immediate refresh', () async {
    final source = _ScriptedSseSource();
    final container = makeContainer(source: source);
    await startAndConnect(container, source);

    final int afterConnect = fetchCount;
    // Drop the upstream — the client backs off and reconnects.
    await source.controllers[0].close();
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(source.controllers.length, greaterThanOrEqualTo(2),
        reason: 'client reopened the stream');
    source.send(_handshake()); // handshake on the reconnected stream
    await Future<void>.delayed(const Duration(milliseconds: 40));

    expect(
      fetchCount,
      greaterThan(afterConnect),
      reason: 'reconnect must refetch without waiting for an event',
    );
  });

  test('app resume triggers an immediate refresh', () async {
    final source = _ScriptedSseSource();
    final container = makeContainer(source: source);
    final sync = syncOf(container);

    expect(fetchCount, 0);
    sync.onAppResumed();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(fetchCount, 1, reason: 'resume refetches the REST summary');
  });

  test('a missed SSE event is recovered by the safety-net poll', () async {
    final source = _ScriptedSseSource();
    const config = OperatorDashboardPollConfig(
      stableInterval: Duration(milliseconds: 40),
      disconnectedInterval: Duration(milliseconds: 40),
      fastInterval: Duration(milliseconds: 40),
      eventDebounce: Duration(milliseconds: 250),
    );
    final container = makeContainer(source: source, config: config);
    await startAndConnect(container, source);

    final int afterConnect = fetchCount;
    // No SSE event is sent — only the periodic poll can advance fetchCount.
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(
      fetchCount,
      greaterThan(afterConnect + 1),
      reason: 'polling must keep refetching when SSE delivers nothing',
    );
  });

  test('waiting state (no active operator) selects the fast poll cadence', () async {
    final source = _ScriptedSseSource();
    served = _summary(activeOperatorName: null);
    final container = makeContainer(source: source, config: _tierConfig);
    await startAndConnect(container, source);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(syncOf(container).currentPollInterval, _tierConfig.fastInterval);
  });

  test('blocked state selects the fast poll cadence', () async {
    final source = _ScriptedSseSource();
    served = _summary(blocked: true);
    final container = makeContainer(source: source, config: _tierConfig);
    await startAndConnect(container, source);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(syncOf(container).currentPollInterval, _tierConfig.fastInterval);
  });

  test('stable connected state selects the slow poll cadence', () async {
    final source = _ScriptedSseSource();
    served = _summary(lineLifecycleStatus: 'ACTIVE');
    final container = makeContainer(source: source, config: _tierConfig);
    await startAndConnect(container, source);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(syncOf(container).currentPollInterval, _tierConfig.stableInterval);
  });

  test('repeated same-tier recomputes do not create duplicate timers', () async {
    final source = _ScriptedSseSource();
    final container = makeContainer(source: source);
    await startAndConnect(container, source);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final int generationAfterConnect = syncOf(container).pollTimerGeneration;
    expect(generationAfterConnect, greaterThanOrEqualTo(1));

    // Several events that keep the line in the same (stable) tier.
    source.send(_productChanged('d1'));
    await Future<void>.delayed(const Duration(milliseconds: 40));
    source.send(_lineStateChanged('d2'));
    await Future<void>.delayed(const Duration(milliseconds: 40));
    source.send(_productChanged('d3'));
    await Future<void>.delayed(const Duration(milliseconds: 40));

    expect(
      syncOf(container).pollTimerGeneration,
      generationAfterConnect,
      reason: 'no new poll timer while the cadence tier is unchanged',
    );
  });
}
