import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:thermoforming_roll_worker/core/errors/app_failure.dart';
import 'package:thermoforming_roll_worker/core/errors/error_code.dart';
import 'package:thermoforming_roll_worker/core/storage/session_index_storage.dart';
import 'package:thermoforming_roll_worker/core/storage/storage_providers.dart';
import 'package:thermoforming_roll_worker/core/theme/app_colors.dart';
import 'package:thermoforming_roll_worker/core/theme/app_theme.dart';
import 'package:thermoforming_roll_worker/core/ui/line_labels.dart';
import 'package:thermoforming_roll_worker/features/home/data/shift_line_summary_providers.dart';
import 'package:thermoforming_roll_worker/features/home/domain/entities/shift_line_summary.dart';
import 'package:thermoforming_roll_worker/features/home/domain/shift_line_summary_repository.dart';
import 'package:thermoforming_roll_worker/features/home/presentation/screens/machine_dashboard_shell.dart';
import 'package:thermoforming_roll_worker/features/home/presentation/screens/roll_worker_home_screen.dart';
import 'package:thermoforming_roll_worker/features/home/presentation/widgets/home_shimmer_skeleton.dart';
import 'package:thermoforming_roll_worker/features/home/presentation/widgets/machine_waiting_card.dart';
import 'package:thermoforming_roll_worker/features/home/presentation/widgets/per_machine_tab.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/data/roll_worker_auth_providers.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/domain/entities/batch_auth_outcome.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/domain/entities/roll_worker_session.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/domain/roll_worker_auth_repository.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/domain/session_batch_repository.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/presentation/controllers/multi_line_session_registry.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/presentation/controllers/multi_line_session_registry_state.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/presentation/widgets/roll_worker_auth_overlay.dart';
import 'package:thermoforming_roll_worker/features/sessions_me/domain/entities/roll_worker_active_line.dart';
import 'package:thermoforming_roll_worker/features/sessions_me/domain/entities/roll_worker_me.dart';
import 'package:thermoforming_roll_worker/features/sessions_me/presentation/controllers/sessions_me_controller.dart';
import 'package:thermoforming_roll_worker/features/sessions_me/presentation/controllers/sessions_me_state.dart';
import 'package:thermoforming_roll_worker/features/shift_line/domain/entities/roll_worker_bootstrap_line.dart';
import 'package:thermoforming_roll_worker/features/shift_line/presentation/controllers/roll_worker_bootstrap_controller.dart';
import 'package:thermoforming_roll_worker/features/shift_line/presentation/controllers/roll_worker_bootstrap_state.dart';

class _MockBatchRepo extends Mock implements SessionBatchRepository {}

class _MockSummaryRepo extends Mock implements ShiftLineSummaryRepository {}

class _MockAuthRepo extends Mock implements RollWorkerAuthRepository {}

class _MockIndex extends Mock implements SessionIndexStorage {}

/// Bootstrap controller pinned to a fixed loaded list — no SSE attach, no
/// network. Overriding [build] without `super` skips the real SSE / poll
/// wiring so the shell tests stay deterministic.
class _StaticBootstrap extends RollWorkerBootstrapController {
  _StaticBootstrap(this._lines);
  final List<RollWorkerBootstrapLine> _lines;

  @override
  RollWorkerBootstrapState build() => RollWorkerBootstrapLoaded(_lines);

  @override
  Future<void> refresh({String trigger = 'manual', bool background = false}) async {}
}

/// Bootstrap controller stuck in the first-load state (no machines yet) so the
/// shell renders its loading branch.
class _LoadingBootstrap extends RollWorkerBootstrapController {
  @override
  RollWorkerBootstrapState build() => const RollWorkerBootstrapInitial();

  @override
  Future<void> refresh({String trigger = 'manual', bool background = false}) async {}
}

/// Registry pinned to an initial state; restore is a no-op (tests pre-seed
/// the state). `onBatchSuccess` / `setActive` remain inherited so the
/// valid-PIN flow can flip the state for real.
class _StaticRegistry extends MultiLineSessionRegistry {
  _StaticRegistry(this._initial);
  final MultiLineSessionRegistryState _initial;

  @override
  MultiLineSessionRegistryState build() => _initial;

  @override
  Future<void> restoreFromStorage() async {}
}

/// Idle /sessions/me with no registry listener → no fallback poll timer.
class _FakeSessionsMe extends SessionsMeController {
  @override
  SessionsMeState build() => const SessionsMeIdle();
}

/// Bootstrap controller whose line list can be swapped mid-test (to simulate an
/// operator-session change on the same physical line: same thermoformingLineId,
/// new shiftLineId).
class _MutableBootstrap extends RollWorkerBootstrapController {
  _MutableBootstrap(this._lines);
  List<RollWorkerBootstrapLine> _lines;

  @override
  RollWorkerBootstrapState build() => RollWorkerBootstrapLoaded(_lines);

  @override
  Future<void> refresh({String trigger = 'manual', bool background = false}) async {}

  void setLines(List<RollWorkerBootstrapLine> lines) {
    _lines = lines;
    state = RollWorkerBootstrapLoaded(lines);
  }
}

/// Registry whose state can be swapped mid-test (e.g. drop shiftLineId 800, add
/// 801 for the same physical line).
class _MutableRegistry extends MultiLineSessionRegistry {
  _MutableRegistry(this._initial);
  final MultiLineSessionRegistryState _initial;

  @override
  MultiLineSessionRegistryState build() => _initial;

  @override
  Future<void> restoreFromStorage() async {}

  void applyState(MultiLineSessionRegistryState next) => state = next;
}

