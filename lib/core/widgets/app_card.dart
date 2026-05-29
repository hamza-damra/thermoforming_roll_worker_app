import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Rounded surface container used across the app.
///
/// The default is a flat, bordered card (kept for backward compatibility).
/// Pass [elevated] (optionally with an [accent]) for the Palletizing-style
/// look: a soft dual shadow (accent tint + black) and a faint accent border
/// instead of the neutral grey border.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.borderColor,
    this.borderRadius = 14,
    this.elevated = false,
    this.accent,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;
  final double borderRadius;

  /// When `true`, renders the soft dual-shadow elevation used by the
  /// dashboard cards. The shadow tint follows [accent] (falls back to the
  /// brand primary).
  final bool elevated;

  /// Accent color driving the elevated shadow tint and border. Ignored
  /// unless [elevated] is `true` (and [borderColor] is not supplied).
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final Color tint = accent ?? AppColors.primary;
    final Border border = Border.all(
      color: borderColor ??
          (elevated ? tint.withValues(alpha: 0.14) : AppColors.border),
    );
    return Container(
      decoration: BoxDecoration(
        color: color ?? AppColors.surface,
        borderRadius: BorderRadius.circular(borderRadius),
        border: border,
        boxShadow: elevated
            ? <BoxShadow>[
                BoxShadow(
                  color: tint.withValues(alpha: 0.10),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      padding: padding,
      child: child,
    );
  }
}
