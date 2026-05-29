import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'section_header.dart';

/// Read-only labelled value box with a status dot — the Palletizing-style
/// identity row (header + bordered value container + active/inactive dot).
///
/// Use for the operator/machine status surfaces. When [value] is null/empty
/// the field renders a muted placeholder and a grey (inactive) dot.
class StatusField extends StatelessWidget {
  const StatusField({
    super.key,
    required this.label,
    required this.icon,
    required this.value,
    this.accent,
    this.placeholder = 'غير متوفر',
    this.active,
  });

  final String label;
  final IconData icon;
  final String? value;
  final Color? accent;
  final String placeholder;

  /// Overrides the status-dot color decision. When null, the dot is green
  /// (active) iff [value] is non-empty.
  final bool? active;

  @override
  Widget build(BuildContext context) {
    final Color color = accent ?? AppColors.primary;
    final bool hasValue = value != null && value!.trim().isNotEmpty;
    final bool isActive = active ?? hasValue;
    final String text = hasValue ? value!.trim() : placeholder;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionHeader(title: label, icon: icon, accent: color),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: hasValue ? color.withValues(alpha: 0.06) : AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hasValue
                  ? color.withValues(alpha: 0.30)
                  : AppColors.border,
            ),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  text,
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: hasValue
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  color: isActive ? AppColors.success : AppColors.textSecondary,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
