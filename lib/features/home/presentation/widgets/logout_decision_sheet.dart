import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/directional_chevron.dart';

/// The four logout resolutions offered when the worker leaves a line that still
/// has a mounted roll (handoff §5.1), in EXACT order.
enum LogoutDecision {
  /// Keep the roll mounted for the next worker; ends the session in one call.
  keepMounted,

  /// Full-consume the roll, then log out.
  fullConsume,

  /// Return the remainder, then log out.
  returnRemaining,

  /// Send the remainder to grinding, then log out.
  grinding,
}

/// First-step sheet shown when the worker taps Leave while a roll is mounted.
/// Returns the picked [LogoutDecision], or `null` if dismissed.
Future<LogoutDecision?> showLogoutDecisionSheet(
  BuildContext context, {
  Color? accent,
}) {
  return showDialog<LogoutDecision>(
    context: context,
    barrierDismissible: true,
    builder: (BuildContext context) => _LogoutDecisionSheet(accent: accent),
  );
}

class _LogoutDecisionSheet extends StatelessWidget {
  const _LogoutDecisionSheet({this.accent});

  final Color? accent;

  static const String title = 'تسجيل الخروج من الخط';
  static const String detail = 'الرول ما زال مركباً. اختر كيف تريد المتابعة.';
  static const String keepMounted = 'الرول ما زال مركب للموظف التالي';
  static const String fullConsume = 'استهلاك كامل وإنزال الرول';
  static const String returnRemaining = 'إرجاع المتبقي';
  static const String grinding = 'إرسال للجرش';
  static const String cancel = 'إلغاء';

  @override
  Widget build(BuildContext context) {
    final Color color = accent ?? AppColors.primary;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(title, style: AppTextStyles.h3),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text(detail, style: AppTextStyles.body),
            const SizedBox(height: 16),
            // 1. Keep mounted for the next worker — the new primary handover.
            _ChoiceTile(
              icon: Icons.layers_outlined,
              label: keepMounted,
              color: color,
              onTap: () =>
                  Navigator.of(context).pop(LogoutDecision.keepMounted),
            ),
            const SizedBox(height: 8),
            // 2. Full consume + close.
            _ChoiceTile(
              icon: Icons.check_circle_outline_rounded,
              label: fullConsume,
              color: color,
              onTap: () =>
                  Navigator.of(context).pop(LogoutDecision.fullConsume),
            ),
            const SizedBox(height: 8),
            // 3. Return remainder.
            _ChoiceTile(
              icon: Icons.assignment_return_outlined,
              label: returnRemaining,
              color: color,
              onTap: () =>
                  Navigator.of(context).pop(LogoutDecision.returnRemaining),
            ),
            const SizedBox(height: 8),
            // 4. Grinding — the only genuinely risky option, kept on warning.
            _ChoiceTile(
              icon: Icons.recycling_rounded,
              label: grinding,
              color: AppColors.warning,
              onTap: () => Navigator.of(context).pop(LogoutDecision.grinding),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            style: TextButton.styleFrom(foregroundColor: color),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(cancel),
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
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(color: color, width: 1.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: <Widget>[
              Icon(icon, size: 24, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const DirectionalChevron(),
            ],
          ),
        ),
      ),
    );
  }
}
