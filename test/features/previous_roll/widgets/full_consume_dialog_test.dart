import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:thermoforming_roll_worker/core/theme/app_theme.dart';
import 'package:thermoforming_roll_worker/features/previous_roll/data/previous_roll_providers.dart';
import 'package:thermoforming_roll_worker/features/previous_roll/domain/entities/previous_roll_resolution.dart';
import 'package:thermoforming_roll_worker/features/previous_roll/domain/previous_roll_repository.dart';
import 'package:thermoforming_roll_worker/features/previous_roll/presentation/widgets/full_consume_confirm_dialog.dart';
import 'package:thermoforming_roll_worker/features/roll_scan/data/roll_scan_providers.dart';
import 'package:thermoforming_roll_worker/features/roll_scan/domain/roll_scan_repository.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/data/roll_worker_auth_providers.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/domain/roll_worker_auth_repository.dart';

class _MockPrevRepo extends Mock implements PreviousRollRepository {}

class _MockScanRepo extends Mock implements RollScanRepository {}

class _MockAuthRepo extends Mock implements RollWorkerAuthRepository {}

const int kShiftLineId = 800;

PreviousRollResolution _consumed() => const PreviousRollResolution(
  rollId: 1,
  generatedRollId: '777000000001',
  finalState: PreviousRollFinalState.consumed,
  consumedWeightKg: 250.0,
  remainingWeightKg: 0.0,
  remainderAction: PreviousRollRemainderAction.none,
  eventType: PreviousRollEventType.closedFull,
  reprintAvailable: false,
);

Widget _harness({
  required GlobalKey<NavigatorState> navKey,
  required _MockPrevRepo prev,
  required _MockScanRepo scan,
  required _MockAuthRepo auth,
}) {
  return ProviderScope(
    overrides: <Override>[
      previousRollRepositoryProvider.overrideWithValue(prev),
      rollScanRepositoryProvider.overrideWithValue(scan),
      rollWorkerAuthRepositoryProvider.overrideWithValue(auth),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      navigatorKey: navKey,
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      home: const Scaffold(body: SizedBox()),
    ),
  );
}

void main() {
  testWidgets('full-consume confirm dispatches and closes on Resolved', (
    WidgetTester tester,
  ) async {
    final navKey = GlobalKey<NavigatorState>();
    final prev = _MockPrevRepo();
    final scan = _MockScanRepo();
    final auth = _MockAuthRepo();
    when(
      () => prev.fullConsume(shiftLineId: kShiftLineId),
    ).thenAnswer((_) async => PreviousRollSuccess(_consumed()));

    await tester.pumpWidget(
      _harness(navKey: navKey, prev: prev, scan: scan, auth: auth),
    );
    unawaited(
      showFullConsumeConfirmDialog(
        navKey.currentContext!,
        shiftLineId: kShiftLineId,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('تأكيد استهلاك كامل'), findsOneWidget);
    expect(find.text('هل تريد إغلاق هذا الرول كاستهلاك كامل؟'), findsOneWidget);
    await tester.tap(find.text('تأكيد الاستهلاك'));
    await tester.pumpAndSettle();

    verify(() => prev.fullConsume(shiftLineId: kShiftLineId)).called(1);
    // Dialog should have popped after Resolved.
    expect(find.text('هل تريد إغلاق هذا الرول كاستهلاك كامل؟'), findsNothing);
  });
}

void unawaited(Future<dynamic>? future) {}
