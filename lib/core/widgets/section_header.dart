import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Reusable card/section header: a small accent icon chip grouped immediately
/// beside a bold title — the same silhouette the Palletizing app uses for its
/// identity rows (`المشغّل`, `المنتج المخطط`, ...).
///
/// In RTL the icon chip sits at the start (right) with the title hugging it
/// just to its left — they read as one tight group on the right edge, never
/// split with the icon floating at the far opposite edge. An optional
/// [trailing] widget (chevron, status pill, refresh spinner) is pushed to the
/// end (left in RTL).
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    required this.icon,
    this.accent,
    this.trailing,
  });

  final String title;
  final IconData icon;

  /// Accent color for the icon chip. Falls back to the brand primary.
  final Color? accent;

  /// Optional trailing widget rendered at the end of the row (e.g. an expand
  /// chevron, a small status pill, or a refresh spinner).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final Color color = accent ?? AppColors.primary;
    return Row(
      children: <Widget>[
        // Icon chip leads (start = right in RTL), grouped with the title.
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 19, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: AppTextStyles.h3,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (trailing != null) ...<Widget>[const SizedBox(width: 10), trailing!],
      ],
    );
  }
}
