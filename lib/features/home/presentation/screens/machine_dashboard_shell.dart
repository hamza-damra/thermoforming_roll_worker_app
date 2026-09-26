import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/ui/line_labels.dart';
import '../../../../core/widgets/app_secondary_button.dart';
import '../../../../core/widgets/inline_error.dart';
import '../../../printer/presentation/screens/printer_settings_screen.dart';
import '../../../roll_worker_auth/domain/entities/roll_worker_session.dart';
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
/// `/bootstrap` refresh is momentarily behind, or after its machine left
/// `/bootstrap` mid-shift). Per-machine accent colors and state (authorized /
/// needs-auth / waiting) are resolved per tab.
///
/// Identity rules (LINE_3 handoff): a tab *is* a machine, keyed by
/// `thermoformingLineId`, so an operator claiming or releasing a machine never
/// moves the selection. Labels are the server's `palletizingLineName`, never
/// computed (see [LineLabels]). The id spaces are never mixed: on production
/// LINE_3 the machine id is 4, the palletizing-line id 3, and shift-line ids
/// are unrelated to both.
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

  /// Tab identities ([_MachineTab.identity]) the controller was built for.
  List<String> _controllerKeys = const <String>[];
  List<_MachineTab> _tabs = const <_MachineTab>[];

  /// Last server label per machine (`thermoformingLineId`), from every
  /// `/bootstrap` and `/sessions/me` row seen. Survives the machine leaving
  /// `/bootstrap` (e.g. LINE_3 disabled mid-shift), so its session-only tab
  /// keeps the same label.
  final Map<int, String> _labelByMachine = <int, String>{};

  /// Last-known server order of machines (`thermoformingLineId`s in
  /// `/bootstrap` array order). A machine that leaves `/bootstrap` keeps its
  /// slot, so a session-only tab stays where the worker last saw it.
  List<int> _machineOrder = const <int>[];

  /// Memo for [_tabLabelsFit]: the shell rebuilds on every tab-swipe frame.
  String? _fitKey;
  bool _fitValue = true;

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

    final RollWorkerSession? activeSession =
        registry is RegistryActive && activeShiftLineId != null
        ? registry.sessions[activeShiftLineId]
        : null;
    if (activeSession != null) {
      return AppColors.accentForLine(
        palletizingLineId: activeSession.palletizingLineId,
        thermoformingLineId: activeSession.thermoformingLineId,
      );
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

  List<RollWorkerActiveLine> _meLinesFrom(SessionsMeState meState) {
    return switch (meState) {
      SessionsMeLoaded(:final me) => me.lines,
      SessionsMeLoading(previous: final me?) => me.lines,
      SessionsMeError(previous: final me?) => me.lines,
      _ => const <RollWorkerActiveLine>[],
    };
  }

  /// Records the server label and order of every machine in this snapshot.
  void _rememberMachines(
    List<RollWorkerBootstrapLine> lines,
    List<RollWorkerActiveLine> meLines,
  ) {
    for (final RollWorkerActiveLine l in meLines) {
      final int? machineId = l.thermoformingLineId;
      final String? label = LineLabels.fromServer(l.palletizingLineName);
      if (machineId != null && label != null) {
        _labelByMachine[machineId] = label;
      }
    }
    for (final RollWorkerBootstrapLine l in lines) {
      final String? label = LineLabels.fromServer(l.palletizingLineName);
      if (label != null) _labelByMachine[l.thermoformingLineId] = label;
    }
    _machineOrder = _mergeOrder(_machineOrder, <int>[
      for (final RollWorkerBootstrapLine l in lines) l.thermoformingLineId,
    ]);
  }

  /// Merges the latest `/bootstrap` order into the known order: the result
  /// follows [latest] exactly for the machines it lists, and keeps each
  /// machine missing from it at its previous relative position.
  static List<int> _mergeOrder(List<int> known, List<int> latest) {
    final Set<int> latestSet = latest.toSet();
    final List<int> merged = <int>[];
    int next = 0;
    for (final int id in known) {
      if (!latestSet.contains(id)) {
        merged.add(id);
        continue;
      }
      while (next < latest.length) {
        final int b = latest[next++];
        if (!merged.contains(b)) merged.add(b);
        if (b == id) break;
      }
    }
    while (next < latest.length) {
      final int b = latest[next++];
      if (!merged.contains(b)) merged.add(b);
    }
    return merged;
  }

  List<_MachineTab> _buildTabs(
    List<RollWorkerBootstrapLine> lines,
    MultiLineSessionRegistryState registry,
    SessionsMeState meState,
  ) {
    final Map<int, RollWorkerSession> sessions = registry is RegistryActive
        ? registry.sessions
        : const <int, RollWorkerSession>{};
    final List<RollWorkerActiveLine> meLines = _meLinesFrom(meState);
    _rememberMachines(lines, meLines);

    final List<_MachineTab> tabs = <_MachineTab>[];
    final Set<int> bootstrapShiftLineIds = <int>{};
    final Set<String> identities = <String>{};

    for (final RollWorkerBootstrapLine line in lines) {
      final int? sid = line.shiftLineId;
      if (sid != null) bootstrapShiftLineIds.add(sid);
      final bool authorized = sid != null && sessions.containsKey(sid);
      final MachineTabKind kind;
      if (authorized) {
        kind = MachineTabKind.authorized;
      } else if (line.selectable && sid != null) {
        kind = MachineTabKind.needsAuth;
      } else {
        kind = MachineTabKind.waiting;
      }
      final String identity = 'th-${line.thermoformingLineId}';
      identities.add(identity);
      tabs.add(
        _MachineTab(
          identity: identity,
          // The page key adds the operator shift-line/session (`shiftLineId`),
          // so a session change on the same machine (new `shiftLineId`) gives
          // the page a fresh ValueKey — tearing down the kept-alive
          // RollWorkerHomeScreen and forcing a fresh summary load for the new
          // scope, with no consumed kg/list leaking from the old session. The
          // tab identity itself stays the machine, so selection never moves.
          key: sid == null ? identity : '$identity/sl-$sid',
          machineId: line.thermoformingLineId,
          shiftLineId: sid,
          label: _labelFor(line.thermoformingLineId),
          accent: AppColors.accentForLine(
            palletizingLineId: line.palletizingLineId,
            thermoformingLineId: line.thermoformingLineId,
            palletizingLineCode: line.palletizingLineCode,
          ),
          kind: kind,
          line: line,
          waitingTitle: LineWaitingStatus.dialogTitle,
          waitingMessage: LineWaitingStatus.dialogBodyFor(line),
          waitingShowSpinner: !LineWaitingStatus.isWarningReason(line),
        ),
      );
    }

    // Registry sessions with no `/bootstrap` row: the list is momentarily
    // behind a just-completed login, or the machine left `/bootstrap` while
    // the worker still holds a session on it (LINE_3 disabled mid-shift —
    // roll actions keep working). Always render their tab so the authorized
    // dashboard stays reachable; only `/sessions/me` ends a session. Identity,
    // label and colour come from the machine's own ids (`/sessions/me` row,
    // else the start-batch session) — never from the shift-line id.
    for (final MapEntry<int, RollWorkerSession> entry in sessions.entries) {
      final int sid = entry.key;
      if (bootstrapShiftLineIds.contains(sid)) continue;
      final RollWorkerActiveLine? meLine = _meLineFor(meLines, sid);
      final int machineId =
          meLine?.thermoformingLineId ?? entry.value.thermoformingLineId;
      // A machine already tabbed from `/bootstrap` under another shift-line
      // (a stale session awaiting `/sessions/me` reconciliation) keeps that
      // tab; this session gets its own identity so identities stay unique.
      String identity = 'th-$machineId';
      if (identities.contains(identity)) identity = 'sl-$sid';
      identities.add(identity);
      tabs.add(
        _MachineTab(
          identity: identity,
          key: identity == 'sl-$sid' ? identity : '$identity/sl-$sid',
          machineId: machineId,
          shiftLineId: sid,
          label: _labelFor(machineId),
          accent: AppColors.accentForLine(
            palletizingLineId:
                meLine?.palletizingLineId ?? entry.value.palletizingLineId,
            thermoformingLineId: machineId,
            palletizingLineCode: meLine?.palletizingLineCode,
          ),
          kind: MachineTabKind.authorized,
          line: null,
        ),
      );
    }

    return _inMachineOrder(tabs);
  }

  RollWorkerActiveLine? _meLineFor(
    List<RollWorkerActiveLine> meLines,
    int shiftLineId,
  ) {
    for (final RollWorkerActiveLine line in meLines) {
      if (line.shiftLineId == shiftLineId) return line;
    }
    return null;
  }

  String _labelFor(int machineId) =>
      _labelByMachine[machineId] ?? LineLabels.unknown;

  /// Orders tabs by the machines' last-known server order. `/bootstrap` tabs
  /// already follow it; this places session-only tabs in their machine's slot
  /// instead of at the end. Machines never seen in `/bootstrap` go last, in
  /// their original order.
  List<_MachineTab> _inMachineOrder(List<_MachineTab> tabs) {
    final List<int> order = _machineOrder;
    int rank(int i) {
      final int known = order.indexOf(tabs[i].machineId);
      return known >= 0 ? known : order.length + i;
    }

    final List<int> indices = List<int>.generate(tabs.length, (int i) => i)
      ..sort((int a, int b) {
        final int byRank = rank(a).compareTo(rank(b));
        return byRank != 0 ? byRank : a.compareTo(b);
      });
    return <_MachineTab>[for (final int i in indices) tabs[i]];
  }

  // ─── TabController lifecycle ──────────────────────────────────────────

  void _syncController(List<_MachineTab> tabs, int? activeShiftLineId) {
    final List<String> keys = <String>[
      for (final _MachineTab t in tabs) t.identity,
    ];
    _tabs = tabs;
    if (_controller != null && _listEquals(_controllerKeys, keys)) return;

    // Preserve the selected machine across tab-list changes. Identity is the
    // machine, so a claim / release / new session on it keeps the selection.
    // If the selected machine is gone, stay at the nearest position instead
    // of jumping to the first tab. On first build, prefer the registry's
    // active session.
    int initial = 0;
    if (_controller != null && _controllerKeys.isNotEmpty) {
      final int previous = _controller!.index.clamp(
        0,
        _controllerKeys.length - 1,
      );
      final int i = keys.indexOf(_controllerKeys[previous]);
      initial = i >= 0 ? i : previous;
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
    final bool tabsFit = _tabLabelsFitCached(context, tabs);

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
                // Fixed-width tabs while every label fits its share of the
                // width; scrollable (start-aligned) once any would clip — no
                // layout assumes a fixed machine count.
                isScrollable: !tabsFit,
                tabAlignment: tabsFit ? null : TabAlignment.start,
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
              lineLabel: t.label == LineLabels.unknown ? null : t.label,
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

  bool _tabLabelsFitCached(BuildContext context, List<_MachineTab> tabs) {
    final String key = <Object>[
      MediaQuery.sizeOf(context).width,
      MediaQuery.textScalerOf(context),
      for (final _MachineTab t in tabs) t.label,
    ].join('\n');
    if (key != _fitKey) {
      _fitKey = key;
      _fitValue = _tabLabelsFit(context, tabs);
    }
    return _fitValue;
  }

  /// Whether every tab label fits a fixed, equal-width tab on this screen.
  static bool _tabLabelsFit(BuildContext context, List<_MachineTab> tabs) {
    if (tabs.isEmpty) return true;
    final double perTab = MediaQuery.sizeOf(context).width / tabs.length;
    final TextScaler scaler = MediaQuery.textScalerOf(context);
    final TextDirection direction = Directionality.of(context);
    for (final _MachineTab t in tabs) {
      final TextPainter painter = TextPainter(
        text: TextSpan(text: t.label, style: AppTextStyles.button),
        textDirection: direction,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final double needed =
          painter.width + _TabLabel.chromeWidth + _tabHorizontalPadding;
      painter.dispose();
      if (needed > perTab) return false;
    }
    return true;
  }

  /// [TabBar]'s default `labelPadding` (16 dp each side).
  static const double _tabHorizontalPadding = 32;

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

  static const double _dotSize = 9;
  static const double _gap = 8;

  /// Width of everything beside the label text.
  static const double chromeWidth = _dotSize + _gap;

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
          width: _dotSize,
          height: _dotSize,
          decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
        ),
        const SizedBox(width: _gap),
        Flexible(
          child: Text(
            tab.label,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
          ),
        ),
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
    required this.identity,
    required this.key,
    required this.machineId,
    required this.shiftLineId,
    required this.label,
    required this.accent,
    required this.kind,
    required this.line,
    this.waitingTitle = '',
    this.waitingMessage = '',
    this.waitingShowSpinner = true,
  });

  /// Tab identity for selection: `th-<thermoformingLineId>` (the machine).
  final String identity;

  /// Page key: the identity plus `/sl-<shiftLineId>` once a session scope
  /// exists, so a new operator session reloads the page.
  final String key;

  /// `thermoformingLineId` — machine identity, label cache key, order key.
  final int machineId;
  final int? shiftLineId;

  /// Server label, or [LineLabels.unknown] while none is known.
  final String label;
  final Color accent;
  final MachineTabKind kind;
  final RollWorkerBootstrapLine? line;
  final String waitingTitle;
  final String waitingMessage;
  final bool waitingShowSpinner;
}
