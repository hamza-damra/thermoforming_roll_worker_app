import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:thermoforming_roll_worker/app/app.dart';
import 'package:thermoforming_roll_worker/app/bootstrap_screen.dart';
import 'package:thermoforming_roll_worker/core/config/app_config.dart';
import 'package:thermoforming_roll_worker/core/config/config_providers.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/data/roll_worker_auth_providers.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/domain/entities/roll_worker_session.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/domain/roll_worker_auth_repository.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/presentation/controllers/multi_line_session_registry.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/presentation/controllers/multi_line_session_registry_state.dart';
import 'package:thermoforming_roll_worker/features/shift_line/data/roll_worker_bootstrap_providers.dart';
import 'package:thermoforming_roll_worker/features/shift_line/data/roll_worker_lines_sse_providers.dart';
import 'package:thermoforming_roll_worker/features/shift_line/domain/entities/roll_worker_bootstrap_line.dart';
import 'package:thermoforming_roll_worker/features/shift_line/domain/roll_worker_bootstrap_repository.dart';
import 'package:thermoforming_roll_worker/features/home/data/shift_line_summary_providers.dart';
import 'package:thermoforming_roll_worker/features/home/domain/entities/shift_line_summary.dart';
import 'package:thermoforming_roll_worker/features/home/domain/shift_line_summary_repository.dart';

import '../features/shift_line/fake_roll_worker_lines_sse_client.dart';

class _MockAuthRepo extends Mock implements RollWorkerAuthRepository {}

class _MockBootstrapRepo extends Mock
    implements RollWorkerBootstrapRepository {}

class _MockSummaryRepo extends Mock implements ShiftLineSummaryRepository {}

ShiftLineSummaryRepository _summaryRepo() {
  final repo = _MockSummaryRepo();
  when(
    () => repo.fetchSummary(shiftLineId: any(named: 'shiftLineId')),
  ).thenAnswer(
    (invocation) async {
      final int id =
          invocation.namedArguments[const Symbol('shiftLineId')] as int;
      return SummarySuccess(
        ShiftLineSummary(
          shiftLineId: id,
          thermoformingLineCode: 'TH-01',
          thermoformingLineName: 'خط التشكيل 1',
          completedRollsInSession: 0,
          completedRollsByCurrentWorker: 0,
          activeOperatorName: 'مشغل التشكيل',
        ),
      );
    },
  );
  return repo;
}

RollWorkerBootstrapRepository _emptyBootstrapRepo() {
  final repo = _MockBootstrapRepo();
  when(repo.fetch).thenAnswer(
    (_) async => const RollWorkerBootstrapSuccess(<RollWorkerBootstrapLine>[]),
  );
  return repo;
}

/// Overrides for the pre-login bootstrap picker: an empty `/bootstrap` repo
/// plus a fake SSE client so no real socket / reconnect timers leak into the
/// widget test.
List<Override> _pickerOverrides() {
  final sse = FakeRollWorkerLinesSseClient();
  addTearDown(sse.dispose);
  return <Override>[
    rollWorkerBootstrapRepositoryProvider.overrideWithValue(
      _emptyBootstrapRepo(),
    ),
    rollWorkerLinesSseClientProvider.overrideWithValue(sse),
  ];
}

const AppConfig _testConfig = AppConfig(
  apiBaseUrl: 'https://test.local',
  deviceKey: 'k',
);

const int kShiftLineId = 800;

RollWorkerSession _session({int shiftLineId = kShiftLineId}) =>
    RollWorkerSession(
      sessionId: 1,
      rollWorkerOperatorId: 1,
      rollWorkerName: 'Ahmad',
      thermoformingShiftId: 700,
      thermoformingShiftLineId: shiftLineId,
      thermoformingLineId: 200,
      palletizingLineId: 10,
      startedAt: DateTime.parse('2026-05-08T13:00:00Z'),
      status: 'ACTIVE',
    );

class _StaticRegistry extends MultiLineSessionRegistry {
  _StaticRegistry(this._initial);
  final MultiLineSessionRegistryState _initial;

  @override
  MultiLineSessionRegistryState build() => _initial;

  @override
  Future<void> restoreFromStorage() async {
    // Tests pre-seed the state via [_initial]; the bootstrap calls this on
    // first frame and on resume — make it a no-op here.
  }
}

MultiLineSessionRegistryState _empty() => const RegistryEmpty();

MultiLineSessionRegistryState _activeWith(
  Map<int, RollWorkerSession> sessions, {
  int? activeId,
}) => RegistryActive(
  sessions: sessions,
  activeShiftLineId: activeId ?? sessions.keys.first,
  logoutStatus: <int, LineLogoutStatus>{
    for (final int id in sessions.keys) id: LineLogoutStatus.idle,
  },
);

