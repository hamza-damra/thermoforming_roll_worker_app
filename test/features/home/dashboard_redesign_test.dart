import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:thermoforming_roll_worker/core/storage/session_index_storage.dart';
import 'package:thermoforming_roll_worker/core/storage/storage_providers.dart';
import 'package:thermoforming_roll_worker/core/theme/app_theme.dart';
import 'package:thermoforming_roll_worker/features/home/data/shift_line_summary_providers.dart';
import 'package:thermoforming_roll_worker/features/home/domain/entities/allowed_roll.dart';
import 'package:thermoforming_roll_worker/features/home/domain/entities/shift_line_summary.dart';
import 'package:thermoforming_roll_worker/features/home/domain/shift_line_summary_repository.dart';
import 'package:thermoforming_roll_worker/features/home/presentation/screens/roll_worker_home_screen.dart';
import 'package:thermoforming_roll_worker/features/home/presentation/widgets/consumed_rolls_section.dart';
import 'package:thermoforming_roll_worker/features/home/presentation/widgets/leave_line_confirm_dialog.dart';
import 'package:thermoforming_roll_worker/features/home/presentation/widgets/product_allowed_rolls_card.dart';
import 'package:thermoforming_roll_worker/features/home/presentation/widgets/roll_worker_session_card.dart';
import 'package:thermoforming_roll_worker/features/operator_dashboard_sse/presentation/controllers/operator_dashboard_sync_controller.dart';
import 'package:thermoforming_roll_worker/features/operator_dashboard_sse/presentation/controllers/operator_dashboard_sync_state.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/data/roll_worker_auth_providers.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/domain/entities/roll_worker_session.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/domain/roll_worker_auth_repository.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/presentation/controllers/multi_line_session_registry.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/presentation/controllers/multi_line_session_registry_state.dart';
import 'package:thermoforming_roll_worker/features/sessions_me/data/dto/roll_worker_me_response.dart';
import 'package:thermoforming_roll_worker/features/sessions_me/domain/entities/roll_worker_me.dart';
import 'package:thermoforming_roll_worker/features/sessions_me/presentation/controllers/sessions_me_controller.dart';
import 'package:thermoforming_roll_worker/features/sessions_me/presentation/controllers/sessions_me_state.dart';

class _MockSummaryRepo extends Mock implements ShiftLineSummaryRepository {}

class _MockAuthRepo extends Mock implements RollWorkerAuthRepository {}

class _MockIndex extends Mock implements SessionIndexStorage {}

const int _kShiftLineId = 800;

/// Fixed-state /sessions/me (no timers, no network).
class _FakeSessionsMe extends SessionsMeController {
  _FakeSessionsMe(this._initial);
  final SessionsMeState _initial;
  @override
  SessionsMeState build() => _initial;
}

/// Registry pinned to an initial state; restore is a no-op but `logout`
/// remains inherited so the leave dialog runs the real per-line logout.
class _SeededRegistry extends MultiLineSessionRegistry {
  _SeededRegistry(this._initial);
  final MultiLineSessionRegistryState _initial;
  @override
  MultiLineSessionRegistryState build() => _initial;
  @override
  Future<void> restoreFromStorage() async {}
}

/// No-op SSE controller — the screen never starts a real subscription.
class _NoopSync extends OperatorDashboardSyncController {
  @override
  OperatorDashboardSyncState build(int arg) =>
      const OperatorDashboardSyncState.idle();
  @override
  Future<void> start() async {}
  @override
  Future<void> stop() async {}
  @override
  void onAppResumed() {}
  @override
  void onAppPaused() {}
}

RollWorkerSession _session(int shiftLineId) => RollWorkerSession(
  sessionId: shiftLineId,
  rollWorkerOperatorId: 7,
  rollWorkerName: 'يوسف',
  thermoformingShiftId: 9000,
  thermoformingShiftLineId: shiftLineId,
  thermoformingLineId: 11,
  palletizingLineId: 21,
  startedAt: DateTime.parse('2026-05-10T10:00:00Z'),
  status: 'ACTIVE',
);

