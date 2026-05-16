import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_primary_button.dart';
import '../../domain/entities/roll_scan_warning.dart';

/// Non-blocking dialog shown after a successful mount that carries a
/// `ROLL_CURING_MAXIMUM_EXCEEDED` warning. The mount has already
/// committed; the worker acknowledges and continues.
Future<void> showCuringMaxWarningDialog(
  BuildContext context, {
  required RollScanWarning warning,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) =>
        _CuringMaxWarningDialog(warning: warning),
  );
}

class _CuringMaxWarningDialog extends StatelessWidget {
  const _CuringMaxWarningDialog({required this.warning});

  final RollScanWarning warning;

  static const String _title = 'تنبيه — تجاوز الحضانة الأعلى';
  static const String _adminNote = 'تم إشعار الإدارة. يمكنك المتابعة في العمل.';
  static const String _continue = 'متابعة';

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 28),
            SizedBox(width: 8),
            Expanded(child: Text(_title, style: AppTextStyles.h3)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(warning.message, style: AppTextStyles.body),
            const SizedBox(height: 12),
            const Text(_adminNote, style: AppTextStyles.caption),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        actions: [
          AppPrimaryButton(
            label: _continue,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
