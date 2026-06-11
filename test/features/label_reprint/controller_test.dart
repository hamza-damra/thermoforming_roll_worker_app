// mocktail's `when` / `verify` need a closure to intercept the call; the
// tearoff lint doesn't apply.
// ignore_for_file: unnecessary_lambdas

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '_hive_test_helper.dart';
import 'package:thermoforming_roll_worker/core/errors/app_failure.dart';
import 'package:thermoforming_roll_worker/core/errors/error_code.dart';
import 'package:thermoforming_roll_worker/features/label_reprint/data/label_reprint_providers.dart';
import 'package:thermoforming_roll_worker/features/label_reprint/domain/entities/roll_label.dart';
import 'package:thermoforming_roll_worker/features/label_reprint/domain/label_reprint_repository.dart';
import 'package:thermoforming_roll_worker/features/label_reprint/presentation/controllers/label_reprint_controller.dart';
import 'package:thermoforming_roll_worker/features/label_reprint/presentation/controllers/label_reprint_state.dart';
import 'package:thermoforming_roll_worker/features/printer/core/printing_exception.dart';
import 'package:thermoforming_roll_worker/features/printer/data/printer_providers.dart';
import 'package:thermoforming_roll_worker/features/printer/domain/entities/label_preset.dart';
import 'package:thermoforming_roll_worker/features/printer/domain/entities/printer_config.dart';
import 'package:thermoforming_roll_worker/features/printer/domain/entities/roll_label_data.dart';
import 'package:thermoforming_roll_worker/features/printer/domain/printer_repository.dart';
import 'package:thermoforming_roll_worker/features/printer/pipeline/printer_transport.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/data/roll_worker_auth_providers.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/domain/roll_worker_auth_repository.dart';

class _MockReprintRepo extends Mock implements LabelReprintRepository {}

class _MockPrinterRepo extends Mock implements PrinterRepository {}

class _MockAuthRepo extends Mock implements RollWorkerAuthRepository {}

/// Records every print invocation. Behaves how each test wants it to.
class _FakePrinterTransport implements PrinterTransport {
  _FakePrinterTransport({this.exceptionToThrow});

  PrintingException? exceptionToThrow;
  int sendCalls = 0;
  PrinterConfig? lastPrinter;
  String? lastValue;
  LabelPreset? lastPreset;
  int? lastCopies;
  RollLabelData? lastLabelData;
  String? lastTopText;
  String? lastBottomText;
  String? lastSideText;

  @override
  Future<void> sendPrintJob({
    required PrinterConfig printer,
    required String value,
    required LabelPreset preset,
    int copies = 1,
    RollLabelData? labelData,
    String? topText,
    String? bottomText,
    String? sideText,
  }) async {
    sendCalls++;
    lastPrinter = printer;
    lastValue = value;
    lastPreset = preset;
    lastCopies = copies;
    lastLabelData = labelData;
    lastTopText = topText;
    lastBottomText = bottomText;
    lastSideText = sideText;
    if (exceptionToThrow != null) throw exceptionToThrow!;
  }

  @override
  Future<bool> testConnection(PrinterConfig printer) async => true;
}

const int kShiftLineId = 800;
const String kRollId = '777000000001';

/// Sentinel marking "the caller did not pass a createdAt — use the
/// default fixture timestamp". Tests that exercise the missing-timestamp
/// abort path pass `createdAt: null` explicitly to bypass the default.
const Object _unset = Object();

RollLabel _label({Object? createdAt = _unset}) => RollLabel(
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
  // `_unset` → default timestamp (so existing tests still pass the new
  // strict gate). Explicit null → null (so the missing-timestamp test
  // can exercise the abort).
  createdAt: identical(createdAt, _unset)
      ? DateTime.utc(2026, 5, 11, 14, 30)
      : createdAt as DateTime?,
);

const PrinterConfig _printer = PrinterConfig(
  id: 'printer-1',
  name: 'Test Printer',
  ip: '192.168.1.100',
  isDefault: true,
);

