import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/app_secondary_button.dart';
import '../controllers/selected_shift_line_provider.dart';

/// Backend-gap blocked screen shown when no Thermoforming shift-line is
/// available for the device.
///
/// Production behavior: this is the entry point until the active-options
/// picker endpoint ships (requirements §7 / §24 gap #1). The retry button
/// re-evaluates state but cannot make progress without backend support.
class WaitingForLineScreen extends ConsumerWidget {
  const WaitingForLineScreen({super.key});

  static const String _title = 'تطبيق عامل الرولات';
  static const String _waiting = 'بانتظار فتح خط من تطبيق المشغّل';
  static const String _heading = 'قائمة الخطوط غير متاحة حاليًا';
  static const String _detail =
      'هذه الميزة قيد التحضير من الخادم. سيتم تفعيلها لاحقًا.';
  static const String _retry = 'إعادة المحاولة';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppScaffold(
      title: _title,
      body: ListView(
        children: [
          const SizedBox(height: 12),
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
            _waiting,
            style: AppTextStyles.h2,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          const AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(_heading, style: AppTextStyles.h3),
                SizedBox(height: 8),
                Text(_detail, style: AppTextStyles.body),
              ],
            ),
          ),
          const SizedBox(height: 24),
          AppSecondaryButton(
            label: _retry,
            icon: Icons.refresh_rounded,
            onPressed: () {
              // Trigger any registered listeners (Stage 4 will wire this to
              // a backend re-fetch). For now the action is a no-op since
              // the picker endpoint does not exist.
              ref.read(selectedShiftLineIdProvider.notifier);
            },
          ),
        ],
      ),
    );
  }
}
