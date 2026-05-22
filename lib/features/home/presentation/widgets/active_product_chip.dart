import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/shift_line_summary.dart';

/// Compact pill showing the line's currently active product.
///
/// Fed by the operator-dashboard SSE channel (handoff §3.1 / §3.5). When
/// the SSE has not produced a snapshot yet (e.g. fresh app launch with
/// no product switch since), [product] is null and the chip is hidden by
/// the parent.
class ActiveProductChip extends StatelessWidget {
  const ActiveProductChip({super.key, required this.product});

  final SummaryActiveProduct product;

  static const String _label = 'المنتج الحالي';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.inventory_2_rounded,
            size: 18,
            color: AppColors.primary,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(_label, style: AppTextStyles.metricLabel),
                const SizedBox(height: 2),
                Text(
                  product.name,
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: AppColors.primaryDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
