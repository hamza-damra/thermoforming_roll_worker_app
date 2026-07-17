import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/takeover_alert_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/ui/line_labels.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/failure_snackbar.dart';
import '../../../../core/widgets/primary_bottom_action.dart';
import '../../../../core/widgets/success_snackbar.dart';
import '../../../label_reprint/presentation/controllers/label_reprint_controller.dart';
import '../../../label_reprint/presentation/screens/label_preview_screen.dart';
import '../../../label_reprint/presentation/widgets/print_in_progress_dialog.dart';
import '../../../previous_roll/domain/entities/previous_roll_resolution.dart';
import '../../../previous_roll/presentation/controllers/previous_roll_resolution_controller.dart';
import '../../../previous_roll/presentation/controllers/previous_roll_resolution_state.dart';
import '../../../previous_roll/presentation/widgets/close_previous_roll_dialog.dart';
import '../../../previous_roll/presentation/widgets/full_consume_confirm_dialog.dart';
import '../../../previous_roll/presentation/widgets/grinding_dialog.dart';
import '../../../previous_roll/presentation/widgets/return_remaining_dialog.dart';
import '../../../printer/data/printer_providers.dart';
import '../../../printer/domain/entities/printer_config.dart';
import '../../../printer/presentation/screens/printer_settings_screen.dart';
import '../../../roll_scan/presentation/controllers/roll_scan_controller.dart';
import '../../../roll_scan/presentation/controllers/roll_scan_state.dart';
import '../../../roll_scan/presentation/screens/scan_roll_screen.dart';
import '../../../sessions_me/presentation/controllers/sessions_me_controller.dart';
import '../../../sessions_me/presentation/controllers/sessions_me_state.dart';
import '../../domain/entities/line_takeover.dart';
import '../../domain/entities/shift_line_summary.dart';
import '../controllers/acknowledged_takeover_controller.dart';
import '../controllers/shift_line_summary_controller.dart';
import '../controllers/shift_line_summary_state.dart';
import '../../../sessions_me/domain/entities/roll_worker_active_line.dart';
import '../../../sessions_me/domain/entities/roll_worker_me.dart';
import '../../domain/entities/allowed_roll.dart';
import '../widgets/empty_roll_state_card.dart';
import '../widgets/compact_mounted_roll_card.dart';
import '../widgets/consumed_rolls_section.dart';
import '../widgets/home_shimmer_skeleton.dart';
import '../widgets/leave_line_confirm_dialog.dart';
import '../widgets/product_allowed_rolls_card.dart';
import '../widgets/returned_remaining_card.dart';
import '../widgets/roll_worker_session_card.dart';
import '../widgets/summary_card.dart';
import '../widgets/takeover_banner.dart';
import '../widgets/takeover_blocked_card.dart';
import '../widgets/takeover_request_dialog.dart';
import '../widgets/takeover_strings.dart';

/// Per-line Roll Worker home screen.
///
/// Product switching is intentionally not available here; it is owned by
/// the Operator / Palletizing Operator App. This screen only covers roll scan,
/// mount display, previous-roll close, and label printing.
///
/// Data comes from the backend summary endpoint — no local roll counts and
/// no session card. The compact header + summary card + optional mounted-roll
/// card are all driven by [ShiftLineSummaryController].
///
/// Navigation between machines is handled by the parent [MachineDashboardShell]
/// via its top [TabBar] (≥2 sessions) — this screen never shows TH codes.
class RollWorkerHomeScreen extends ConsumerStatefulWidget {
  const RollWorkerHomeScreen({
    super.key,
    required this.shiftLineId,
    this.lineIndex = 1,
    this.lineLabel,
    this.showLineHeader = false,
    this.standaloneScaffold = true,
    this.accentColor,
  });

  final int shiftLineId;

  /// 1-based position of this machine among active sessions (خط أ، …).
  final int lineIndex;

  /// Backend-derived line label (`خط أ`, `خط ب`, …) supplied by the shell.
  /// Falls back to a label derived from [lineIndex] when absent.
  final String? lineLabel;

  /// Whether to render the in-body line-label header. The shell sets this only
  /// when its tab bar is hidden (single active line) so the label is never
  /// duplicated beside the tabs.
  final bool showLineHeader;

