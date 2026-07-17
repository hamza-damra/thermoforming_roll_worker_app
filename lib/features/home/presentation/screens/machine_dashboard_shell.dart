import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/ui/line_labels.dart';
import '../../../../core/widgets/app_secondary_button.dart';
import '../../../../core/widgets/inline_error.dart';
import '../../../printer/presentation/screens/printer_settings_screen.dart';
import '../../../roll_worker_auth/presentation/controllers/multi_line_session_registry.dart';
import '../../../roll_worker_auth/presentation/controllers/multi_line_session_registry_state.dart';
import '../../../sessions_me/domain/entities/roll_worker_active_line.dart';
import '../../../sessions_me/presentation/controllers/sessions_me_controller.dart';
import '../../../sessions_me/presentation/controllers/sessions_me_state.dart';
import '../../../shift_line/domain/entities/roll_worker_bootstrap_line.dart';
import '../../../shift_line/presentation/controllers/roll_worker_bootstrap_controller.dart';
import '../../../shift_line/presentation/controllers/roll_worker_bootstrap_state.dart';
import '../../../shift_line/presentation/widgets/line_waiting_status.dart';
import '../widgets/home_shimmer_skeleton.dart';
import '../widgets/per_machine_tab.dart';
import 'roll_worker_home_screen.dart';

/// Unified, always-on machine dashboard.
///
/// Replaces the old pre-login picker + post-login bottom-nav shell with one
/// surface (matching the reference Palletizing app): **all** active
/// thermoforming machines are top tabs at all times, each rendering its own
/// dashboard. Authorization for an un-logged-in machine is a blocking PIN
/// overlay drawn on top of the dimmed machine dashboard — there is no
/// separate login screen in this flow.
///
/// The tab list is the union of `/bootstrap` machines and any active
/// registry session (so a freshly-authorized line keeps its tab even if a
/// `/bootstrap` refresh is momentarily behind). Per-machine accent colors and
/// state (authorized / needs-auth / waiting) are resolved per tab.
class MachineDashboardShell extends ConsumerStatefulWidget {
  const MachineDashboardShell({super.key});

  static const String emptyHeadline = 'بانتظار فتح خط من تطبيق المشغّل';
  static const String emptyDetail =
      'سيظهر الخط هنا فور فتحه من تطبيق المشغّل. اسحب للأسفل للتحديث.';
  static const String retryLabel = 'إعادة المحاولة';
  static const String printerSettingsTooltip = 'إعدادات الطباعة';

  @override
  ConsumerState<MachineDashboardShell> createState() =>
      _MachineDashboardShellState();
}

