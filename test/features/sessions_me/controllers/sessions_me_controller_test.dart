import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:thermoforming_roll_worker/core/errors/app_failure.dart';
import 'package:thermoforming_roll_worker/core/errors/error_code.dart';
import 'package:thermoforming_roll_worker/core/storage/session_index_storage.dart';
import 'package:thermoforming_roll_worker/core/storage/storage_providers.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/data/roll_worker_auth_providers.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/domain/entities/roll_worker_session.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/domain/roll_worker_auth_repository.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/presentation/controllers/multi_line_session_registry.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/presentation/controllers/multi_line_session_registry_state.dart';
import 'package:thermoforming_roll_worker/features/sessions_me/data/dto/roll_worker_me_response.dart';
import 'package:thermoforming_roll_worker/features/sessions_me/data/sessions_me_providers.dart';
import 'package:thermoforming_roll_worker/features/sessions_me/domain/entities/roll_worker_me.dart';
import 'package:thermoforming_roll_worker/features/sessions_me/domain/sessions_me_repository.dart';
import 'package:thermoforming_roll_worker/features/sessions_me/presentation/controllers/sessions_me_controller.dart';
import 'package:thermoforming_roll_worker/features/sessions_me/presentation/controllers/sessions_me_poll_config.dart';
import 'package:thermoforming_roll_worker/features/sessions_me/presentation/controllers/sessions_me_state.dart';

class _MockAuthRepo extends Mock implements RollWorkerAuthRepository {}

class _MockSessionsMeRepo extends Mock implements SessionsMeRepository {}

class _MockRawStorage extends Mock implements FlutterSecureStorage {}

/// A worker-scoped `/sessions/me` payload listing exactly [shiftLineIds] as
/// ACTIVE. This is what the backend returns regardless of which line's token
/// was sent (handoff §3 — the token only identifies the worker).
RollWorkerMe _me(List<int> shiftLineIds) {
  return RollWorkerMeResponse.fromEnvelopeData(<String, dynamic>{
    'rollWorkerOperatorId': 7,
    'rollWorkerName': 'Ahmad',
    'lines': <Map<String, dynamic>>[
      for (final int id in shiftLineIds)
        <String, dynamic>{
          'sessionId': id * 10,
          'shiftLineId': id,
          'lineLifecycleStatus': 'ACTIVE',
          'sessionStartedAt': '2026-06-09T10:00:00.000+03:00',
        },
    ],
  });
}

RollWorkerSession _session(int shiftLineId) => RollWorkerSession(
  sessionId: shiftLineId * 10,
  rollWorkerOperatorId: 7,
  rollWorkerName: 'Ahmad',
  thermoformingShiftId: 900,
  thermoformingShiftLineId: shiftLineId,
  thermoformingLineId: shiftLineId + 100,
  palletizingLineId: shiftLineId + 200,
  startedAt: DateTime.parse('2026-06-09T10:00:00.000+03:00'),
);

class _Harness {
  _Harness()
    : auth = _MockAuthRepo(),
      meRepo = _MockSessionsMeRepo(),
      rawIndex = _MockRawStorage() {
    // Index storage: in-memory blob so the registry can persist its id set.
    when(
      () => rawIndex.read(key: any<String>(named: 'key')),
    ).thenAnswer((_) async => null);
    when(
      () => rawIndex.write(
        key: any<String>(named: 'key'),
        value: any<String>(named: 'value'),
      ),
    ).thenAnswer((_) async {});
    // notifySessionLost → repo.clearStoredToken; default no-op.
    when(() => auth.clearStoredToken(any<int>())).thenAnswer((_) async {});

    container = ProviderContainer(
      overrides: <Override>[
        rollWorkerAuthRepositoryProvider.overrideWithValue(auth),
        sessionIndexStorageProvider.overrideWithValue(
          SessionIndexStorage.withStorage(rawIndex),
        ),
        sessionsMeRepositoryProvider.overrideWithValue(meRepo),
        // Park the fallback poll far in the future so its periodic timer
        // never fires inside a synchronous test (it is cancelled on dispose).
        sessionsMePollConfigProvider.overrideWithValue(
          const SessionsMePollConfig(fallbackPollInterval: Duration(hours: 1)),
        ),
      ],
    );
  }

  final _MockAuthRepo auth;
  final _MockSessionsMeRepo meRepo;
  final _MockRawStorage rawIndex;
  late final ProviderContainer container;

  MultiLineSessionRegistry get registry =>
      container.read(multiLineSessionRegistryProvider.notifier);

  SessionsMeController get controller =>
      container.read(sessionsMeControllerProvider.notifier);

  MultiLineSessionRegistryState get registryState =>
      container.read(multiLineSessionRegistryProvider);

  Set<int> get registryIds {
    final MultiLineSessionRegistryState s = registryState;
    return s is RegistryActive ? s.sessions.keys.toSet() : <int>{};
  }

  void stubMe(RollWorkerMe me) {
    when(meRepo.fetchMe).thenAnswer((_) async => SessionsMeSuccess(me));
  }

