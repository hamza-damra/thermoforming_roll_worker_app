import 'package:flutter/material.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/errors/error_messages_ar.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_primary_button.dart';

/// Blocking modal shown when the backend rejects a mount with
/// `ROLL_CURING_MINIMUM_NOT_MET` (HTTP 409). The mount did not happen and
/// the worker MUST acknowledge before the scan flow re-arms.
///
/// Body text prefers `failure.serverMessage` (backend authors a localized
/// Arabic message via MessageSource); falls back to the static mapping in
/// [arabicMessageFor] for clients that arrived before the locale was set.
Future<void> showCuringMinViolationDialog(
  BuildContext context, {
  required BusinessFailure failure,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) =>
        _CuringMinViolationDialog(failure: failure),
  );
}

class _CuringMinViolationDialog extends StatelessWidget {
  const _CuringMinViolationDialog({required this.failure});

  final BusinessFailure failure;

  static const String _title = 'لا يمكن تركيب الرول';
  static const String _ok = 'حسناً';

  @override
  Widget build(BuildContext context) {
    final String body =
        (failure.serverMessage != null && failure.serverMessage!.isNotEmpty)
        ? failure.serverMessage!
        : arabicMessageFor(failure);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.block_rounded, color: AppColors.error, size: 28),
            SizedBox(width: 8),
            Expanded(child: Text(_title, style: AppTextStyles.h3)),
          ],
        ),
        content: Text(body, style: AppTextStyles.body),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        actions: [
          AppPrimaryButton(
            label: _ok,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
