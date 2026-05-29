import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/section_header.dart';

/// Readable current-product card.
///
/// Shows the clean product name only — the leading segment before the first
/// `/`, dropping color/quantity metadata (e.g. `TBB-14 C1000 Beige`, not
/// `… / Beige / 24 كرتونة`). Renders a neutral placeholder when no product is
/// active.
class CurrentProductCard extends StatelessWidget {
  const CurrentProductCard({
    super.key,
    required this.productName,
    this.accent,
  });

  final String? productName;
  final Color? accent;

  static const String label = 'المنتج الحالي';
  static const String placeholder = 'لا يوجد منتج حالي على هذا الخط';

  @override
  Widget build(BuildContext context) {
    final Color color = accent ?? AppColors.primary;
    final String? name = (productName != null && productName!.trim().isNotEmpty)
        ? productName!.trim()
        : null;

    return AppCard(
      elevated: true,
      accent: color,
      borderRadius: 18,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SectionHeader(
            title: label,
            icon: Icons.inventory_2_rounded,
            accent: color,
          ),
          const SizedBox(height: 12),
          if (name == null)
            Text(
              placeholder,
              style: AppTextStyles.bodyLarge.copyWith(
                color: AppColors.textSecondary,
              ),
            )
          else
            // Clean product name only (leading segment before the first `/`),
            // slightly smaller than the old prominent headline (task I).
            Text(
              _cleanName(name),
              style: AppTextStyles.h2.copyWith(color: color),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }

  /// Leading product segment before the first `/`, dropping color/quantity
  /// metadata. Names with no `/` are returned as-is.
  static String _cleanName(String name) {
    final String head = name.split('/').first.trim();
    return head.isNotEmpty ? head : name;
  }
}
