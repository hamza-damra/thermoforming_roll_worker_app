import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../roll_worker_auth/presentation/controllers/multi_line_session_registry.dart';
import '../../../roll_worker_auth/presentation/controllers/multi_line_session_registry_state.dart';

/// Confirms a "تسجيل خروج من جميع الخطوط" action. After confirmation, the
/// dialog calls [MultiLineSessionRegistry.logoutAll] and surfaces either
/// a success dismiss or a per-line failure list with retry buttons.
class LogoutAllConfirmDialog extends ConsumerStatefulWidget {
  const LogoutAllConfirmDialog({super.key, required this.lineCount});

  final int lineCount;

  static const String title = 'تأكيد تسجيل الخروج';
  static const String confirmLabel = 'تسجيل الخروج';
  static const String cancelLabel = 'إلغاء';
  static const String successHint = 'تم تسجيل الخروج من جميع الخطوط.';
  static const String failureHint =
      'فشل تسجيل الخروج من بعض الخطوط، يمكنك إعادة المحاولة.';
  static const String retryLineLabel = 'إعادة المحاولة لخط';

  static String confirmBody(int n) => 'تأكيد تسجيل الخروج من $n خط؟';

  static Future<void> show(BuildContext context, {required int lineCount}) {
    return showDialog<void>(
      context: context,
      builder: (_) => LogoutAllConfirmDialog(lineCount: lineCount),
    );
  }

  @override
  ConsumerState<LogoutAllConfirmDialog> createState() =>
      _LogoutAllConfirmDialogState();
}

class _LogoutAllConfirmDialogState
    extends ConsumerState<LogoutAllConfirmDialog> {
  bool _submitting = false;
  LogoutAllResult? _result;

  Future<void> _confirm() async {
    setState(() => _submitting = true);
    final LogoutAllResult result = await ref
        .read(multiLineSessionRegistryProvider.notifier)
        .logoutAll();
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _result = result;
    });
    // If everything succeeded, auto-close.
    if (!result.hasFailures) {
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _retry(int shiftLineId) async {
    await ref
        .read(multiLineSessionRegistryProvider.notifier)
        .logout(shiftLineId);
  }

  @override
  Widget build(BuildContext context) {
    final LogoutAllResult? result = _result;
    return AlertDialog(
      title: const Text(LogoutAllConfirmDialog.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            result == null
                ? LogoutAllConfirmDialog.confirmBody(widget.lineCount)
                : (result.hasFailures
                      ? LogoutAllConfirmDialog.failureHint
                      : LogoutAllConfirmDialog.successHint),
            style: AppTextStyles.body,
          ),
          if (result != null && result.hasFailures) ...[
            const SizedBox(height: 12),
            for (final int id in result.failed)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'خط #$id',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.warning,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _retry(id),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text(
                        LogoutAllConfirmDialog.retryLineLabel,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
      actions: <Widget>[
        if (result == null) ...[
          TextButton(
            onPressed: _submitting ? null : () => Navigator.of(context).pop(),
            child: const Text(LogoutAllConfirmDialog.cancelLabel),
          ),
          TextButton(
            onPressed: _submitting ? null : _confirm,
            child: _submitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(LogoutAllConfirmDialog.confirmLabel),
          ),
        ] else
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(LogoutAllConfirmDialog.cancelLabel),
          ),
      ],
    );
  }
}
