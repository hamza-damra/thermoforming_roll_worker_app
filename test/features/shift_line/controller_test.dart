// ignore: unnecessary_import
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:thermoforming_roll_worker/core/errors/app_failure.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/domain/entities/roll_worker_session.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/presentation/controllers/multi_line_session_registry.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/presentation/controllers/multi_line_session_registry_state.dart';
import 'package:thermoforming_roll_worker/features/shift_line/data/roll_worker_bootstrap_providers.dart';
import 'package:thermoforming_roll_worker/features/shift_line/data/roll_worker_lines_sse_providers.dart';
import 'package:thermoforming_roll_worker/features/shift_line/domain/entities/roll_worker_bootstrap_line.dart';
import 'package:thermoforming_roll_worker/features/shift_line/domain/entities/roll_worker_lines_event.dart';
import 'package:thermoforming_roll_worker/features/shift_line/domain/roll_worker_bootstrap_repository.dart';
import 'package:thermoforming_roll_worker/features/shift_line/presentation/controllers/roll_worker_bootstrap_controller.dart';
import 'package:thermoforming_roll_worker/features/shift_line/presentation/controllers/roll_worker_bootstrap_poll_config.dart';
import 'package:thermoforming_roll_worker/features/shift_line/presentation/controllers/roll_worker_bootstrap_state.dart';
import 'package:thermoforming_roll_worker/features/shift_line/presentation/controllers/selected_shift_line_provider.dart';

import 'fake_roll_worker_lines_sse_client.dart';

class _MockRepo extends Mock implements RollWorkerBootstrapRepository {}

/// Registry whose state the test drives directly — models the worker
/// logging in (`goActive`) and returning to the picker (`goEmpty`).
class _FakeRegistry extends MultiLineSessionRegistry {
  @override
  MultiLineSessionRegistryState build() => const RegistryEmpty();

  void goActive() {
    state = const RegistryActive(
      sessions: <int, RollWorkerSession>{},
      activeShiftLineId: 1,
      logoutStatus: <int, LineLogoutStatus>{},
    );
  }

  void goEmpty() => state = const RegistryEmpty();
}

/// `shiftLineId` is `thermoLineId + 1000` for a selectable row, `null`
/// otherwise — keeping the two ids distinct so a keying mistake surfaces.
RollWorkerBootstrapLine _line(int thermoLineId, {bool selectable = true}) =>
    RollWorkerBootstrapLine(
      thermoformingLineId: thermoLineId,
      lineCode: 'TH-0$thermoLineId',
      lineName: 'خط $thermoLineId',
      machineNumber: thermoLineId,
      palletizingLineId: 20,
      productionLineId: 20,
      palletizingLineCode: 'PL-0$thermoLineId',
      palletizingLineName: 'Palletizer $thermoLineId',
      shiftLineId: selectable ? thermoLineId + 1000 : null,
      thermoformingShiftId: 42,
      currentProductTypeId: 50,
      currentProductTypeName: 'Cup-200ml',
      activeOperatorId: 7,
      activeOperatorName: 'محمد',
      currentRollId: null,
      currentRollGeneratedRollId: null,
      currentRollTypeCode: null,
      currentRollTypeName: null,
      currentRollLastKnownWeightKg: null,
      selectable: selectable,
      canStartRollWorkerSession: selectable,
      blocked: false,
      blockedReason: null,
      handoverPending: false,
      takeoverRequestStatus: null,
      takeoverIncomingOperatorName: null,
      lineLifecycleStatus: selectable ? 'ACTIVE' : 'NO_ACTIVE_SHIFT',
      updatedAt: null,
    );

/// Poll intervals long enough never to fire during a test — call-count
/// assertions then only see initial-build / SSE / manual refreshes.
const RollWorkerBootstrapPollConfig _slowConfig = RollWorkerBootstrapPollConfig(
  safetyNetInterval: Duration(seconds: 100),
  eventDebounce: Duration(milliseconds: 20),
);

ProviderContainer _container(
  RollWorkerBootstrapRepository repo, {
  RollWorkerBootstrapPollConfig config = _slowConfig,
  FakeRollWorkerLinesSseClient? sse,
  MultiLineSessionRegistry Function()? registry,
}) {
  final FakeRollWorkerLinesSseClient sseClient =
      sse ?? FakeRollWorkerLinesSseClient();
  final c = ProviderContainer(
    overrides: <Override>[
      rollWorkerBootstrapRepositoryProvider.overrideWithValue(repo),
      rollWorkerBootstrapPollConfigProvider.overrideWithValue(config),
      rollWorkerLinesSseClientProvider.overrideWithValue(sseClient),
      if (registry != null)
        multiLineSessionRegistryProvider.overrideWith(registry),
    ],
  );
  addTearDown(sseClient.dispose);
  addTearDown(c.dispose);
  return c;
}

