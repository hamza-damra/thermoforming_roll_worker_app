import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../printer/presentation/screens/printer_settings_screen.dart';
import '../../../roll_worker_auth/presentation/controllers/multi_line_session_registry.dart';
import '../../../roll_worker_auth/presentation/controllers/multi_line_session_registry_state.dart';
import '../controllers/shift_line_summary_controller.dart';
import '../controllers/shift_line_summary_state.dart';
import '../widgets/logout_all_confirm_dialog.dart';
import 'roll_worker_home_screen.dart';

/// Top-level home shell.
///
/// **Single active session (1 line):** renders [RollWorkerHomeScreen] with its
/// own [AppScaffold] — no bottom navigation.
///
/// **Multiple active sessions (≥2 lines):** renders a [Scaffold] with a
/// [NavigationBar], one destination per line. Destination labels are the
/// backend-supplied line code (`TH-01`); while the summary is still loading the
/// fallback `خط N` (1-based) is shown.
///
/// Switching destinations:
/// 1. Moves the active-line pointer in the registry.
/// 2. Triggers a summary refresh for the newly focused line so the worker
///    always sees up-to-date counts on tab focus.
class MultiLineHomeShell extends ConsumerWidget {
  const MultiLineHomeShell({super.key});

  static const String menuLogoutCurrent = 'تسجيل خروج من الخط الحالي';
  static const String menuLogoutAll = 'تسجيل خروج من جميع الخطوط';
  static const String printerSettingsTooltip = 'إعدادات الطباعة';

  Future<void> _onMenuSelected(
    BuildContext context,
    WidgetRef ref,
    _MenuAction action,
    RegistryActive state,
  ) async {
    switch (action) {
      case _MenuAction.logoutCurrent:
        await ref
            .read(multiLineSessionRegistryProvider.notifier)
            .logout(state.activeShiftLineId);
      case _MenuAction.logoutAll:
        await LogoutAllConfirmDialog.show(
          context,
          lineCount: state.sessions.length,
        );
    }
  }

  void _onDestinationSelected(int index, List<int> ids, WidgetRef ref) {
    final int newId = ids[index];
    ref.read(multiLineSessionRegistryProvider.notifier).setActive(newId);
    ref
        .read(shiftLineSummaryControllerProvider(newId).notifier)
        .refresh();
  }

  String _tabLabel(int shiftLineId, int oneBasedIndex, WidgetRef ref) {
    final ShiftLineSummaryState s = ref.watch(
      shiftLineSummaryControllerProvider(shiftLineId),
    );
    if (s is SummaryLoaded) return s.summary.thermoformingLineCode;
    return 'خط $oneBasedIndex';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final MultiLineSessionRegistryState registry = ref.watch(
      multiLineSessionRegistryProvider,
    );
    if (registry is! RegistryActive) return const SizedBox.shrink();

    final List<int> ids = registry.sessions.keys.toList(growable: false);
    final int activeId = registry.activeShiftLineId;
    final int currentIndex = ids.indexOf(activeId).clamp(0, ids.length - 1);

    Widget popupMenu(RegistryActive state) => PopupMenuButton<_MenuAction>(
      tooltip: 'القائمة',
      icon: const Icon(Icons.more_vert_rounded),
      onSelected: (action) => _onMenuSelected(context, ref, action, state),
      itemBuilder: (_) => const <PopupMenuEntry<_MenuAction>>[
        PopupMenuItem<_MenuAction>(
          value: _MenuAction.logoutCurrent,
          child: Text(menuLogoutCurrent),
        ),
        PopupMenuItem<_MenuAction>(
          value: _MenuAction.logoutAll,
          child: Text(menuLogoutAll),
        ),
      ],
    );

    // ── Single-line mode: no bottom navigation ──────────────────────────────
    if (ids.length == 1) {
      return RollWorkerHomeScreen(
        shiftLineId: activeId,
        lineIndex: 1,
        standaloneScaffold: true,
        headerActions: <Widget>[popupMenu(registry)],
      );
    }

    // ── Multi-line mode: NavigationBar ──────────────────────────────────────
    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: AppBar(
        title: const Text(RollWorkerHomeScreen.title),
        actions: <Widget>[
          IconButton(
            tooltip: printerSettingsTooltip,
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => const PrinterSettingsScreen(),
              ),
            ),
            icon: const Icon(Icons.print_rounded),
          ),
          popupMenu(registry),
        ],
      ),
      body: RollWorkerHomeScreen(
        shiftLineId: activeId,
        lineIndex: currentIndex + 1,
        standaloneScaffold: false,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (i) => _onDestinationSelected(i, ids, ref),
        destinations: <NavigationDestination>[
          for (int i = 0; i < ids.length; i++)
            NavigationDestination(
              icon: const Icon(Icons.precision_manufacturing_outlined),
              selectedIcon: const Icon(Icons.precision_manufacturing_rounded),
              label: _tabLabel(ids[i], i + 1, ref),
            ),
        ],
      ),
    );
  }
}

enum _MenuAction { logoutCurrent, logoutAll }
