import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_primary_button.dart';
import '../../../../core/widgets/app_secondary_button.dart';
import '../../domain/entities/roll_worker_bootstrap_line.dart';
import '../controllers/roll_worker_bootstrap_controller.dart';
import '../controllers/roll_worker_bootstrap_state.dart';
import 'line_waiting_status.dart';

/// Shows the polished blocking dialog for a non-selectable machine row.
///
/// The Roll Worker app stays passive — the dialog only explains *why* the
/// line cannot be selected yet and offers a silent status refresh. It carries
/// no accept / reject / handover / takeover actions, and starting a session
/// remains impossible until the backend reports the row `selectable`.
Future<void> showLineUnavailableDialog(
  BuildContext context, {
  required RollWorkerBootstrapLine line,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _LineUnavailableDialog(line: line),
  );
}

class _LineUnavailableDialog extends ConsumerWidget {
  const _LineUnavailableDialog({required this.line});

  /// The machine row the worker tapped. Identified across refreshes by its
  /// stable [RollWorkerBootstrapLine.thermoformingLineId].
  final RollWorkerBootstrapLine line;

  /// Looks the row up again in a freshly-refreshed bootstrap state.
  static RollWorkerBootstrapLine? _findLine(
    RollWorkerBootstrapState state,
    int thermoformingLineId,
  ) {
    final List<RollWorkerBootstrapLine> lines = switch (state) {
      RollWorkerBootstrapLoaded(:final lines) => lines,
      RollWorkerBootstrapLoading(:final previous) => previous,
      RollWorkerBootstrapFailureState(:final previous) => previous,
      RollWorkerBootstrapInitial() => const <RollWorkerBootstrapLine>[],
    };
    for (final RollWorkerBootstrapLine candidate in lines) {
      if (candidate.thermoformingLineId == thermoformingLineId) {
        return candidate;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Auto-dismiss the moment the backend reports this machine ready — a
    // silent "تحديث الحالة" tap or a background SSE / poll refresh both land
    // here, so the worker is never left staring at a stale dialog.
    ref.listen<RollWorkerBootstrapState>(
      rollWorkerBootstrapControllerProvider,
      (_, RollWorkerBootstrapState next) {
        final RollWorkerBootstrapLine? updated = _findLine(
          next,
          line.thermoformingLineId,
        );
        final bool ready =
            updated != null &&
            updated.selectable &&
            updated.shiftLineId != null;
        if (ready && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      },
    );

    final bool warning = LineWaitingStatus.isWarningReason(line);
    final Color accent = warning ? AppColors.accent : AppColors.primary;
    final Color accentBg = warning
        ? AppColors.offlineBg
        : AppColors.primaryLight;
    final IconData icon = warning
        ? Icons.swap_horizontal_circle_outlined
        : Icons.hourglass_top_rounded;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Column(
          children: <Widget>[
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: accentBg,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: accent),
            ),
            const SizedBox(height: 12),
            const Text(
              LineWaitingStatus.dialogTitle,
              style: AppTextStyles.h3,
              textAlign: TextAlign.center,
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              LineWaitingStatus.dialogBodyFor(line),
              style: AppTextStyles.body,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              LineWaitingStatus.dialogHelper,
              style: AppTextStyles.caption,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            AppPrimaryButton(
              label: LineWaitingStatus.dialogPrimaryAction,
              icon: Icons.check_rounded,
              onPressed: () => Navigator.of(context).pop(),
            ),
            const SizedBox(height: 10),
            AppSecondaryButton(
              label: LineWaitingStatus.dialogRefreshAction,
              icon: Icons.refresh_rounded,
              // Silent background refresh — no full-screen spinner. The
              // `ref.listen` above closes the dialog if the line is ready.
              onPressed: () => ref
                  .read(rollWorkerBootstrapControllerProvider.notifier)
                  .refresh(trigger: 'dialog-refresh', background: true),
            ),
          ],
        ),
      ),
    );
  }
}
