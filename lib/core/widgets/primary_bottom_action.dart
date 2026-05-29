import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'app_primary_button.dart';

/// Fixed bottom action bar — a white, shadowed footer holding a single
/// full-width primary button. Matches the reference app's non-floating
/// "create" CTA: visually dominant, easy to reach, never a FAB.
class PrimaryBottomAction extends StatelessWidget {
  const PrimaryBottomAction({
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
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        minimum: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: AppPrimaryButton(
            label: label,
            icon: icon,
            isLoading: isLoading,
            onPressed: onPressed,
            color: color,
          ),
        ),
      ),
    );
  }
}
