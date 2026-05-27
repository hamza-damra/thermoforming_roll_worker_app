import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Compact pill showing the line's currently active product.
///
/// Source of truth is `/sessions/me` (`currentPlanItemProductTypeId` /
/// `currentPlanItemProductName`). When the line has no active production-plan
/// item, render the placeholder constructor instead so the layout stays
/// stable.
class ActiveProductChip extends StatelessWidget {
  const ActiveProductChip({
    super.key,
    required this.productName,
    this.productId,
  }) : isPlaceholder = false;

  const ActiveProductChip.placeholder({super.key})
    : productName = _placeholderText,
      productId = null,
      isPlaceholder = true;

  final String productName;
  final int? productId;
  final bool isPlaceholder;

  static const String _label = 'المنتج الحالي';
  static const String _placeholderText = 'لا يوجد منتج حالي';

  @override
  Widget build(BuildContext context) {
    final Color background = isPlaceholder
        ? AppColors.primaryLight.withValues(alpha: 0.5)
        : AppColors.primaryLight;
    final Color border = isPlaceholder
        ? AppColors.textSecondary.withValues(alpha: 0.25)
        : AppColors.primary.withValues(alpha: 0.25);
    final Color iconColor = isPlaceholder
        ? AppColors.textSecondary
        : AppColors.primary;
    final Color valueColor = isPlaceholder
        ? AppColors.textSecondary
        : AppColors.primaryDark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.inventory_2_rounded,
            size: 18,
            color: iconColor,
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
                  productName,
                  style: AppTextStyles.bodyLarge.copyWith(color: valueColor),
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