  /// When `true` (default, single-line mode) the screen wraps itself in an
  /// [AppScaffold] with its own AppBar. When `false` (the
  /// [MachineDashboardShell] owns the AppBar) only the body is rendered.
  final bool standaloneScaffold;

  /// Per-line accent color used by the multi-line shell to tint the line
  /// header strip + scan button — `null` falls back to the global accent.
  /// Same line gets the same color across launches (see
  /// `AppColors.accentForLine`).
  final Color? accentColor;

  static const String title = 'تطبيق موظف الرولات';
  // Fixed bottom action labels — state-driven: mount when no roll is
  // mounted, unmount ("إنزال") when one is.
  static const String registerRoll = 'تركيب رول';
  static const String closeCurrentRoll = 'إنزال الرول الحالي';
  static const String closedRollSnack = 'تم إنزال الرول بنجاح';
  static const String refreshFailed = 'تعذر تحديث البيانات. حاول مرة أخرى.';
  static const String printerSettingsTooltip = 'إعدادات الطباعة';
  static const String _leftLineSnack = 'تم تسجيل خروجك من الخط';

  @override
  ConsumerState<RollWorkerHomeScreen> createState() =>
      _RollWorkerHomeScreenState();
}

class _RollWorkerHomeScreenState extends ConsumerState<RollWorkerHomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Initial REST-summary load for this line. SSE-driven refreshes are
      // now owned globally by `SessionsMeController` (which also triggers
      // a /summary refresh for the visible line). Per-line operator-
      // dashboard SSE was retired in the realtime + line-management
      // handoff §3.
      ref
          .read(shiftLineSummaryControllerProvider(widget.shiftLineId).notifier)
          .load();
    });
  }

  int get _shiftLineId => widget.shiftLineId;

  /// Request id of the last takeover we played the sound/vibration alert for.
  /// Guards against replaying the alert on every summary refresh / SSE event.
  int? _alertedTakeoverRequestId;

  /// Reacts to a refreshed summary: when a *new* `PENDING` takeover appears,
  /// play the alert once and open the blocking dialog. Runs from a
  /// `ref.listen` callback, never on a plain refresh of the same request.
  void _onSummaryChanged(ShiftLineSummaryState next) {
    if (next is! SummaryLoaded) return;
    final LineTakeover? takeover = next.summary.takeover;
    if (takeover == null || takeover.status != TakeoverStatus.pending) return;

    final int? requestId = takeover.requestId;
    if (requestId == null || _alertedTakeoverRequestId == requestId) return;
    _alertedTakeoverRequestId = requestId;

    // Already acknowledged (e.g. the screen state was rebuilt) — keep the
    // banner, but do not replay the alert or re-open the dialog.
    final int? acknowledged = ref.read(
      acknowledgedTakeoverProvider(_shiftLineId),
    );
    if (acknowledged == requestId) return;

    unawaited(ref.read(takeoverAlertServiceProvider).playAlert());
    unawaited(_showTakeoverDialog(takeover));
  }

  Future<void> _showTakeoverDialog(LineTakeover takeover) async {
    if (!mounted) return;
    await showTakeoverRequestDialog(
      context,
      shiftLineId: _shiftLineId,
      takeover: takeover,
    );
  }

  Future<void> _openScanScreen(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ScanRollScreen(
          shiftLineId: _shiftLineId,
          accentColor: widget.accentColor,
        ),
      ),
    );
  }

  Future<void> _openCloseFlow(
    BuildContext context,
    SummaryMountedRoll roll,
  ) async {
    ref
        .read(previousRollResolutionControllerProvider(_shiftLineId).notifier)
        .clearError();

    final ClosePreviousRollAction? action = await showClosePreviousRollDialog(
      context,
      accent: widget.accentColor,
    );
    if (action == null || !context.mounted) return;

    switch (action) {
      case ClosePreviousRollAction.fullConsume:
        await showFullConsumeConfirmDialog(
          context,
          shiftLineId: _shiftLineId,
          accent: widget.accentColor,
        );
      case ClosePreviousRollAction.returnRemaining:
        await showReturnRemainingDialog(
          context,
          shiftLineId: _shiftLineId,
          maxAllowedKg: roll.lastKnownWeightKg,
          accent: widget.accentColor,
        );
      case ClosePreviousRollAction.sendToGrinding:
        await showGrindingDialog(
          context,
          shiftLineId: _shiftLineId,
          maxAllowedKg: roll.lastKnownWeightKg,
          accent: widget.accentColor,
        );
    }
  }

  /// Pull-to-refresh: re-fetches everything that drives this screen — the
  /// line summary (operator, product, allowed rolls, mounted roll, session
  /// stats, consumed rolls) and `/sessions/me` (roll-worker identity + product
  /// name). Both controllers swallow failures into their own state and never
  /// throw, so we inspect the result and surface a single failure snackbar.
  /// The selected line/tab lives in the registry + shell TabController, so a
  /// refresh never changes it.
  Future<void> _onRefresh() async {
    final summaryNotifier = ref.read(
      shiftLineSummaryControllerProvider(_shiftLineId).notifier,
    );
    await Future.wait<void>(<Future<void>>[
      ref
          .read(sessionsMeControllerProvider.notifier)
          .refresh(trigger: 'pull-to-refresh'),
      summaryNotifier.refresh(),
    ]);
    if (!mounted) return;
    final ShiftLineSummaryState summaryState = ref.read(
      shiftLineSummaryControllerProvider(_shiftLineId),
    );
    final SessionsMeState meState = ref.read(sessionsMeControllerProvider);
    final bool failed =
        summaryState is SummaryError ||
        meState is SessionsMeError ||
        summaryNotifier.lastRefreshFailed;
    if (failed) {
      FailureSnackbar.show(context, RollWorkerHomeScreen.refreshFailed);
    }
  }

  Future<void> _onReprintTap(
    BuildContext context,
    String generatedRollId, {
    DateTime? overrideTimestamp,
    String? labelType,
  }) async {
    final PrinterConfig? printer = ref
        .read(printerRepositoryProvider)
        .getDefault();
    if (printer == null) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(builder: (_) => const PrinterSettingsScreen()),
      );
      return;
    }

    ref.read(labelReprintControllerProvider(_shiftLineId).notifier).reset();
    final Future<void> dialog = PrintInProgressDialog.show(
      context,
      shiftLineId: _shiftLineId,
    );
    // ignore: unawaited_futures
    ref
        .read(labelReprintControllerProvider(_shiftLineId).notifier)
        .reprint(
          generatedRollId,
          overrideTimestamp: overrideTimestamp,
          labelType: labelType,
        );
    await dialog;
  }

  /// Looks up the consumed roll on the current summary so the reprint
  /// path can pass the backend-authoritative `labelTimestamp` and
  /// `reprintLabelType` overrides (avoiding device-time substitution and
  /// GRINDING-vs-RETURN guesswork).
  ({DateTime? timestamp, String? labelType}) _reprintOverridesFor(
    String generatedRollId,
  ) {
    final ShiftLineSummaryState s = ref.read(
      shiftLineSummaryControllerProvider(_shiftLineId),
    );
    final ShiftLineSummary? summary = switch (s) {
      SummaryLoaded(:final summary) => summary,
      _ => null,
    };
    if (summary == null) return (timestamp: null, labelType: null);
    for (final ConsumedRoll r in summary.consumedRolls) {
      if (r.generatedRollId == generatedRollId) {
        return (timestamp: r.labelTimestamp, labelType: r.reprintLabelType);
      }
    }
    return (timestamp: null, labelType: null);
  }

  Future<void> _openLabelPreview(
    BuildContext context,
    String generatedRollId,
  ) async {
    ref.read(labelReprintControllerProvider(_shiftLineId).notifier).reset();
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => LabelPreviewScreen(
          shiftLineId: _shiftLineId,
          generatedRollId: generatedRollId,
        ),
      ),
    );
  }

  Future<void> _openPrinterSettings(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const PrinterSettingsScreen()),
    );
  }

  /// Resolves the current product from `/sessions/me` (production-plan
  /// driven). Renders the readable [CurrentProductCard] (placeholder copy
  /// when no active plan item is present). The legacy
  /// `summary.currentProductType*` fields are not used here.
  ///
  /// Uses `select` to scope rebuilds to the product name for THIS line —
  /// otherwise a fallback poll or refresh-flag flip would rebuild the card
  /// on every tick.
  /// Combined "current product + allowed rolls" card. The product name comes
  /// from `/sessions/me` (post-migration source of truth); the allowed rolls
  /// come from the line summary and refresh together with it.
  Widget _buildProductAndAllowedCard(List<AllowedRoll> allowedRolls) {
    final String? name = ref.watch(
      sessionsMeControllerProvider.select<String?>((s) {
        if (s is! SessionsMeLoaded) return null;
        for (final RollWorkerActiveLine l in s.me.lines) {
          if (l.shiftLineId == _shiftLineId) {
            return l.currentPlanItemProductName;
          }
        }
        return null;
      }),
    );
    return ProductAllowedRollsCard(
      productName: name,
      allowedRolls: allowedRolls,
      accent: widget.accentColor,
    );
  }

  /// User-facing line label (`خط أ`, …). Prefers the shell-supplied backend
  /// label, falling back to one derived from the 1-based line index.
  String get _lineLabel =>
      widget.lineLabel ?? LineLabels.label(fallbackIndex: widget.lineIndex);

  /// Resolves the logged-in roll employee for THIS line from `/sessions/me`:
  /// the worker's display name + this line's raw session start. Returns a
  /// value record so `select` only rebuilds the card when these fields change.
  ({String? name, DateTime? startedAt, bool present}) get _rollEmployeeInfo {
    return ref.watch(
      sessionsMeControllerProvider.select((SessionsMeState s) {
        final RollWorkerMe? me = switch (s) {
          SessionsMeLoaded(:final me) => me,
          SessionsMeLoading(previous: final me?) => me,
          SessionsMeError(previous: final me?) => me,
          _ => null,
        };
        if (me == null) {
          return (name: null, startedAt: null, present: false);
        }
        for (final RollWorkerActiveLine l in me.lines) {
          if (l.shiftLineId == _shiftLineId) {
            return (
              name: me.rollWorkerName,
              startedAt: l.sessionStartedAt,
              present: true,
            );
          }
        }
        return (name: null, startedAt: null, present: false);
      }),
    );
  }

  /// Single merged worker-session card (collapsed: worker name + leave;
  /// expanded: current operator + relative session start). The operator name
  /// comes from the line summary; the worker identity + start time from
  /// `/sessions/me`.
  Widget _buildWorkerSessionCard(String? operatorName) {
    final ({String? name, DateTime? startedAt, bool present}) info =
        _rollEmployeeInfo;
    final bool loggedIn =
        info.present && (info.name?.trim().isNotEmpty ?? false);
    return RollWorkerSessionCard(
      workerName: loggedIn ? info.name : null,
      operatorName: operatorName,
      sessionStartedAt: info.startedAt,
      accent: widget.accentColor,
      // Leave is only offered when an employee is logged into this line. The
      // dialog runs the existing per-line logout API — never a fake logout.
      onLeave: loggedIn ? () => _openLeaveDialog(info.name) : null,
    );
  }

  /// Reads the current product name for THIS line from `/sessions/me` so the
  /// leave dialog can show it as context — read (not watched) at tap time.
  String? _currentProductName() {
    final SessionsMeState s = ref.read(sessionsMeControllerProvider);
    final RollWorkerMe? me = switch (s) {
      SessionsMeLoaded(:final me) => me,
      SessionsMeLoading(previous: final me?) => me,
      SessionsMeError(previous: final me?) => me,
      _ => null,
    };
    if (me == null) return null;
    for (final RollWorkerActiveLine l in me.lines) {
      if (l.shiftLineId == _shiftLineId) return l.currentPlanItemProductName;
    }
    return null;
  }

  /// Reads the currently-loaded summary for this line, or `null` when the
  /// first load hasn't resolved.
  ShiftLineSummary? _currentSummary() {
    final ShiftLineSummaryState s = ref.read(
      shiftLineSummaryControllerProvider(_shiftLineId),
    );
    return switch (s) {
      SummaryLoaded(:final summary) => summary,
      _ => null,
    };
  }

  /// Backend-authoritative label template, with a `remainderAction` fallback
  /// for older backends. Shared by the auto-print and the logout-flow print.
  String? _resolveLabelType(PreviousRollResolution res) {
    final String inferredType = switch (res.remainderAction) {
      PreviousRollRemainderAction.grinding => 'GRINDING_REMAINING',
      PreviousRollRemainderAction.returned => 'RETURN_REMAINING',
      _ => '',
    };
    return (res.reprintLabelType != null && res.reprintLabelType!.isNotEmpty)
        ? res.reprintLabelType
        : (inferredType.isEmpty ? null : inferredType);
  }

  /// Leave action from the worker-session card. V109: logging out is always a
  /// plain `/roll-worker-logout` — the mounted roll (if any) stays mounted on
  /// the line for the next worker/operator, with no weight prompt and no
  /// disposition decision. The confirm copy adapts to whether a roll is mounted.
  Future<void> _openLeaveDialog(String? employeeName) async {
    final bool rollMounted = _currentSummary()?.mountedRoll != null;
    final bool? left = await LeaveLineConfirmDialog.show(
      context,
      shiftLineId: _shiftLineId,
      rollMounted: rollMounted,
      employeeName: employeeName,
      lineLabel: _lineLabel,
      productName: _currentProductName(),
    );
    if (left == true && mounted) {
      SuccessSnackbar.show(context, RollWorkerHomeScreen._leftLineSnack);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ShiftLineSummaryState summaryState = ref.watch(
      shiftLineSummaryControllerProvider(_shiftLineId),
    );

    ref.listen<RollScanState>(rollScanControllerProvider(_shiftLineId), (
      prev,
      next,
    ) {
      if (next is RollScanMounted && prev is! RollScanMounted) {
        ref
            .read(shiftLineSummaryControllerProvider(_shiftLineId).notifier)
            .refresh();
      }
    });

    // Whenever /sessions/me reports a fresher snapshot, refresh THIS line's
    // /summary too — this is the "refresh /summary only for currently
    // active/visible lines" rule. Each visible PerMachineTab owns this
    // listener, so an off-screen line in the TabBarView still updates on
    // tab focus via the initial load + this listener firing once the page
    // becomes built.
    ref.listen<SessionsMeState>(sessionsMeControllerProvider, (prev, next) {
      if (next is! SessionsMeLoaded) return;
      // Only refresh when a NEW snapshot arrived — not on `isRefreshing`
      // flips that don't carry new data.
      if (prev is SessionsMeLoaded && prev.fetchedAt == next.fetchedAt) {
        return;
      }
      // Skip when this line is no longer in the unified state (cascade
      // detection already started; the summary refresh would just 401).
      final bool stillActive = next.me.shiftLineIds.contains(_shiftLineId);
      if (!stillActive) return;
      ref
          .read(shiftLineSummaryControllerProvider(_shiftLineId).notifier)
          .refresh();
    });

    // Detect a new pending Line Takeover Request → alert + blocking dialog.
    ref.listen<ShiftLineSummaryState>(
      shiftLineSummaryControllerProvider(_shiftLineId),
      (_, ShiftLineSummaryState next) => _onSummaryChanged(next),
    );

    ref.listen<PreviousRollResolutionState>(
      previousRollResolutionControllerProvider(_shiftLineId),
      (prev, next) {
        if (next is PreviousRollResolved && prev is! PreviousRollResolved) {
          // Non-blocking success feedback: refresh the summary so the
          // closed roll lands in the consumed-rolls list (where the worker
          // can reprint when RETURN/GRINDING), show a brief snackbar, and
          // immediately acknowledge the resolved state so the mount
          // section never collapses to the old blocking summary card.
          ref
              .read(shiftLineSummaryControllerProvider(_shiftLineId).notifier)
              .refresh();
          SuccessSnackbar.show(context, RollWorkerHomeScreen.closedRollSnack);
          ref
              .read(
                previousRollResolutionControllerProvider(_shiftLineId).notifier,
              )
              .acknowledge();
          // Auto-trigger remainder-label print after RETURN / GRINDING.
          // Backend gates this with `reprintAvailable = true` (always
          // false for FULL_CONSUMPTION). Schedule via post-frame so the
          // snackbar and the print dialog don't race over the same
          // BuildContext. The print pipeline itself is fire-and-forget —
          // the close already succeeded; a print failure surfaces as a
          // retry on the consumed-roll card.
          if (next.resolution.reprintAvailable) {
            final PreviousRollResolution res = next.resolution;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              _onReprintTap(
                context,
                res.generatedRollId,
                overrideTimestamp: res.labelTimestamp,
                labelType: _resolveLabelType(res),
              );
            });
          }
        }
      },
    );

    final ShiftLineSummary? summary = switch (summaryState) {
      SummaryLoaded(:final summary) => summary,
      _ => null,
    };
    final bool isRefreshing =
        summaryState is SummaryLoaded && summaryState.isRefreshing;

    final LineTakeover? takeover = summary?.takeover;
    // The backend is authoritative for whether roll work is allowed. We block
    // when it says `blocked`, or when the takeover has auto-released and the
    // line is mid-handover (spec §8). A plain pending/accepted takeover does
    // NOT block work on its own.
    final bool workBlocked =
        (summary?.blocked ?? false) || (takeover?.forcesWorkBlock ?? false);

    // The line is unavailable for roll work when the backend blocks it OR
    // when no thermoforming operator currently owns the line. In both cases
    // the Roll Worker app is a passive observer and shows the waiting card
    // (Line State Refresh Events handoff — "Expected UI behaviour").
    final bool noActiveOperator = summary?.noActiveOperator ?? false;
    final bool lineUnavailable = workBlocked || noActiveOperator;

    // The fixed bottom action is state-driven: when a roll is mounted it
    // closes the current roll (`إغلاق الرول الحالي`), otherwise it registers a
    // new one (`تسجيل رول`). It is hidden only while the first load is still
    // resolving (shimmer) or the line is unavailable for roll work — never
    // both buttons at once.
    final SummaryMountedRoll? mountedRoll = summary?.mountedRoll;
    final bool showBottomAction =
        !lineUnavailable && summaryState is! SummaryLoading;

    final List<Widget> listChildren = <Widget>[
      // 1. Line header. The line tab already carries the identity (`خط أ`/
      //    `خط ب`), so this is shown ONLY when the shell hides its tab bar
      //    (single active line) — never as a duplicate chip beside the tabs.
      if (widget.showLineHeader) ...<Widget>[
        _LineHeader(label: _lineLabel, accent: widget.accentColor),
        const SizedBox(height: 10),
      ],
      if (takeover != null && takeover.isActive) ...<Widget>[
        TakeoverBanner(shiftLineId: _shiftLineId, takeover: takeover),
        const SizedBox(height: 10),
      ],
      if (summaryState is SummaryLoading)
        HomeShimmerSkeleton(accent: widget.accentColor)
      else if (summary != null) ...<Widget>[
        // 1. Merged worker-session card (FIRST): worker name + leave action;
        //    expands to the current operator + relative session start. Replaces
        //    the old separate operator + roll-employee cards.
        _buildWorkerSessionCard(summary.activeOperatorName),
        const SizedBox(height: 12),
        // 2. Combined current product + allowed rolls (informational only —
        //    the backend still validates every scan/mount server-side).
        _buildProductAndAllowedCard(summary.allowedRolls),
        const SizedBox(height: 12),
        // 3. Mounted roll / current roll state — or the blocked/waiting card
        //    when the line is unavailable for roll work.
        if (lineUnavailable)
          TakeoverBlockedCard(
            // `blocked` keeps its backend reason (card falls back to the
            // generic handover copy); a plain no-operator state shows the
            // dedicated waiting message.
            reason: workBlocked
                ? summary.blockedReason
                : TakeoverStrings.noActiveOperator,
          )
        else
          _MountSection(
            summaryMountedRoll: summary.mountedRoll,
            accentColor: widget.accentColor,
          ),
        const SizedBox(height: 12),
        // 4. Returned-remaining banner after an operator incompatible switch.
        if (summary.returnedRemainingRoll != null) ...<Widget>[
          ReturnedRemainingCard(
            snapshot: summary.returnedRemainingRoll!,
            onAcknowledge: () => ref
                .read(shiftLineSummaryControllerProvider(_shiftLineId).notifier)
                .acknowledgeReturnedRemaining(),
            // Reprint is a roll action — suppressed while the line is
            // unavailable (blocked, or no active operator).
            onReprint:
                !lineUnavailable && summary.returnedRemainingRoll!.canPrintLabel
                ? (id) => _onReprintTap(context, id)
                : null,
            onPreview:
                !lineUnavailable && summary.returnedRemainingRoll!.canPrintLabel
                ? (id) => _openLabelPreview(context, id)
                : null,
          ),
          const SizedBox(height: 12),
        ],
        // 5. Lower-priority session stats + consumed-rolls history — kept LAST
        //    so the history never dominates the first screen.
        SummaryCard(
          completedRollsInSession: summary.completedRollsInSession,
          // V123: operator-shift-line-scoped consumed kg (includes live
          // provisional from the mounted roll). Backend-corrected counters are
          // trusted as-is (V127) — never recomputed from the active token.
          consumedWeightKg: summary.consumedWeightKgInSession,
          mountedRollPresent: summary.mountedRoll != null,
          isRefreshing: isRefreshing,
          accent: widget.accentColor,
        ),
        const SizedBox(height: 12),
        ConsumedRollsSection(
          rolls: summary.consumedRolls,
          accent: widget.accentColor,
          // Reprint is suppressed while the line is unavailable (handover,
          // takeover blocked, no operator) — the worker can't act on the
          // physical roll right now anyway.
          //
          // When enabled, the per-row `labelTimestamp` and `reprintLabelType`
          // from /summary are passed as overrides so the print pipeline never
          // substitutes device time and the GRINDING scrap icon renders
          // correctly.
          onReprint: lineUnavailable
              ? null
              : (id) {
                  final overrides = _reprintOverridesFor(id);
                  _onReprintTap(
                    context,
                    id,
                    overrideTimestamp: overrides.timestamp,
                    labelType: overrides.labelType,
                  );
                },
        ),
        const SizedBox(height: 10),
      ]
      else
        // First-load failure with no prior data: keep the empty mount card
        // live so the worker can retry; the fixed bottom button stays
        // "تسجيل رول" so a scan can recover the line.
        _MountSection(
          summaryMountedRoll: null,
          accentColor: widget.accentColor,
        ),
    ];

    final Widget scrollable = RefreshIndicator(
      // Pull-to-refresh refetches the summary AND /sessions/me (operator,
      // roll worker, product, allowed rolls, mounted roll, session data).
      onRefresh: _onRefresh,
      child: ListView(
        // AlwaysScrollable so the gesture works even when the content is
        // shorter than the viewport (empty / error / waiting states). The
        // generous bottom padding keeps the last card clear of the fixed
        // bottom action (which sits in its own row below this scroll view, so
        // it can never overlap the list).
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: listChildren,
      ),
    );

    // State-driven fixed bottom action — close the mounted roll, or register a
    // new one. Never both; hidden while loading / line unavailable.
    final Widget body = showBottomAction
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(child: scrollable),
              if (mountedRoll != null)
                PrimaryBottomAction(
                  label: RollWorkerHomeScreen.closeCurrentRoll,
                  icon: Icons.archive_outlined,
                  onPressed: () => _openCloseFlow(context, mountedRoll),
                  color: widget.accentColor,
                )
              else
                PrimaryBottomAction(
                  label: RollWorkerHomeScreen.registerRoll,
                  icon: Icons.qr_code_scanner_rounded,
                  onPressed: () => _openScanScreen(context),
                  color: widget.accentColor,
                ),
            ],
          )
        : scrollable;

    if (!widget.standaloneScaffold) return body;

    return AppScaffold(
      title: _lineLabel,
      actions: <Widget>[
        IconButton(
          tooltip: RollWorkerHomeScreen.printerSettingsTooltip,
          onPressed: () => _openPrinterSettings(context),
          icon: const Icon(Icons.print_rounded),
        ),
      ],
      body: body,
    );
  }
}

/// Renders the mounted-roll card (when a roll is mounted) or the empty-state
/// card. The close action is NOT here — it is the screen's state-driven fixed
/// bottom button (`إغلاق الرول الحالي`), so this section only shows the card.
class _MountSection extends StatelessWidget {
  const _MountSection({
    required this.summaryMountedRoll,
    this.accentColor,
  });

  final SummaryMountedRoll? summaryMountedRoll;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final SummaryMountedRoll? roll = summaryMountedRoll;
    if (roll != null) {
      return CompactMountedRollCard(roll: roll, accentColor: accentColor);
    }
    return EmptyRollStateCard(accent: accentColor);
  }
}

/// Compact top-of-content header carrying the line identity (`خط أ`, …) as an
/// accent-tinted pill. Shown in shell mode where the screen owns no AppBar.
class _LineHeader extends StatelessWidget {
  const _LineHeader({required this.label, this.accent});

  final String label;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final Color color = accent ?? AppColors.primary;
    return Row(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.30)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.linear_scale_rounded, size: 18, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppTextStyles.h3.copyWith(color: color),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