void main() {
  testWidgets(
    'cold start with empty registry → renders the picker empty-state copy',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            appConfigProvider.overrideWithValue(_testConfig),
            multiLineSessionRegistryProvider.overrideWith(
              () => _StaticRegistry(_empty()),
            ),
            ..._pickerOverrides(),
          ],
          child: const RollWorkerApp(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('بانتظار فتح خط من تطبيق المشغّل'), findsOneWidget);
    },
  );

  testWidgets(
    'cold start with one active session → renders the multi-line home',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            appConfigProvider.overrideWithValue(_testConfig),
            multiLineSessionRegistryProvider.overrideWith(
              () => _StaticRegistry(
                _activeWith(<int, RollWorkerSession>{
                  kShiftLineId: _session(),
                }),
              ),
            ),
            rollWorkerAuthRepositoryProvider.overrideWithValue(_MockAuthRepo()),
            shiftLineSummaryRepositoryProvider.overrideWithValue(_summaryRepo()),
            ..._pickerOverrides(),
          ],
          child: const RollWorkerApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Home screen rendered — RTL is preserved.
      final BuildContext ctx = tester.element(find.byType(Scaffold).first);
      expect(Directionality.of(ctx), TextDirection.rtl);
      // Single-line mode: no NavigationBar.
      expect(find.byType(NavigationBar), findsNothing);
    },
  );

  testWidgets(
    'cold start with two active sessions → renders NavigationBar with two tabs',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            appConfigProvider.overrideWithValue(_testConfig),
            multiLineSessionRegistryProvider.overrideWith(
              () => _StaticRegistry(
                _activeWith(<int, RollWorkerSession>{
                  800: _session(shiftLineId: 800),
                  801: _session(shiftLineId: 801),
                }),
              ),
            ),
            rollWorkerAuthRepositoryProvider.overrideWithValue(_MockAuthRepo()),
            shiftLineSummaryRepositoryProvider.overrideWithValue(_summaryRepo()),
            ..._pickerOverrides(),
          ],
          child: const RollWorkerApp(),
        ),
      );
      await tester.pumpAndSettle();

      // New shell (handoff §8 items 6-7): synced PageView + BottomNavigationBar.
      expect(find.byType(BottomNavigationBar), findsOneWidget);
      expect(find.byType(PageView), findsOneWidget);
      // Two tabs → two destinations on the nav.
      final BottomNavigationBar nav = tester.widget<BottomNavigationBar>(
        find.byType(BottomNavigationBar),
      );
      expect(nav.items.length, 2);
    },
  );

  testWidgets(
    'cascade snackbar fires when active line is lost while others remain',
    (WidgetTester tester) async {
      late ProviderContainer container;
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            appConfigProvider.overrideWithValue(_testConfig),
            multiLineSessionRegistryProvider.overrideWith(
              () => _StaticRegistry(
                _activeWith(
                  <int, RollWorkerSession>{
                    800: _session(shiftLineId: 800),
                    801: _session(shiftLineId: 801),
                  },
                  activeId: 800,
                ),
              ),
            ),
            rollWorkerAuthRepositoryProvider.overrideWithValue(_MockAuthRepo()),
            shiftLineSummaryRepositoryProvider.overrideWithValue(_summaryRepo()),
            ..._pickerOverrides(),
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

      // Simulate a non-active-line loss first: should NOT fire a snackbar.
      container.read(multiLineSessionRegistryProvider.notifier).state =
          RegistryActive(
            sessions: <int, RollWorkerSession>{800: _session(shiftLineId: 800)},
            activeShiftLineId: 800,
            logoutStatus: const <int, LineLogoutStatus>{800: LineLogoutStatus.idle},
            lastEvent: const LineLost(801),
          );
      await tester.pump();
      await tester.pump();
      expect(find.text(BootstrapScreen.cascadeMessage), findsNothing);

      // Now lose the active line — surviving sessions remain. Snackbar fires.
      container.read(multiLineSessionRegistryProvider.notifier).state =
          RegistryActive(
            sessions: <int, RollWorkerSession>{801: _session(shiftLineId: 801)},
            activeShiftLineId: 801,
            logoutStatus: const <int, LineLogoutStatus>{801: LineLogoutStatus.idle},
            lastEvent: const LineLost(800),
          );
      await tester.pump();
      await tester.pump();

      expect(find.text(BootstrapScreen.cascadeMessage), findsOneWidget);
    },
  );

  testWidgets(
    'cascade snackbar fires when registry transitions Active → Empty via LineLost',
    (WidgetTester tester) async {
      late ProviderContainer container;
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            appConfigProvider.overrideWithValue(_testConfig),
            multiLineSessionRegistryProvider.overrideWith(
              () => _StaticRegistry(
                _activeWith(<int, RollWorkerSession>{
                  kShiftLineId: _session(),
                }),
              ),
            ),
            rollWorkerAuthRepositoryProvider.overrideWithValue(_MockAuthRepo()),
            shiftLineSummaryRepositoryProvider.overrideWithValue(_summaryRepo()),
            ..._pickerOverrides(),
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

      container.read(multiLineSessionRegistryProvider.notifier).state =
          const RegistryEmpty(lastEvent: LineLost(kShiftLineId));
      await tester.pump();
      await tester.pump();

      expect(find.text(BootstrapScreen.cascadeMessage), findsOneWidget);
    },
  );

  testWidgets(
    'no cascade snackbar on a deliberate logout (Active → Empty without LineLost)',
    (WidgetTester tester) async {
      late ProviderContainer container;
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            appConfigProvider.overrideWithValue(_testConfig),
            multiLineSessionRegistryProvider.overrideWith(
              () => _StaticRegistry(
                _activeWith(<int, RollWorkerSession>{
                  kShiftLineId: _session(),
                }),
              ),
            ),
            rollWorkerAuthRepositoryProvider.overrideWithValue(_MockAuthRepo()),
            shiftLineSummaryRepositoryProvider.overrideWithValue(_summaryRepo()),
            ..._pickerOverrides(),
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

      container.read(multiLineSessionRegistryProvider.notifier).state =
          const RegistryEmpty(lastEvent: DeliberateLogout(kShiftLineId));
      await tester.pump();
      await tester.pump();

      expect(find.text(BootstrapScreen.cascadeMessage), findsNothing);
    },
  );
}
