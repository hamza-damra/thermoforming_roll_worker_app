import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:thermoforming_roll_worker/app/app.dart';
import 'package:thermoforming_roll_worker/core/config/app_config.dart';
import 'package:thermoforming_roll_worker/core/config/config_providers.dart';
import 'package:thermoforming_roll_worker/core/errors/app_failure.dart';
import 'package:thermoforming_roll_worker/core/errors/error_code.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/data/roll_worker_auth_providers.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/domain/entities/roll_worker_session.dart';
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
      await tester.pumpAndSettle();

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
}

class _StaticShiftLineNotifier extends SelectedShiftLineNotifier {
  _StaticShiftLineNotifier(this.initial);
  final int initial;

  @override
  int? build() => initial;
}
