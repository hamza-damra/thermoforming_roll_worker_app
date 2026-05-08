import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/app_secondary_button.dart';
import '../../../../core/widgets/info_row.dart';
import '../../domain/entities/roll_worker_session.dart';
import '../controllers/roll_worker_auth_controller.dart';

/// Stage 3 placeholder shown after successful authentication. Stage 5 will
/// replace this with the real Roll Worker home (mount card, scan, close,
/// product-switch, reprint).
class AuthenticatedHomePlaceholder extends ConsumerWidget {
  const AuthenticatedHomePlaceholder({
    super.key,
    required this.shiftLineId,
    required this.session,
  });

  final int shiftLineId;
  final RollWorkerSession session;

  static const String _title = 'تطبيق عامل الرولات';
  static const String _heading = 'مرحبًا بك';
  static const String _stagePlaceholder =
      'تم تسجيل الدخول. ستظهر شاشات تركيب الرول وإغلاق الرول وتغيير المنتج وإعادة طباعة الليبل في المراحل التالية.';
  static const String _logoutLabel = 'تسجيل خروج عامل الرولات';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppScaffold(
      title: _title,
      body: ListView(
        children: [
          const SizedBox(height: 12),
          AppCard(
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
                          const Text(_heading, style: AppTextStyles.label),
                          const SizedBox(height: 2),
                          Text(session.rollWorkerName, style: AppTextStyles.h3),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                InfoRow(
                  label: 'خط التشكيل',
                  value: '#${session.thermoformingLineId}',
                  icon: Icons.precision_manufacturing_rounded,
                ),
                InfoRow(
                  label: 'خط الطبليات المرتبط',
                  value: '#${session.palletizingLineId}',
                  icon: Icons.local_shipping_rounded,
                ),
                InfoRow(
                  label: 'بدأت الجلسة',
                  value:
                      session.startedAtDisplay ??
                      session.startedAt.toIso8601String(),
                  icon: Icons.schedule_rounded,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const AppCard(
            child: Text(_stagePlaceholder, style: AppTextStyles.body),
          ),
          const SizedBox(height: 24),
          AppSecondaryButton(
            label: _logoutLabel,
            icon: Icons.logout_rounded,
            onPressed: () {
              ref
                  .read(rollWorkerAuthControllerProvider(shiftLineId).notifier)
                  .logout();
            },
          ),
        ],
      ),
    );
  }
}
