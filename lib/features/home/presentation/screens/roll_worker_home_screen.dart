import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_primary_button.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/app_secondary_button.dart';
import '../../../../core/widgets/info_row.dart';
import '../../../previous_roll/domain/entities/previous_roll_resolution.dart';
import '../../../previous_roll/presentation/controllers/previous_roll_resolution_controller.dart';
import '../../../previous_roll/presentation/controllers/previous_roll_resolution_state.dart';
import '../../../previous_roll/presentation/widgets/close_previous_roll_dialog.dart';
import '../../../previous_roll/presentation/widgets/closed_roll_summary_card.dart';
import '../../../previous_roll/presentation/widgets/full_consume_confirm_dialog.dart';
import '../../../previous_roll/presentation/widgets/grinding_dialog.dart';
import '../../../previous_roll/presentation/widgets/return_remaining_dialog.dart';
import '../../../roll_scan/domain/entities/mounted_roll.dart';
import '../../../roll_scan/presentation/controllers/roll_scan_controller.dart';
import '../../../roll_scan/presentation/controllers/roll_scan_state.dart';
import '../../../roll_scan/presentation/screens/scan_roll_screen.dart';
import '../../../roll_scan/presentation/widgets/mount_card.dart';
import '../../../roll_worker_auth/domain/entities/roll_worker_session.dart';
import '../../../roll_worker_auth/presentation/controllers/roll_worker_auth_controller.dart';

/// Real Roll Worker home — replaces the Stage 3 placeholder.
///
/// Surface:
///   - Worker / line context card
///   - Active mount card + close button when a roll is mounted
///   - Closed-roll summary card immediately after a successful close
///   - Empty mount CTA when nothing is mounted
///   - Logout button
///
/// Stage 7 will stub the product-switch entry; Stage 8 the reprint button.
class RollWorkerHomeScreen extends ConsumerWidget {
  const RollWorkerHomeScreen({
    super.key,
    required this.shiftLineId,
    required this.session,
  });

  final int shiftLineId;
  final RollWorkerSession session;

  static const String title = 'تطبيق عامل الرولات';
  static const String workerHeading = 'مرحبًا بك';
  static const String thermoformingLine = 'خط التشكيل';
  static const String palletizingLine = 'خط الطبليات المرتبط';
  static const String sessionStarted = 'بدأت الجلسة';
  static const String mountNewRoll = 'تركيب رول جديد';
  static const String closePreviousRoll = 'إغلاق الرول السابق';
  static const String emptyMountHeading = 'لا يوجد رول مركّب حاليًا';
  static const String emptyMountDetail = 'ابدأ بتركيب رول جديد بمسح رمز QR.';
  static const String logoutLabel = 'تسجيل خروج عامل الرولات';
  static const String closedRollSnack = 'تم إغلاق الرول بنجاح';