class _MachineDashboardShellState extends ConsumerState<MachineDashboardShell>
    with TickerProviderStateMixin {
  TabController? _controller;
  List<String> _controllerKeys = const <String>[];
  List<_MachineTab> _tabs = const <_MachineTab>[];

  @override
  void dispose() {
    _controller?.removeListener(_onTabChanged);
    _controller?.animation?.removeListener(_onAnimationTick);
    _controller?.dispose();
    super.dispose();
  }

  void _onAnimationTick() {
    if (mounted) {
      setState(() {});
    }
  }

  Color _getInterpolatedColor(double value, List<_MachineTab> tabs) {
    if (tabs.isEmpty) return AppColors.primary;
    if (tabs.length == 1) return tabs[0].accent;
    final int floorIndex = value.floor().clamp(0, tabs.length - 1);
    final int ceilIndex = value.ceil().clamp(0, tabs.length - 1);
    if (floorIndex == ceilIndex) {
      return tabs[floorIndex].accent;
    }
    final double t = value - floorIndex;
    return Color.lerp(tabs[floorIndex].accent, tabs[ceilIndex].accent, t) ??
        tabs[floorIndex].accent;
  }

  Color _resolveLoadingAccent({
    required RollWorkerBootstrapState bootstrap,
    required MultiLineSessionRegistryState registry,
    required SessionsMeState meState,
  }) {
    final int? activeShiftLineId =
        registry is RegistryActive ? registry.activeShiftLineId : null;

    final List<RollWorkerBootstrapLine> lines = _linesFrom(bootstrap);

    if (activeShiftLineId != null) {
      final int index = lines.indexWhere((l) => l.shiftLineId == activeShiftLineId);
      if (index >= 0) {
        final RollWorkerBootstrapLine line = lines[index];
        return AppColors.accentForLine(
          palletizingLineId: line.palletizingLineId,
          thermoformingLineId: line.thermoformingLineId,
          palletizingLineCode: line.palletizingLineCode,
        );
      }
    }

    if (activeShiftLineId != null) {
      final List<RollWorkerActiveLine>? meLines = switch (meState) {
        SessionsMeLoaded(:final me) => me.lines,
        SessionsMeLoading(previous: final me?) => me.lines,
        SessionsMeError(previous: final me?) => me.lines,
        _ => null,
      };
      if (meLines != null) {
        for (final RollWorkerActiveLine l in meLines) {
          if (l.shiftLineId == activeShiftLineId) {
            return l.accentColor;
          }
        }
      }
    }

    if (activeShiftLineId != null) {
      return AppColors.accentForLine(thermoformingLineId: activeShiftLineId);
    }

    if (lines.isNotEmpty) {
      final RollWorkerBootstrapLine firstLine = lines.first;
      return AppColors.accentForLine(
        palletizingLineId: firstLine.palletizingLineId,
        thermoformingLineId: firstLine.thermoformingLineId,
        palletizingLineCode: firstLine.palletizingLineCode,
      );
    }

    return AppColors.primary;
  }

  // ─── Tab-list construction ────────────────────────────────────────────

  List<RollWorkerBootstrapLine> _linesFrom(RollWorkerBootstrapState state) {
    return switch (state) {
      RollWorkerBootstrapLoaded(:final lines) => lines,
      RollWorkerBootstrapLoading(:final previous) => previous,
      RollWorkerBootstrapFailureState(:final previous) => previous,
      RollWorkerBootstrapInitial() => const <RollWorkerBootstrapLine>[],
    };
  }

  RollWorkerActiveLine? _meLineFor(SessionsMeState meState, int shiftLineId) {
    final List<RollWorkerActiveLine>? lines = switch (meState) {
      SessionsMeLoaded(:final me) => me.lines,
      SessionsMeLoading(previous: final me?) => me.lines,
      SessionsMeError(previous: final me?) => me.lines,
      _ => null,
    };
    if (lines == null) return null;
    for (final RollWorkerActiveLine line in lines) {
      if (line.shiftLineId == shiftLineId) return line;
    }
    return null;
  }

  List<_MachineTab> _buildTabs(
    List<RollWorkerBootstrapLine> lines,
    MultiLineSessionRegistryState registry,
    SessionsMeState meState,
  ) {
    final Set<int> sessionIds = registry is RegistryActive
        ? registry.sessions.keys.toSet()
        : const <int>{};

    final List<_MachineTab> tabs = <_MachineTab>[];
    final Set<int> bootstrapShiftLineIds = <int>{};
    int index = 0;

    for (final RollWorkerBootstrapLine line in lines) {
      index += 1;
      final int? sid = line.shiftLineId;
      if (sid != null) bootstrapShiftLineIds.add(sid);
      final Color accent = AppColors.accentForLine(
        palletizingLineId: line.palletizingLineId,
        thermoformingLineId: line.thermoformingLineId,
        palletizingLineCode: line.palletizingLineCode,
      );
      final bool authorized = sid != null && sessionIds.contains(sid);
      final MachineTabKind kind;
      if (authorized) {
        kind = MachineTabKind.authorized;
      } else if (line.selectable && sid != null) {
        kind = MachineTabKind.needsAuth;
      } else {
        kind = MachineTabKind.waiting;
      }
      // Label by backend line number (`machineNumber`), not tab index — only
      // falling back to the position when the backend supplies no number.
      final String lineLabel = LineLabels.label(
        lineNumber: line.machineNumber,
        fallbackIndex: index,
      );
      tabs.add(
        _MachineTab(
          // Key by the operator shift-line/session (`shiftLineId`), NOT the
          // physical line, so a session change (new `shiftLineId` on the same
          // physical line) gives the tab a fresh ValueKey — tearing down the
          // kept-alive RollWorkerHomeScreen and forcing a fresh summary load
          // for the new scope, with no consumed kg/list leaking from the old
          // session. Falls back to the physical-line key only when there is no
          // session yet (waiting tab). Matches the registry-only `sl-$sid` key.
          key: sid != null ? 'sl-$sid' : 'th-${line.thermoformingLineId}',
          shiftLineId: sid,
          oneBasedIndex: index,
          label: lineLabel,
          accent: accent,
          kind: kind,
          line: line,
          waitingTitle: LineWaitingStatus.dialogTitle,
          waitingMessage: LineWaitingStatus.dialogBodyFor(line),
          waitingShowSpinner: !LineWaitingStatus.isWarningReason(line),
        ),
      );
    }

    // Registry-only sessions with no `/bootstrap` row yet (e.g. the list is
    // momentarily behind a just-completed login). Always render their tab so
    // the authorized dashboard is reachable.
    if (registry is RegistryActive) {
      for (final int sid in registry.sessions.keys) {
        if (bootstrapShiftLineIds.contains(sid)) continue;
        index += 1;
        final RollWorkerActiveLine? meLine = _meLineFor(meState, sid);
        final Color accent = meLine?.accentColor ??
            AppColors.accentForLine(thermoformingLineId: sid);
        tabs.add(
          _MachineTab(
            key: 'sl-$sid',
            shiftLineId: sid,
            oneBasedIndex: index,
            label: LineLabels.label(fallbackIndex: index),
            accent: accent,
            kind: MachineTabKind.authorized,
            line: null,
          ),
        );
      }
    }

    return tabs;
  }

  // ─── TabController lifecycle ──────────────────────────────────────────

  void _syncController(List<_MachineTab> tabs, int? activeShiftLineId) {
    final List<String> keys = <String>[for (final _MachineTab t in tabs) t.key];
    _tabs = tabs;
    if (_controller != null && _listEquals(_controllerKeys, keys)) return;

    // Preserve the selected machine across tab-list changes: prefer the
    // previously-selected key, else the registry's active session, else 0.
    String? targetKey;
    if (_controller != null &&
        _controllerKeys.isNotEmpty &&
        _controller!.index < _controllerKeys.length) {
      targetKey = _controllerKeys[_controller!.index];
    }
    int initial = 0;
    if (targetKey != null) {
      final int i = keys.indexOf(targetKey);
      if (i >= 0) initial = i;
    } else if (activeShiftLineId != null) {
      final int i = tabs.indexWhere((t) => t.shiftLineId == activeShiftLineId);
      if (i >= 0) initial = i;
    }

    _controller?.removeListener(_onTabChanged);
    _controller?.animation?.removeListener(_onAnimationTick);
    _controller?.dispose();
    _controller = TabController(
      length: keys.length,
      vsync: this,
      initialIndex: keys.isEmpty ? 0 : initial.clamp(0, keys.length - 1),
    );
    _controller!.addListener(_onTabChanged);
    _controller!.animation?.addListener(_onAnimationTick);
    _controllerKeys = keys;
  }

  void _onTabChanged() {
    if (!mounted || _controller == null) return;
    setState(() {}); // repaint the app-bar accent for the new active machine
    if (_controller!.indexIsChanging) return;
    final int i = _controller!.index;
    if (i < 0 || i >= _tabs.length) return;
    final _MachineTab tab = _tabs[i];
    if (tab.kind == MachineTabKind.authorized && tab.shiftLineId != null) {
      ref
          .read(multiLineSessionRegistryProvider.notifier)
          .setActive(tab.shiftLineId!);
    }
  }

  // ─── App-bar actions ──────────────────────────────────────────────────

  Future<void> _openPrinterSettings() {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const PrinterSettingsScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Keep the machine list + previews fresh while logged in: the bootstrap
    // controller pauses its own poll/SSE once a session is active, so nudge
    // a background refresh whenever /sessions/me lands a new snapshot.
    ref.listen<SessionsMeState>(sessionsMeControllerProvider, (prev, next) {
      final bool fresh = next is SessionsMeLoaded &&
          (prev is! SessionsMeLoaded || prev.fetchedAt != next.fetchedAt);
      if (fresh) {
        ref
            .read(rollWorkerBootstrapControllerProvider.notifier)
            .refresh(trigger: 'shell-sessions-sync', background: true);
      }
    });

    final RollWorkerBootstrapState bootstrap = ref.watch(
      rollWorkerBootstrapControllerProvider,
    );
    final MultiLineSessionRegistryState registry = ref.watch(
      multiLineSessionRegistryProvider,
    );
    final SessionsMeState meState = ref.watch(sessionsMeControllerProvider);

    final List<RollWorkerBootstrapLine> lines = _linesFrom(bootstrap);
    final List<_MachineTab> tabs = _buildTabs(lines, registry, meState);

    if (tabs.isEmpty) {
      final Color loadingAccent = _resolveLoadingAccent(
        bootstrap: bootstrap,
        registry: registry,
        meState: meState,
      );
      return _NoMachinesScaffold(
        bootstrap: bootstrap,
        accent: loadingAccent,
        onRetry: () => ref
            .read(rollWorkerBootstrapControllerProvider.notifier)
            .refresh(trigger: 'manual'),
      );
    }

    final int? activeShiftLineId =
        registry is RegistryActive ? registry.activeShiftLineId : null;
    _syncController(tabs, activeShiftLineId);

    final int currentIndex = _controller!.index.clamp(0, tabs.length - 1);
    final double animationValue = _controller?.animation?.value ?? currentIndex.toDouble();
    final Color activeAccent = _getInterpolatedColor(animationValue, tabs);

    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: AppBar(
        backgroundColor: activeAccent,
        title: const Text(RollWorkerHomeScreen.title),
        actions: <Widget>[
          // Each line now carries its own inline "مغادرة الآن" leave action on
          // the worker-session card, so the old overflow logout menu was
          // removed (see RollWorkerSessionCard + LeaveLineConfirmDialog). Only
          // the printer settings action remains in the header.
          IconButton(
            tooltip: MachineDashboardShell.printerSettingsTooltip,
            onPressed: _openPrinterSettings,
            icon: const Icon(Icons.print_rounded),
          ),
        ],
        bottom: tabs.length > 1
            ? TabBar(
                controller: _controller,
                isScrollable: false,
                indicatorColor: Colors.white,
                indicatorWeight: 3,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                labelStyle: AppTextStyles.button,
                unselectedLabelStyle: AppTextStyles.button,
                tabs: <Widget>[
                  for (final _MachineTab t in tabs)
                    Tab(height: 50, child: _TabLabel(tab: t)),
                ],
              )
            : null,
      ),
      body: TabBarView(
        controller: _controller,
        // Horizontal swipe switches lines (kept in sync with the TabBar via the
        // shared TabController). Vertical card scrolling and tab taps are on
        // different axes, so they don't compete with the swipe gesture.
        physics: const ClampingScrollPhysics(),
        children: <Widget>[
          for (final _MachineTab t in tabs)
            PerMachineTab(
              key: ValueKey<String>(t.key),
              kind: t.kind,
              shiftLineId: t.shiftLineId,
              lineIndex: t.oneBasedIndex,
              lineLabel: t.label,
              // The in-body line header is shown only when the tab bar is
              // hidden (single line) — otherwise the tab already labels it.
              showLineHeader: tabs.length <= 1,
              accent: t.accent,
              line: t.line,
              waitingTitle: t.waitingTitle,
              waitingMessage: t.waitingMessage,
              waitingShowSpinner: t.waitingShowSpinner,
            ),
        ],
      ),
    );
  }

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Tab content: a small state dot + the machine label.
class _TabLabel extends StatelessWidget {
  const _TabLabel({required this.tab});

