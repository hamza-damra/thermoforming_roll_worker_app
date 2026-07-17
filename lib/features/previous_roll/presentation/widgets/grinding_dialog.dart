import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/errors/error_code.dart';
import '../../../../core/errors/error_messages_ar.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_primary_button.dart';
import '../../../../core/widgets/app_secondary_button.dart';
import '../../../../core/widgets/inline_error.dart';
import '../../domain/entities/previous_roll_resolution.dart';
import '../controllers/previous_roll_resolution_controller.dart';
import '../controllers/previous_roll_resolution_state.dart';
import 'reason_text_field.dart';
import 'reason_text_validation.dart';
import 'remaining_weight_field.dart';
import 'remaining_weight_validation.dart';

/// Numeric input + confirm dialog for sending the remainder of a partial
/// roll to the grinding station. Adds an extra warning per requirements §10
/// because the action is not reversible from the worker's side.
/// Resolves to the [PreviousRollResolution] when the grinding close succeeded
/// (the logout flow uses it to print the remainder label, then log out), or
/// `null` on cancel.
Future<PreviousRollResolution?> showGrindingDialog(
  BuildContext context, {
  required int shiftLineId,
  double? maxAllowedKg,
  Color? accent,
}) {
  return showDialog<PreviousRollResolution>(
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

  /// Extra warning per requirements §10 — grinding is not reversible from the
  /// worker's side.
  static const String warning =
      'سيتم إرسال هذه البقايا إلى خط الجرش، هل أنت متأكد؟';
  static const String reasonLabel = 'سبب التوصية بالجرش';

  @override
  ConsumerState<_GrindingDialog> createState() => _GrindingDialogState();
}

class _GrindingDialogState extends ConsumerState<_GrindingDialog> {
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();

  /// `true` once the worker has typed — suppresses an error on first open.
  bool _touched = false;
  bool _reasonTouched = false;

  @override
  void dispose() {
    _weightController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  double? _parseWeight() => double.tryParse(_weightController.text.trim());

  /// Live validation error (null when valid). Enforces `0 < value <= max`.
  String? get _error => RemainingWeightValidation.validate(
    _weightController.text,
    maxAllowedKg: widget.maxAllowedKg,
  );

  /// Live reason validation (required, non-blank, ≤ 500 chars).
  String? get _reasonError =>
      ReasonTextValidation.validate(_reasonController.text);

  bool get _canSubmit => _error == null && _reasonError == null;

  Future<void> _submit() async {
    if (!_canSubmit) {
      setState(() {
        _touched = true;
        _reasonTouched = true;
      });
      return;
    }
    await ref
        .read(
          previousRollResolutionControllerProvider(widget.shiftLineId).notifier,
        )
        .sendToGrinding(_parseWeight()!, _reasonController.text.trim());
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
    final AppFailure? failure = state is PreviousRollFailureState
        ? state.failure
        : null;
    final bool reasonBackendError =
        failure is BusinessFailure &&
        failure.code == ErrorCode.rollGrindingReasonRequired;
    final String? backendError = failure != null
        ? arabicMessageFor(failure)
        : null;
    // Client-side error (once touched) takes precedence; otherwise surface a
    // blank-reason rejection from the backend even when the field looks valid.
    final String? clientReasonError = _reasonTouched ? _reasonError : null;
    final String? reasonErrorText =
        clientReasonError ?? (reasonBackendError ? backendError : null);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        scrollable: true,
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(_GrindingDialog.title, style: AppTextStyles.h3),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(_GrindingDialog.body, style: AppTextStyles.bodyLarge),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 18,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _GrindingDialog.warning,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.warning,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
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
            const SizedBox(height: 16),
            ReasonTextField(
              controller: _reasonController,
              label: _GrindingDialog.reasonLabel,
              enabled: !resolving,
              errorText: reasonErrorText,
              accent: widget.accent,
              onChanged: (_) => setState(() => _reasonTouched = true),
            ),
            if (backendError != null && !reasonBackendError) ...[
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
