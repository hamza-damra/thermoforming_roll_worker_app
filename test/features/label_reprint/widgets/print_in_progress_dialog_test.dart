// mocktail's `when` / `verify` need a closure to intercept the call; the
// tearoff lint doesn't apply.
// ignore_for_file: unnecessary_lambdas

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../_hive_test_helper.dart';
import 'package:thermoforming_roll_worker/core/theme/app_theme.dart';
import 'package:thermoforming_roll_worker/features/label_reprint/data/label_reprint_providers.dart';
import 'package:thermoforming_roll_worker/features/label_reprint/domain/entities/roll_label.dart';
import 'package:thermoforming_roll_worker/features/label_reprint/domain/label_reprint_repository.dart';
import 'package:thermoforming_roll_worker/features/label_reprint/presentation/controllers/label_reprint_controller.dart';
import 'package:thermoforming_roll_worker/features/label_reprint/presentation/widgets/print_in_progress_dialog.dart';
import 'package:thermoforming_roll_worker/features/printer/core/printing_exception.dart';
import 'package:thermoforming_roll_worker/features/printer/data/printer_providers.dart';
import 'package:thermoforming_roll_worker/features/printer/domain/entities/label_preset.dart';
import 'package:thermoforming_roll_worker/features/printer/domain/entities/printer_config.dart';
import 'package:thermoforming_roll_worker/features/printer/domain/printer_repository.dart';
import 'package:thermoforming_roll_worker/features/printer/pipeline/printer_transport.dart';

class _MockReprintRepo extends Mock implements LabelReprintRepository {}

class _MockPrinterRepo extends Mock implements PrinterRepository {}

class _FakePrinterTransport implements PrinterTransport {
  _FakePrinterTransport({this.exceptionToThrow});
  PrintingException? exceptionToThrow;
  int sendCalls = 0;

  @override
  Future<void> sendPrintJob({
    required PrinterConfig printer,
    required String value,
    required LabelPreset preset,
    int copies = 1,
    String? topText,
    String? bottomText,
    String? sideText,
  }) async {
    sendCalls++;
    if (exceptionToThrow != null) throw exceptionToThrow!;
  }

  @override
  Future<bool> testConnection(PrinterConfig printer) async => true;
}

const int kShiftLineId = 800;
const String kRollId = '777000000001';

RollLabel _label() => const RollLabel(
  generatedRollId: kRollId,
  prefixSnapshot: '777',
  serialNumber: 1,
  rollTypeId: 70,
  rollTypeRollCode: 'TT-1S B250 White',
  rollTypeDisplayName: 'TT-1S B250',
  colorName: 'White',
  standardLengthM: 100.0,
  standardWeightKg: 250.0,
  actualLengthM: 99.5,
  actualWeightKg: 248.0,
  actualThicknessMm: 0.250,
  productionKind: 'NORMAL',
  consumptionState: RollConsumptionState.partiallyReturned,
  lastKnownWeightKg: 75.5,
);

const PrinterConfig _printer = PrinterConfig(
  id: 'p',
  name: 'Test',
  ip: '192.168.1.100',
  isDefault: true,
);