  final _MachineTab tab;

  @override
  Widget build(BuildContext context) {
    final Color dot = switch (tab.kind) {
      MachineTabKind.authorized => Colors.white,
      MachineTabKind.needsAuth => Colors.white.withValues(alpha: 0.55),
      MachineTabKind.waiting => Colors.white.withValues(alpha: 0.30),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(tab.label),
      ],
    );
  }
}

/// Shown when there are no machine tabs at all (no `/bootstrap` machines and
/// no active sessions): loading, error, or the "waiting for the operator
/// app" empty state.
class _NoMachinesScaffold extends StatelessWidget {
  const _NoMachinesScaffold({
    required this.bootstrap,
    required this.onRetry,
    this.accent,
  });

  final RollWorkerBootstrapState bootstrap;
  final VoidCallback onRetry;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    // First-load / refresh with no machines yet → full dashboard shimmer
    // skeleton (replaces the old green-app-bar spinner). Only failure and the
    // genuinely-empty "waiting for the operator app" states fall through to
    // their own scaffolds below.
    switch (bootstrap) {
      case RollWorkerBootstrapInitial():
      case RollWorkerBootstrapLoading():
        return RollWorkerLoadingScaffold(accent: accent);
      case RollWorkerBootstrapFailureState():
      case RollWorkerBootstrapLoaded():
        break;
    }
    final Widget body = switch (bootstrap) {
      RollWorkerBootstrapFailureState() => _ErrorBody(onRetry: onRetry),
      _ => _EmptyBody(onRetry: onRetry),
    };
    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: AppBar(title: const Text(RollWorkerHomeScreen.title)),
      body: Padding(padding: const EdgeInsets.all(16), child: body),
    );
  }
}

