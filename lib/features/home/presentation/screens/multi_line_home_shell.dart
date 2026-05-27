import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/util/line_label_mapper.dart';
import '../../../printer/presentation/screens/printer_settings_screen.dart';
import '../../../roll_worker_auth/presentation/controllers/multi_line_session_registry.dart';
import '../../../roll_worker_auth/presentation/controllers/multi_line_session_registry_state.dart';
import '../../../sessions_me/domain/entities/roll_worker_active_line.dart';
import '../../../sessions_me/presentation/controllers/sessions_me_controller.dart';
import '../../../sessions_me/presentation/controllers/sessions_me_state.dart';
import '../widgets/add_line_sheet.dart';
import '../widgets/logout_all_confirm_dialog.dart';
import 'per_line_page.dart';
import 'roll_worker_home_screen.dart';

/// Top-level home shell driven by `/sessions/me`.
///
/// Architecture (realtime + line-management handoff §8):
///   - One [PageView] sibling per ACTIVE roll-worker session, each holding
///     a stable [PerLinePage] (with `AutomaticKeepAliveClientMixin`) so
///     per-page state — scroll position, mount-roll controllers, scan
///     screens — survives swipes.
///   - A [BottomNavigationBar] is synced with the PageView via a single
///     shared [PageController]: swiping the page updates the nav, tapping
///     the nav animates the page. One source of truth, no drift.
///   - Per-line accent color (handoff §8 item 8) — same line gets the same
///     color across launches (see [AppColors.accentForLine]). Applied to:
///     the line header chip, the scan button, and the bottom-nav selected
///     item icon/label tint.
///   - Cascade handling: when [SessionsMeController]'s `/sessions/me`
///     response drops a line, the registry collapses, the PageView page
///     disappears, and the active index is clamped before rebuild.
///   - "Add another line" opens [AddLineSheet] which fetches
///     `/sessions/me/joinable-lines`, multi-selects, and routes through
///     the existing PIN flow.
///   - "Leave all" calls `/sessions/leave-all` in one round-trip
///     (handoff §5.4) via [MultiLineSessionRegistry.logoutAll].
class MultiLineHomeShell extends ConsumerStatefulWidget {
  const MultiLineHomeShell({super.key});

  static const String menuLogoutCurrent = 'تسجيل خروج من الخط الحالي';
  static const String menuLogoutAll = 'تسجيل خروج من جميع الخطوط';
  static const String menuAddLine = 'إضافة خط آخر';
  static const String printerSettingsTooltip = 'إعدادات الطباعة';

  @override
  ConsumerState<MultiLineHomeShell> createState() =>
      _MultiLineHomeShellState();
}

class _MultiLineHomeShellState extends ConsumerState<MultiLineHomeShell> {
  final PageController _pageController = PageController();
  int _selectedIndex = 0;

  /// Tracks the previous list of shift-line ids so a rebuild driven by
  /// /sessions/me can detect adds/removes and clamp the active index
  /// BEFORE the new page list is mounted.
  List<int> _previousIds = const <int>[];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Computes the desired ordered list of shift-line ids to render.
  ///
  /// Priority: /sessions/me.lines (handoff §1 — authoritative for the tab
  /// list). Falls back to the registry's keys while /sessions/me has not
  /// yet returned (first load) so the shell shows tabs immediately rather
  /// than a flicker of nothing.
  List<int> _orderedIdsFor(
    RegistryActive registry,
    SessionsMeState meState,
  ) {
    if (meState is SessionsMeLoaded) {
      // /sessions/me orders by session start ASC (handoff §2.4).
      final List<int> remote = meState.me.lines
          .map((l) => l.shiftLineId)
          .where(registry.sessions.containsKey)
          .toList(growable: false);
      if (remote.isNotEmpty) return remote;
    }
    if (meState is SessionsMeLoading) {
      final List<int>? previous = meState.previous?.lines
          .map((l) => l.shiftLineId)
          .where(registry.sessions.containsKey)
          .toList(growable: false);
      if (previous != null && previous.isNotEmpty) return previous;
    }
    return registry.sessions.keys.toList(growable: false);
  }

