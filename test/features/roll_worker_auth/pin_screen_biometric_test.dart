import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:thermoforming_roll_worker/core/errors/app_failure.dart';
import 'package:thermoforming_roll_worker/core/errors/biometric_denial.dart';
import 'package:thermoforming_roll_worker/core/errors/error_code.dart';
import 'package:thermoforming_roll_worker/core/storage/session_index_storage.dart';
import 'package:thermoforming_roll_worker/core/storage/storage_providers.dart';
import 'package:thermoforming_roll_worker/core/theme/app_theme.dart';
import 'package:thermoforming_roll_worker/features/biometric_login/data/biometric_login_providers.dart';
import 'package:thermoforming_roll_worker/features/biometric_login/domain/biometric_attempt_repository.dart';
import 'package:thermoforming_roll_worker/features/biometric_login/domain/entities/biometric_attempt_status.dart';
import 'package:thermoforming_roll_worker/features/biometric_login/presentation/controllers/biometric_poll_config.dart';
import 'package:thermoforming_roll_worker/features/biometric_login/presentation/widgets/biometric_login_dialog.dart';
import 'package:thermoforming_roll_worker/features/biometric_login/presentation/widgets/biometric_login_strings.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/data/roll_worker_auth_providers.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/domain/entities/batch_auth_outcome.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/domain/entities/roll_worker_session.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/domain/session_batch_repository.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/presentation/controllers/batch_auth_controller.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/presentation/controllers/batch_auth_state.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/presentation/screens/pin_screen.dart';
import 'package:thermoforming_roll_worker/features/sessions_me/presentation/controllers/sessions_me_controller.dart';
import 'package:thermoforming_roll_worker/features/sessions_me/presentation/controllers/sessions_me_state.dart';

class _MockBatchRepo extends Mock implements SessionBatchRepository {}

class _MockIndex extends Mock implements SessionIndexStorage {}

class _InertSessionsMe extends SessionsMeController {
  @override
  SessionsMeState build() => const SessionsMeIdle();
}

class _HeldStatusRepo implements BiometricAttemptRepository {
  final List<Completer<BiometricStatusResult>> polls =
      <Completer<BiometricStatusResult>>[];

  @override
  Future<BiometricStatusResult> getStatus({
    required String? statusPath,
    required String attemptToken,
  }) {
    final Completer<BiometricStatusResult> c =
        Completer<BiometricStatusResult>();
    polls.add(c);
    return c.future;
  }
}

const Set<int> _ids = <int>{800, 801};
const String _home = 'picker-home';

BatchAuthOutcome _outcome() => BatchAuthOutcome(
  rollWorkerOperatorId: 77,
  rollWorkerName: 'Yusuf',
  sessions: <int, RollWorkerSession>{
    for (final int id in _ids)
      id: RollWorkerSession(
        sessionId: id,
        rollWorkerOperatorId: 77,
        rollWorkerName: 'Yusuf',
        thermoformingShiftId: 9001,
        thermoformingShiftLineId: id,
        thermoformingLineId: id - 700,
        palletizingLineId: id - 600,
        startedAt: DateTime.utc(2026, 9, 24, 8),
      ),
  },
);

final BatchAuthResult _denied = BatchAuthFailureResult(
  BiometricDenialFailure(
    denial: const BiometricDenial(
      code: 'BIOMETRIC_VERIFICATION_REQUIRED',
      message: 'يرجى تمرير البصمة على جهاز البصمة ثم إعادة المحاولة.',
      validitySeconds: 300,
      attemptAvailable: true,
      attemptToken: 'secret-token',
    ),
    statusCode: 403,
  ),
);

