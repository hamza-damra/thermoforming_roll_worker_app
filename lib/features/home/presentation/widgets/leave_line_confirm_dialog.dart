import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../roll_worker_auth/presentation/controllers/multi_line_session_registry.dart';
import '../../../roll_worker_auth/presentation/controllers/multi_line_session_registry_state.dart';

/// Clean, modern confirmation for the roll employee's deliberate "leave now"
/// (`مغادرة الآن`) on a single line.
///
/// Reuses the existing per-line logout API
/// ([MultiLineSessionRegistry.logout]) — no new endpoint, no fake local
/// logout. The dialog:
///   * is not dismissible while a logout is in flight (barrier + back),
///   * shows a loading state on confirm,
///   * surfaces an inline error and allows retry on failure,
///   * pops `true` on success so the caller can show feedback.
///
/// Danger styling is reserved for the final confirm button only.
class LeaveLineConfirmDialog extends ConsumerStatefulWidget {
  const LeaveLineConfirmDialog({
    super.key,
    required this.shiftLineId,
    this.employeeName,
    this.lineLabel,
    this.productName,
  });

  final int shiftLineId;
  final String? employeeName;
  final String? lineLabel;
  final String? productName;

  static const String title = 'تأكيد مغادرة الخط';
  static const String body =
      'سيتم تسجيل خروجك من هذا الخط. تأكد أنك أنهيت عملك على الرول الحالي قبل '
      'المغادرة. المتابعة على مسؤوليتك.';
  static const String cancelLabel = 'إلغاء';
  static const String confirmLabel = 'تأكيد المغادرة';
  static const String errorMessage =
      'تعذّر تسجيل الخروج. تحقّق من الاتصال وحاول مرة أخرى.';

  static Future<bool?> show(
    BuildContext context, {
    required int shiftLineId,
    String? employeeName,
    String? lineLabel,
    String? productName,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => LeaveLineConfirmDialog(
        shiftLineId: shiftLineId,
        employeeName: employeeName,
        lineLabel: lineLabel,
        productName: productName,
      ),
    );
  }

  @override
  ConsumerState<LeaveLineConfirmDialog> createState() =>
      _LeaveLineConfirmDialogState();
}

class _LeaveLineConfirmDialogState
    extends ConsumerState<LeaveLineConfirmDialog> {
  bool _submitting = false;
  bool _failed = false;

  Future<void> _confirm() async {
    setState(() {
      _submitting = true;
      _failed = false;
    });

    // Existing per-line logout — clears the line token + drops the session.
    await ref
        .read(multiLineSessionRegistryProvider.notifier)
        .logout(widget.shiftLineId);
    if (!mounted) return;

    // Success ⇒ the line is no longer in the registry (dropped, or registry
    // collapsed to empty). If it survives, the logout failed and was marked
    // retryable — keep the dialog open with an inline error.
    final MultiLineSessionRegistryState state = ref.read(
      multiLineSessionRegistryProvider,
    );
    final bool stillLoggedIn =
        state is RegistryActive &&
        state.sessions.containsKey(widget.shiftLineId);

    if (stillLoggedIn) {
      setState(() {
        _submitting = false;
        _failed = true;
      });
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final List<_ContextRow> rows = <_ContextRow>[
      if (_nonEmpty(widget.employeeName) != null)
        _ContextRow(
          icon: Icons.badge_rounded,
          label: 'الموظف',
          value: widget.employeeName!.trim(),
        ),
      if (_nonEmpty(widget.lineLabel) != null)
        _ContextRow(
          icon: Icons.linear_scale_rounded,
          label: 'الخط',
          value: widget.lineLabel!.trim(),
        ),
      if (_nonEmpty(widget.productName) != null)
        _ContextRow(
          icon: Icons.inventory_2_rounded,
          label: 'المنتج',
          value: widget.productName!.trim(),
        ),
    ];

    return PopScope(
      // Block accidental back-dismiss while the logout request is in flight.
      canPop: !_submitting,
      child: Dialog(
        backgroundColor: AppColors.surface,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    size: 32,
                    color: AppColors.warning,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                LeaveLineConfirmDialog.title,
                style: AppTextStyles.h2,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                LeaveLineConfirmDialog.body,
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              if (rows.isNotEmpty) ...<Widget>[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: <Widget>[
                      for (int i = 0; i < rows.length; i++) ...<Widget>[
                        if (i > 0) const SizedBox(height: 8),
                        rows[i],
                      ],
                    ],
                  ),
                ),
              ],
              if (_failed) ...<Widget>[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.errorBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: <Widget>[
                      Icon(
                        Icons.error_outline_rounded,
                        size: 18,
                        color: AppColors.error,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          LeaveLineConfirmDialog.errorMessage,
                          style: AppTextStyles.errorInline,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _submitting
                          ? null
                          : () => Navigator.of(context).pop(false),
                      child: const Text(LeaveLineConfirmDialog.cancelLabel),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _confirm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        disabledBackgroundColor: AppColors.error.withValues(
                          alpha: 0.5,
                        ),
                        foregroundColor: AppColors.textOnPrimary,
                      ),
                      child: _submitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.textOnPrimary,
                                ),
                              ),
                            )
                          : Text(
                              _failed
                                  ? 'إعادة المحاولة'
                                  : LeaveLineConfirmDialog.confirmLabel,
                              style: AppTextStyles.button,
                              overflow: TextOverflow.ellipsis,
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String? _nonEmpty(String? v) =>
      (v != null && v.trim().isNotEmpty) ? v.trim() : null;
}

class _ContextRow extends StatelessWidget {
  const _ContextRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: AppTextStyles.caption.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
