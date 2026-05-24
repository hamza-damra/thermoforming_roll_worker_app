import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/takeover_alert_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/ui/factory_machine_labels.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_primary_button.dart';
import '../../../../core/widgets/app_scaffold.dart';
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
import '../widgets/active_product_chip.dart';
import '../widgets/compact_line_header.dart';
import '../widgets/compact_mounted_roll_card.dart';
import '../widgets/consumed_rolls_section.dart';
import '../widgets/home_shimmer_skeleton.dart';
import '../widgets/returned_remaining_card.dart';
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
/// Navigation between machines is handled by the parent [MultiLineHomeShell]
/// via a [NavigationBar] (≥2 sessions) — this screen never shows TH codes.
class RollWorkerHomeScreen extends ConsumerStatefulWidget {
  const RollWorkerHomeScreen({
    super.key,
    required this.shiftLineId,
    this.lineIndex = 1,
    this.standaloneScaffold = true,
    this.headerActions,
    this.accentColor,
  });

  final int shiftLineId;

  /// 1-based position of this machine among active sessions (ماكنة أ، …).
  final int lineIndex;

  /// When `true` (default, single-line mode) the screen wraps itself in an
  /// [AppScaffold] with its own AppBar. When `false` (multi-line shell owns
  /// the AppBar) only the body is rendered.
  final bool standaloneScaffold;

  /// Extra AppBar actions injected by the shell (printer icon, overflow menu).
  final List<Widget>? headerActions;

  /// Per-line accent color used by the multi-line shell to tint the line
  /// header strip + scan button — `null` falls back to the global accent.
  /// Same line gets the same color across launches (see
  /// `AppColors.accentForLine`).
  final Color? accentColor;