/// Pushes [PinScreen] over a stand-in picker so its success / per-line pops
/// are observable.
Future<ProviderContainer> _open(
  WidgetTester tester,
  List<BatchAuthResult> logins,
  _HeldStatusRepo status,
) async {
  final repo = _MockBatchRepo();
  when(
    () => repo.startBatch(pin: '1234', shiftLineIds: _ids),
  ).thenAnswer((_) async => logins.removeAt(0));
  final index = _MockIndex();
  when(() => index.writeIds(any())).thenAnswer((_) async {});
  when(index.readIds).thenAnswer((_) async => <int>{});

  final container = ProviderContainer(
    overrides: <Override>[
      sessionBatchRepositoryProvider.overrideWithValue(repo),
      sessionIndexStorageProvider.overrideWithValue(index),
      sessionsMeControllerProvider.overrideWith(_InertSessionsMe.new),
      biometricAttemptRepositoryProvider.overrideWithValue(status),
      biometricPollConfigProvider.overrideWithValue(
        const BiometricPollConfig(minPollSpacing: Duration.zero),
      ),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (BuildContext context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => const PinScreen(shiftLineIds: _ids),
                  ),
                ),
                child: const Text(_home),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text(_home));
  await tester.pumpAndSettle();

  await tester.enterText(find.byType(TextField), '1234');
  await tester.tap(find.text(PinScreen.submitLabel));
  await _frames(tester);
  return container;
}

Future<void> _frames(WidgetTester tester, [int n = 8]) async {
  for (int i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  setUpAll(() {
    registerFallbackValue(<int>{});
  });

  testWidgets('biometric 403 → dialog; VERIFIED → success pops the PIN screen', (
    WidgetTester tester,
  ) async {
    final status = _HeldStatusRepo();
    final container = await _open(
      tester,
      <BatchAuthResult>[_denied, BatchAuthSuccessResult(_outcome())],
      status,
    );

    expect(find.byType(BiometricLoginDialog), findsOneWidget);
    expect(find.byType(PinScreen), findsOneWidget);

    status.polls.last.complete(
      const BiometricStatusAnswered(
        BiometricAttemptStatusResponse(status: BiometricAttemptStatus.verified),
      ),
    );
    await _frames(tester);
    await tester.pumpAndSettle();

    expect(find.byType(BiometricLoginDialog), findsNothing);
    expect(find.byType(PinScreen), findsNothing);
    expect(find.text(_home), findsOneWidget);
    expect(
      container.read(batchAuthControllerProvider),
      isA<BatchAuthSuccess>(),
    );
  });

  testWidgets(
    'a per-line conflict on resubmit pops the PIN screen — not the dialog — '
    'and keeps the conflict ids for the picker',
    (WidgetTester tester) async {
      final status = _HeldStatusRepo();
      final container = await _open(tester, <BatchAuthResult>[
        _denied,
        const BatchAuthFailureResult(
          BusinessFailure(
            code: ErrorCode.rollWorkerSessionLineUsedByOtherWorker,
          ),
          conflictShiftLineIds: <int>{801},
        ),
      ], status);

      status.polls.last.complete(
        const BiometricStatusAnswered(
          BiometricAttemptStatusResponse(
            status: BiometricAttemptStatus.notRequired,
          ),
        ),
      );
      await _frames(tester);
      await tester.pumpAndSettle();

      expect(find.byType(BiometricLoginDialog), findsNothing);
      expect(find.byType(PinScreen), findsNothing);
      expect(find.text(_home), findsOneWidget);
      final BatchAuthState state = container.read(batchAuthControllerProvider);
      expect(state, isA<BatchAuthFailure>());
      expect((state as BatchAuthFailure).conflictShiftLineIds, <int>{801});
    },
  );

  testWidgets('cancel keeps the PIN screen open and re-enables it', (
    WidgetTester tester,
  ) async {
    final status = _HeldStatusRepo();
    final container = await _open(tester, <BatchAuthResult>[_denied], status);

    await tester.tap(find.text(BiometricLoginStrings.cancelButton));
    await tester.pumpAndSettle();

    expect(find.byType(BiometricLoginDialog), findsNothing);
    expect(find.byType(PinScreen), findsOneWidget);
    expect(
      container.read(batchAuthControllerProvider),
      isA<BatchAuthInitial>(),
    );
    final TextField field = tester.widget(find.byType(TextField));
    expect(field.enabled, isTrue);
  });
}