/// Lets the microtask-scheduled initial refresh (and any follow-up async
/// work) settle.
Future<void> _settle() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  group('RollWorkerBootstrapController — lifecycle', () {
    test('initial build kicks off a refresh that resolves to Loaded', () async {
      final repo = _MockRepo();
      when(repo.fetch).thenAnswer(
        (_) async => RollWorkerBootstrapSuccess(<RollWorkerBootstrapLine>[
          _line(1),
        ]),
      );
      final container = _container(repo);

      container.read(rollWorkerBootstrapControllerProvider);
      await _settle();

      final state = container.read(rollWorkerBootstrapControllerProvider);
      expect(state, isA<RollWorkerBootstrapLoaded>());
      expect(
        (state as RollWorkerBootstrapLoaded).lines.single.thermoformingLineId,
        1,
      );
    });

    test('a foreground refresh failure preserves the previous list', () async {
      final repo = _MockRepo();
      int call = 0;
      when(repo.fetch).thenAnswer((_) async {
        call++;
        if (call == 1) {
          return RollWorkerBootstrapSuccess(<RollWorkerBootstrapLine>[
            _line(1),
          ]);
        }
        return const RollWorkerBootstrapFailure(NetworkFailure());
      });
      final container = _container(repo);

      container.read(rollWorkerBootstrapControllerProvider);
      await _settle();

      await container
          .read(rollWorkerBootstrapControllerProvider.notifier)
          .refresh();

      final state = container.read(rollWorkerBootstrapControllerProvider);
      expect(state, isA<RollWorkerBootstrapFailureState>());
      expect(
        (state as RollWorkerBootstrapFailureState)
            .previous
            .single
            .thermoformingLineId,
        1,
      );
    });

    test(
      'a background refresh failure keeps the last good list on screen',
      () async {
        final repo = _MockRepo();
        int call = 0;
        when(repo.fetch).thenAnswer((_) async {
          call++;
          if (call == 1) {
            return RollWorkerBootstrapSuccess(<RollWorkerBootstrapLine>[
              _line(1),
            ]);
          }
          return const RollWorkerBootstrapFailure(NetworkFailure());
        });
        final container = _container(repo);

        container.read(rollWorkerBootstrapControllerProvider);
        await _settle();

        await container
            .read(rollWorkerBootstrapControllerProvider.notifier)
            .refresh(background: true);

        final state = container.read(rollWorkerBootstrapControllerProvider);
        expect(state, isA<RollWorkerBootstrapLoaded>());
        expect((state as RollWorkerBootstrapLoaded).lines.single.lineCode,
            'TH-01');
      },
    );

    test(
      'refresh drops disappeared shiftLineIds from the picker selection',
      () async {
        final repo = _MockRepo();
        int call = 0;
        when(repo.fetch).thenAnswer((_) async {
          call++;
          if (call == 1) {
            return RollWorkerBootstrapSuccess(<RollWorkerBootstrapLine>[
              _line(7),
              _line(8),
            ]);
          }
          return RollWorkerBootstrapSuccess(<RollWorkerBootstrapLine>[
            _line(8),
          ]);
        });
        final container = _container(repo);

        container.read(pickerShiftLineSelectionProvider.notifier)
          ..add(1007)
          ..add(1008);

        container.read(rollWorkerBootstrapControllerProvider);
        await _settle();
        expect(
          container.read(pickerShiftLineSelectionProvider),
          <int>{1007, 1008},
        );

        await container
            .read(rollWorkerBootstrapControllerProvider.notifier)
            .refresh();

        expect(container.read(pickerShiftLineSelectionProvider), <int>{1008});
      },
    );

    test(
      'a row that goes non-selectable is dropped from the selection',
      () async {
        final repo = _MockRepo();
        int call = 0;
        when(repo.fetch).thenAnswer((_) async {
          call++;
          if (call == 1) {
            return RollWorkerBootstrapSuccess(<RollWorkerBootstrapLine>[
              _line(7),
            ]);
          }
          return RollWorkerBootstrapSuccess(<RollWorkerBootstrapLine>[
            _line(7, selectable: false),
          ]);
        });
        final container = _container(repo);

        container.read(pickerShiftLineSelectionProvider.notifier).add(1007);

        container.read(rollWorkerBootstrapControllerProvider);
        await _settle();
        expect(container.read(pickerShiftLineSelectionProvider), <int>{1007});

        await container
            .read(rollWorkerBootstrapControllerProvider.notifier)
            .refresh();

        expect(container.read(pickerShiftLineSelectionProvider), <int>{});
      },
    );
  });

  group('RollWorkerBootstrapController — SSE trigger', () {
    test('an SSE connect handshake refetches /bootstrap immediately', () async {
      final repo = _MockRepo();
      int calls = 0;
      when(repo.fetch).thenAnswer((_) async {
        calls++;
        return const RollWorkerBootstrapSuccess(<RollWorkerBootstrapLine>[]);
      });
      final sse = FakeRollWorkerLinesSseClient();
      final container = _container(repo, sse: sse);

      container.read(rollWorkerBootstrapControllerProvider);
      await _settle();
      expect(calls, 1, reason: 'initial-build fetch');

      sse.emit(const PickerSseConnected());
      await _settle();

      expect(calls, 2, reason: 'connect handshake triggers an immediate fetch');
    });

    test('an SSE reconnect refetches /bootstrap immediately', () async {
      final repo = _MockRepo();
      int calls = 0;
      when(repo.fetch).thenAnswer((_) async {
        calls++;
        return const RollWorkerBootstrapSuccess(<RollWorkerBootstrapLine>[]);
      });
      final sse = FakeRollWorkerLinesSseClient();
      final container = _container(repo, sse: sse);

      container.read(rollWorkerBootstrapControllerProvider);
      await _settle();

      sse.emit(const PickerSseReconnected());
      await _settle();

      expect(calls, 2);
    });

    test(
      'a burst of SSE refresh frames collapses into one debounced refetch',
      () async {
        final repo = _MockRepo();
        int calls = 0;
        when(repo.fetch).thenAnswer((_) async {
          calls++;
          return const RollWorkerBootstrapSuccess(<RollWorkerBootstrapLine>[]);
        });
        final sse = FakeRollWorkerLinesSseClient();
        final container = _container(repo, sse: sse);

        container.read(rollWorkerBootstrapControllerProvider);
        await _settle();
        expect(calls, 1);

        sse
          ..emit(const PickerSseRefreshTriggered(type: 'LINE_STATE_CHANGED'))
          ..emit(const PickerSseRefreshTriggered(type: 'PRODUCT_CHANGED'))
          ..emit(const PickerSseRefreshTriggered(type: 'LINE_STATE_CHANGED'));
        await Future<void>.delayed(const Duration(milliseconds: 60));

        expect(
          calls,
          2,
          reason: 'three frames within the debounce window → one refetch',
        );
      },
    );
  });

  group('RollWorkerBootstrapController — refresh ordering', () {
    test(
      'an out-of-order /bootstrap response never overwrites a fresher one',
      () async {
        final repo = _MockRepo();
        // fetch() call N resolves via completers[N]: [0]=initial-build,
        // [1]=older refresh, [2]=newer refresh.
        final completers = <Completer<RollWorkerBootstrapResult>>[
          Completer<RollWorkerBootstrapResult>(),
          Completer<RollWorkerBootstrapResult>(),
          Completer<RollWorkerBootstrapResult>(),
        ];
        int call = 0;
        when(repo.fetch).thenAnswer((_) => completers[call++].future);
        final container = _container(repo);

        container.read(rollWorkerBootstrapControllerProvider);
        completers[0].complete(
          RollWorkerBootstrapSuccess(<RollWorkerBootstrapLine>[_line(1)]),
        );
        await _settle();
        final notifier = container.read(
          rollWorkerBootstrapControllerProvider.notifier,
        );

        // Two background refreshes in flight: older issued first, newer
        // second.
        final Future<void> older = notifier.refresh(
          trigger: 'poll',
          background: true,
        );
        final Future<void> newer = notifier.refresh(
          trigger: 'sse-event',
          background: true,
        );

        // The newer refresh resolves first with the fresh row...
        completers[2].complete(
          RollWorkerBootstrapSuccess(<RollWorkerBootstrapLine>[_line(9)]),
        );
        // ...then the older refresh resolves late with a now-stale row.
        completers[1].complete(
          RollWorkerBootstrapSuccess(<RollWorkerBootstrapLine>[_line(1)]),
        );
        await Future.wait(<Future<void>>[older, newer]);
        await _settle();

        final state = container.read(rollWorkerBootstrapControllerProvider);
        expect(state, isA<RollWorkerBootstrapLoaded>());
        expect(
          (state as RollWorkerBootstrapLoaded).lines.single.thermoformingLineId,
          9,
          reason: 'the superseded older response must be discarded',
        );
      },
    );
  });

  group('RollWorkerBootstrapController — safety-net poll', () {
    test('cadence is the disconnected tier while SSE is not connected', () async {
      final repo = _MockRepo();
      when(repo.fetch).thenAnswer(
        (_) async => const RollWorkerBootstrapSuccess(<RollWorkerBootstrapLine>[]),
      );
      final container = _container(repo);

      container.read(rollWorkerBootstrapControllerProvider);
      await _settle();

      expect(
        container
            .read(rollWorkerBootstrapControllerProvider.notifier)
            .currentPollInterval,
        _slowConfig.safetyNetInterval,
      );
    });

    test('poll is OFF once SSE is connected (handoff §4)', () async {
      final repo = _MockRepo();
      when(repo.fetch).thenAnswer(
        (_) async => const RollWorkerBootstrapSuccess(<RollWorkerBootstrapLine>[]),
      );
      final sse = FakeRollWorkerLinesSseClient();
      final container = _container(repo, sse: sse);

      container.read(rollWorkerBootstrapControllerProvider);
      await _settle();

      sse.emit(const PickerSseConnected());
      await _settle();

      final notifier = container.read(
        rollWorkerBootstrapControllerProvider.notifier,
      );
      expect(notifier.sseConnected, isTrue);
      // New contract (handoff §4): SSE connected → no poll. The fallback
      // poll only runs while the link is down.
      expect(notifier.currentPollInterval, isNull);
    });

    test('the safety-net poll keeps re-fetching on its cadence', () async {
      final repo = _MockRepo();
      int calls = 0;
      when(repo.fetch).thenAnswer((_) async {
        calls++;
        return const RollWorkerBootstrapSuccess(<RollWorkerBootstrapLine>[]);
      });
      const config = RollWorkerBootstrapPollConfig(
        safetyNetInterval: Duration(milliseconds: 30),
        eventDebounce: Duration(milliseconds: 20),
      );
      final container = _container(repo, config: config);

      container.read(rollWorkerBootstrapControllerProvider);
      await Future<void>.delayed(const Duration(milliseconds: 170));

      expect(calls, greaterThan(2), reason: 'the poll must keep re-fetching');
    });

    test('no duplicate poll timers while the cadence tier is unchanged', () async {
      final repo = _MockRepo();
      when(repo.fetch).thenAnswer(
        (_) async => const RollWorkerBootstrapSuccess(<RollWorkerBootstrapLine>[]),
      );
      const config = RollWorkerBootstrapPollConfig(
        safetyNetInterval: Duration(milliseconds: 30),
        eventDebounce: Duration(milliseconds: 20),
      );
      final container = _container(repo, config: config);

      container.read(rollWorkerBootstrapControllerProvider);
      await Future<void>.delayed(const Duration(milliseconds: 25));
      final notifier = container.read(
        rollWorkerBootstrapControllerProvider.notifier,
      );
      final int firstGeneration = notifier.pollTimerGeneration;
      expect(firstGeneration, greaterThanOrEqualTo(1));

      await Future<void>.delayed(const Duration(milliseconds: 130));

      expect(
        notifier.pollTimerGeneration,
        firstGeneration,
        reason: 'a same-tier recompute must not create a new timer',
      );
    });

    test('the poll is suspended once the worker logs in', () async {
      final repo = _MockRepo();
      when(repo.fetch).thenAnswer(
        (_) async => const RollWorkerBootstrapSuccess(<RollWorkerBootstrapLine>[]),
      );
      final container = _container(repo, registry: _FakeRegistry.new);

      container.read(rollWorkerBootstrapControllerProvider);
      await _settle();
      final notifier = container.read(
        rollWorkerBootstrapControllerProvider.notifier,
      );
      expect(notifier.currentPollInterval, isNotNull);

      (container.read(multiLineSessionRegistryProvider.notifier)
              as _FakeRegistry)
          .goActive();
      await _settle();

      expect(notifier.currentPollInterval, isNull);
    });

    test('returning to the picker re-fetches and resumes the poll', () async {
      final repo = _MockRepo();
      int calls = 0;
      when(repo.fetch).thenAnswer((_) async {
        calls++;
        return const RollWorkerBootstrapSuccess(<RollWorkerBootstrapLine>[]);
      });
      final container = _container(repo, registry: _FakeRegistry.new);

      container.read(rollWorkerBootstrapControllerProvider);
      await _settle();
      final fake =
          container.read(multiLineSessionRegistryProvider.notifier)
              as _FakeRegistry;

      fake.goActive();
      await _settle();
      final int callsAfterLogin = calls;

      fake.goEmpty();
      await _settle();

      expect(calls, greaterThan(callsAfterLogin));
      expect(
        container
            .read(rollWorkerBootstrapControllerProvider.notifier)
            .currentPollInterval,
        isNotNull,
      );
    });
  });
}