RegistryActive _active(Set<int> ids) => RegistryActive(
  sessions: <int, RollWorkerSession>{for (final int id in ids) id: _session(id)},
  activeShiftLineId: ids.first,
  logoutStatus: <int, LineLogoutStatus>{
    for (final int id in ids) id: LineLogoutStatus.idle,
  },
);

RollWorkerMe _me({bool loggedIn = true, String? productName = 'Blue 10kg'}) {
  return RollWorkerMeResponse.fromEnvelopeData(<String, dynamic>{
    'rollWorkerOperatorId': 7,
    'rollWorkerName': 'يوسف',
    'lines': <Map<String, dynamic>>[
      if (loggedIn)
        <String, dynamic>{
          'sessionId': 1,
          'shiftLineId': _kShiftLineId,
          'currentPlanItemProductTypeId': productName == null ? null : 6,
          'currentPlanItemProductName': productName,
          'sessionStartedAt': '2026-05-29T08:00:00.000Z',
          'sessionStartedAtDisplay': '10:00 ص',
          'lineLifecycleStatus': 'ACTIVE',
        },
    ],
  });
}

const AllowedRoll _preferredRoll = AllowedRoll(
  id: 70,
  code: 'TP-6',
  name: 'زبدية',
  colorName: 'Black',
  thicknessStandardMm: 1.8,
  displayName: 'TP-6 Black / زبدية',
  preferred: true,
  active: true,
);

const AllowedRoll _inactiveRoll = AllowedRoll(
  id: 71,
  code: 'TP-2',
  name: 'علبة',
  colorName: 'White',
  displayName: 'TP-2 White / علبة',
  preferred: false,
  active: false,
);

ConsumedRoll _consumedRoll() => ConsumedRoll(
  consumptionItemId: 900,
  rollId: 12345,
  generatedRollId: '001000000123',
  rollTypeCode: 'CR-1',
  rollTypeName: 'Used',
  startWeightKg: 200,
  endWeightKg: 0,
  consumedWeightKg: 200,
  closedReason: 'FULL_CONSUMPTION',
  remainderAction: 'NONE',
  endedAt: DateTime.utc(2026, 5, 23, 10),
  endedAtDisplay: '23 أيار، 10:00 ص',
);

ShiftLineSummary _summary({
  List<AllowedRoll> allowedRolls = const <AllowedRoll>[],
  List<ConsumedRoll> consumedRolls = const <ConsumedRoll>[],
  String? activeOperatorName = 'مشغل التشكيل',
}) => ShiftLineSummary(
  shiftLineId: _kShiftLineId,
  thermoformingLineCode: 'TH-01',
  thermoformingLineName: 'خط التشكيل 1',
  completedRollsInSession: 8,
  completedRollsByCurrentWorker: 8,
  activeOperatorName: activeOperatorName,
  allowedRolls: allowedRolls,
  consumedRolls: consumedRolls,
);

ProviderContainer _makeContainer({
  required ShiftLineSummary summary,
  SessionsMeState? sessionsMe,
  MultiLineSessionRegistryState? registry,
  RollWorkerAuthRepository? authRepo,
}) {
  final _MockSummaryRepo summaryRepo = _MockSummaryRepo();
  when(
    () => summaryRepo.fetchSummary(shiftLineId: _kShiftLineId),
  ).thenAnswer((_) async => SummarySuccess(summary));

  final RollWorkerAuthRepository auth = authRepo ?? _MockAuthRepo();
  when(() => auth.clearStoredToken(any())).thenAnswer((_) async {});

  final _MockIndex index = _MockIndex();
  when(() => index.writeIds(any())).thenAnswer((_) async {});
  when(index.readIds).thenAnswer((_) async => <int>{});

  return ProviderContainer(
    overrides: <Override>[
      shiftLineSummaryRepositoryProvider.overrideWithValue(summaryRepo),
      rollWorkerAuthRepositoryProvider.overrideWithValue(auth),
      sessionIndexStorageProvider.overrideWithValue(index),
      operatorDashboardSyncControllerProvider.overrideWith(_NoopSync.new),
      sessionsMeControllerProvider.overrideWith(
        () => _FakeSessionsMe(sessionsMe ?? SessionsMeLoaded(
          me: _me(),
          fetchedAt: DateTime(2026, 5, 23),
        )),
      ),
      if (registry != null)
        multiLineSessionRegistryProvider.overrideWith(
          () => _SeededRegistry(registry),
        ),
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
      home: const RollWorkerHomeScreen(shiftLineId: _kShiftLineId),
    ),
  );
}

