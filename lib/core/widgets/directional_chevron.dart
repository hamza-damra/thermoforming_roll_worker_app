import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// A "drill-in" chevron that points in the reading-forward direction for the
/// ambient text direction: **left in RTL** (Arabic) and **right in LTR**.
///
/// Use this for list/option rows and navigation affordances instead of a
/// hard-coded `Icons.chevron_left/right` so the arrow is always correct when
/// the app renders RTL. The icon's own [textDirection] is pinned to LTR so the
/// framework does not additionally mirror the glyph — we pick the correct
/// glyph explicitly.
class DirectionalChevron extends StatelessWidget {
  const DirectionalChevron({
    super.key,
    this.color,
    this.size,
    this.rounded = true,
  });

  final Color? color;
  final double? size;

  /// Use the rounded Material variant to match the app's card chrome.
  final bool rounded;

  @override
  Widget build(BuildContext context) {
    final bool isRtl = Directionality.of(context) == TextDirection.rtl;
    final IconData icon = isRtl
        ? (rounded ? Icons.chevron_left_rounded : Icons.chevron_left)
        : (rounded ? Icons.chevron_right_rounded : Icons.chevron_right);
    return Icon(
      icon,
      color: color ?? AppColors.textSecondary,
      size: size,
      // Pin LTR so the framework does not mirror the glyph we already chose.
      textDirection: TextDirection.ltr,
    );
  }
}
