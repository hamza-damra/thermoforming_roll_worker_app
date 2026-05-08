import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:thermoforming_roll_worker/core/theme/app_theme.dart';
import 'package:thermoforming_roll_worker/features/previous_roll/data/previous_roll_providers.dart';
import 'package:thermoforming_roll_worker/features/previous_roll/domain/entities/previous_roll_resolution.dart';
import 'package:thermoforming_roll_worker/features/previous_roll/domain/previous_roll_repository.dart';
import 'package:thermoforming_roll_worker/features/previous_roll/presentation/widgets/grinding_dialog.dart';
import 'package:thermoforming_roll_worker/features/roll_scan/data/roll_scan_providers.dart';
import 'package:thermoforming_roll_worker/features/roll_scan/domain/roll_scan_repository.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/data/roll_worker_auth_providers.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/domain/roll_worker_auth_repository.dart';

class _MockPrevRepo extends Mock implements PreviousRollRepository {}

class _MockScanRepo extends Mock implements RollScanRepository {}

class _MockAuthRepo extends Mock implements RollWorkerAuthRepository {}

const int kShiftLineId = 800;

PreviousRollResolution _grinded() => const PreviousRollResolution(
  rollId: 1,
  generatedRollId: '777000000001',
  finalState: PreviousRollFinalState.sentToGrinding,
  consumedWeightKg: 210.0,
  remainingWeightKg: 40.0,
  remainderAction: PreviousRollRemainderAction.grinding,
  eventType: PreviousRollEventType.closedPartialGrinding,
  reprintAvailable: true,
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
  testWidgets('renders the prescribed warning copy', (
    WidgetTester tester,
  ) async {
    final navKey = GlobalKey<NavigatorState>();
    final prev = _MockPrevRepo();
    final scan = _MockScanRepo();
    final auth = _MockAuthRepo();

    await tester.pumpWidget(
      _harness(navKey: navKey, prev: prev, scan: scan, auth: auth),
    );
    unawaited(
      showGrindingDialog(
        navKey.currentContext!,
        shiftLineId: kShiftLineId,
        maxAllowedKg: 250.0,
      ),
    );
    await tester.pumpAndSettle();

    // Title, body line, and the extra warning chip all render the
    // prescribed Arabic copy.
    expect(find.text('تأكيد إرسال المتبقي للجرش'), findsOneWidget);
    expect(find.text('هل تريد إرسال الوزن المتبقي للجرش؟'), findsOneWidget);
    expect(
      find.text('سيتم إرسال هذه البقايا إلى خط الجرش، هل أنت متأكد؟'),
      findsOneWidget,
    );
  });

  testWidgets('valid input dispatches sendToGrinding to the repository', (
    WidgetTester tester,
  ) async {
    final navKey = GlobalKey<NavigatorState>();
    final prev = _MockPrevRepo();
    final scan = _MockScanRepo();
    final auth = _MockAuthRepo();
    when(
      () => prev.sendToGrinding(
        shiftLineId: kShiftLineId,
        remainingWeightKg: 40.0,
      ),
    ).thenAnswer((_) async => PreviousRollSuccess(_grinded()));

    await tester.pumpWidget(
      _harness(navKey: navKey, prev: prev, scan: scan, auth: auth),
    );
    unawaited(
      showGrindingDialog(
        navKey.currentContext!,
        shiftLineId: kShiftLineId,
        maxAllowedKg: 250.0,
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '40');
    await tester.tap(find.text('تأكيد الجرش'));
    await tester.pumpAndSettle();

    verify(
      () => prev.sendToGrinding(
        shiftLineId: kShiftLineId,
        remainingWeightKg: 40.0,
      ),
    ).called(1);
  });
}

void unawaited(Future<dynamic>? future) {}
