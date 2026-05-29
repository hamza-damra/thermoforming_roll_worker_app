import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class AppSecondaryButton extends StatelessWidget {
  const AppSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.color,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;

  /// Outline + icon + label color. Falls back to the brand primary so the
  /// button can follow the active line accent when supplied by the caller.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final bool disabled = onPressed == null || isLoading;
    final Color c = color ?? AppColors.primary;
    return OutlinedButton(
      onPressed: disabled ? null : onPressed,
      style: color == null
          ? null
          : OutlinedButton.styleFrom(
              foregroundColor: c,
              side: BorderSide(color: c, width: 1.5),
            ),
      child: isLoading
          ? SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(c),
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 22, color: c),
                  const SizedBox(width: 10),
                ],
                Text(
                  label,
                  style: AppTextStyles.button.copyWith(color: c),
                ),
              ],
            ),
    );
  }
}
