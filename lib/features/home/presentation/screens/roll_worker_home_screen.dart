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
import '../../../label_reprint/presentation/controllers/label_reprint_controller.dart';
import '../../../label_reprint/presentation/screens/label_preview_screen.dart';
import '../../../label_reprint/presentation/widgets/print_in_progress_dialog.dart';
import '../../../operator_dashboard_sse/presentation/controllers/operator_dashboard_sync_controller.dart';
import '../../../previous_roll/domain/entities/previous_roll_resolution.dart';
import '../../../previous_roll/presentation/controllers/previous_roll_resolution_controller.dart';
import '../../../previous_roll/presentation/controllers/previous_roll_resolution_state.dart';
import '../../../previous_roll/presentation/widgets/close_previous_roll_dialog.dart';
import '../../../previous_roll/presentation/widgets/closed_roll_summary_card.dart';
import '../../../previous_roll/presentation/widgets/full_consume_confirm_dialog.dart';
import '../../../previous_roll/presentation/widgets/grinding_dialog.dart';
import '../../../previous_roll/presentation/widgets/return_remaining_dialog.dart';
import '../../../printer/data/printer_providers.dart';
import '../../../printer/domain/entities/printer_config.dart';
import '../../../printer/presentation/screens/printer_settings_screen.dart';
import '../../../roll_scan/presentation/controllers/roll_scan_controller.dart';
import '../../../roll_scan/presentation/controllers/roll_scan_state.dart';
import '../../../roll_scan/presentation/screens/scan_roll_screen.dart';
import '../../domain/entities/line_takeover.dart';
import '../../domain/entities/shift_line_summary.dart';
import '../controllers/acknowledged_takeover_controller.dart';
import '../controllers/shift_line_summary_controller.dart';
import '../controllers/shift_line_summary_state.dart';
import '../widgets/active_product_chip.dart';
import '../widgets/compact_line_header.dart';
import '../widgets/compact_mounted_roll_card.dart';
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

class _RollWorkerHomeScreenState extends ConsumerState<RollWorkerHomeScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(shiftLineSummaryControllerProvider(widget.shiftLineId).notifier)
          .load();
      // Start the operator-dashboard SSE bridge so operator-side roll-state /
      // product updates are reflected here without a manual refresh
      // (handoff §3 / §6).
      ref
          .read(
            operatorDashboardSyncControllerProvider(
              widget.shiftLineId,
            ).notifier,
          )
          .start();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Forwards app foreground/background transitions to the SSE sync
  /// controller. The operator-dashboard broker does not replay events missed
  /// while the app was paused, so on resume the controller refreshes the REST
  /// summary immediately and restarts its adaptive poll; on pause it drops
  /// the poll (Line State Refresh Events handoff §3 / §6).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final OperatorDashboardSyncController sync = ref.read(
      operatorDashboardSyncControllerProvider(_shiftLineId).notifier,
    );
    switch (state) {
      case AppLifecycleState.resumed:
        sync.onAppResumed();
      case AppLifecycleState.paused:
        sync.onAppPaused();
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        break;
    }
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
    String generatedRollId,
  ) async {
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
        .reprint(generatedRollId);
    await dialog;
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

    // Detect a new pending Line Takeover Request → alert + blocking dialog.
    ref.listen<ShiftLineSummaryState>(
      shiftLineSummaryControllerProvider(_shiftLineId),
      (_, ShiftLineSummaryState next) => _onSummaryChanged(next),
    );

    ref.listen<PreviousRollResolutionState>(
      previousRollResolutionControllerProvider(_shiftLineId),
      (prev, next) {
        if (next is PreviousRollResolved && prev is! PreviousRollResolved) {
          ref
              .read(shiftLineSummaryControllerProvider(_shiftLineId).notifier)
              .refresh();
          ScaffoldMessenger.maybeOf(context)
            ?..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(
                content: Text(RollWorkerHomeScreen.closedRollSnack),
              ),
            );
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
        ),
        const SizedBox(height: 12),
      ],
      if (takeover != null && takeover.isActive) ...[
        TakeoverBanner(shiftLineId: _shiftLineId, takeover: takeover),
        const SizedBox(height: 12),
      ],
      if (summaryState is SummaryLoading)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Center(child: CircularProgressIndicator()),
        )
      else if (summary != null) ...[
        if (summary.activeProduct != null) ...[
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: ActiveProductChip(product: summary.activeProduct!),
          ),
          const SizedBox(height: 12),
        ],
        SummaryCard(
          completedRollsInShift: summary.completedRollsInShift,
          completedRollsByCurrentWorker: summary.completedRollsByCurrentWorker,
          isRefreshing: isRefreshing,
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
          resolutionState: resolutionState,
          summaryMountedRoll: summary?.mountedRoll,
          onCloseTap: (roll) => _openCloseFlow(context, roll),
          onReprintTap: (id) => _onReprintTap(context, id),
          onPreviewTap: (id) => _openLabelPreview(context, id),
          onAcknowledgeResolved: () => ref
              .read(
                previousRollResolutionControllerProvider(_shiftLineId).notifier,
              )
              .acknowledge(),
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
    required this.resolutionState,
    required this.summaryMountedRoll,
    required this.onCloseTap,
    required this.onReprintTap,
    required this.onPreviewTap,
    required this.onAcknowledgeResolved,
  });

  final int shiftLineId;
  final PreviousRollResolutionState resolutionState;
  final SummaryMountedRoll? summaryMountedRoll;
  final ValueChanged<SummaryMountedRoll> onCloseTap;
  final ValueChanged<String> onReprintTap;
  final ValueChanged<String> onPreviewTap;
  final VoidCallback onAcknowledgeResolved;

  @override
  Widget build(BuildContext context) {
    if (resolutionState is PreviousRollResolved) {
      final PreviousRollResolution resolution =
          (resolutionState as PreviousRollResolved).resolution;
      return ClosedRollSummaryCard(
        resolution: resolution,
        onAcknowledge: onAcknowledgeResolved,
        onReprint: resolution.reprintAvailable ? onReprintTap : null,
        onPreview: resolution.reprintAvailable ? onPreviewTap : null,
      );
    }

    final SummaryMountedRoll? roll = summaryMountedRoll;
    if (roll != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
              decoration: BoxDecoration(
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