Widget _harness({
  required GlobalKey<NavigatorState> navKey,
  required _MockReprintRepo reprintRepo,
  required _MockPrinterRepo printerRepo,
  required PrinterTransport transport,
}) {
  return ProviderScope(
    overrides: <Override>[
      labelReprintRepositoryProvider.overrideWithValue(reprintRepo),
      printerRepositoryProvider.overrideWithValue(printerRepo),
      printerTransportProvider.overrideWithValue(transport),
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
  late Directory hiveDir;

  setUp(() async {
    hiveDir = await initHiveForTest();
  });

  tearDown(() async {
    await closeHiveForTest(hiveDir);
  });

  testWidgets('Sent state shows the prescribed Arabic + Close', (
    WidgetTester tester,
  ) async {
    final navKey = GlobalKey<NavigatorState>();
    final reprintRepo = _MockReprintRepo();
    final printerRepo = _MockPrinterRepo();
    final transport = _FakePrinterTransport();
    when(
      () => reprintRepo.fetchLabel(
        shiftLineId: kShiftLineId,
        generatedRollId: kRollId,
      ),
    ).thenAnswer((_) async => LabelReprintSuccess(_label()));
    when(() => printerRepo.getDefault()).thenReturn(_printer);

    await tester.pumpWidget(
      _harness(
        navKey: navKey,
        reprintRepo: reprintRepo,
        printerRepo: printerRepo,
        transport: transport,
      ),
    );

    final ProviderContainer container = ProviderScope.containerOf(
      navKey.currentContext!,
    );

    // Show the dialog.
    final Future<void> dialog = PrintInProgressDialog.show(
      navKey.currentContext!,
      shiftLineId: kShiftLineId,
    );
    await tester.pump();

    // Drive the controller to Sent.
    await container
        .read(labelReprintControllerProvider(kShiftLineId).notifier)
        .reprint(kRollId);
    await tester.pumpAndSettle();

    expect(find.text('تم إرسال الليبل للطابعة'), findsOneWidget);
    expect(find.text('إغلاق'), findsOneWidget);

    await tester.tap(find.text('إغلاق'));
    await tester.pumpAndSettle();
    await dialog;

    // Sent → cancel → Idle after dismissal.
    final state = container.read(labelReprintControllerProvider(kShiftLineId));
    expect(state.runtimeType.toString(), 'LabelReprintIdle');
  });

  testWidgets('Failure state shows error + Retry / إعدادات الطباعة / إغلاق', (
    WidgetTester tester,
  ) async {
    final navKey = GlobalKey<NavigatorState>();
    final reprintRepo = _MockReprintRepo();
    final printerRepo = _MockPrinterRepo();
    final transport = _FakePrinterTransport(
      exceptionToThrow: PrintingException.connectionTimeout(),
    );
    when(
      () => reprintRepo.fetchLabel(
        shiftLineId: kShiftLineId,
        generatedRollId: kRollId,
      ),
    ).thenAnswer((_) async => LabelReprintSuccess(_label()));
    when(() => printerRepo.getDefault()).thenReturn(_printer);

    await tester.pumpWidget(
      _harness(
        navKey: navKey,
        reprintRepo: reprintRepo,
        printerRepo: printerRepo,
        transport: transport,
      ),
    );
    final ProviderContainer container = ProviderScope.containerOf(
      navKey.currentContext!,
    );

    // ignore: unawaited_futures
    PrintInProgressDialog.show(
      navKey.currentContext!,
      shiftLineId: kShiftLineId,
    );
    await tester.pump();

    await container
        .read(labelReprintControllerProvider(kShiftLineId).notifier)
        .reprint(kRollId);
    await tester.pumpAndSettle();

    expect(find.text('تعذّر إرسال الليبل'), findsOneWidget);
    expect(find.text('انتهت مهلة الاتصال بالطابعة'), findsOneWidget);
    expect(find.text('إعادة المحاولة'), findsOneWidget);
    expect(find.text('إعدادات الطباعة'), findsOneWidget);
    expect(find.text('إغلاق'), findsOneWidget);
  });

  testWidgets('Retry from failure re-runs the print stage with cached label', (
    WidgetTester tester,
  ) async {
    final navKey = GlobalKey<NavigatorState>();
    final reprintRepo = _MockReprintRepo();
    final printerRepo = _MockPrinterRepo();
    final transport = _FakePrinterTransport(
      exceptionToThrow: PrintingException.connectionFailed(),
    );
    when(
      () => reprintRepo.fetchLabel(
        shiftLineId: kShiftLineId,
        generatedRollId: kRollId,
      ),
    ).thenAnswer((_) async => LabelReprintSuccess(_label()));
    when(() => printerRepo.getDefault()).thenReturn(_printer);

    await tester.pumpWidget(
      _harness(
        navKey: navKey,
        reprintRepo: reprintRepo,
        printerRepo: printerRepo,
        transport: transport,
      ),
    );
    final ProviderContainer container = ProviderScope.containerOf(
      navKey.currentContext!,
    );

    // ignore: unawaited_futures
    PrintInProgressDialog.show(
      navKey.currentContext!,
      shiftLineId: kShiftLineId,
    );
    await tester.pump();

    await container
        .read(labelReprintControllerProvider(kShiftLineId).notifier)
        .reprint(kRollId);
    await tester.pumpAndSettle();
    expect(find.text('إعادة المحاولة'), findsOneWidget);

    // Make the next print succeed and tap retry.
    transport.exceptionToThrow = null;
    await tester.tap(find.text('إعادة المحاولة'));
    await tester.pumpAndSettle();

    expect(find.text('تم إرسال الليبل للطابعة'), findsOneWidget);
    // No re-fetch — the cached label was used.
    verify(
      () => reprintRepo.fetchLabel(
        shiftLineId: kShiftLineId,
        generatedRollId: kRollId,
      ),
    ).called(1);
    expect(transport.sendCalls, 2);
  });
}
