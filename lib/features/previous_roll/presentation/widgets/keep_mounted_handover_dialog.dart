import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/error_messages_ar.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_primary_button.dart';
import '../../../../core/widgets/app_secondary_button.dart';
import '../../../../core/widgets/inline_error.dart';
import '../../data/dto/roll_worker_handover_response.dart';
import '../controllers/keep_mounted_handover_controller.dart';
import '../controllers/keep_mounted_handover_state.dart';
import 'remaining_weight_field.dart';
import 'remaining_weight_validation.dart';

/// Weight prompt for the keep-mounted handover (logout option 1). The leaving
/// worker declares the current remaining weight; they are credited the consumed
/// interval and the roll stays mounted for the next worker. This call ENDS the
/// worker's session — on success the dialog pops with the
/// [RollWorkerHandoverResponse] so the caller can drop the local session and
/// route to the PIN overlay (it must NOT call roll-worker-logout afterwards).
Future<RollWorkerHandoverResponse?> showKeepMountedHandoverDialog(
  BuildContext context, {
  required int shiftLineId,
  double? currentWeightKg,
  Color? accent,
}) {
  return showDialog<RollWorkerHandoverResponse>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) => _KeepMountedHandoverDialog(
      shiftLineId: shiftLineId,
      currentWeightKg: currentWeightKg,
      accent: accent,
    ),
  );
}

class _KeepMountedHandoverDialog extends ConsumerStatefulWidget {
  const _KeepMountedHandoverDialog({
    required this.shiftLineId,
    this.currentWeightKg,
    this.accent,
  });

  final int shiftLineId;
  final double? currentWeightKg;
  final Color? accent;

  static const String title = 'أدخل الوزن الحالي المتبقي على الرول';
  static const String submit = 'تأكيد المغادرة';
  static const String cancel = 'إلغاء';

  @override
  ConsumerState<_KeepMountedHandoverDialog> createState() =>
      _KeepMountedHandoverDialogState();
}

class _KeepMountedHandoverDialogState
    extends ConsumerState<_KeepMountedHandoverDialog> {
  final TextEditingController _weightController = TextEditingController();

  /// `true` once the worker has typed — suppresses an error on first open.
  bool _touched = false;

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  double? _parseWeight() => double.tryParse(_weightController.text.trim());

  /// Live validation error (null when valid). The leaving worker must declare
  /// a remaining weight `> 0` (a finished roll is "استهلاك كامل", not a
  /// keep-mounted handover) that does not exceed the current roll weight.
  String? get _error => RemainingWeightValidation.validate(
    _weightController.text,
    maxAllowedKg: widget.currentWeightKg,
  );

  bool get _canSubmit => _error == null;

  /// `سيتم احتساب الوزن المستهلك لك: {current} − {entered} = {diff} كغ`.
  String? get _consumedHelper {
    final double? current = widget.currentWeightKg;
    final double? entered = _parseWeight();
    if (current == null || entered == null || entered < 0 || entered > current) {
      return null;
    }
    final double diff = current - entered;
    return 'سيتم احتساب الوزن المستهلك لك: '
        '${current.toStringAsFixed(3)} − ${entered.toStringAsFixed(3)} = '
        '${diff.toStringAsFixed(3)} كغ';
  }

  Future<void> _submit() async {
    if (!_canSubmit) {
      setState(() => _touched = true);
      return;
    }
    await ref
        .read(keepMountedHandoverControllerProvider(widget.shiftLineId).notifier)
        .submit(_parseWeight()!);
  }

  @override
  Widget build(BuildContext context) {
    final KeepMountedHandoverState state = ref.watch(
      keepMountedHandoverControllerProvider(widget.shiftLineId),
    );

    ref.listen<KeepMountedHandoverState>(
      keepMountedHandoverControllerProvider(widget.shiftLineId),
      (prev, next) {
        if (next is KeepMountedSucceeded) {
          Navigator.of(context).pop(next.response);
        }
      },
    );

    final bool submitting = state is KeepMountedSubmitting;
    final String? backendError = state is KeepMountedHandoverFailure
        ? arabicMessageFor(state.failure)
        : null;
    final String? helper = _consumedHelper;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          _KeepMountedHandoverDialog.title,
          style: AppTextStyles.h3,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            RemainingWeightField(
              controller: _weightController,
              maxAllowedKg: widget.currentWeightKg,
              enabled: !submitting,
              errorText: _touched ? _error : null,
              accent: widget.accent,
              onChanged: (_) => setState(() => _touched = true),
            ),
            if (helper != null) ...<Widget>[
              const SizedBox(height: 10),
              Text(
                helper,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (backendError != null) ...<Widget>[
              const SizedBox(height: 12),
              InlineError(message: backendError),
            ],
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        actions: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: AppSecondaryButton(
                  label: _KeepMountedHandoverDialog.cancel,
                  color: widget.accent,
                  onPressed: submitting
                      ? null
                      : () => Navigator.of(context).pop(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppPrimaryButton(
                  label: _KeepMountedHandoverDialog.submit,
                  color: widget.accent,
                  isLoading: submitting,
                  onPressed: (submitting || !_canSubmit) ? null : _submit,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