ConsumedRoll _consumedRoll({required String generatedRollId}) => ConsumedRoll(
      consumptionItemId: 900,
      rollId: 901,
      generatedRollId: generatedRollId,
      rollTypeCode: 'TP-1',
      rollTypeName: 'White',
      startWeightKg: 200.0,
      endWeightKg: 0.0,
      consumedWeightKg: 42.0,
      closedReason: 'FULL_CONSUMPTION',
      remainderAction: 'NONE',
      endedAt: DateTime.parse('2026-05-23T10:00:00Z'),
      endedAtDisplay: '٢٣ أيار',
    );

/// Summary repo that returns a DISTINCT consumed list per shiftLineId:
/// 800 → one roll "AAA000000800"; any other id → empty. Proves the scope is
/// keyed by shiftLineId (a new session shows its own data, not the old).
ShiftLineSummaryRepository _scopedSummaryRepo() {
  final repo = _MockSummaryRepo();
  when(() => repo.fetchSummary(shiftLineId: any(named: 'shiftLineId')))
      .thenAnswer((invocation) async {
    final int id =
        invocation.namedArguments[const Symbol('shiftLineId')] as int;
    return SummarySuccess(
      ShiftLineSummary(
        shiftLineId: id,
        thermoformingLineCode: 'TH-0$id',
        thermoformingLineName: 'خط التشكيل',
        completedRollsInSession: 0,
        completedRollsByCurrentWorker: 0,
        consumedWeightKgInSession: id == 800 ? 42.0 : 0.0,
        consumedRolls: id == 800
            ? <ConsumedRoll>[_consumedRoll(generatedRollId: 'AAA000000800')]
            : const <ConsumedRoll>[],
        activeOperatorName: 'مشغل التشكيل',
      ),
    );
  });
  return repo;
}

RollWorkerBootstrapLine _line({
  required int thermoformingLineId,
  required int? shiftLineId,
  required bool selectable,
  int? machineNumber,
  int? palletizingLineId,
  String? label,
  String? lineCode,
  String? lineName,
  String? lineDisplayName,
  String? product,
  String? operatorName,
  String lifecycle = 'ACTIVE',
}) {
  final int plId = palletizingLineId ?? thermoformingLineId;
  return RollWorkerBootstrapLine(
    thermoformingLineId: thermoformingLineId,
    lineCode: lineCode ?? 'TF_LINE_$thermoformingLineId',
    lineName: lineName ?? 'خط $thermoformingLineId',
    lineDisplayName: lineDisplayName,
    machineNumber: machineNumber,
    palletizingLineId: plId,
    productionLineId: plId,
    palletizingLineCode: 'LINE_$plId',
    palletizingLineName: label ?? 'خط طبليات $thermoformingLineId',
    shiftLineId: shiftLineId,
    thermoformingShiftId: 9000,
    currentProductTypeId: product == null ? null : 5,
    currentProductTypeName: product,
    activeOperatorId: operatorName == null ? null : 1,
    activeOperatorName: operatorName,
    currentRollId: null,
    currentRollGeneratedRollId: null,
    currentRollTypeCode: null,
    currentRollTypeName: null,
    currentRollLastKnownWeightKg: null,
    selectable: selectable,
    canStartRollWorkerSession: selectable,
    blocked: false,
    blockedReason: null,
    handoverPending: false,
    takeoverRequestStatus: null,
    takeoverIncomingOperatorName: null,
    lineLifecycleStatus: lifecycle,
    updatedAt: null,
  );
}

RollWorkerSession _session(
  int shiftLineId, {
  int thermoformingLineId = 11,
  int palletizingLineId = 21,
}) => RollWorkerSession(
      sessionId: shiftLineId,
      rollWorkerOperatorId: 7,
      rollWorkerName: 'Yusuf',
      thermoformingShiftId: 9000,
      thermoformingShiftLineId: shiftLineId,
      thermoformingLineId: thermoformingLineId,
      palletizingLineId: palletizingLineId,
      startedAt: DateTime.parse('2026-05-10T10:00:00Z'),
      status: 'ACTIVE',
    );

ShiftLineSummaryRepository _summaryRepo() {
  final repo = _MockSummaryRepo();
  when(() => repo.fetchSummary(shiftLineId: any(named: 'shiftLineId'))).thenAnswer(
    (invocation) async {
      final int id =
          invocation.namedArguments[const Symbol('shiftLineId')] as int;
      return SummarySuccess(
        ShiftLineSummary(
          shiftLineId: id,
          thermoformingLineCode: 'TH-0$id',
          thermoformingLineName: 'خط التشكيل',
          completedRollsInSession: 0,
          completedRollsByCurrentWorker: 0,
          activeOperatorName: 'مشغل التشكيل',
        ),
      );
    },
  );
  return repo;
}

ProviderContainer _container({
  required List<RollWorkerBootstrapLine> lines,
  required MultiLineSessionRegistryState registry,
  SessionBatchRepository? batchRepo,
}) {
  final auth = _MockAuthRepo();
  when(() => auth.clearStoredToken(any())).thenAnswer((_) async {});
  final index = _MockIndex();
  when(() => index.writeIds(any())).thenAnswer((_) async {});
  when(index.readIds).thenAnswer((_) async => <int>{});

  return ProviderContainer(
    overrides: <Override>[
      rollWorkerBootstrapControllerProvider.overrideWith(
        () => _StaticBootstrap(lines),
      ),
      multiLineSessionRegistryProvider.overrideWith(
        () => _StaticRegistry(registry),
      ),
      sessionsMeControllerProvider.overrideWith(_FakeSessionsMe.new),
      rollWorkerAuthRepositoryProvider.overrideWithValue(auth),
      shiftLineSummaryRepositoryProvider.overrideWithValue(_summaryRepo()),
      sessionIndexStorageProvider.overrideWithValue(index),
      if (batchRepo != null)
        sessionBatchRepositoryProvider.overrideWithValue(batchRepo),
    ],
  );
}

