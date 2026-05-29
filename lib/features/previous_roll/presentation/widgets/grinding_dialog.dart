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
import 'remaining_weight_field.dart';

/// Numeric input + confirm dialog for sending the remainder of a partial
/// roll to the grinding station. Adds an extra warning per requirements §10
/// because the action is not reversible from the worker's side.
Future<void> showGrindingDialog(
  BuildContext context, {
  required int shiftLineId,
  double? maxAllowedKg,
  Color? accent,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) => _GrindingDialog(
      shiftLineId: shiftLineId,
      maxAllowedKg: maxAllowedKg,
      accent: accent,
    ),
  );
}

class _GrindingDialog extends ConsumerStatefulWidget {
  const _GrindingDialog({
    required this.shiftLineId,
    this.maxAllowedKg,
    this.accent,
  });

  final int shiftLineId;
  final double? maxAllowedKg;

  /// Active line accent for the weight field + cancel button. The confirm
  /// button intentionally stays on the warning color — grinding is the one
  /// genuinely risky (non-reversible) close option.
  final Color? accent;

  static const String title = 'تأكيد إرسال المتبقي للجرش';
  static const String body = 'هل تريد إرسال الوزن المتبقي للجرش؟';
  static const String submit = 'تأكيد الجرش';
  static const String cancel = 'إلغاء';
  static const String validationOverflow =
      'لا يمكن أن يكون الوزن المتبقي أكبر من وزن بداية الرول';
  static const String validationFormat = 'يرجى إدخال الوزن المتبقي';
  static const String validationNegative =
      'يجب أن يكون الوزن المتبقي أكبر من أو يساوي صفر';

  @override
  ConsumerState<_GrindingDialog> createState() => _GrindingDialogState();
}

class _GrindingDialogState extends ConsumerState<_GrindingDialog> {
  final TextEditingController _weightController = TextEditingController();
  String? _localError;

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  double? _parseWeight() => double.tryParse(_weightController.text.trim());

  String? _validate() {
    final double? value = _parseWeight();
    if (value == null) return _GrindingDialog.validationFormat;
    if (value < 0) return _GrindingDialog.validationNegative;
    if (widget.maxAllowedKg != null && value > widget.maxAllowedKg!) {
      return _GrindingDialog.validationOverflow;
    }
    return null;
  }

  Future<void> _submit() async {
    final String? error = _validate();
    if (error != null) {
      setState(() => _localError = error);
      return;
    }
    setState(() => _localError = null);
    await ref
        .read(
          previousRollResolutionControllerProvider(widget.shiftLineId).notifier,
        )
        .sendToGrinding(_parseWeight()!);
  }

  @override
  Widget build(BuildContext context) {
    final PreviousRollResolutionState state = ref.watch(
      previousRollResolutionControllerProvider(widget.shiftLineId),
    );

    ref.listen<PreviousRollResolutionState>(
      previousRollResolutionControllerProvider(widget.shiftLineId),
      (prev, next) {
        if (next is PreviousRollResolved) Navigator.of(context).maybePop();
      },
    );

    final bool resolving = state is PreviousRollResolving;
    final String? backendError = state is PreviousRollFailureState
        ? arabicMessageFor(state.failure)
        : null;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(_GrindingDialog.title, style: AppTextStyles.h3),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(_GrindingDialog.body, style: AppTextStyles.bodyLarge),
            const SizedBox(height: 16),
            RemainingWeightField(
              controller: _weightController,
              maxAllowedKg: widget.maxAllowedKg,
              enabled: !resolving,
              errorText: _localError,
              accent: widget.accent,
              onChanged: (_) {
                if (_localError != null) {
                  setState(() => _localError = null);
                }
              },
            ),
            if (backendError != null) ...[
              const SizedBox(height: 12),
              InlineError(message: backendError),
            ],
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        actions: [
          Row(
            children: [
              Expanded(
                child: AppSecondaryButton(
                  label: _GrindingDialog.cancel,
                  color: widget.accent,
                  onPressed: resolving
                      ? null
                      : () => Navigator.of(context).pop(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppPrimaryButton.accent(
                  label: _GrindingDialog.submit,
                  icon: Icons.recycling_rounded,
                  isLoading: resolving,
                  onPressed: resolving ? null : _submit,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