class _EmptyBody extends StatelessWidget {
  const _EmptyBody({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: <Widget>[
        const SizedBox(height: 24),
        Center(
          child: Container(
            width: 96,
            height: 96,
            decoration: const BoxDecoration(
              color: AppColors.primaryLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.access_time_rounded,
              size: 48,
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          MachineDashboardShell.emptyHeadline,
          style: AppTextStyles.h2,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            MachineDashboardShell.emptyDetail,
            style: AppTextStyles.body,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 24),
        AppSecondaryButton(
          label: MachineDashboardShell.retryLabel,
          icon: Icons.refresh_rounded,
          onPressed: onRetry,
        ),
      ],
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: <Widget>[
        const SizedBox(height: 12),
        const InlineError(message: 'تعذّر تحميل الماكينات. حاول مرة أخرى.'),
        const SizedBox(height: 12),
        AppSecondaryButton(
          label: MachineDashboardShell.retryLabel,
          icon: Icons.refresh_rounded,
          onPressed: onRetry,
        ),
      ],
    );
  }
}

/// View-model for one machine tab.
class _MachineTab {
  const _MachineTab({
    required this.key,
    required this.shiftLineId,
    required this.oneBasedIndex,
    required this.label,
    required this.accent,
    required this.kind,
    required this.line,
    this.waitingTitle = '',
    this.waitingMessage = '',
    this.waitingShowSpinner = true,
  });

  final String key;
  final int? shiftLineId;
  final int oneBasedIndex;
  final String label;
  final Color accent;
  final MachineTabKind kind;
  final RollWorkerBootstrapLine? line;
  final String waitingTitle;
  final String waitingMessage;
  final bool waitingShowSpinner;
}
