import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'app_primary_button.dart';
import 'app_secondary_button.dart';

/// Fixed bottom action bar — a white, shadowed footer holding a single
/// full-width primary button. Matches the reference app's non-floating
/// "create" CTA: visually dominant, easy to reach, never a FAB.
///
/// An optional secondary action renders as a full-width outlined button above
/// the primary one, for a second way to reach the same goal.
class PrimaryBottomAction extends StatelessWidget {
  const PrimaryBottomAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.color,
    this.secondaryLabel,
    this.secondaryIcon,
    this.onSecondaryPressed,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final Color? color;

  /// Shown only when non-null.
  final String? secondaryLabel;
  final IconData? secondaryIcon;
  final VoidCallback? onSecondaryPressed;

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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (secondaryLabel != null) ...<Widget>[
                AppSecondaryButton(
                  label: secondaryLabel!,
                  icon: secondaryIcon,
                  color: color,
                  onPressed: onSecondaryPressed,
                ),
                const SizedBox(height: 10),
              ],
              AppPrimaryButton(
                label: label,
                icon: icon,
                isLoading: isLoading,
                onPressed: onPressed,
                color: color,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