  void stubMeFailure(AppFailure failure) {
    when(meRepo.fetchMe).thenAnswer((_) async => SessionsMeFailure(failure));
  }

  void dispose() => container.dispose();
}

void main() {
  group('SessionsMeController reconciliation (merge-based)', () {
    test(
      'start-batch [81] while 82 active + a stale /sessions/me=[82] does NOT '
      'drop 81 — registry keeps BOTH lines, no login loop',
      () async {
        final h = _Harness();
        addTearDown(h.dispose);

        // Worker already active on 82 on this device.
        await h.registry.onBatchSuccess(<int, RollWorkerSession>{
          82: _session(82),
        });
        // First /sessions/me confirms 82.
        h.stubMe(_me(<int>[82]));
        await h.controller.refresh(background: false);
        await pumpEventQueue();
        expect(h.registryIds, <int>{82});

        // Worker logs into 81 (additive start-batch). Registry merges → {81,82}.
        await h.registry.onBatchSuccess(<int, RollWorkerSession>{
          81: _session(81),
        });
        await pumpEventQueue();
        expect(h.registryIds, <int>{81, 82});

        // A stale / lagging /sessions/me still only lists 82 (read-after-write
        // race on the just-created 81). This MUST NOT drop 81.
        h.stubMe(_me(<int>[82]));
        await h.controller.refresh();
        await pumpEventQueue();

        expect(
          h.registryState,
          isA<RegistryActive>(),
          reason: 'A successful start-batch must never collapse to empty',
        );
        expect(
          h.registryIds,
          <int>{81, 82},
          reason: 'unconfirmed, freshly-added 81 must survive a stale me=[82]',
        );
        // No token was evicted for the transiently-omitted line.
        verifyNever(() => h.auth.clearStoredToken(81));
      },
    );

    test(
      'a successful /sessions/me merge never replaces the registry '
      '(both lines stay)',
      () async {
        final h = _Harness();
        addTearDown(h.dispose);

        await h.registry.onBatchSuccess(<int, RollWorkerSession>{
          81: _session(81),
          82: _session(82),
        });
        h.stubMe(_me(<int>[81, 82]));

        await h.controller.refresh(background: false);
        await pumpEventQueue();
        // A second identical response — still both, nothing dropped/replaced.
        await h.controller.refresh();
        await pumpEventQueue();

        expect(h.registryIds, <int>{81, 82});
        verifyNever(() => h.auth.clearStoredToken(any<int>()));
      },
    );

    test(
      'a CONFIRMED line later absent from a successful /sessions/me IS dropped '
      '(legitimate cascade still works)',
      () async {
        final h = _Harness();
        addTearDown(h.dispose);

        await h.registry.onBatchSuccess(<int, RollWorkerSession>{
          81: _session(81),
          82: _session(82),
        });

        // Confirm both lines present.
        h.stubMe(_me(<int>[81, 82]));
        await h.controller.refresh(background: false);
        await pumpEventQueue();
        expect(h.registryIds, <int>{81, 82});

        // 81 genuinely ends (operator ended shift). A current me omits it.
        h.stubMe(_me(<int>[82]));
        await h.controller.refresh();
        await pumpEventQueue();

        expect(h.registryIds, <int>{82});
        verify(() => h.auth.clearStoredToken(81)).called(1);
      },
    );

    test(
      'non-2xx /sessions/me (ROLL_WORKER_SESSION_REQUIRED) preserves the '
      'registry and evicts no token',
      () async {
        final h = _Harness();
        addTearDown(h.dispose);

        await h.registry.onBatchSuccess(<int, RollWorkerSession>{
          81: _session(81),
          82: _session(82),
        });
        // Confirm both first so we prove the failure path — not a missing
        // confirmation — is what keeps the lines.
        h.stubMe(_me(<int>[81, 82]));
        await h.controller.refresh(background: false);
        await pumpEventQueue();

        h.stubMeFailure(
          const BusinessFailure(code: ErrorCode.rollWorkerSessionRequired),
        );
        await h.controller.refresh();
        await pumpEventQueue();

        expect(
          h.registryState,
          isA<RegistryActive>(),
          reason: 'a non-2xx me is never evidence any line ended (handoff §6.4)',
        );
        expect(h.registryIds, <int>{81, 82});
        verifyNever(() => h.auth.clearStoredToken(any<int>()));
      },
    );

    test('non-2xx /sessions/me keeps the last good snapshot visible', () async {
      final h = _Harness();
      addTearDown(h.dispose);

      await h.registry.onBatchSuccess(<int, RollWorkerSession>{
        81: _session(81),
      });
      h.stubMe(_me(<int>[81]));
      await h.controller.refresh(background: false);
      await pumpEventQueue();
      expect(h.container.read(sessionsMeControllerProvider), isA<SessionsMeLoaded>());

      h.stubMeFailure(const NetworkFailure());
      await h.controller.refresh();
      await pumpEventQueue();

      final state = h.container.read(sessionsMeControllerProvider);
      expect(
        state,
        isA<SessionsMeLoaded>(),
        reason: 'a transient background failure must not blank the home shell',
      );
    });
  });
}