  static const String title = 'تطبيق موظف الرولات';
  static const String scanRoll = 'مسح رول';
  static const String closePreviousRoll = 'إغلاق الرول السابق';
  static const String emptyMountHeading = 'لا يوجد رول مركّب حاليًا';
  static const String emptyMountDetail = 'امسح رمز QR لتركيب رول جديد';
  static const String closedRollSnack = 'تم إغلاق الرول بنجاح';
  static const String printerSettingsTooltip = 'إعدادات الطباعة';

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
        builder: (_) => ScanRollScreen(shiftLineId: _shiftLineId),
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
    );
    if (action == null || !context.mounted) return;

    switch (action) {
      case ClosePreviousRollAction.fullConsume:
        await showFullConsumeConfirmDialog(context, shiftLineId: _shiftLineId);
      case ClosePreviousRollAction.returnRemaining:
        await showReturnRemainingDialog(
          context,
          shiftLineId: _shiftLineId,
          maxAllowedKg: roll.lastKnownWeightKg,
        );
      case ClosePreviousRollAction.sendToGrinding:
        await showGrindingDialog(
          context,
          shiftLineId: _shiftLineId,
          maxAllowedKg: roll.lastKnownWeightKg,
        );
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
  /// driven). Falls back to a neutral placeholder chip when no active plan
  /// item is present. The legacy `summary.currentProductType*` fields are no
  /// longer used for the chip.
  ///
  /// Uses `select` to scope rebuilds to the (id, name) pair for THIS line —
  /// otherwise a fallback poll or refresh-flag flip would rebuild the chip
  /// on every tick.
  Widget _buildActiveProductChip() {
    final (int?, String?) selected = ref.watch(
      sessionsMeControllerProvider.select<(int?, String?)>((s) {
        if (s is! SessionsMeLoaded) return (null, null);
        for (final RollWorkerActiveLine l in s.me.lines) {
          if (l.shiftLineId == _shiftLineId) {
            return (l.currentPlanItemProductTypeId, l.currentPlanItemProductName);
          }
        }
        return (null, null);
      }),
    );
    final int? id = selected.$1;
    final String? name = selected.$2;
    if (name == null) return const ActiveProductChip.placeholder();
    return ActiveProductChip(productName: name, productId: id);
  }

  bool _showThumbZoneScan({
    required ShiftLineSummaryState summaryState,
    required PreviousRollResolutionState resolutionState,
    required ShiftLineSummary? summary,
  }) {
    if (resolutionState is PreviousRollResolved) return false;
    if (summaryState is SummaryLoading) return false;
    if (summaryState is SummaryLoaded) {
      return summary!.mountedRoll == null;
    }
    if (summaryState is SummaryError) return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final ShiftLineSummaryState summaryState = ref.watch(
      shiftLineSummaryControllerProvider(_shiftLineId),
    );
    final PreviousRollResolutionState resolutionState = ref.watch(
      previousRollResolutionControllerProvider(_shiftLineId),
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
    // active/visible lines" rule. Each visible PerLinePage owns this
    // listener, so an off-screen line in the PageView still updates on
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
            // Auto-print priority for the timestamp:
            //   1. close-response labelTimestamp (this branch)
            //   2. /reprint-label.createdAt (fetched inside the
            //      controller)
            //   3. abort with PrintingException.missingLabelTimestamp.
            // Never substitute DateTime.now().
            //
            // GRINDING vs RETURN drives the scrap-icon switch in the
            // renderer. Prefer the explicit backend `reprintLabelType`
            // when present; otherwise infer from `remainderAction` so
            // older backends still pick the right template.
            final String inferredType = switch (res.remainderAction) {
              PreviousRollRemainderAction.grinding => 'GRINDING_REMAINING',
              PreviousRollRemainderAction.returned => 'RETURN_REMAINING',
              _ => '',
            };
            final String? labelType =
                (res.reprintLabelType != null && res.reprintLabelType!.isNotEmpty)
                    ? res.reprintLabelType
                    : (inferredType.isEmpty ? null : inferredType);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              _onReprintTap(
                context,
                res.generatedRollId,
                overrideTimestamp: res.labelTimestamp,
                labelType: labelType,
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

    final bool showThumbScan =
        !lineUnavailable &&
        _showThumbZoneScan(
          summaryState: summaryState,
          resolutionState: resolutionState,
          summary: summary,
        );

    final List<Widget> listChildren = <Widget>[
      if (!widget.standaloneScaffold) ...[
        CompactLineHeader(
          lineCode: summary?.thermoformingLineCode,
          lineName: summary?.thermoformingLineName,
          lineIndex: widget.lineIndex,
          accentColor: widget.accentColor,
        ),
        const SizedBox(height: 12),
      ],
      if (takeover != null && takeover.isActive) ...[
        TakeoverBanner(shiftLineId: _shiftLineId, takeover: takeover),
        const SizedBox(height: 12),
      ],
      if (summaryState is SummaryLoading)
        const HomeShimmerSkeleton()
      else if (summary != null) ...[
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: _buildActiveProductChip(),
        ),
        const SizedBox(height: 12),
        SummaryCard(
          completedRollsInSession: summary.completedRollsInSession,
          completedRollsByCurrentWorker: summary.completedRollsByCurrentWorker,
          isRefreshing: isRefreshing,
        ),
        const SizedBox(height: 12),
        ConsumedRollsSection(
          rolls: summary.consumedRolls,
          // Reprint is suppressed while the line is unavailable (handover,
          // takeover blocked, no operator) — the worker can't act on the
          // physical roll right now anyway.
          //
          // When enabled, the per-row `labelTimestamp` and
          // `reprintLabelType` from /summary are passed as overrides so
          // the print pipeline never substitutes device time and the
          // GRINDING scrap icon is rendered correctly.
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
        const SizedBox(height: 12),
        if (summary.returnedRemainingRoll != null) ...[
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
      ],
      if (lineUnavailable)
        TakeoverBlockedCard(
          // `blocked` keeps its backend reason (card falls back to the
          // generic handover copy); a plain no-operator state shows the
          // dedicated waiting message.
          reason: workBlocked
              ? summary?.blockedReason
              : TakeoverStrings.noActiveOperator,
        )
      else
        _MountSection(
          shiftLineId: _shiftLineId,
          summaryMountedRoll: summary?.mountedRoll,
          onCloseTap: (roll) => _openCloseFlow(context, roll),
        ),
      if (showThumbScan) const SizedBox(height: 24),
    ];

    final Widget scrollable = RefreshIndicator(
      onRefresh: () => ref
          .read(shiftLineSummaryControllerProvider(_shiftLineId).notifier)
          .refresh(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        children: listChildren,
      ),
    );

    final Widget body = showThumbScan
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: scrollable),
              SafeArea(
                top: false,
                minimum: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: AppPrimaryButton(
                    label: RollWorkerHomeScreen.scanRoll,
                    icon: Icons.qr_code_scanner_rounded,
                    onPressed: () => _openScanScreen(context),
                    // Per-line accent (handoff §8 item 8: scan button is
                    // one of the surfaces tinted with the line color).
                    color: widget.accentColor,
                  ),
                ),
              ),
            ],
          )
        : scrollable;

    if (!widget.standaloneScaffold) return body;

    final String appBarTitle = FactoryMachineLabels.titleForOneBasedIndex(
      widget.lineIndex,
    );

    return AppScaffold(
      title: appBarTitle,
      actions: <Widget>[
        IconButton(
          tooltip: RollWorkerHomeScreen.printerSettingsTooltip,
          onPressed: () => _openPrinterSettings(context),
          icon: const Icon(Icons.print_rounded),
        ),
        ...?widget.headerActions,
      ],
      body: body,
    );
  }
}

class _MountSection extends StatelessWidget {
  const _MountSection({
    required this.shiftLineId,
    required this.summaryMountedRoll,
    required this.onCloseTap,
  });

  final int shiftLineId;
  final SummaryMountedRoll? summaryMountedRoll;
  final ValueChanged<SummaryMountedRoll> onCloseTap;

  @override
  Widget build(BuildContext context) {
    final SummaryMountedRoll? roll = summaryMountedRoll;
    if (roll != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          CompactMountedRollCard(roll: roll),
          const SizedBox(height: 12),
          AppPrimaryButton.accent(
            label: RollWorkerHomeScreen.closePreviousRoll,
            icon: Icons.archive_outlined,
            onPressed: () => onCloseTap(roll),
          ),
        ],
      );
    }

    return const _EmptyMountPromptCard();
  }
}

class _EmptyMountPromptCard extends StatelessWidget {
  const _EmptyMountPromptCard();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      borderRadius: 18,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.inventory_2_outlined,
                size: 36,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            RollWorkerHomeScreen.emptyMountHeading,
            style: AppTextStyles.h2,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            RollWorkerHomeScreen.emptyMountDetail,
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
