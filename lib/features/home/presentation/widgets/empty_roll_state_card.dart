import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/section_header.dart';

/// Empty-state card for the "no roll mounted" case.
///
/// Shares the [title] (`الرول المركب حالياً`) and accent chrome with
/// [CompactMountedRollCard] so the two mount states read as the same card,
/// then shows a compact message + helper line. Kept deliberately small (a
/// single icon + two text lines) — professional, not a huge hero panel. The
/// accent tints the icon badge so it still belongs to the machine's color
/// identity while clearly reading as idle.
class EmptyRollStateCard extends StatelessWidget {
  const EmptyRollStateCard({
    super.key,
    this.title = defaultTitle,
    this.message = defaultMessage,
    this.helper = defaultHelper,
    this.accent,
  });

  final String title;
  final String message;
  final String helper;
  final Color? accent;

  static const String defaultTitle = 'الرول المركب حالياً';
  static const String defaultMessage = 'لا يوجد رول مركب حالياً';
  static const String defaultHelper = 'اضغط تركيب رول لبدء رول جديد';

  @override
  Widget build(BuildContext context) {
    final Color color = accent ?? AppColors.primary;
    return AppCard(
      elevated: true,
      accent: color,
      borderRadius: 18,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SectionHeader(
            title: title,
            icon: Icons.qr_code_2_rounded,
            accent: color,
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.inventory_2_outlined,
                  size: 24,
                  color: color,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      message,
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      helper,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
