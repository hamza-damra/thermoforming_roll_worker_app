import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// The three exclusive close-flow choices.
enum ClosePreviousRollAction { fullConsume, returnRemaining, sendToGrinding }

/// First-step dialog letting the worker pick one of the three exclusive
/// close flows. Returns the picked action, or `null` if the worker
/// dismissed.
Future<ClosePreviousRollAction?> showClosePreviousRollDialog(
  BuildContext context, {
  Color? accent,
}) {
  return showDialog<ClosePreviousRollAction>(
    context: context,
    barrierDismissible: true,
    builder: (BuildContext context) => _ClosePreviousRollDialog(accent: accent),
  );
}

class _ClosePreviousRollDialog extends StatelessWidget {
  const _ClosePreviousRollDialog({this.accent});

  /// Active line accent used by the two non-destructive choices and the
  /// cancel button. The grinding choice stays on the warning color because it
  /// is the only genuinely risky option. Falls back to the brand primary.
  final Color? accent;

  static const String _title = 'إغلاق الرول السابق';
  static const String _detail = 'اختر طريقة إغلاق الرول الحالي';
  static const String _fullConsume = 'استهلاك كامل';
  static const String _returnRemaining = 'إرجاع المتبقي';
  static const String _grinding = 'إرسال المتبقي للجرش';
  static const String _cancel = 'إلغاء';

  @override
  Widget build(BuildContext context) {
    final Color color = accent ?? AppColors.primary;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(_title, style: AppTextStyles.h3),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(_detail, style: AppTextStyles.body),
            const SizedBox(height: 16),
            _ChoiceTile(
              icon: Icons.check_circle_outline_rounded,
              label: _fullConsume,
              color: color,
              onTap: () => Navigator.of(
                context,
              ).pop(ClosePreviousRollAction.fullConsume),
            ),
            const SizedBox(height: 8),
            _ChoiceTile(
              icon: Icons.assignment_return_outlined,
              label: _returnRemaining,
              color: color,
              onTap: () => Navigator.of(
                context,
              ).pop(ClosePreviousRollAction.returnRemaining),
            ),
            const SizedBox(height: 8),
            _ChoiceTile(
              icon: Icons.recycling_rounded,
              label: _grinding,
              // Only the grinding choice is highlighted as a warning.
              color: AppColors.warning,
              onTap: () => Navigator.of(
                context,
              ).pop(ClosePreviousRollAction.sendToGrinding),
            ),
          ],
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: color),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(_cancel),
          ),
        ],
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// Border + icon color for this choice (line accent, or warning for the
  /// risky grinding option).
  final Color color;

  @override
  Widget build(BuildContext context) {
    final Color border = color;
    final Color iconColor = color;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(color: border, width: 1.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, size: 24, color: iconColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_left_rounded,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
