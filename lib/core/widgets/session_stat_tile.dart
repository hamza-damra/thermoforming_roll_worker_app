import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Compact session metric tile — optional accent icon circle + label + large
/// value, with an optional [subline] and [trailing] widget. Mirrors the stat
/// tiles in the Palletizing summary card. When [icon] is null the leading
/// circle is omitted and the text column takes the full width.
class SessionStatTile extends StatelessWidget {
  const SessionStatTile({
    super.key,
    this.icon,
    required this.label,
    required this.value,
    this.subline,
    this.trailing,
    this.accent,
  });

  final IconData? icon;
  final String label;

  /// Pre-formatted value string (kept as a plain [Text] so it stays
  /// test-findable, e.g. `'8'`).
  final String value;

  /// Optional secondary line under the value (e.g. `'منك: 3'`).
  final String? subline;

  /// Optional trailing widget (e.g. a small refresh spinner).
  final Widget? trailing;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final Color color = accent ?? AppColors.primary;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        if (icon != null) ...<Widget>[
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 24, color: color),
          ),
          const SizedBox(width: 14),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(label, style: AppTextStyles.metricLabel),
              const SizedBox(height: 4),
              // Value and subline are stacked (not a horizontal Row): a wide
              // value (e.g. "142.5 كغ") plus a long subline (e.g.
              // "ساهمت في: 3 رولات") would otherwise overflow the row,
              // especially at larger accessibility text scales.
              Text(
                value,
                style: AppTextStyles.metricValue.copyWith(
                  color: color,
                  fontSize: 30,
                ),
              ),
              if (subline != null) ...<Widget>[
                const SizedBox(height: 2),
                Text(
                  subline!,
                  style: AppTextStyles.caption.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...<Widget>[const SizedBox(width: 10), trailing!],
      ],
    );
  }
}
