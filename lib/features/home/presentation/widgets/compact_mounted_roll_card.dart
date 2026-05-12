import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/entities/shift_line_summary.dart';

/// Compact mounted-roll card driven by [SummaryMountedRoll].
///
/// Shows `rollTypeCode • generatedRollId` on the first line and the
/// last-known weight on the second line. Rendered only when the backend
/// returns a non-null `mountedRoll` in the summary response.
class CompactMountedRollCard extends StatelessWidget {
  const CompactMountedRollCard({super.key, required this.roll});

  final SummaryMountedRoll roll;

  @override
  Widget build(BuildContext context) {
    final String weightText = roll.lastKnownWeightKg != null
        ? '~ ${roll.lastKnownWeightKg!.toStringAsFixed(1)} كجم'
        : '—';
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: AppColors.primaryLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.qr_code_2_rounded,
              size: 22,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'الرول المُحمَّل',
                  style: AppTextStyles.metricLabel,
                ),
                const SizedBox(height: 2),
                Text(
                  '${roll.rollTypeCode}  •  ${roll.generatedRollId}',
                  style: AppTextStyles.bodyLarge,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(weightText, style: AppTextStyles.label),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
