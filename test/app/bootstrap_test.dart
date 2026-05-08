import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:thermoforming_roll_worker/app/app.dart';
import 'package:thermoforming_roll_worker/app/bootstrap_screen.dart';
import 'package:thermoforming_roll_worker/core/config/app_config.dart';
import 'package:thermoforming_roll_worker/core/config/config_providers.dart';
import 'package:thermoforming_roll_worker/core/errors/app_failure.dart';
import 'package:thermoforming_roll_worker/core/errors/error_code.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/data/roll_worker_auth_providers.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/domain/entities/roll_worker_session.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/presentation/controllers/roll_worker_auth_controller.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/domain/roll_worker_auth_repository.dart';
import 'package:thermoforming_roll_worker/features/shift_line/presentation/controllers/selected_shift_line_provider.dart';

class _MockRepo extends Mock implements RollWorkerAuthRepository {}

const AppConfig _testConfig = AppConfig(
  apiBaseUrl: 'https://test.local',
  deviceKey: 'k',
);

const int kShiftLineId = 800;

void main() {
  testWidgets(
    'no shiftLineId selected → shows the waiting-for-line backend-gap screen',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            appConfigProvider.overrideWithValue(_testConfig),
          ],
          child: const RollWorkerApp(),
        ),
      );
      // The waiting screen contains a passive heartbeat indicator that
      // never settles. Use a bounded pump instead of pumpAndSettle.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('بانتظار فتح خط من تطبيق المشغّل'), findsOneWidget);
      expect(find.text('قائمة الخطوط غير متاحة حاليًا'), findsOneWidget);
    },
  );

  testWidgets('shiftLineId selected and no session → routes to PIN screen', (
    WidgetTester tester,
  ) async {
    final repo = _MockRepo();
    when(() => repo.getCurrentSession(kShiftLineId)).thenAnswer(
      // ROLL_WORKER_SESSION_REQUIRED → unauthenticated route to PIN.
      (_) async => const RollWorkerAuthFailure(
        BusinessFailure(code: ErrorCode.rollWorkerSessionRequired),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          appConfigProvider.overrideWithValue(_testConfig),
          selectedShiftLineIdProvider.overrideWith(
            () => _StaticShiftLineNotifier(kShiftLineId),
          ),
          rollWorkerAuthRepositoryProvider.overrideWithValue(repo),
        ],
        child: const RollWorkerApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('تسجيل دخول عامل الرولات'), findsWidgets);
    expect(find.text('دخول'), findsOneWidget);
  });

  testWidgets(
    'authenticated session → routes to home placeholder with logout button',
    (WidgetTester tester) async {
      final repo = _MockRepo();
      when(() => repo.getCurrentSession(kShiftLineId)).thenAnswer(
        (_) async => RollWorkerAuthSuccess(
          RollWorkerSession(
            sessionId: 1,
            rollWorkerOperatorId: 1,
            rollWorkerName: 'Ahmad',
            thermoformingShiftId: 700,
            thermoformingShiftLineId: kShiftLineId,
            thermoformingLineId: 200,
            palletizingLineId: 10,
            startedAt: DateTime.parse('2026-05-08T13:00:00Z'),
            startedAtDisplay: '2026-05-08، 1:00 مساءً',
            status: 'ACTIVE',
          ),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            appConfigProvider.overrideWithValue(_testConfig),
            selectedShiftLineIdProvider.overrideWith(
              () => _StaticShiftLineNotifier(kShiftLineId),
            ),
            rollWorkerAuthRepositoryProvider.overrideWithValue(repo),
          ],
          child: const RollWorkerApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ahmad'), findsOneWidget);
      expect(find.text('تسجيل خروج عامل الرولات'), findsOneWidget);
      // RTL is preserved everywhere.
      final BuildContext ctx = tester.element(find.byType(Scaffold).first);
      expect(Directionality.of(ctx), TextDirection.rtl);
    },
  );

  testWidgets(
    'cascade snackbar shows when active session disappears (silent loss)',
    (WidgetTester tester) async {
      final repo = _MockRepo();
      // First check returns ACTIVE. Second check (after we trigger
      // notifySessionLost) drops to silent-loss Unauthenticated.
      when(() => repo.getCurrentSession(kShiftLineId)).thenAnswer(
        (_) async => RollWorkerAuthSuccess(
          RollWorkerSession(
            sessionId: 1,
            rollWorkerOperatorId: 1,
            rollWorkerName: 'Ahmad',
            thermoformingShiftId: 700,
            thermoformingShiftLineId: kShiftLineId,
            thermoformingLineId: 200,
            palletizingLineId: 10,
            startedAt: DateTime.parse('2026-05-08T13:00:00Z'),
            status: 'ACTIVE',
          ),
        ),
      );
      when(() => repo.clearStoredToken(kShiftLineId)).thenAnswer((_) async {});

      late ProviderContainer container;
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            appConfigProvider.overrideWithValue(_testConfig),
            selectedShiftLineIdProvider.overrideWith(
              () => _StaticShiftLineNotifier(kShiftLineId),
            ),
            rollWorkerAuthRepositoryProvider.overrideWithValue(repo),
          ],
          child: Builder(
            builder: (context) {
              container = ProviderScope.containerOf(context);
              return const RollWorkerApp();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Sanity: we landed on the home placeholder.
      expect(find.text('Ahmad'), findsOneWidget);

      // Simulate cascade-on-end: a Stage 5+ feature would call this when a
      // mutating endpoint returns ROLL_WORKER_SESSION_REQUIRED.
      await container
          .read(rollWorkerAuthControllerProvider(kShiftLineId).notifier)
          .notifySessionLost();
      await tester.pump(); // build PIN screen
      await tester.pump(); // process snackbar

      expect(find.text(BootstrapScreen.cascadeMessage), findsOneWidget);
    },
  );

  testWidgets('cascade snackbar does NOT show on a deliberate logout', (
    WidgetTester tester,
  ) async {
    final repo = _MockRepo();
    when(() => repo.getCurrentSession(kShiftLineId)).thenAnswer(
      (_) async => RollWorkerAuthSuccess(
        RollWorkerSession(
          sessionId: 1,
          rollWorkerOperatorId: 1,
          rollWorkerName: 'Ahmad',
          thermoformingShiftId: 700,
          thermoformingShiftLineId: kShiftLineId,
          thermoformingLineId: 200,
          palletizingLineId: 10,
          startedAt: DateTime.parse('2026-05-08T13:00:00Z'),
          status: 'ACTIVE',
        ),
      ),
    );
    when(() => repo.logout(kShiftLineId)).thenAnswer((_) async {});

    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          appConfigProvider.overrideWithValue(_testConfig),
          selectedShiftLineIdProvider.overrideWith(
            () => _StaticShiftLineNotifier(kShiftLineId),
          ),
          rollWorkerAuthRepositoryProvider.overrideWithValue(repo),
        ],
        child: Builder(
          builder: (context) {
            container = ProviderScope.containerOf(context);
            return const RollWorkerApp();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await container
        .read(rollWorkerAuthControllerProvider(kShiftLineId).notifier)
        .logout();
    await tester.pump();
    await tester.pump();

    expect(find.text(BootstrapScreen.cascadeMessage), findsNothing);
  });

  testWidgets('app-resume triggers checkSession for the active shift-line', (
    WidgetTester tester,
  ) async {
    final repo = _MockRepo();
    // Both calls (mount + resume) return the same active session — we
    // assert by call count.
    when(() => repo.getCurrentSession(kShiftLineId)).thenAnswer(
      (_) async => RollWorkerAuthSuccess(
        RollWorkerSession(
          sessionId: 1,
          rollWorkerOperatorId: 1,
          rollWorkerName: 'Ahmad',
          thermoformingShiftId: 700,
          thermoformingShiftLineId: kShiftLineId,
          thermoformingLineId: 200,
          palletizingLineId: 10,
          startedAt: DateTime.parse('2026-05-08T13:00:00Z'),
          status: 'ACTIVE',
        ),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          appConfigProvider.overrideWithValue(_testConfig),
          selectedShiftLineIdProvider.overrideWith(
            () => _StaticShiftLineNotifier(kShiftLineId),
          ),
          rollWorkerAuthRepositoryProvider.overrideWithValue(repo),
        ],
        child: const RollWorkerApp(),
      ),
    );
    await tester.pumpAndSettle();

    // First check happened on mount.
    verify(() => repo.getCurrentSession(kShiftLineId)).called(1);

    // Simulate the app being backgrounded then resumed.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    verify(() => repo.getCurrentSession(kShiftLineId)).called(1);
  });

  testWidgets(
    'app-resume does NOT call checkSession when no shift-line is selected',
    (WidgetTester tester) async {
      final repo = _MockRepo();
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            appConfigProvider.overrideWithValue(_testConfig),
            rollWorkerAuthRepositoryProvider.overrideWithValue(repo),
          ],
          child: const RollWorkerApp(),
        ),
      );
      // Waiting screen has a passive heartbeat — bounded pumps only.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      verifyNever(() => repo.getCurrentSession(any<int>()));
    },
  );
}

class _StaticShiftLineNotifier extends SelectedShiftLineNotifier {
  _StaticShiftLineNotifier(this.initial);
  final int initial;

  @override
  int? build() => initial;
}
