import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/error_messages_ar.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_primary_button.dart';
import '../../../../core/widgets/app_secondary_button.dart';
import '../../../../core/widgets/inline_error.dart';
import '../controllers/previous_roll_resolution_controller.dart';
import '../controllers/previous_roll_resolution_state.dart';

/// Confirmation dialog for full-consume close. Submits via the controller
/// and pops on resolved/failure-via-controller; the host stays open while
/// resolving.
Future<void> showFullConsumeConfirmDialog(
  BuildContext context, {
  required int shiftLineId,
  Color? accent,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) =>
        _FullConsumeConfirmDialog(shiftLineId: shiftLineId, accent: accent),
  );
}

class _FullConsumeConfirmDialog extends ConsumerWidget {
  const _FullConsumeConfirmDialog({required this.shiftLineId, this.accent});

  final int shiftLineId;

  /// Active line accent for the confirm + cancel buttons.
  final Color? accent;

  static const String _title = 'تأكيد استهلاك كامل';
  static const String _question = 'هل تريد إغلاق هذا الرول كاستهلاك كامل؟';
  static const String _confirm = 'تأكيد الاستهلاك';
  static const String _cancel = 'إلغاء';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PreviousRollResolutionState state = ref.watch(
      previousRollResolutionControllerProvider(shiftLineId),
    );

    // Pop the dialog as soon as the controller resolves or fails — the host
    // surface (home) shows the summary or inline error.
    ref.listen<PreviousRollResolutionState>(
      previousRollResolutionControllerProvider(shiftLineId),
      (prev, next) {
        if (next is PreviousRollResolved) Navigator.of(context).maybePop();
      },
    );

    final bool resolving = state is PreviousRollResolving;
    final String? errorMessage = state is PreviousRollFailureState
        ? arabicMessageFor(state.failure)
        : null;

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
            const Text(_question, style: AppTextStyles.bodyLarge),
            if (errorMessage != null) ...[
              const SizedBox(height: 12),
              InlineError(message: errorMessage),
            ],
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        actions: [
          Row(
            children: [
              Expanded(
                child: AppSecondaryButton(
                  label: _cancel,
                  color: accent,
                  onPressed: resolving
                      ? null
                      : () => Navigator.of(context).pop(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppPrimaryButton(
                  label: _confirm,
                  color: accent,
                  isLoading: resolving,
                  onPressed: resolving
                      ? null
                      : () => ref
                            .read(
                              previousRollResolutionControllerProvider(
                                shiftLineId,
                              ).notifier,
                            )
                            .fullConsume(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