  RollWorkerActiveLine? _lineFor(SessionsMeState meState, int shiftLineId) {
    final RollWorkerMeContainer? container = _containerFor(meState);
    if (container == null) return null;
    for (final RollWorkerActiveLine line in container.lines) {
      if (line.shiftLineId == shiftLineId) return line;
    }
    return null;
  }

  RollWorkerMeContainer? _containerFor(SessionsMeState meState) {
    return switch (meState) {
      SessionsMeLoaded(:final me) => RollWorkerMeContainer(me.lines),
      SessionsMeLoading(previous: final me?) =>
        RollWorkerMeContainer(me.lines),
      SessionsMeError(previous: final me?) => RollWorkerMeContainer(me.lines),
      _ => null,
    };
  }

  Color _accentFor(int shiftLineId, SessionsMeState meState) {
    final RollWorkerActiveLine? line = _lineFor(meState, shiftLineId);
    if (line != null) return line.accentColor;
    return AppColors.accentForLine(palletizingLineId: shiftLineId);
  }

  String _tabLabelFor(int shiftLineId, int oneBasedIndex,
      SessionsMeState meState) {
    final RollWorkerActiveLine? line = _lineFor(meState, shiftLineId);
    return LineLabelMapper.friendlyLineLabel(
      thermoformingLineCode: line?.thermoformingLineCode,
      thermoformingLineName: line?.thermoformingLineName,
      oneBasedIndex: oneBasedIndex,
    );
  }

  Future<void> _onMenuSelected(
    BuildContext context,
    _MenuAction action,
    RegistryActive state,
    List<int> ids,
  ) async {
    switch (action) {
      case _MenuAction.addLine:
        await AddLineSheet.show(context);
      case _MenuAction.logoutCurrent:
        final int active = ids[_selectedIndex.clamp(0, ids.length - 1)];
        await ref
            .read(multiLineSessionRegistryProvider.notifier)
            .logout(active);
      case _MenuAction.logoutAll:
        await LogoutAllConfirmDialog.show(
          context,
          lineCount: state.sessions.length,
        );
    }
  }

  void _onPageChanged(int index) {
    if (index == _selectedIndex) return;
    setState(() => _selectedIndex = index);
    // Pointer-only registry move — keeps existing per-feature controllers
    // happy (label reprint, takeover dialog) that depend on
    // `activeShiftLineId`.
    final List<int> ids = _previousIds;
    if (index < ids.length) {
      ref
          .read(multiLineSessionRegistryProvider.notifier)
          .setActive(ids[index]);
    }
  }

