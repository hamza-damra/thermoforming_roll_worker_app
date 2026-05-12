import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class AppPrimaryButton extends StatelessWidget {
  const AppPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.color,
  });

  const AppPrimaryButton.accent({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
  }) : color = AppColors.accent;

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final bool disabled = onPressed == null || isLoading;
    return ElevatedButton(
      onPressed: disabled ? null : onPressed,
      style: color == null
          ? null
          : ElevatedButton.styleFrom(
              backgroundColor: color,
              disabledBackgroundColor: color!.withValues(alpha: 0.5),
            ),
      child: isLoading
          ? const SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.textOnPrimary,
                ),
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 22, color: AppColors.textOnPrimary),
                  const SizedBox(width: 10),
                ],
                Flexible(
                  child: Text(
                    label,
                    style: AppTextStyles.button,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
    );
  }
}