  Future<void> _openScanScreen(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ScanRollScreen(shiftLineId: shiftLineId),
      ),
    );
  }

  Future<void> _openCloseFlow(
    BuildContext context,
    WidgetRef ref,
    MountedRoll roll,
  ) async {
    // Reset any stale failure before opening so the new dialog starts clean.
    ref
        .read(previousRollResolutionControllerProvider(shiftLineId).notifier)
        .clearError();

    final ClosePreviousRollAction? action = await showClosePreviousRollDialog(
      context,
    );
    if (action == null || !context.mounted) return;

    switch (action) {
      case ClosePreviousRollAction.fullConsume:
        await showFullConsumeConfirmDialog(context, shiftLineId: shiftLineId);
      case ClosePreviousRollAction.returnRemaining:
        await showReturnRemainingDialog(
          context,
          shiftLineId: shiftLineId,
          maxAllowedKg: roll.lastKnownWeightKg,
        );
      case ClosePreviousRollAction.sendToGrinding:
        await showGrindingDialog(
          context,
          shiftLineId: shiftLineId,
          maxAllowedKg: roll.lastKnownWeightKg,
        );
    }
  }

  void _logout(WidgetRef ref) {
    ref.read(rollScanControllerProvider(shiftLineId).notifier).reset();
    ref
        .read(previousRollResolutionControllerProvider(shiftLineId).notifier)
        .reset();
    ref.read(rollWorkerAuthControllerProvider(shiftLineId).notifier).logout();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final RollScanState scanState = ref.watch(
      rollScanControllerProvider(shiftLineId),
    );
    final PreviousRollResolutionState resolutionState = ref.watch(
      previousRollResolutionControllerProvider(shiftLineId),
    );

    // Surface a snackbar on every successful close.
    ref.listen<PreviousRollResolutionState>(
      previousRollResolutionControllerProvider(shiftLineId),
      (prev, next) {
        if (next is PreviousRollResolved && prev is! PreviousRollResolved) {
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

    return AppScaffold(
      title: title,
      body: ListView(
        children: [
          const SizedBox(height: 12),
          _SessionCard(session: session),
          const SizedBox(height: 16),
          _MountSection(
            shiftLineId: shiftLineId,
            scanState: scanState,
            resolutionState: resolutionState,
            onMountTap: () => _openScanScreen(context),
            onCloseTap: (MountedRoll roll) =>
                _openCloseFlow(context, ref, roll),
            onAcknowledgeResolved: () => ref
                .read(
                  previousRollResolutionControllerProvider(
                    shiftLineId,
                  ).notifier,
                )
                .acknowledge(),
          ),
          const SizedBox(height: 24),
          AppSecondaryButton(
            label: logoutLabel,
            icon: Icons.logout_rounded,
            onPressed: () => _logout(ref),
          ),
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session});

  final RollWorkerSession session;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: AppColors.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_rounded,
                  size: 28,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      RollWorkerHomeScreen.workerHeading,
                      style: AppTextStyles.label,
                    ),
                    const SizedBox(height: 2),
                    Text(session.rollWorkerName, style: AppTextStyles.h3),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          InfoRow(
            label: RollWorkerHomeScreen.thermoformingLine,
            value: '#${session.thermoformingLineId}',
            icon: Icons.precision_manufacturing_rounded,
          ),
          InfoRow(
            label: RollWorkerHomeScreen.palletizingLine,
            value: '#${session.palletizingLineId}',
            icon: Icons.local_shipping_rounded,
          ),
          InfoRow(
            label: RollWorkerHomeScreen.sessionStarted,
            value:
                session.startedAtDisplay ?? session.startedAt.toIso8601String(),
            icon: Icons.schedule_rounded,
          ),
        ],
      ),
    );
  }
}

class _MountSection extends StatelessWidget {
  const _MountSection({
    required this.shiftLineId,
    required this.scanState,
    required this.resolutionState,
    required this.onMountTap,
    required this.onCloseTap,
    required this.onAcknowledgeResolved,
  });

  final int shiftLineId;
  final RollScanState scanState;
  final PreviousRollResolutionState resolutionState;
  final VoidCallback onMountTap;
  final ValueChanged<MountedRoll> onCloseTap;
  final VoidCallback onAcknowledgeResolved;

  @override
  Widget build(BuildContext context) {
    // After a successful close, the summary takes precedence over any
    // residual scan state until the worker dismisses it.
    if (resolutionState is PreviousRollResolved) {
      final PreviousRollResolution resolution =
          (resolutionState as PreviousRollResolved).resolution;
      return ClosedRollSummaryCard(
        resolution: resolution,
        onAcknowledge: onAcknowledgeResolved,
      );
    }

    final MountedRoll? roll = switch (scanState) {
      RollScanMounted(:final roll) => roll,
      RollScanFailureState(:final previous) => previous,
      _ => null,
    };

    if (roll == null) {
      return _EmptyMountCard(onTap: onMountTap);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MountCard(roll: roll),
        const SizedBox(height: 12),
        AppPrimaryButton.accent(
          label: RollWorkerHomeScreen.closePreviousRoll,
          icon: Icons.archive_outlined,
          onPressed: () => onCloseTap(roll),
        ),
      ],
    );
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
            label: RollWorkerHomeScreen.mountNewRoll,
            icon: Icons.qr_code_scanner_rounded,
            onPressed: onTap,
          ),
        ],
      ),
    );
  }
}