Widget _wrap(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      theme: AppTheme.light(),
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      home: const MachineDashboardShell(),
    ),
  );
}

RegistryActive _active(Set<int> ids, {int? activeId}) => RegistryActive(
      sessions: <int, RollWorkerSession>{
        for (final int id in ids) id: _session(id),
      },
      activeShiftLineId: activeId ?? ids.first,
      logoutStatus: <int, LineLogoutStatus>{
        for (final int id in ids) id: LineLogoutStatus.idle,
      },
    );

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets(
    'two selectable machines, no session → top tabs + blocking PIN overlay',
    (WidgetTester tester) async {
      final container = _container(
        lines: <RollWorkerBootstrapLine>[
          _line(
            thermoformingLineId: 1,
            shiftLineId: 800,
            selectable: true,
            machineNumber: 1,
            label: 'خط أ',
            lineDisplayName: 'ماكينة A',
            operatorName: 'م. حمزة',
            product: 'TBS-13 C1500 Black / Black / 32 كرتونة',
          ),
          _line(
            thermoformingLineId: 2,
            shiftLineId: 801,
            selectable: true,
            machineNumber: 2,
            label: 'خط ب',
            lineDisplayName: 'ماكينة B',
            operatorName: 'م. حمزة',
          ),
        ],
        registry: const RegistryEmpty(),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(_wrap(container));
      await _settle(tester);

      // Top tabs (not bottom nav), one per machine.
      expect(find.byType(BottomNavigationBar), findsNothing);
      expect(find.byType(TabBar), findsOneWidget);
      final TabBar tabBar = tester.widget<TabBar>(find.byType(TabBar));
      expect(tabBar.tabs.length, 2);
      // Server line labels (`palletizingLineName`: خط أ / خط ب, D1 option B)
      // — never the Roll Worker machine name (`lineDisplayName`).
      expect(find.text('خط أ'), findsOneWidget);
      expect(find.text('خط ب'), findsOneWidget);
      expect(find.textContaining('ماكينة'), findsNothing);

      // The visible (unauthorized) machine shows the blocking PIN overlay.
      expect(find.byType(RollWorkerAuthOverlay), findsOneWidget);
      expect(find.text(RollWorkerAuthOverlay.title), findsOneWidget);
      expect(find.text(RollWorkerAuthOverlay.submitLabel), findsOneWidget);
      // The dimmed dashboard preview behind it shows the readable product.
      expect(find.text('TBS-13 C1500 Black'), findsOneWidget);
    },
  );

  testWidgets(
    'an authorized machine shows the live dashboard; the other shows the overlay',
    (WidgetTester tester) async {
      final container = _container(
        lines: <RollWorkerBootstrapLine>[
          _line(
            thermoformingLineId: 1,
            shiftLineId: 800,
            selectable: true,
            machineNumber: 1,
            label: 'خط أ',
            operatorName: 'م. حمزة',
          ),
          _line(
            thermoformingLineId: 2,
            shiftLineId: 801,
            selectable: true,
            machineNumber: 2,
            label: 'خط ب',
            operatorName: 'م. حمزة',
          ),
        ],
        registry: _active(<int>{800}, activeId: 800),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(_wrap(container));
      await _settle(tester);

      // Machine 1 (active session) → live dashboard, no overlay on this tab.
      expect(find.byType(RollWorkerAuthOverlay), findsNothing);
      expect(find.text(RollWorkerHomeScreen.registerRoll), findsOneWidget);

      // Switch to line ب (no session) → blocking overlay appears.
      await tester.tap(find.text('خط ب'));
      await _settle(tester);
      expect(find.byType(RollWorkerAuthOverlay), findsOneWidget);
    },
  );

  testWidgets('invalid PIN surfaces an inline Arabic error in the overlay', (
    WidgetTester tester,
  ) async {
    final batchRepo = _MockBatchRepo();
    when(
      () => batchRepo.startBatch(
        pin: any<String>(named: 'pin'),
        shiftLineIds: any<Set<int>>(named: 'shiftLineIds'),
      ),
    ).thenAnswer(
      (_) async => const BatchAuthFailureResult(
        BusinessFailure(code: ErrorCode.operatorPinInvalid),
      ),
    );

    final container = _container(
      lines: <RollWorkerBootstrapLine>[
        _line(
          thermoformingLineId: 1,
          shiftLineId: 800,
          selectable: true,
          machineNumber: 1,
          operatorName: 'م. حمزة',
        ),
      ],
      registry: const RegistryEmpty(),
      batchRepo: batchRepo,
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_wrap(container));
    await _settle(tester);

    await tester.enterText(find.byType(TextField), '0000');
    await tester.pump();
    await tester.tap(find.text(RollWorkerAuthOverlay.submitLabel));
    await _settle(tester);

    expect(find.text('رمز PIN غير صحيح.'), findsOneWidget);
  });

  testWidgets('submitting a valid PIN calls startBatch with the single-line set', (
    WidgetTester tester,
  ) async {
    final batchRepo = _MockBatchRepo();
    when(
      () => batchRepo.startBatch(pin: '1234', shiftLineIds: <int>{800}),
    ).thenAnswer(
      (_) async => BatchAuthSuccessResult(
        BatchAuthOutcome(
          rollWorkerOperatorId: 7,
          rollWorkerName: 'Yusuf',
          sessions: <int, RollWorkerSession>{800: _session(800)},
        ),
      ),
    );

    final container = _container(
      lines: <RollWorkerBootstrapLine>[
        _line(
          thermoformingLineId: 1,
          shiftLineId: 800,
          selectable: true,
          machineNumber: 1,
          operatorName: 'م. حمزة',
        ),
      ],
      registry: const RegistryEmpty(),
      batchRepo: batchRepo,
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_wrap(container));
    await _settle(tester);

    await tester.enterText(find.byType(TextField), '1234');
    await tester.pump();
    await tester.tap(find.text(RollWorkerAuthOverlay.submitLabel));
    await _settle(tester);

    // The overlay reuses the batch contract for a single shift-line.
    verify(
      () => batchRepo.startBatch(pin: '1234', shiftLineIds: <int>{800}),
    ).called(1);
    // Registry flipped active → overlay removed, live dashboard shown.
    expect(find.byType(RollWorkerAuthOverlay), findsNothing);
  });

  testWidgets('a non-selectable machine shows the blocking waiting card', (
    WidgetTester tester,
  ) async {
    final container = _container(
      lines: <RollWorkerBootstrapLine>[
        _line(
          thermoformingLineId: 1,
          shiftLineId: null,
          selectable: false,
          machineNumber: 1,
          lifecycle: 'NO_ACTIVE_SHIFT',
        ),
      ],
      registry: const RegistryEmpty(),
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_wrap(container));
    await _settle(tester);

    expect(find.byType(MachineWaitingCard), findsOneWidget);
    expect(find.byType(RollWorkerAuthOverlay), findsNothing);
  });

  testWidgets('first-load (no machines yet) shows the shimmer skeleton, '
      'not the old spinner', (WidgetTester tester) async {
    final auth = _MockAuthRepo();
    when(() => auth.clearStoredToken(any())).thenAnswer((_) async {});
    final index = _MockIndex();
    when(() => index.writeIds(any())).thenAnswer((_) async {});
    when(index.readIds).thenAnswer((_) async => <int>{});

    final container = ProviderContainer(
      overrides: <Override>[
        rollWorkerBootstrapControllerProvider.overrideWith(
          _LoadingBootstrap.new,
        ),
        multiLineSessionRegistryProvider.overrideWith(
          () => _StaticRegistry(const RegistryEmpty()),
        ),
        sessionsMeControllerProvider.overrideWith(_FakeSessionsMe.new),
        rollWorkerAuthRepositoryProvider.overrideWithValue(auth),
        shiftLineSummaryRepositoryProvider.overrideWithValue(_summaryRepo()),
        sessionIndexStorageProvider.overrideWithValue(index),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_wrap(container));
    // A single frame only — the shimmer animates forever, so pumpAndSettle
    // would hang (and that is exactly the proof it is a shimmer, not a static
    // screen).
    await tester.pump();

    expect(find.byType(RollWorkerLoadingScaffold), findsOneWidget);
    // The old green-app-bar spinner is gone.
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  group('summary scope is keyed by shiftLineId, not physical line', () {
    testWidgets(
      'an authorized page key carries sl-<shiftLineId> (operator session) '
      'under its machine identity th-<thermoformingLineId>',
      (WidgetTester tester) async {
        final container = _container(
          lines: <RollWorkerBootstrapLine>[
            _line(
              thermoformingLineId: 1,
              shiftLineId: 800,
              selectable: true,
              machineNumber: 1,
              operatorName: 'م. حمزة',
            ),
          ],
          registry: _active(<int>{800}, activeId: 800),
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(_wrap(container));
        await _settle(tester);

        final PerMachineTab tab = tester.widget<PerMachineTab>(
          find.byType(PerMachineTab),
        );
        // The page key includes the operator shift-line/session, so a new
        // shiftLineId tears the kept-alive subtree down and reloads; the
        // machine prefix keeps the tab (and selection) on the same machine.
        expect(tab.key, const ValueKey<String>('th-1/sl-800'));
      },
    );

    testWidgets(
      'same physical line, shiftLineId 800 → 801: old consumed data does not '
      'leak; the new session shows its own (empty) scope',
      (WidgetTester tester) async {
        // Tall surface so the lower consumed-rolls section is laid out.
        tester.view.physicalSize = const Size(1200, 4000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final auth = _MockAuthRepo();
        when(() => auth.clearStoredToken(any())).thenAnswer((_) async {});
        final index = _MockIndex();
        when(() => index.writeIds(any())).thenAnswer((_) async {});
        when(index.readIds).thenAnswer((_) async => <int>{});

        final container = ProviderContainer(
          overrides: <Override>[
            rollWorkerBootstrapControllerProvider.overrideWith(
              () => _MutableBootstrap(<RollWorkerBootstrapLine>[
                _line(
                  thermoformingLineId: 1,
                  shiftLineId: 800,
                  selectable: true,
                  machineNumber: 1,
                  operatorName: 'م. حمزة',
                ),
              ]),
            ),
            multiLineSessionRegistryProvider.overrideWith(
              () => _MutableRegistry(_active(<int>{800}, activeId: 800)),
            ),
            sessionsMeControllerProvider.overrideWith(_FakeSessionsMe.new),
            rollWorkerAuthRepositoryProvider.overrideWithValue(auth),
            shiftLineSummaryRepositoryProvider.overrideWithValue(
              _scopedSummaryRepo(),
            ),
            sessionIndexStorageProvider.overrideWithValue(index),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(_wrap(container));
        await _settle(tester);
        await _settle(tester);

        // Session 800 shows its consumed roll.
        expect(find.text('AAA000000800'), findsOneWidget);
        expect(find.text('42.000 كغ'), findsWidgets);

        // Operator-session change on the SAME physical line (thermoformingLineId
        // 1): old shiftLineId 800 ends, new shiftLineId 801 starts.
        final bootstrap = container.read(
          rollWorkerBootstrapControllerProvider.notifier,
        ) as _MutableBootstrap;
        final registry = container.read(
          multiLineSessionRegistryProvider.notifier,
        ) as _MutableRegistry;
        bootstrap.setLines(<RollWorkerBootstrapLine>[
          _line(
            thermoformingLineId: 1,
            shiftLineId: 801,
            selectable: true,
            machineNumber: 1,
            operatorName: 'م. حمزة',
          ),
        ]);
        registry.applyState(_active(<int>{801}, activeId: 801));

        await _settle(tester);
        await _settle(tester);

        // The new session (801) shows its OWN empty scope — the old session's
        // consumed roll must NOT leak across the shiftLineId boundary.
        expect(find.text('AAA000000800'), findsNothing);
        expect(
          find.text('لا توجد رولات مستهلكة في هذه المناوبة بعد'),
          findsOneWidget,
        );
      },
    );
  });

  // LINE_3 handoff §6.10. Ids are skewed like production (V191): TF_LINE_3 is
  // machine 4 but palletizing line 3, and shift-line ids are a third,
  // unrelated space — so any id mix-up fails here, not only on the floor.
  group('LINE_3: three machines with skewed ids', () {
    TabController controllerOf(WidgetTester tester) =>
        tester.widget<TabBar>(find.byType(TabBar)).controller!;

    Future<void> selectTab(WidgetTester tester, String label) async {
      await tester.tap(find.text(label));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets(
      'three rows render three server-labelled tabs in server order, first '
      'tab rightmost; nothing is computed from machineNumber or ids',
      (WidgetTester tester) async {
        final container = _containerWith(
          bootstrap: () => _MutableBootstrap(<RollWorkerBootstrapLine>[
            _machine(1, shiftLineId: 9120),
            _machine(2, shiftLineId: 9121),
            _machine(3),
          ]),
          registry: () => _StaticRegistry(const RegistryEmpty()),
        );

        await tester.pumpWidget(_wrap(container));
        await _settle(tester);

        expect(tester.widget<TabBar>(find.byType(TabBar)).tabs.length, 3);
        expect(find.text('خط أ'), findsOneWidget);
        expect(find.text('خط ب'), findsOneWidget);
        expect(find.text('خط ج'), findsOneWidget);
        // RTL: the first server row is the rightmost tab.
        final double a = tester.getCenter(find.text('خط أ')).dx;
        final double b = tester.getCenter(find.text('خط ب')).dx;
        final double c = tester.getCenter(find.text('خط ج')).dx;
        expect(a, greaterThan(b));
        expect(b, greaterThan(c));
        // Never the old local letter, the machine name, or raw identity.
        expect(find.text('خط ت'), findsNothing);
        expect(find.textContaining('ماكينة'), findsNothing);
        expect(find.textContaining('TF_LINE'), findsNothing);
        expect(find.textContaining('خط التشغيل'), findsNothing);
      },
    );

    testWidgets(
      'machine C claimed while selected: its tab stays selected and turns '
      'PIN-enterable',
      (WidgetTester tester) async {
        final container = _containerWith(
          bootstrap: () => _MutableBootstrap(<RollWorkerBootstrapLine>[
            _machine(1, shiftLineId: 9120),
            _machine(2, shiftLineId: 9121),
            _machine(3),
          ]),
          registry: () => _StaticRegistry(const RegistryEmpty()),
        );

        await tester.pumpWidget(_wrap(container));
        await _settle(tester);
        await selectTab(tester, 'خط ج');
        expect(controllerOf(tester).index, 2);
        expect(find.byType(MachineWaitingCard), findsOneWidget);

        // The operator claims machine C: the row gains shift-line 9123.
        (container.read(rollWorkerBootstrapControllerProvider.notifier)
                as _MutableBootstrap)
            .setLines(<RollWorkerBootstrapLine>[
          _machine(1, shiftLineId: 9120),
          _machine(2, shiftLineId: 9121),
          _machine(3, shiftLineId: 9123),
        ]);
        await _settle(tester);

        expect(controllerOf(tester).index, 2, reason: 'no jump to machine A');
        expect(find.byType(MachineWaitingCard), findsNothing);
        expect(find.byType(RollWorkerAuthOverlay), findsOneWidget);
        expect(
          find.byKey(const ValueKey<String>('th-4/sl-9123')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'selection follows the machine, not the position, when a claim and a '
      'tab removal land together',
      (WidgetTester tester) async {
        final container = _containerWith(
          bootstrap: () => _MutableBootstrap(<RollWorkerBootstrapLine>[
            _machine(1, shiftLineId: 9120),
            _machine(2),
            _machine(3, shiftLineId: 9123),
          ]),
          registry: () => _StaticRegistry(const RegistryEmpty()),
        );

        await tester.pumpWidget(_wrap(container));
        await _settle(tester);
        await selectTab(tester, 'خط ب');
        expect(controllerOf(tester).index, 1);

        // In one refresh: machine A drops out and machine B is claimed.
        (container.read(rollWorkerBootstrapControllerProvider.notifier)
                as _MutableBootstrap)
            .setLines(<RollWorkerBootstrapLine>[
          _machine(2, shiftLineId: 9121),
          _machine(3, shiftLineId: 9123),
        ]);
        await _settle(tester);

        expect(controllerOf(tester).index, 0, reason: 'still on machine B');
        expect(
          find.byKey(const ValueKey<String>('th-2/sl-9121')),
          findsOneWidget,
        );
      },
    );

    testWidgets('PIN on machine C sends only its shift-line id (never 4 or 3)', (
      WidgetTester tester,
    ) async {
      final batchRepo = _MockBatchRepo();
      when(
        () => batchRepo.startBatch(
          pin: any<String>(named: 'pin'),
          shiftLineIds: any<Set<int>>(named: 'shiftLineIds'),
        ),
      ).thenAnswer(
        (_) async => BatchAuthSuccessResult(
          BatchAuthOutcome(
            rollWorkerOperatorId: 7,
            rollWorkerName: 'Yusuf',
            sessions: <int, RollWorkerSession>{
              9123: _session(9123, thermoformingLineId: 4, palletizingLineId: 3),
            },
          ),
        ),
      );
      final container = _containerWith(
        bootstrap: () => _MutableBootstrap(<RollWorkerBootstrapLine>[
          _machine(1),
          _machine(2),
          _machine(3, shiftLineId: 9123),
        ]),
        registry: () => _StaticRegistry(const RegistryEmpty()),
        batchRepo: batchRepo,
      );

      await tester.pumpWidget(_wrap(container));
      await _settle(tester);
      await selectTab(tester, 'خط ج');

      await tester.enterText(find.byType(TextField), '1234');
      await tester.pump();
      await tester.tap(find.text(RollWorkerAuthOverlay.submitLabel));
      await _settle(tester);

      verify(
        () => batchRepo.startBatch(pin: '1234', shiftLineIds: <int>{9123}),
      ).called(1);
      verifyNever(
        () => batchRepo.startBatch(
          pin: any<String>(named: 'pin'),
          shiftLineIds: <int>{4},
        ),
      );
      verifyNever(
        () => batchRepo.startBatch(
          pin: any<String>(named: 'pin'),
          shiftLineIds: <int>{3},
        ),
      );
      // Authorized now, and still on machine C.
      expect(find.byType(RollWorkerAuthOverlay), findsNothing);
      expect(controllerOf(tester).index, 2);
    });

    testWidgets(
      'LINE_3 disabled mid-session: C leaves /bootstrap but keeps its tab, '
      'cached label, machine colour and selection',
      (WidgetTester tester) async {
        // Shift-line 9125, not 9123: 9123 % 6 == 3 would give the same palette
        // slot as palletizing line 3 and hide a shift-line id used as a colour
        // key.
        final container = _containerWith(
          bootstrap: () => _MutableBootstrap(<RollWorkerBootstrapLine>[
            _machine(1, shiftLineId: 9120),
            _machine(2, shiftLineId: 9121),
            _machine(3, shiftLineId: 9125),
          ]),
          registry: () => _StaticRegistry(
            _activeWith(<RollWorkerSession>[
              _session(9125, thermoformingLineId: 4, palletizingLineId: 3),
            ]),
          ),
        );

        await tester.pumpWidget(_wrap(container));
        await _settle(tester);
        expect(controllerOf(tester).index, 2);

        (container.read(rollWorkerBootstrapControllerProvider.notifier)
                as _MutableBootstrap)
            .setLines(<RollWorkerBootstrapLine>[
          _machine(1, shiftLineId: 9120),
          _machine(2, shiftLineId: 9121),
        ]);
        await _settle(tester);

        expect(tester.widget<TabBar>(find.byType(TabBar)).tabs.length, 3);
        // /sessions/me is idle here, so the label comes from the cache.
        expect(find.text('خط ج'), findsOneWidget);
        expect(find.text(LineLabels.unknown), findsNothing);
        expect(controllerOf(tester).index, 2);
        final PerMachineTab tab = tester.widget<PerMachineTab>(
          find.byKey(const ValueKey<String>('th-4/sl-9125')),
        );
        expect(tab.kind, MachineTabKind.authorized);
        expect(tab.lineLabel, 'خط ج');
        // Colour from palletizing line 3 — the same colour C had in bootstrap.
        expect(tab.accent, AppColors.accentForLine(palletizingLineId: 3));
      },
    );

    testWidgets(
      'a session-only tab takes its label from /sessions/me and keeps its '
      "machine's slot instead of moving to the end",
      (WidgetTester tester) async {
        final container = _containerWith(
          bootstrap: () => _MutableBootstrap(<RollWorkerBootstrapLine>[
            _machine(1, shiftLineId: 9120),
            // No server label on B's row — only /sessions/me names it.
            _machine(2, shiftLineId: 9121, withLabel: false),
            _machine(3, shiftLineId: 9123),
          ]),
          registry: () => _StaticRegistry(
            _activeWith(<RollWorkerSession>[
              _session(9121, thermoformingLineId: 2, palletizingLineId: 2),
            ]),
          ),
          sessionsMe: () => _MutableSessionsMe(
            _meLoaded(<RollWorkerActiveLine>[
              _meLine(
                shiftLineId: 9121,
                thermoformingLineId: 2,
                palletizingLineId: 2,
                palletizingLineName: 'خط ب',
              ),
            ]),
          ),
        );

        await tester.pumpWidget(_wrap(container));
        await _settle(tester);

        // Machine B leaves /bootstrap; the worker still holds its session.
        (container.read(rollWorkerBootstrapControllerProvider.notifier)
                as _MutableBootstrap)
            .setLines(<RollWorkerBootstrapLine>[
          _machine(1, shiftLineId: 9120),
          _machine(3, shiftLineId: 9123),
        ]);
        await _settle(tester);

        expect(tester.widget<TabBar>(find.byType(TabBar)).tabs.length, 3);
        final double a = tester.getCenter(find.text('خط أ')).dx;
        final double b = tester.getCenter(find.text('خط ب')).dx;
        final double c = tester.getCenter(find.text('خط ج')).dx;
        expect(a, greaterThan(b));
        expect(b, greaterThan(c), reason: 'B stays between A and C');
      },
    );

    testWidgets(
      'the selected machine disappearing moves the selection to an existing '
      'tab without crashing',
      (WidgetTester tester) async {
        final container = _containerWith(
          bootstrap: () => _MutableBootstrap(<RollWorkerBootstrapLine>[
            _machine(1, shiftLineId: 9120),
            _machine(2, shiftLineId: 9121),
            _machine(3, shiftLineId: 9123),
          ]),
          registry: () => _StaticRegistry(const RegistryEmpty()),
        );

        await tester.pumpWidget(_wrap(container));
        await _settle(tester);
        await selectTab(tester, 'خط ج');

        (container.read(rollWorkerBootstrapControllerProvider.notifier)
                as _MutableBootstrap)
            .setLines(<RollWorkerBootstrapLine>[
          _machine(1, shiftLineId: 9120),
          _machine(2, shiftLineId: 9121),
        ]);
        await _settle(tester);

        expect(tester.takeException(), isNull);
        expect(tester.widget<TabBar>(find.byType(TabBar)).tabs.length, 2);
        expect(controllerOf(tester).index, 1);
        expect(find.text('خط ج'), findsNothing);
      },
    );

    for (final Size size in const <Size>[Size(360, 780), Size(1280, 800)]) {
      testWidgets(
        'three tabs lay out at ${size.width.toInt()} dp without clipping or '
        'wrapping',
        (WidgetTester tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final container = _containerWith(
            bootstrap: () => _MutableBootstrap(<RollWorkerBootstrapLine>[
              _machine(1, shiftLineId: 9120),
              _machine(2, shiftLineId: 9121),
              _machine(3),
            ]),
            registry: () => _StaticRegistry(const RegistryEmpty()),
          );

          await tester.pumpWidget(_wrap(container));
          await _settle(tester);

          expect(tester.takeException(), isNull);
          expect(tester.widget<TabBar>(find.byType(TabBar)).isScrollable, isFalse);
          for (final String label in <String>['خط أ', 'خط ب', 'خط ج']) {
            final Text text = tester.widget<Text>(find.text(label));
            expect(text.maxLines, 1, reason: label);
            expect(text.softWrap, isFalse, reason: label);
          }
        },
      );
    }

    testWidgets('labels too long for fixed tabs switch the bar to scrollable', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final container = _containerWith(
        bootstrap: () => _MutableBootstrap(<RollWorkerBootstrapLine>[
          for (int n = 1; n <= 4; n++)
            _line(
              thermoformingLineId: n,
              shiftLineId: 9120 + n,
              selectable: true,
              label: 'خط الطبليات الرئيسي $n',
              operatorName: 'م. حمزة',
            ),
        ]),
        registry: () => _StaticRegistry(const RegistryEmpty()),
      );

      await tester.pumpWidget(_wrap(container));
      await _settle(tester);

      expect(tester.takeException(), isNull);
      final TabBar bar = tester.widget<TabBar>(find.byType(TabBar));
      expect(bar.tabs.length, 4);
      expect(bar.isScrollable, isTrue);
      expect(bar.tabAlignment, TabAlignment.start);
    });

    testWidgets(
      'logged in: each fresh /sessions/me snapshot nudges a background '
      '/bootstrap refresh',
      (WidgetTester tester) async {
        final container = _containerWith(
          bootstrap: () => _CountingBootstrap(<RollWorkerBootstrapLine>[
            _machine(1, shiftLineId: 9120),
            _machine(2, shiftLineId: 9121),
          ]),
          registry: () => _StaticRegistry(
            _activeWith(<RollWorkerSession>[
              _session(9120, thermoformingLineId: 1, palletizingLineId: 1),
            ]),
          ),
          sessionsMe: () => _MutableSessionsMe(const SessionsMeIdle()),
        );

        await tester.pumpWidget(_wrap(container));
        await _settle(tester);
        final _CountingBootstrap bootstrap =
            container.read(rollWorkerBootstrapControllerProvider.notifier)
                as _CountingBootstrap;
        final _MutableSessionsMe me =
            container.read(sessionsMeControllerProvider.notifier)
                as _MutableSessionsMe;
        expect(bootstrap.refreshTriggers, isEmpty);

        final RollWorkerMe snapshot = _meLoaded(<RollWorkerActiveLine>[
          _meLine(
            shiftLineId: 9120,
            thermoformingLineId: 1,
            palletizingLineId: 1,
            palletizingLineName: 'خط أ',
          ),
        ]).me;
        final DateTime t1 = DateTime.utc(2026, 9, 15, 8);
        me.emit(SessionsMeLoaded(me: snapshot, fetchedAt: t1));
        await _settle(tester);
        expect(bootstrap.refreshTriggers, <String>['shell-sessions-sync']);

        // Same snapshot again (no new fetch) → no extra refresh.
        me.emit(SessionsMeLoaded(me: snapshot, fetchedAt: t1));
        await _settle(tester);
        expect(bootstrap.refreshTriggers, hasLength(1));

        me.emit(
          SessionsMeLoaded(
            me: snapshot,
            fetchedAt: t1.add(const Duration(seconds: 2)),
          ),
        );
        await _settle(tester);
        expect(bootstrap.refreshTriggers, hasLength(2));
      },
    );
  });
}

// ─── LINE_3 fixtures ─────────────────────────────────────────────────────

const List<String> _letters = <String>['أ', 'ب', 'ج'];

/// Machine [n] (1..3) as production has it after V191: machine ids 1, 2, 4
/// feed palletizing lines 1, 2, 3. Waiting (no operator) unless
/// [shiftLineId] is given. The row carries the server label `خط أ/ب/ج`
/// unless [withLabel] is false.
RollWorkerBootstrapLine _machine(
  int n, {
  int? shiftLineId,
  bool withLabel = true,
}) {
  final bool claimed = shiftLineId != null;
  return _line(
    thermoformingLineId: n == 3 ? 4 : n,
    palletizingLineId: n,
    machineNumber: n,
    shiftLineId: shiftLineId,
    selectable: claimed,
    label: withLabel ? 'خط ${_letters[n - 1]}' : '',
    lineCode: 'TF_LINE_$n',
    lineName: 'خط التشغيل ${_letters[n - 1]}',
    lineDisplayName: 'ماكينة ${'ABC'[n - 1]}',
    operatorName: claimed ? 'م. حمزة' : null,
    lifecycle: claimed ? 'ACTIVE' : 'NO_ACTIVE_SHIFT',
  );
}

RegistryActive _activeWith(List<RollWorkerSession> sessions) => RegistryActive(
  sessions: <int, RollWorkerSession>{
    for (final RollWorkerSession s in sessions) s.thermoformingShiftLineId: s,
  },
  activeShiftLineId: sessions.first.thermoformingShiftLineId,
  logoutStatus: <int, LineLogoutStatus>{
    for (final RollWorkerSession s in sessions)
      s.thermoformingShiftLineId: LineLogoutStatus.idle,
  },
);

RollWorkerActiveLine _meLine({
  required int shiftLineId,
  required int thermoformingLineId,
  required int palletizingLineId,
  required String palletizingLineName,
}) => RollWorkerActiveLine(
  sessionId: shiftLineId + 30000,
  shiftLineId: shiftLineId,
  palletizingLineId: palletizingLineId,
  palletizingLineCode: 'LINE_$palletizingLineId',
  palletizingLineName: palletizingLineName,
  thermoformingLineId: thermoformingLineId,
  thermoformingLineCode: 'TF_LINE_$palletizingLineId',
  thermoformingLineName: 'خط التشغيل',
  thermoformingShiftId: 5052,
  supervisingOperatorId: 31,
  supervisingOperatorName: 'م. حمزة',
  currentPlanItemProductTypeId: null,
  currentPlanItemProductName: null,
  currentRollId: null,
  currentRollGeneratedRollId: null,
  currentRollTypeCode: null,
  currentRollTypeName: null,
  currentRollLastKnownWeightKg: null,
  handoverPending: false,
  takeoverRequestStatus: null,
  takeoverIncomingOperatorName: null,
  blocked: false,
  blockedReason: null,
  lineLifecycleStatus: 'ACTIVE',
  sessionStartedAt: null,
  sessionStartedAtDisplay: null,
);

SessionsMeLoaded _meLoaded(List<RollWorkerActiveLine> lines) => SessionsMeLoaded(
  me: RollWorkerMe(
    rollWorkerOperatorId: 7,
    rollWorkerName: 'Yusuf',
    lines: lines,
  ),
  fetchedAt: DateTime.utc(2026, 9, 15, 7),
);

/// /sessions/me pinned to a state the test swaps via [emit]; no network.
class _MutableSessionsMe extends SessionsMeController {
  _MutableSessionsMe(this._initial);
  final SessionsMeState _initial;

  @override
  SessionsMeState build() => _initial;

  @override
  Future<void> refresh({
    String trigger = 'manual',
    bool background = true,
  }) async {}

  void emit(SessionsMeState next) => state = next;
}

/// Records every refresh trigger instead of fetching.
class _CountingBootstrap extends _MutableBootstrap {
  _CountingBootstrap(super.lines);
  final List<String> refreshTriggers = <String>[];

  @override
  Future<void> refresh({
    String trigger = 'manual',
    bool background = false,
  }) async {
    refreshTriggers.add(trigger);
  }
}

ProviderContainer _containerWith({
  required RollWorkerBootstrapController Function() bootstrap,
  required MultiLineSessionRegistry Function() registry,
  SessionsMeController Function()? sessionsMe,
  SessionBatchRepository? batchRepo,
}) {
  final auth = _MockAuthRepo();
  when(() => auth.clearStoredToken(any())).thenAnswer((_) async {});
  final index = _MockIndex();
  when(() => index.writeIds(any())).thenAnswer((_) async {});
  when(index.readIds).thenAnswer((_) async => <int>{});

  final container = ProviderContainer(
    overrides: <Override>[
      rollWorkerBootstrapControllerProvider.overrideWith(bootstrap),
      multiLineSessionRegistryProvider.overrideWith(registry),
      sessionsMeControllerProvider.overrideWith(
        sessionsMe ?? _FakeSessionsMe.new,
      ),
      rollWorkerAuthRepositoryProvider.overrideWithValue(auth),
      shiftLineSummaryRepositoryProvider.overrideWithValue(_summaryRepo()),
      sessionIndexStorageProvider.overrideWithValue(index),
      if (batchRepo != null)
        sessionBatchRepositoryProvider.overrideWithValue(batchRepo),
    ],
  );
  addTearDown(container.dispose);
  return container;
}