ProviderContainer _container({
  required _MockReprintRepo reprintRepo,
  required _MockPrinterRepo printerRepo,
  required PrinterTransport transport,
  RollWorkerAuthRepository? authRepo,
}) {
  final c = ProviderContainer(
    overrides: <Override>[
      labelReprintRepositoryProvider.overrideWithValue(reprintRepo),
      printerRepositoryProvider.overrideWithValue(printerRepo),
      printerTransportProvider.overrideWithValue(transport),
      if (authRepo != null)
        rollWorkerAuthRepositoryProvider.overrideWithValue(authRepo),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  late Directory hiveDir;

  setUp(() async {
    hiveDir = await initHiveForTest();
  });

  tearDown(() async {
    await closeHiveForTest(hiveDir);
  });

  group('LabelReprintController.reprint (full pipeline)', () {
    test(
      'case 1 — no configured printer → FailureState, no transport call',
      () async {
        final reprintRepo = _MockReprintRepo();
        final printerRepo = _MockPrinterRepo();
        final transport = _FakePrinterTransport();
        when(
          () => reprintRepo.fetchLabel(
            shiftLineId: kShiftLineId,
            generatedRollId: kRollId,
          ),
        ).thenAnswer((_) async => LabelReprintSuccess(_label()));
        when(() => printerRepo.getDefault()).thenReturn(null);
        final container = _container(
          reprintRepo: reprintRepo,
          printerRepo: printerRepo,
          transport: transport,
        );

        await container
            .read(labelReprintControllerProvider(kShiftLineId).notifier)
            .reprint(kRollId);

        final state = container.read(
          labelReprintControllerProvider(kShiftLineId),
        );
        expect(state, isA<LabelReprintFailureState>());
        expect(
          (state as LabelReprintFailureState).message,
          'لم يتم اختيار طابعة',
        );
        // Cached label is present so retry can re-send without a new
        // fetch once a printer is configured.
        expect(state.cachedLabel, isNotNull);
        expect(transport.sendCalls, 0);
      },
    );

    test(
      'case 2 — default printer selected and print invoked → Sent',
      () async {
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
        final container = _container(
          reprintRepo: reprintRepo,
          printerRepo: printerRepo,
          transport: transport,
        );

        await container
            .read(labelReprintControllerProvider(kShiftLineId).notifier)
            .reprint(kRollId);

        final state = container.read(
          labelReprintControllerProvider(kShiftLineId),
        );
        if (state is LabelReprintFailureState) {
          // Help diagnose: surface the controller's failure message so the
          // test output isn't just "isn't an instance of Sent".
          fail('Expected Sent but got Failure: ${state.message}');
        }
        expect(state, isA<LabelReprintSent>());
        expect(transport.sendCalls, 1);
        expect(transport.lastPrinter, _printer);
        expect(transport.lastValue, kRollId);
        // New structured 100×100 layout: the controller passes a
        // RollLabelData (not legacy top/bottom/side text) so the renderer
        // takes the QR + roll-number + serial + weekday/date/time path.
        // The Arabic remainder banner is dropped per the
        // RollProductionApp reference (no return-specific marker).
        expect(transport.lastTopText, isNull);
        expect(transport.lastBottomText, isNull);
        expect(transport.lastSideText, isNull);
        expect(transport.lastLabelData, isNotNull);
        expect(transport.lastLabelData!.generatedRollId, kRollId);
        // Regex `-(\d+)` against 'TT-1S B250 White' captures '1'.
        expect(transport.lastLabelData!.rollNumber, '1');
        // Default fixture's createdAt is 2026-05-11 14:30 UTC; the
        // controller passed it through unchanged (no device-time fallback).
        expect(
          transport.lastLabelData!.createdAt,
          DateTime.utc(2026, 5, 11, 14, 30),
        );
        // Default reprint (no labelType override) → not a grinding
        // remainder, so no scrap icon.
        expect(transport.lastLabelData!.isScrap, false);
      },
    );

    test(
      'case 3 — printer connection failure → FailureState with cached label',
      () async {
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
        final container = _container(
          reprintRepo: reprintRepo,
          printerRepo: printerRepo,
          transport: transport,
        );

        await container
            .read(labelReprintControllerProvider(kShiftLineId).notifier)
            .reprint(kRollId);

        final state = container.read(
          labelReprintControllerProvider(kShiftLineId),
        );
        expect(state, isA<LabelReprintFailureState>());
        final failure = state as LabelReprintFailureState;
        expect(failure.message, 'انتهت مهلة الاتصال بالطابعة');
        // Failed during print stage — cached label set so retry skips
        // re-fetch.
        expect(failure.failedDuringPrint, isTrue);
        expect(failure.cachedLabel, isNotNull);
        expect(transport.sendCalls, 1);
      },
    );

    test('case 4 — retry after print failure does NOT re-fetch', () async {
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
      final container = _container(
        reprintRepo: reprintRepo,
        printerRepo: printerRepo,
        transport: transport,
      );

      await container
          .read(labelReprintControllerProvider(kShiftLineId).notifier)
          .reprint(kRollId);
      expect(
        container.read(labelReprintControllerProvider(kShiftLineId)),
        isA<LabelReprintFailureState>(),
      );
      verify(
        () => reprintRepo.fetchLabel(
          shiftLineId: kShiftLineId,
          generatedRollId: kRollId,
        ),
      ).called(1);

      // Make the second send succeed and retry.
      transport.exceptionToThrow = null;
      await container
          .read(labelReprintControllerProvider(kShiftLineId).notifier)
          .retry();

      expect(
        container.read(labelReprintControllerProvider(kShiftLineId)),
        isA<LabelReprintSent>(),
      );
      // Critically: only the original fetch happened — retry reused
      // the cached label.
      verifyNoMoreInteractions(reprintRepo);
      expect(transport.sendCalls, 2);
    });

    test(
      'case 5 — reprint API failure → FailureState (no cached label)',
      () async {
        final reprintRepo = _MockReprintRepo();
        final printerRepo = _MockPrinterRepo();
        final transport = _FakePrinterTransport();
        when(
          () => reprintRepo.fetchLabel(
            shiftLineId: kShiftLineId,
            generatedRollId: kRollId,
          ),
        ).thenAnswer(
          (_) async => const LabelReprintFailureResult(
            BusinessFailure(code: ErrorCode.rollLabelReprintNotAvailable),
          ),
        );
        when(() => printerRepo.getDefault()).thenReturn(_printer);
        final container = _container(
          reprintRepo: reprintRepo,
          printerRepo: printerRepo,
          transport: transport,
        );

        await container
            .read(labelReprintControllerProvider(kShiftLineId).notifier)
            .reprint(kRollId);

        final state = container.read(
          labelReprintControllerProvider(kShiftLineId),
        );
        expect(state, isA<LabelReprintFailureState>());
        final failure = state as LabelReprintFailureState;
        expect(
          failure.message,
          'إعادة طباعة ملصق الرول متاحة فقط بعد الإرجاع الجزئي أو إغلاق الجرش.',
        );
        expect(failure.failedDuringFetch, isTrue);
        expect(failure.cachedLabel, isNull);
        expect(transport.sendCalls, 0);
      },
    );

    test(
      'case 6 — SESSION_REQUIRED cascades through auth.notifySessionLost',
      () async {
        final reprintRepo = _MockReprintRepo();
        final printerRepo = _MockPrinterRepo();
        final authRepo = _MockAuthRepo();
        final transport = _FakePrinterTransport();
        when(
          () => reprintRepo.fetchLabel(
            shiftLineId: kShiftLineId,
            generatedRollId: kRollId,
          ),
        ).thenAnswer(
          (_) async => const LabelReprintFailureResult(
            BusinessFailure(code: ErrorCode.rollWorkerSessionRequired),
          ),
        );
        when(() => printerRepo.getDefault()).thenReturn(_printer);
        when(
          () => authRepo.clearStoredToken(kShiftLineId),
        ).thenAnswer((_) async {});
        final container = _container(
          reprintRepo: reprintRepo,
          printerRepo: printerRepo,
          transport: transport,
          authRepo: authRepo,
        );

        await container
            .read(labelReprintControllerProvider(kShiftLineId).notifier)
            .reprint(kRollId);

        verify(() => authRepo.clearStoredToken(kShiftLineId)).called(1);
        expect(
          container.read(labelReprintControllerProvider(kShiftLineId)),
          isA<LabelReprintFailureState>(),
        );
        expect(transport.sendCalls, 0);
      },
    );

    test(
      'case 6b — SHIFT_LINE NOT_ACTIVE / NOT_FOUND also cascade '
      '(authoritative per-line end signals, handoff §7)',
      () async {
        for (final ErrorCode code in const <ErrorCode>[
          ErrorCode.thermoformingShiftLineNotActive,
          ErrorCode.thermoformingShiftLineNotFound,
        ]) {
          final reprintRepo = _MockReprintRepo();
          final printerRepo = _MockPrinterRepo();
          final authRepo = _MockAuthRepo();
          final transport = _FakePrinterTransport();
          when(
            () => reprintRepo.fetchLabel(
              shiftLineId: kShiftLineId,
              generatedRollId: kRollId,
            ),
          ).thenAnswer(
            (_) async => LabelReprintFailureResult(BusinessFailure(code: code)),
          );
          when(() => printerRepo.getDefault()).thenReturn(_printer);
          when(
            () => authRepo.clearStoredToken(kShiftLineId),
          ).thenAnswer((_) async {});
          final container = _container(
            reprintRepo: reprintRepo,
            printerRepo: printerRepo,
            transport: transport,
            authRepo: authRepo,
          );

          await container
              .read(labelReprintControllerProvider(kShiftLineId).notifier)
              .reprint(kRollId);

          verify(() => authRepo.clearStoredToken(kShiftLineId)).called(1);
          expect(transport.sendCalls, 0, reason: 'no print on a dead line ($code)');
        }
      },
    );
  });

  group('retry from fetch failure', () {
    test('re-runs fetch then sends on success', () async {
      final reprintRepo = _MockReprintRepo();
      final printerRepo = _MockPrinterRepo();
      final transport = _FakePrinterTransport();
      var fetchCallCount = 0;
      when(
        () => reprintRepo.fetchLabel(
          shiftLineId: kShiftLineId,
          generatedRollId: kRollId,
        ),
      ).thenAnswer((_) async {
        fetchCallCount++;
        if (fetchCallCount == 1) {
          return const LabelReprintFailureResult(
            BusinessFailure(code: ErrorCode.rollLabelReprintNotAvailable),
          );
        }
        return LabelReprintSuccess(_label());
      });
      when(() => printerRepo.getDefault()).thenReturn(_printer);
      final container = _container(
        reprintRepo: reprintRepo,
        printerRepo: printerRepo,
        transport: transport,
      );

      await container
          .read(labelReprintControllerProvider(kShiftLineId).notifier)
          .reprint(kRollId);
      expect(
        container.read(labelReprintControllerProvider(kShiftLineId)),
        isA<LabelReprintFailureState>(),
      );

      await container
          .read(labelReprintControllerProvider(kShiftLineId).notifier)
          .retry();

      expect(
        container.read(labelReprintControllerProvider(kShiftLineId)),
        isA<LabelReprintSent>(),
      );
      expect(fetchCallCount, 2);
      expect(transport.sendCalls, 1);
    });
  });

  group('previewOnly', () {
    test('on success transitions to LabelReprintReady (no print)', () async {
      final reprintRepo = _MockReprintRepo();
      final printerRepo = _MockPrinterRepo();
      final transport = _FakePrinterTransport();
      when(
        () => reprintRepo.fetchLabel(
          shiftLineId: kShiftLineId,
          generatedRollId: kRollId,
        ),
      ).thenAnswer((_) async => LabelReprintSuccess(_label()));
      final container = _container(
        reprintRepo: reprintRepo,
        printerRepo: printerRepo,
        transport: transport,
      );

      await container
          .read(labelReprintControllerProvider(kShiftLineId).notifier)
          .previewOnly(kRollId);

      expect(
        container.read(labelReprintControllerProvider(kShiftLineId)),
        isA<LabelReprintReady>(),
      );
      expect(transport.sendCalls, 0);
    });
  });

  group('printAlreadyFetched', () {
    test('from Ready → Sent without re-fetching', () async {
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
      final container = _container(
        reprintRepo: reprintRepo,
        printerRepo: printerRepo,
        transport: transport,
      );

      await container
          .read(labelReprintControllerProvider(kShiftLineId).notifier)
          .previewOnly(kRollId);
      verify(
        () => reprintRepo.fetchLabel(
          shiftLineId: kShiftLineId,
          generatedRollId: kRollId,
        ),
      ).called(1);

      await container
          .read(labelReprintControllerProvider(kShiftLineId).notifier)
          .printAlreadyFetched();

      expect(
        container.read(labelReprintControllerProvider(kShiftLineId)),
        isA<LabelReprintSent>(),
      );
      verifyNoMoreInteractions(reprintRepo);
      expect(transport.sendCalls, 1);
    });
  });

  group('strict timestamp resolution (PR C — no DateTime.now() fallback)', () {
    test(
      'all sources null (fetched label createdAt missing, no override) → '
      'FailureState with missing-timestamp message, transport NOT called',
      () async {
        final reprintRepo = _MockReprintRepo();
        final printerRepo = _MockPrinterRepo();
        final transport = _FakePrinterTransport();
        // Older-backend simulation: /reprint-label payload has no
        // createdAt, so the entity carries createdAt = null.
        when(
          () => reprintRepo.fetchLabel(
            shiftLineId: kShiftLineId,
            generatedRollId: kRollId,
          ),
        ).thenAnswer(
          (_) async => LabelReprintSuccess(_label(createdAt: null)),
        );
        when(() => printerRepo.getDefault()).thenReturn(_printer);
        final container = _container(
          reprintRepo: reprintRepo,
          printerRepo: printerRepo,
          transport: transport,
        );

        await container
            .read(labelReprintControllerProvider(kShiftLineId).notifier)
            .reprint(kRollId);

        final state = container.read(
          labelReprintControllerProvider(kShiftLineId),
        );
        expect(state, isA<LabelReprintFailureState>());
        expect(
          (state as LabelReprintFailureState).message,
          PrintingException.missingLabelTimestamp().displayMessage,
        );
        // Hard precondition: we must NOT have hit the transport. The
        // renderer never receives device time.
        expect(transport.sendCalls, 0);
        expect(transport.lastLabelData, isNull);
      },
    );

    test(
      'overrideTimestamp wins over fetched RollLabel.createdAt',
      () async {
        final DateTime fetched = DateTime.utc(2020, 1, 1);
        final DateTime override = DateTime.utc(2026, 5, 11, 14, 30);
        final reprintRepo = _MockReprintRepo();
        final printerRepo = _MockPrinterRepo();
        final transport = _FakePrinterTransport();
        when(
          () => reprintRepo.fetchLabel(
            shiftLineId: kShiftLineId,
            generatedRollId: kRollId,
          ),
        ).thenAnswer(
          (_) async => LabelReprintSuccess(_label(createdAt: fetched)),
        );
        when(() => printerRepo.getDefault()).thenReturn(_printer);
        final container = _container(
          reprintRepo: reprintRepo,
          printerRepo: printerRepo,
          transport: transport,
        );

        await container
            .read(labelReprintControllerProvider(kShiftLineId).notifier)
            .reprint(kRollId, overrideTimestamp: override);

        expect(transport.sendCalls, 1);
        expect(transport.lastLabelData, isNotNull);
        expect(transport.lastLabelData!.createdAt, override);
      },
    );

    test(
      'fetched RollLabel.createdAt used when no override is provided',
      () async {
        final DateTime fetched = DateTime.utc(2026, 6, 1, 8);
        final reprintRepo = _MockReprintRepo();
        final printerRepo = _MockPrinterRepo();
        final transport = _FakePrinterTransport();
        when(
          () => reprintRepo.fetchLabel(
            shiftLineId: kShiftLineId,
            generatedRollId: kRollId,
          ),
        ).thenAnswer(
          (_) async => LabelReprintSuccess(_label(createdAt: fetched)),
        );
        when(() => printerRepo.getDefault()).thenReturn(_printer);
        final container = _container(
          reprintRepo: reprintRepo,
          printerRepo: printerRepo,
          transport: transport,
        );

        await container
            .read(labelReprintControllerProvider(kShiftLineId).notifier)
            .reprint(kRollId);

        expect(transport.sendCalls, 1);
        expect(transport.lastLabelData!.createdAt, fetched);
      },
    );
  });

  group('labelType drives RollLabelData.isScrap (PR C — scrap icon switch)', () {
    test('GRINDING_REMAINING → isScrap=true', () async {
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
      final container = _container(
        reprintRepo: reprintRepo,
        printerRepo: printerRepo,
        transport: transport,
      );

      await container
          .read(labelReprintControllerProvider(kShiftLineId).notifier)
          .reprint(kRollId, labelType: 'GRINDING_REMAINING');

      expect(transport.lastLabelData!.isScrap, true);
    });

    test('RETURN_REMAINING → isScrap=false (no scrap icon)', () async {
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
      final container = _container(
        reprintRepo: reprintRepo,
        printerRepo: printerRepo,
        transport: transport,
      );

      await container
          .read(labelReprintControllerProvider(kShiftLineId).notifier)
          .reprint(kRollId, labelType: 'RETURN_REMAINING');

      expect(transport.lastLabelData!.isScrap, false);
    });

    test('null labelType → isScrap=false (default standard label)', () async {
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
      final container = _container(
        reprintRepo: reprintRepo,
        printerRepo: printerRepo,
        transport: transport,
      );

      await container
          .read(labelReprintControllerProvider(kShiftLineId).notifier)
          .reprint(kRollId);

      expect(transport.lastLabelData!.isScrap, false);
    });
  });

  group('cancel', () {
    test('cancel from Sent → Idle', () async {
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
      final container = _container(
        reprintRepo: reprintRepo,
        printerRepo: printerRepo,
        transport: transport,
      );

      await container
          .read(labelReprintControllerProvider(kShiftLineId).notifier)
          .reprint(kRollId);
      expect(
        container.read(labelReprintControllerProvider(kShiftLineId)),
        isA<LabelReprintSent>(),
      );

      container
          .read(labelReprintControllerProvider(kShiftLineId).notifier)
          .cancel();
      expect(
        container.read(labelReprintControllerProvider(kShiftLineId)),
        isA<LabelReprintIdle>(),
      );
    });
  });
}
