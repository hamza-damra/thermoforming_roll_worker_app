import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:thermoforming_roll_worker/core/storage/session_index_storage.dart';
import 'package:thermoforming_roll_worker/core/storage/storage_providers.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/data/roll_worker_auth_providers.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/domain/entities/roll_worker_session.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/domain/roll_worker_auth_repository.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/presentation/controllers/multi_line_session_registry.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/presentation/controllers/multi_line_session_registry_state.dart';

class _MockAuthRepo extends Mock implements RollWorkerAuthRepository {}

class _MockIndexRaw extends Mock implements FlutterSecureStorage {}

RollWorkerSession _session(int id) => RollWorkerSession(
  sessionId: id,
  rollWorkerOperatorId: 77,
  rollWorkerName: 'Yusuf',
  thermoformingShiftId: 9001,
  thermoformingShiftLineId: id,
  thermoformingLineId: id + 100,
  palletizingLineId: id + 200,
  startedAt: DateTime.parse('2026-06-01T08:00:00.000+03:00'),
  status: 'ACTIVE',
);

void main() {
  late _MockAuthRepo auth;
  late _MockIndexRaw raw;
  late ProviderContainer container;

  setUp(() {
    auth = _MockAuthRepo();
    raw = _MockIndexRaw();
    when(() => raw.read(key: any<String>(named: 'key')))
        .thenAnswer((_) async => null);
    when(
      () => raw.write(
        key: any<String>(named: 'key'),
        value: any<String>(named: 'value'),
      ),
    ).thenAnswer((_) async {});
    when(() => auth.clearStoredToken(any<int>())).thenAnswer((_) async {});
    container = ProviderContainer(
      overrides: <Override>[
        rollWorkerAuthRepositoryProvider.overrideWithValue(auth),
        sessionIndexStorageProvider.overrideWithValue(
          SessionIndexStorage.withStorage(raw),
        ),
      ],
    );
    addTearDown(container.dispose);
  });

  test(
    'drops the line WITHOUT a network logout, emits DeliberateLogout, clears token',
    () async {
      final notifier =
          container.read(multiLineSessionRegistryProvider.notifier);
      await notifier.onBatchSuccess(<int, RollWorkerSession>{
        101: _session(101),
        102: _session(102),
      });

      await notifier.markSessionEndedLocally(101);

      final state = container.read(multiLineSessionRegistryProvider);
      expect(state, isA<RegistryActive>());
      final active = state as RegistryActive;
      expect(active.sessions.keys.toSet(), <int>{102});
      expect(active.activeShiftLineId, 102);
      expect(active.lastEvent, isA<DeliberateLogout>());
      // Token cleared locally; the network logout endpoint is NOT called
      // (keep-mounted already ended the session server-side).
      verify(() => auth.clearStoredToken(101)).called(1);
      verifyNever(() => auth.logout(any<int>()));
    },
  );

  test('on the last line, collapses to RegistryEmpty with DeliberateLogout',
      () async {
    final notifier = container.read(multiLineSessionRegistryProvider.notifier);
    await notifier.onBatchSuccess(<int, RollWorkerSession>{101: _session(101)});

    await notifier.markSessionEndedLocally(101);

    final state = container.read(multiLineSessionRegistryProvider);
    expect(state, isA<RegistryEmpty>());
    expect((state as RegistryEmpty).lastEvent, isA<DeliberateLogout>());
  });
}
