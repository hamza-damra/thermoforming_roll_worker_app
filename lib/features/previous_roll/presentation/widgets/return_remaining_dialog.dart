import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/error_messages_ar.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_primary_button.dart';
import '../../../../core/widgets/app_secondary_button.dart';
import '../../../../core/widgets/inline_error.dart';
import '../../domain/entities/previous_roll_resolution.dart';
import '../controllers/previous_roll_resolution_controller.dart';
import '../controllers/previous_roll_resolution_state.dart';
import 'remaining_weight_field.dart';
import 'remaining_weight_validation.dart';

/// Numeric input + confirm dialog for returning the remainder of a partial
/// roll to the warehouse. Resolves to the [PreviousRollResolution] when the
/// close succeeded (the logout flow uses it to print the remainder label, then
/// log out), or `null` on cancel.
Future<PreviousRollResolution?> showReturnRemainingDialog(
  BuildContext context, {
  required int shiftLineId,
  double? maxAllowedKg,
  Color? accent,
}) {
  return showDialog<PreviousRollResolution>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) => _ReturnRemainingDialog(
      shiftLineId: shiftLineId,
      maxAllowedKg: maxAllowedKg,
      accent: accent,
    ),
  );
}

class _ReturnRemainingDialog extends ConsumerStatefulWidget {
  const _ReturnRemainingDialog({
    required this.shiftLineId,
    this.maxAllowedKg,
    this.accent,
  });

  final int shiftLineId;
  final double? maxAllowedKg;

  /// Active line accent for the weight field + confirm/cancel buttons.
  final Color? accent;

  static const String title = 'تأكيد إرجاع المتبقي';
  static const String body = 'هل تريد إرجاع الوزن المتبقي من هذا الرول؟';
  static const String submit = 'إرجاع المتبقي';
  static const String cancel = 'إلغاء';

  @override
  ConsumerState<_ReturnRemainingDialog> createState() =>
      _ReturnRemainingDialogState();
}

class _ReturnRemainingDialogState
    extends ConsumerState<_ReturnRemainingDialog> {
  final TextEditingController _weightController = TextEditingController();

  /// `true` once the worker has typed into the field — keeps the dialog from
  /// showing an error the instant it opens (the empty field is "invalid" but
  /// not yet "wrong"). The confirm button is disabled regardless.
  bool _touched = false;

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  double? _parseWeight() => double.tryParse(_weightController.text.trim());

  /// Live validation error (null when valid). Enforces `0 < value <= max`
  /// (handoff: remaining weight must be > 0; 0 is only valid for full consume).
  String? get _error => RemainingWeightValidation.validate(
    _weightController.text,
    maxAllowedKg: widget.maxAllowedKg,
  );

  bool get _canSubmit => _error == null;

  Future<void> _submit() async {
    if (!_canSubmit) {
      setState(() => _touched = true);
      return;
    }
    await ref
        .read(
          previousRollResolutionControllerProvider(widget.shiftLineId).notifier,
        )
        .returnRemaining(_parseWeight()!);
  }

  @override
  Widget build(BuildContext context) {
    final PreviousRollResolutionState state = ref.watch(
      previousRollResolutionControllerProvider(widget.shiftLineId),
    );

    ref.listen<PreviousRollResolutionState>(
      previousRollResolutionControllerProvider(widget.shiftLineId),
      (prev, next) {
        if (next is PreviousRollResolved) {
          Navigator.of(context).pop(next.resolution);
        }
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
        title: const Text(
          _ReturnRemainingDialog.title,
          style: AppTextStyles.h3,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              _ReturnRemainingDialog.body,
              style: AppTextStyles.bodyLarge,
            ),
            const SizedBox(height: 16),
            RemainingWeightField(
              controller: _weightController,
              maxAllowedKg: widget.maxAllowedKg,
              enabled: !resolving,
              errorText: _touched ? _error : null,
              accent: widget.accent,
              onChanged: (_) => setState(() => _touched = true),
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
                  label: _ReturnRemainingDialog.cancel,
                  color: widget.accent,
                  onPressed: resolving
                      ? null
                      : () => Navigator.of(context).pop(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppPrimaryButton(
                  label: _ReturnRemainingDialog.submit,
                  color: widget.accent,
                  isLoading: resolving,
                  onPressed: (resolving || !_canSubmit) ? null : _submit,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