void _useTallSurface(WidgetTester tester) {
  // The redesigned dashboard is intentionally tall (many stacked cards). Give
  // the ListView a large viewport so every section is laid out for finders.
  tester.view.physicalSize = const Size(1200, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('merged worker card shows the worker name; expands to operator '
      '+ relative session start', (WidgetTester tester) async {
    _useTallSurface(tester);
    final ProviderContainer container = _makeContainer(
      summary: _summary(allowedRolls: <AllowedRoll>[_preferredRoll]),
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_wrap(container));
    await tester.pumpAndSettle();

    // One merged worker-session card, not the old separate operator/worker
    // cards.
    expect(find.byType(RollWorkerSessionCard), findsOneWidget);
    // Collapsed: roll worker name is shown; the operator name is hidden.
    expect(find.text('يوسف'), findsOneWidget);
    expect(find.text('مشغل التشكيل'), findsNothing);
    // Product card carries both titles.
    expect(find.text(ProductAllowedRollsCard.productTitle), findsOneWidget);
    expect(find.text(ProductAllowedRollsCard.allowedTitle), findsOneWidget);

    // Expand the worker card → operator name + relative session start appear.
    await tester.tap(find.text('يوسف'));
    await tester.pumpAndSettle();
    expect(find.text('مشغل التشكيل'), findsOneWidget);
    expect(find.textContaining(RollWorkerSessionCard.operatorLabel), findsOneWidget);
    expect(find.textContaining('منذ'), findsOneWidget);
  });

  testWidgets('allowed roll badges use the de-duplicated Arabic label, '
      'collapsed→expanded', (WidgetTester tester) async {
    _useTallSurface(tester);
    final ProviderContainer container = _makeContainer(
      summary: _summary(
        allowedRolls: <AllowedRoll>[_preferredRoll, _inactiveRoll],
      ),
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_wrap(container));
    await tester.pumpAndSettle();

    // Collapsed: only the first (preferred) badge previews. Label is the
    // shared de-duplicated format `TP-6 Black (زبدية)` — never `TP-6 Black Black`.
    expect(find.text('TP-6 Black (زبدية)'), findsOneWidget);
    expect(find.text(ProductAllowedRollsCard.preferredBadge), findsOneWidget);
    expect(find.text('TP-2 White (علبة)'), findsNothing); // hidden until expand
    expect(find.textContaining('Black Black'), findsNothing); // no duplicate

    // Expand the card → all badges visible (incl. the inactive marker).
    await tester.tap(find.text(ProductAllowedRollsCard.productTitle));
    await tester.pumpAndSettle();

    expect(find.text('TP-6 Black (زبدية)'), findsOneWidget);
    expect(find.text('TP-2 White (علبة)'), findsOneWidget);
    expect(find.text(ProductAllowedRollsCard.inactiveBadge), findsOneWidget);
  });

  testWidgets('empty allowedRolls shows the calm empty state (not an error)', (
    WidgetTester tester,
  ) async {
    _useTallSurface(tester);
    final ProviderContainer container = _makeContainer(
      summary: _summary(allowedRolls: const <AllowedRoll>[]),
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_wrap(container));
    await tester.pumpAndSettle();

    expect(find.text(ProductAllowedRollsCard.allowedEmpty), findsOneWidget);
    // The allowed-rolls title is still present (calm, not an error surface).
    expect(find.text(ProductAllowedRollsCard.allowedTitle), findsOneWidget);
  });

  testWidgets('consumed rolls section is rendered below the allowed rolls', (
    WidgetTester tester,
  ) async {
    _useTallSurface(tester);
    final ProviderContainer container = _makeContainer(
      summary: _summary(
        allowedRolls: <AllowedRoll>[_preferredRoll],
        consumedRolls: <ConsumedRoll>[_consumedRoll()],
      ),
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_wrap(container));
    await tester.pumpAndSettle();

    final double allowedY = tester
        .getTopLeft(find.text(ProductAllowedRollsCard.allowedTitle))
        .dy;
    final double consumedY = tester
        .getTopLeft(find.text(ConsumedRollsSection.heading))
        .dy;
    expect(consumedY, greaterThan(allowedY));
  });

  testWidgets('empty state appears when there is no logged-in roll employee', (
    WidgetTester tester,
  ) async {
    _useTallSurface(tester);
    final ProviderContainer container = _makeContainer(
      summary: _summary(),
      sessionsMe: SessionsMeLoaded(
        me: _me(loggedIn: false),
        fetchedAt: DateTime(2026, 5, 23),
      ),
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_wrap(container));
    await tester.pumpAndSettle();

    expect(find.text(RollWorkerSessionCard.emptyState), findsOneWidget);
    // No leave button when nobody is logged in.
    expect(find.text(RollWorkerSessionCard.leaveLabel), findsNothing);
  });

  testWidgets('مغادرة الآن opens the clean confirmation dialog', (
    WidgetTester tester,
  ) async {
    _useTallSurface(tester);
    final ProviderContainer container = _makeContainer(
      summary: _summary(),
      registry: _active(<int>{_kShiftLineId}),
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_wrap(container));
    await tester.pumpAndSettle();

    expect(find.text(RollWorkerSessionCard.leaveLabel), findsOneWidget);
    await tester.tap(find.text(RollWorkerSessionCard.leaveLabel));
    await tester.pumpAndSettle();

    expect(find.byType(LeaveLineConfirmDialog), findsOneWidget);
    expect(find.text(LeaveLineConfirmDialog.title), findsOneWidget);
    expect(find.text(LeaveLineConfirmDialog.body), findsOneWidget);
    expect(find.text(LeaveLineConfirmDialog.confirmLabel), findsOneWidget);
    expect(find.text(LeaveLineConfirmDialog.cancelLabel), findsOneWidget);
  });

  testWidgets('confirm logout shows loading then succeeds with feedback', (
    WidgetTester tester,
  ) async {
    _useTallSurface(tester);
    final _MockAuthRepo auth = _MockAuthRepo();
    when(() => auth.clearStoredToken(any())).thenAnswer((_) async {});
    final Completer<void> gate = Completer<void>();
    when(() => auth.logout(_kShiftLineId)).thenAnswer((_) => gate.future);

    final ProviderContainer container = _makeContainer(
      summary: _summary(),
      registry: _active(<int>{_kShiftLineId}),
      authRepo: auth,
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_wrap(container));
    await tester.pumpAndSettle();

    await tester.tap(find.text(RollWorkerSessionCard.leaveLabel));
    await tester.pumpAndSettle();

    await tester.tap(find.text(LeaveLineConfirmDialog.confirmLabel));
    await tester.pump(); // kick off the in-flight logout

    // Loading spinner inside the dialog while the request is in flight.
    expect(
      find.descendant(
        of: find.byType(LeaveLineConfirmDialog),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );

    gate.complete();
    await tester.pumpAndSettle();

    // Dialog closed + success snackbar shown.
    expect(find.byType(LeaveLineConfirmDialog), findsNothing);
    expect(find.text('تم تسجيل خروجك من الخط'), findsOneWidget);
    verify(() => auth.logout(_kShiftLineId)).called(1);
  });

  testWidgets('confirm logout surfaces an inline error on failure', (
    WidgetTester tester,
  ) async {
    _useTallSurface(tester);
    final _MockAuthRepo auth = _MockAuthRepo();
    when(() => auth.clearStoredToken(any())).thenAnswer((_) async {});
    when(() => auth.logout(_kShiftLineId)).thenThrow(Exception('boom'));

    final ProviderContainer container = _makeContainer(
      summary: _summary(),
      registry: _active(<int>{_kShiftLineId}),
      authRepo: auth,
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_wrap(container));
    await tester.pumpAndSettle();

    await tester.tap(find.text(RollWorkerSessionCard.leaveLabel));
    await tester.pumpAndSettle();
    await tester.tap(find.text(LeaveLineConfirmDialog.confirmLabel));
    await tester.pumpAndSettle();

    // Dialog stays open with an inline error.
    expect(find.byType(LeaveLineConfirmDialog), findsOneWidget);
    expect(find.text(LeaveLineConfirmDialog.errorMessage), findsOneWidget);
  });
}
