import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/info_row.dart';
import '../../domain/entities/previous_roll_resolution.dart';

/// Post-close summary card. Replaces the active mount card on the home
/// screen for the brief window between a successful close and the next
/// mount (or worker dismissing the summary).
///
/// Stage 6 only renders the summary; the reprint button arrives in
/// Stage 8. The `reprintAvailable` flag is intentionally tracked here so
/// downstream stages can light up the button without further state churn.
class ClosedRollSummaryCard extends StatelessWidget {
  const ClosedRollSummaryCard({
    super.key,
    required this.resolution,
    required this.onAcknowledge,
  });

  final PreviousRollResolution resolution;
  final VoidCallback onAcknowledge;

  static const String _heading = 'تم إغلاق الرول';
  static const String _generatedRollId = 'رقم الرول';
  static const String _finalState = 'النتيجة';
  static const String _consumed = 'الوزن المستهلك';
  static const String _remaining = 'الوزن المتبقي';
  static const String _ackLabel = 'حسنًا';
  static const String _reprintAvailable = 'يمكن إعادة طباعة الليبل';

  String _finalStateLabel(PreviousRollFinalState state) {
    return switch (state) {
      PreviousRollFinalState.consumed => 'تم الاستهلاك بالكامل',
      PreviousRollFinalState.partiallyReturned => 'تم إرجاع المتبقي',
      PreviousRollFinalState.sentToGrinding => 'تم إرسال المتبقي للجرش',
    };
  }

  String _kg(double v) => '${v.toStringAsFixed(3)} كغ';

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
                decoration: const BoxDecoration(
                  color: AppColors.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  size: 24,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(_heading, style: AppTextStyles.h3),
                    const SizedBox(height: 2),
                    Text(
                      resolution.generatedRollId,
                      style: AppTextStyles.label,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          InfoRow(
            label: _generatedRollId,
            value: resolution.generatedRollId,
            icon: Icons.tag_rounded,
          ),
          InfoRow(
            label: _finalState,
            value: _finalStateLabel(resolution.finalState),
            icon: Icons.flag_outlined,
          ),
          InfoRow(
            label: _consumed,
            value: _kg(resolution.consumedWeightKg),
            icon: Icons.scale_rounded,
            valueStyle: AppTextStyles.metricValue,
          ),
          InfoRow(
            label: _remaining,
            value: _kg(resolution.remainingWeightKg),
            icon: Icons.balance_rounded,
          ),
          if (resolution.reprintAvailable) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.print_outlined,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(_reprintAvailable, style: AppTextStyles.label),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onAcknowledge,
            icon: const Icon(Icons.check_rounded, size: 22),
            label: const Text(_ackLabel),
          ),
        ],
      ),
    );
  }
}