  void _onNavTap(int index, List<int> ids) {
    if (index == _selectedIndex) return;
    // Animate to the target — onPageChanged fires when it lands.
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  /// Reconciles the PageView to a new ordered id list. Adds expand the
  /// PageView automatically (new sibling at the end). Removes need an
  /// explicit clamp + jump so the user is never looking at a page that
  /// no longer exists for a frame.
  void _syncControllerToIds(List<int> nextIds) {
    if (_previousIds == nextIds) return;
    if (nextIds.isEmpty) {
      _previousIds = const <int>[];
      _selectedIndex = 0;
      return;
    }
    // What was the previously active shift-line id?
    final int? prevActiveId = (_previousIds.isNotEmpty &&
            _selectedIndex < _previousIds.length)
        ? _previousIds[_selectedIndex]
        : null;
    int nextIndex;
    if (prevActiveId != null && nextIds.contains(prevActiveId)) {
      nextIndex = nextIds.indexOf(prevActiveId);
    } else {
      nextIndex = _selectedIndex.clamp(0, nextIds.length - 1);
    }
    _previousIds = nextIds;
    if (nextIndex != _selectedIndex) {
      _selectedIndex = nextIndex;
      // Jump (not animate) — the page we were on no longer exists, an
      // animation would flash a wrong page.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_pageController.hasClients) return;
        _pageController.jumpToPage(nextIndex);
      });
    }
  }

  Widget _popupMenu(RegistryActive state, List<int> ids) {
    return PopupMenuButton<_MenuAction>(
      tooltip: 'القائمة',
      icon: const Icon(Icons.more_vert_rounded),
      onSelected: (action) => _onMenuSelected(context, action, state, ids),
      itemBuilder: (_) => const <PopupMenuEntry<_MenuAction>>[
        PopupMenuItem<_MenuAction>(
          value: _MenuAction.addLine,
          child: Text(MultiLineHomeShell.menuAddLine),
        ),
        PopupMenuItem<_MenuAction>(
          value: _MenuAction.logoutCurrent,
          child: Text(MultiLineHomeShell.menuLogoutCurrent),
        ),
        PopupMenuItem<_MenuAction>(
          value: _MenuAction.logoutAll,
          child: Text(MultiLineHomeShell.menuLogoutAll),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final MultiLineSessionRegistryState registry = ref.watch(
      multiLineSessionRegistryProvider,
    );
    if (registry is! RegistryActive) return const SizedBox.shrink();

    final SessionsMeState meState = ref.watch(sessionsMeControllerProvider);
    final List<int> ids = _orderedIdsFor(registry, meState);
    // Reconcile the controller before rendering so add/remove clamp
    // happens in the same frame as the new ids land.
    _syncControllerToIds(ids);
    if (ids.isEmpty) return const SizedBox.shrink();

    final int currentIndex = _selectedIndex.clamp(0, ids.length - 1);
    final int activeShiftLineId = ids[currentIndex];
    final Color activeAccent = _accentFor(activeShiftLineId, meState);

    final List<Widget> pages = <Widget>[
      for (int i = 0; i < ids.length; i++)
        PerLinePage(
          key: ValueKey<int>(ids[i]),
          shiftLineId: ids[i],
          lineIndex: i + 1,
          accentColor: _accentFor(ids[i], meState),
        ),
    ];

    // Single-line mode: no swipe needed — wrap the single page in the
    // standalone scaffold path so the home screen renders its own
    // AppBar with the printer + menu icons.
    if (ids.length == 1) {
      return RollWorkerHomeScreen(
        shiftLineId: activeShiftLineId,
        lineIndex: 1,
        standaloneScaffold: true,
        accentColor: activeAccent,
        headerActions: <Widget>[_popupMenu(registry, ids)],
      );
    }

    // Multi-line mode: shared AppBar + PageView + BottomNavigationBar
    // synced via the shared PageController.
    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: AppBar(
        title: const Text(RollWorkerHomeScreen.title),
        actions: <Widget>[
          IconButton(
            tooltip: MultiLineHomeShell.printerSettingsTooltip,
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => const PrinterSettingsScreen(),
              ),
            ),
            icon: const Icon(Icons.print_rounded),
          ),
          _popupMenu(registry, ids),
        ],
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        physics: const PageScrollPhysics(),
        children: pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (i) => _onNavTap(i, ids),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: activeAccent,
        unselectedItemColor: AppColors.textSecondary,
        showUnselectedLabels: true,
        items: <BottomNavigationBarItem>[
          for (int i = 0; i < ids.length; i++)
            BottomNavigationBarItem(
              icon: Icon(
                Icons.precision_manufacturing_outlined,
                color: i == currentIndex
                    ? _accentFor(ids[i], meState)
                    : AppColors.textSecondary,
              ),
              activeIcon: Icon(
                Icons.precision_manufacturing_rounded,
                color: _accentFor(ids[i], meState),
              ),
              label: _tabLabelFor(ids[i], i + 1, meState),
            ),
        ],
      ),
    );
  }
}

/// Tiny value-equality wrapper so a downstream selector test can compare
/// `_lineFor` results without depending on `RollWorkerMe`'s identity.
class RollWorkerMeContainer {
  RollWorkerMeContainer(this.lines);
  final List<RollWorkerActiveLine> lines;
}

enum _MenuAction { addLine, logoutCurrent, logoutAll }
