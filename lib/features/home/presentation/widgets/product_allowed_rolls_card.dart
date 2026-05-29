import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/section_header.dart';
import '../../domain/entities/allowed_roll.dart';

/// Combined, **expandable** "current product + allowed rolls" card.
///
/// Collapsed (default): the product title, the clean product name (no
/// color/quantity metadata), and a single allowed-roll preview badge with a
/// chevron hint — compact, low vertical footprint.
///
/// Expanded: the product name, the `الرولات المسموحة لهذا المنتج` header, and
/// every allowed roll as a full-width badge. Smooth `AnimatedSize` expansion,
/// no default `ExpansionTile` chrome/borders.
///
/// Display-only — the backend still validates every scan/mount server-side.
/// Every roll label goes through [formatAllowedRollDisplayName] so the
/// de-duplicated `TP-1 Black (زبدية)` formatting is shared, never re-derived.
class ProductAllowedRollsCard extends StatefulWidget {
  const ProductAllowedRollsCard({
    super.key,
    required this.productName,
    required this.allowedRolls,
    this.accent,
    this.initiallyExpanded = false,
  });

  /// Raw current-product string from the summary; only the leading segment
  /// (before the first `/`) is shown. `null`/empty ⇒ "no current product".
  final String? productName;
  final List<AllowedRoll> allowedRolls;
  final Color? accent;

  /// Mostly for tests/golden states — the card defaults to collapsed.
  final bool initiallyExpanded;

  static const String productTitle = 'المنتج الحالي';
  static const String allowedTitle = 'الرولات المسموحة لهذا المنتج';
  static const String noProduct = 'لا يوجد منتج حالي';
  static const String allowedEmpty = 'لا توجد رولات مسموحة لهذا المنتج';
  static const String preferredBadge = 'مفضل';
  static const String inactiveBadge = 'غير نشط';
  static const String expandHint = 'اضغط لعرض كل الرولات المسموحة';

  /// Backwards-compatible short label — now delegates to the single shared
  /// formatter so older call sites stay correct.
  static String shortLabel(AllowedRoll roll) =>
      formatAllowedRollDisplayName(roll);

  static String? _cleanProductName(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final String name = raw.trim();
    final String head = name.split('/').first.trim();
    return head.isNotEmpty ? head : name;
  }

  @override
  State<ProductAllowedRollsCard> createState() =>
      _ProductAllowedRollsCardState();
}

class _ProductAllowedRollsCardState extends State<ProductAllowedRollsCard> {
  late bool _expanded = widget.initiallyExpanded;

  void _toggle() => setState(() => _expanded = !_expanded);

  @override
  Widget build(BuildContext context) {
    final Color color = widget.accent ?? AppColors.primary;
    final String? name = ProductAllowedRollsCard._cleanProductName(
      widget.productName,
    );
    final List<AllowedRoll> rolls = widget.allowedRolls;
    final bool hasRolls = rolls.isNotEmpty;
    // Only the preview/expand affordance needs the toggle; with ≤1 roll the
    // collapsed preview already shows everything, so the card stays static.
    final bool expandable = rolls.length > 1;

    return AppCard(
      elevated: true,
      accent: color,
      borderRadius: 18,
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: expandable ? _toggle : null,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SectionHeader(
                title: ProductAllowedRollsCard.productTitle,
                icon: Icons.inventory_2_rounded,
                accent: color,
                trailing: expandable
                    ? AnimatedRotation(
                        turns: _expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: color,
                          size: 24,
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: 10),
              if (name == null)
                Text(
                  ProductAllowedRollsCard.noProduct,
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: AppColors.textSecondary,
                  ),
                )
              else
                Text(
                  name,
                  // Task I: product name only, slightly smaller than the old h1.
                  style: AppTextStyles.h2.copyWith(color: color),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 14),
              // Allowed-rolls sub-header is always present so the preview badge
              // is labelled even in the collapsed state.
              SectionHeader(
                title: ProductAllowedRollsCard.allowedTitle,
                icon: Icons.layers_rounded,
                accent: color,
              ),
              const SizedBox(height: 12),
              if (!hasRolls)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    ProductAllowedRollsCard.allowedEmpty,
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                )
              else
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeInOut,
                  alignment: Alignment.topCenter,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      // Always show the first (preferred) roll as the preview.
                      _RollBadge(roll: rolls.first, accent: color),
                      if (expandable && _expanded)
                        for (int i = 1; i < rolls.length; i++) ...<Widget>[
                          const SizedBox(height: 8),
                          _RollBadge(roll: rolls[i], accent: color),
                        ],
                      if (expandable && !_expanded) ...<Widget>[
                        const SizedBox(height: 8),
                        Text(
                          '+${rolls.length - 1} · '
                          '${ProductAllowedRollsCard.expandHint}',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.caption.copyWith(color: color),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-width allowed-roll badge: spans the card, centered RTL label from the
/// shared formatter, with a preferred star / inactive marker.
class _RollBadge extends StatelessWidget {
  const _RollBadge({required this.roll, required this.accent});

  final AllowedRoll roll;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final bool active = roll.active;
    final Color fg = active ? AppColors.textPrimary : AppColors.textSecondary;
    final Color bg = active
        ? accent.withValues(alpha: 0.06)
        : AppColors.surfaceMuted;
    final Color borderColor = active
        ? accent.withValues(alpha: 0.30)
        : AppColors.border;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Flexible(
            child: Text(
              formatAllowedRollDisplayName(roll),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodyLarge.copyWith(
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
          ),
          if (roll.preferred && active) ...<Widget>[
            const SizedBox(width: 8),
            const Icon(Icons.star_rounded, size: 16, color: AppColors.warning),
            const SizedBox(width: 2),
            Text(
              ProductAllowedRollsCard.preferredBadge,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.warning,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (!active) ...<Widget>[
            const SizedBox(width: 8),
            Text(
              ProductAllowedRollsCard.inactiveBadge,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
