import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:thermoforming_roll_worker/core/theme/app_theme.dart';
import 'package:thermoforming_roll_worker/features/home/presentation/screens/roll_worker_home_screen.dart';
import 'package:thermoforming_roll_worker/features/roll_scan/data/roll_scan_providers.dart';
import 'package:thermoforming_roll_worker/features/roll_scan/domain/entities/mounted_roll.dart';
import 'package:thermoforming_roll_worker/features/roll_scan/domain/roll_scan_repository.dart';
import 'package:thermoforming_roll_worker/features/roll_scan/presentation/controllers/roll_scan_controller.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/data/roll_worker_auth_providers.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/domain/entities/roll_worker_session.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/domain/roll_worker_auth_repository.dart';

class _MockScanRepo extends Mock implements RollScanRepository {}

class _MockAuthRepo extends Mock implements RollWorkerAuthRepository {}

const int kShiftLineId = 800;

RollWorkerSession _session() => RollWorkerSession(
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
);

MountedRoll _mounted() => const MountedRoll(
  rollId: 1,
  generatedRollId: '777000000001',
  rollTypeId: 70,
  rollTypeRollCode: 'TT-1S B250 White',
  rollTypeDisplayName: 'TT-1S B250',
  colorName: 'White',
  productTypeId: 5,
  productTypeName: 'أحمر 20 كغ',
  consumptionItemId: 5000,
  activeSegmentId: 6000,
  state: 'IN_CONSUMPTION',
  lastKnownWeightKg: 250.0,
);

Widget _wrap({
  required _MockScanRepo scanRepo,
  required _MockAuthRepo authRepo,
}) {
  return ProviderScope(
    overrides: <Override>[
      rollScanRepositoryProvider.overrideWithValue(scanRepo),
      rollWorkerAuthRepositoryProvider.overrideWithValue(authRepo),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      home: RollWorkerHomeScreen(
        shiftLineId: kShiftLineId,
        session: _session(),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'idle state shows the empty mount card and the "تركيب رول جديد" CTA',
    (WidgetTester tester) async {
      final scanRepo = _MockScanRepo();
      final authRepo = _MockAuthRepo();
      await tester.pumpWidget(_wrap(scanRepo: scanRepo, authRepo: authRepo));
      await tester.pumpAndSettle();

      expect(find.text('Ahmad'), findsOneWidget);
      expect(find.text('لا يوجد رول مركّب حاليًا'), findsOneWidget);
      expect(find.text('تركيب رول جديد'), findsOneWidget);
      expect(find.text('تسجيل خروج عامل الرولات'), findsOneWidget);
    },
  );

  testWidgets(
    'after a successful mount, the mount card shows the mounted roll details',
    (WidgetTester tester) async {
      final scanRepo = _MockScanRepo();
      final authRepo = _MockAuthRepo();
      when(
        () => scanRepo.mountRoll(
          shiftLineId: kShiftLineId,
          generatedRollId: '777000000001',
        ),
      ).thenAnswer((_) async => RollScanSuccess(_mounted()));

      late ProviderContainer container;
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            rollScanRepositoryProvider.overrideWithValue(scanRepo),
            rollWorkerAuthRepositoryProvider.overrideWithValue(authRepo),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            builder: (context, child) => Directionality(
              textDirection: TextDirection.rtl,
              child: Builder(
                builder: (context) {
                  container = ProviderScope.containerOf(context);
                  return child ?? const SizedBox.shrink();
                },
              ),
            ),
            home: RollWorkerHomeScreen(
              shiftLineId: kShiftLineId,
              session: _session(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Drive a successful mount through the controller (the ScanRollScreen
      // is a separate widget covered by other tests).
      await container
          .read(rollScanControllerProvider(kShiftLineId).notifier)
          .mountRoll('777000000001');
      await tester.pumpAndSettle();

      expect(find.text('777000000001'), findsWidgets);
      expect(find.text('أحمر 20 كغ'), findsOneWidget);
      expect(find.text('TT-1S B250'), findsOneWidget);
      expect(find.text('250.000 كغ'), findsOneWidget);
      // CTA is hidden once a roll is mounted.
      expect(find.text('تركيب رول جديد'), findsNothing);
    },
  );
}
