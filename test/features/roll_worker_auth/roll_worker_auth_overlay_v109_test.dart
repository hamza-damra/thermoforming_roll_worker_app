import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:thermoforming_roll_worker/core/errors/app_failure.dart';
import 'package:thermoforming_roll_worker/core/errors/error_code.dart';
import 'package:thermoforming_roll_worker/core/storage/session_index_storage.dart';
import 'package:thermoforming_roll_worker/core/storage/storage_providers.dart';
import 'package:thermoforming_roll_worker/core/theme/app_theme.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/data/roll_worker_auth_providers.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/domain/entities/batch_auth_outcome.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/domain/entities/roll_worker_session.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/domain/session_batch_repository.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/presentation/controllers/multi_line_session_registry.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/presentation/controllers/multi_line_session_registry_state.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/presentation/widgets/roll_worker_auth_overlay.dart';

/// V109 integration test: the PIN overlay drives the real
/// [BatchAuthController] → [SessionBatchRepository] → [MultiLineSessionRegistry]
/// chain. Login while a roll is mounted on the line now SUCCEEDS on the normal
/// auth path (the backend no longer throws ROLL_WORKER_TAKEOVER_REQUIRED), so
/// no takeover screen is ever shown and the registry is seeded directly.
class _MockBatchRepo extends Mock implements SessionBatchRepository {}

class _MockIndexRaw extends Mock implements FlutterSecureStorage {}

const int _kShiftLineId = 800;

BatchAuthOutcome _outcome() => BatchAuthOutcome(
  rollWorkerOperatorId: 77,
  rollWorkerName: 'Yusuf',
  sessions: <int, RollWorkerSession>{
    _kShiftLineId: RollWorkerSession(
      sessionId: 1,
      rollWorkerOperatorId: 77,
      rollWorkerName: 'Yusuf',
      thermoformingShiftId: 9001,
      thermoformingShiftLineId: _kShiftLineId,
      thermoformingLineId: 11,
      palletizingLineId: 21,
      startedAt: DateTime.parse('2026-05-10T10:00:00Z'),
    ),
  },
);

ProviderContainer _container(SessionBatchRepository repo) {
  final raw = _MockIndexRaw();
  when(
    () => raw.read(key: any<String>(named: 'key')),
  ).thenAnswer((_) async => null);
  when(
    () => raw.write(
      key: any<String>(named: 'key'),
      value: any<String>(named: 'value'),
    ),
  ).thenAnswer((_) async {});

  final c = ProviderContainer(
    overrides: <Override>[
      sessionBatchRepositoryProvider.overrideWithValue(repo),
      sessionIndexStorageProvider.overrideWithValue(
        SessionIndexStorage.withStorage(raw),
      ),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

Widget _wrap(ProviderContainer container) => UncontrolledProviderScope(
  container: container,
  child: MaterialApp(
    theme: AppTheme.light(),
    home: const Scaffold(
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: RollWorkerAuthOverlay(
              shiftLineId: _kShiftLineId,
              accentColor: Colors.teal,
            ),
          ),
        ],
      ),
    ),
  ),
);

Future<void> _enterPinAndSubmit(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField), '1234');
  await tester.pump();
  await tester.tap(find.text(RollWorkerAuthOverlay.submitLabel));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    registerFallbackValue(<int>{});
  });

  testWidgets(
    'login on a line with a roll mounted succeeds → registry seeded, '
    'no takeover screen, no error',
    (WidgetTester tester) async {
      final repo = _MockBatchRepo();
      when(
        () => repo.startBatch(
          pin: '1234',
          shiftLineIds: <int>{_kShiftLineId},
        ),
      ).thenAnswer((_) async => BatchAuthSuccessResult(_outcome()));

      final container = _container(repo);
      await tester.pumpWidget(_wrap(container));
      await tester.pumpAndSettle();

      await _enterPinAndSubmit(tester);

      // The full chain ran: overlay → controller → repository → registry.
      final state = container.read(multiLineSessionRegistryProvider);
      expect(state, isA<RegistryActive>());
      expect(
        (state as RegistryActive).sessions.keys.toSet(),
        <int>{_kShiftLineId},
      );
      verify(
        () => repo.startBatch(pin: '1234', shiftLineIds: <int>{_kShiftLineId}),
      ).called(1);
    },
  );

  testWidgets(
    'a business failure shows a plain inline error — no takeover flow',
    (WidgetTester tester) async {
      final repo = _MockBatchRepo();
      when(
        () => repo.startBatch(
          pin: '1234',
          shiftLineIds: <int>{_kShiftLineId},
        ),
      ).thenAnswer(
        (_) async => const BatchAuthFailureResult(
          BusinessFailure(code: ErrorCode.operatorPinInvalid),
        ),
      );

      final container = _container(repo);
      await tester.pumpWidget(_wrap(container));
      await tester.pumpAndSettle();

      await _enterPinAndSubmit(tester);

      // Generic mapped error; registry never became active (no session seeded).
      expect(find.text('رمز PIN غير صحيح.'), findsOneWidget);
      expect(
        container.read(multiLineSessionRegistryProvider),
        isNot(isA<RegistryActive>()),
      );
    },
  );
}
