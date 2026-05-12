import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_primary_button.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/app_secondary_button.dart';
import '../../../label_reprint/presentation/controllers/label_reprint_controller.dart';
import '../../../label_reprint/presentation/screens/label_preview_screen.dart';
import '../../../label_reprint/presentation/widgets/print_in_progress_dialog.dart';
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
import '../../../product_switch/presentation/screens/product_switch_blocked_screen.dart';
import '../../../roll_scan/presentation/controllers/roll_scan_controller.dart';
import '../../../roll_scan/presentation/controllers/roll_scan_state.dart';
import '../../../roll_scan/presentation/screens/scan_roll_screen.dart';
import '../../domain/entities/shift_line_summary.dart';
import '../controllers/shift_line_summary_controller.dart';
import '../controllers/shift_line_summary_state.dart';
import '../widgets/compact_line_header.dart';
import '../widgets/compact_mounted_roll_card.dart';
import '../widgets/summary_card.dart';

/// Per-line Roll Worker home screen.
///
/// Data comes from the backend summary endpoint — no local roll counts and
/// no session card. The compact header + summary card + optional mounted-roll
/// card are all driven by [ShiftLineSummaryController].
///
/// Navigation between lines is handled by the parent [MultiLineHomeShell]
/// via a [NavigationBar] (≥2 lines) — this screen never renders chips.
class RollWorkerHomeScreen extends ConsumerStatefulWidget {
  const RollWorkerHomeScreen({
    super.key,
    required this.shiftLineId,
    this.lineIndex = 1,
    this.standaloneScaffold = true,
    this.headerActions,
  });

  final int shiftLineId;

  /// 1-based position of this line in the active sessions list. Used as
  /// the fallback label (`خط N`) while the summary is loading.
  final int lineIndex;

  /// When `true` (default, single-line mode) the screen wraps itself in an
  /// [AppScaffold] with its own AppBar. When `false` (multi-line shell owns
  /// the AppBar) only the body is rendered.
  final bool standaloneScaffold;

  /// Extra AppBar actions injected by the shell (printer icon, overflow menu).
  final List<Widget>? headerActions;

  static const String title = 'تطبيق عامل الرولات';
  static const String scanRoll = 'مسح رول';
  static const String closePreviousRoll = 'إغلاق الرول السابق';
  static const String productSwitch = 'تغيير المنتج';
  static const String emptyMountHeading = 'لا يوجد رول مركّب حاليًا';
  static const String emptyMountDetail = 'ابدأ بتركيب رول جديد بمسح رمز QR.';
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
      if (mounted) {
        ref
            .read(
              shiftLineSummaryControllerProvider(widget.shiftLineId).notifier,
            )
            .load();
      }
    });
  }

  int get _shiftLineId => widget.shiftLineId;

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

  Future<void> _openProductSwitch(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const ProductSwitchBlockedScreen(mountedRoll: null),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    final ShiftLineSummaryState summaryState = ref.watch(
      shiftLineSummaryControllerProvider(_shiftLineId),
    );
    final PreviousRollResolutionState resolutionState = ref.watch(
      previousRollResolutionControllerProvider(_shiftLineId),
    );

    // Refresh summary after a successful mount.
    ref.listen<RollScanState>(
      rollScanControllerProvider(_shiftLineId),
      (prev, next) {
        if (next is RollScanMounted && prev is! RollScanMounted) {
          ref
              .read(
                shiftLineSummaryControllerProvider(_shiftLineId).notifier,
              )
              .refresh();
        }
      },
    );

    // Refresh summary + snackbar after a successful close.
    ref.listen<PreviousRollResolutionState>(
      previousRollResolutionControllerProvider(_shiftLineId),
      (prev, next) {
        if (next is PreviousRollResolved && prev is! PreviousRollResolved) {
          ref
              .read(
                shiftLineSummaryControllerProvider(_shiftLineId).notifier,
              )
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

    final Widget body = RefreshIndicator(
      onRefresh: () => ref
          .read(shiftLineSummaryControllerProvider(_shiftLineId).notifier)
          .refresh(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          CompactLineHeader(
            lineCode: summary?.thermoformingLineCode,
            lineName: summary?.thermoformingLineName,
            lineIndex: widget.lineIndex,
          ),
          const SizedBox(height: 12),
          if (summaryState is SummaryLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (summary != null) ...[
            SummaryCard(
              completedRollsInShift: summary.completedRollsInShift,
              completedRollsByCurrentWorker:
                  summary.completedRollsByCurrentWorker,
              isRefreshing: isRefreshing,
            ),
            const SizedBox(height: 12),
          ],
          _MountSection(
            shiftLineId: _shiftLineId,
            resolutionState: resolutionState,
            summaryMountedRoll: summary?.mountedRoll,
            onMountTap: () => _openScanScreen(context),
            onCloseTap: (roll) => _openCloseFlow(context, roll),
            onProductSwitchTap: () => _openProductSwitch(context),
            onReprintTap: (id) => _onReprintTap(context, id),
            onPreviewTap: (id) => _openLabelPreview(context, id),
            onAcknowledgeResolved: () => ref
                .read(
                  previousRollResolutionControllerProvider(
                    _shiftLineId,
                  ).notifier,
                )
                .acknowledge(),
          ),
        ],
      ),
    );

    if (!widget.standaloneScaffold) return body;

    return AppScaffold(
      title: RollWorkerHomeScreen.title,
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
    required this.onMountTap,
    required this.onCloseTap,
    required this.onProductSwitchTap,
    required this.onReprintTap,
    required this.onPreviewTap,
    required this.onAcknowledgeResolved,
  });

  final int shiftLineId;
  final PreviousRollResolutionState resolutionState;
  final SummaryMountedRoll? summaryMountedRoll;
  final VoidCallback onMountTap;
  final ValueChanged<SummaryMountedRoll> onCloseTap;
  final VoidCallback onProductSwitchTap;
  final ValueChanged<String> onReprintTap;
  final ValueChanged<String> onPreviewTap;
  final VoidCallback onAcknowledgeResolved;

  @override
  Widget build(BuildContext context) {
    // Priority 1: post-close summary card until the worker dismisses it.
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

    // Priority 2: backend says a roll is mounted → show compact card + actions.
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
          const SizedBox(height: 12),
          AppSecondaryButton(
            label: RollWorkerHomeScreen.productSwitch,
            icon: Icons.swap_horiz_rounded,
            onPressed: onProductSwitchTap,
          ),
        ],
      );
    }

    // Priority 3: nothing mounted → empty CTA.
    return _EmptyMountCard(onTap: onMountTap);
  }
}

class _EmptyMountCard extends StatelessWidget {
  const _EmptyMountCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.inventory_outlined,
                  size: 24,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      RollWorkerHomeScreen.emptyMountHeading,
                      style: AppTextStyles.h3,
                    ),
                    SizedBox(height: 4),
                    Text(
                      RollWorkerHomeScreen.emptyMountDetail,
                      style: AppTextStyles.body,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AppPrimaryButton(
            label: RollWorkerHomeScreen.scanRoll,
            icon: Icons.qr_code_scanner_rounded,
            onPressed: onTap,
          ),
        ],
      ),
    );
  }
}
