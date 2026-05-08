import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_scaffold.dart';

/// Backend-gap blocked screen shown when no Thermoforming shift-line is
/// available for the device.
///
/// Production behavior: this is the entry point until the
/// active-shift-lines picker endpoint ships
/// (`GET /api/v1/thermoforming-roll-app/shift-lines/active-options`,
/// requirements §7 / §24 gap #1). The screen is intentionally passive — no
/// manual entry, no debug shortcut, no build-time bypass flag, no hardcoded
/// id. Once the operator opens a Thermoforming shift-line and the backend
/// exposes the picker, this screen will route automatically into the PIN
/// flow without any worker interaction here.
///
/// The retry indicator is a *visible heartbeat*, not an action — it tells
/// the worker the device is alive and listening, even though no backend
/// refresh is possible yet.
class WaitingForLineScreen extends ConsumerWidget {
  const WaitingForLineScreen({super.key});

  static const String title = 'تطبيق عامل الرولات';

  /// Primary, prescribed Arabic copy.
  static const String headlineMessage = 'بانتظار فتح خط من تطبيق المشغّل';

  /// Secondary heading shown inside the card.
  static const String backendGapHeading = 'قائمة الخطوط غير متاحة حاليًا';

  /// Detail line shown beneath the heading.
  static const String backendGapDetail =
      'هذه الميزة قيد التحضير من الخادم. سيتم تفعيلها لاحقًا.';

  /// Caption next to the live-pulse indicator.
  static const String waitingIndicatorLabel = 'قيد الانتظار…';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppScaffold(
      title: title,
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
            headlineMessage,
            style: AppTextStyles.h2,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          const AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(backendGapHeading, style: AppTextStyles.h3),
                SizedBox(height: 8),
                Text(backendGapDetail, style: AppTextStyles.body),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
              SizedBox(width: 10),
              Text(waitingIndicatorLabel, style: AppTextStyles.label),
            ],
          ),
        ],
      ),
    );
  }
}
