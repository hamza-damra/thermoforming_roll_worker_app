import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_primary_button.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/app_secondary_button.dart';
import '../../../../core/widgets/info_row.dart';
import '../../../roll_scan/presentation/controllers/roll_scan_controller.dart';
import '../../../roll_scan/presentation/controllers/roll_scan_state.dart';
import '../../../roll_scan/presentation/screens/scan_roll_screen.dart';
import '../../../roll_scan/presentation/widgets/mount_card.dart';
import '../../../roll_worker_auth/domain/entities/roll_worker_session.dart';
import '../../../roll_worker_auth/presentation/controllers/roll_worker_auth_controller.dart';

/// Real Roll Worker home — replaces the Stage 3 placeholder.
///
/// Stage 5 surface:
///   - Worker / line context card
///   - Active mount card (when a roll is mounted) OR empty mount CTA
///   - Logout button
///
/// Stage 6 will add the close-previous-roll dialog; Stage 7 stub the
/// product-switch entry; Stage 8 the reprint button.
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
  static const String emptyMountHeading = 'لا يوجد رول مركّب حاليًا';
  static const String emptyMountDetail = 'ابدأ بتركيب رول جديد بمسح رمز QR.';
  static const String logoutLabel = 'تسجيل خروج عامل الرولات';

  Future<void> _openScanScreen(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ScanRollScreen(shiftLineId: shiftLineId),
      ),
    );
  }

  void _logout(WidgetRef ref) {
    ref.read(rollScanControllerProvider(shiftLineId).notifier).reset();
    ref.read(rollWorkerAuthControllerProvider(shiftLineId).notifier).logout();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final RollScanState scanState = ref.watch(
      rollScanControllerProvider(shiftLineId),
    );

    return AppScaffold(
      title: title,
      body: ListView(
        children: [
          const SizedBox(height: 12),
          _SessionCard(session: session),
          const SizedBox(height: 16),
          _MountSection(
            scanState: scanState,
            onMountTap: () => _openScanScreen(context),
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
  const _MountSection({required this.scanState, required this.onMountTap});

  final RollScanState scanState;
  final VoidCallback onMountTap;

  @override
  Widget build(BuildContext context) {
    return switch (scanState) {
      RollScanMounted(:final roll) => MountCard(roll: roll),
      RollScanFailureState(:final previous) when previous != null => MountCard(
        roll: previous,
      ),
      _ => _EmptyMountCard(onTap: onMountTap),
    };
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
