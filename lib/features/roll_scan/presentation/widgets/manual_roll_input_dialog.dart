import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_primary_button.dart';
import '../../../../core/widgets/app_secondary_button.dart';
import '../../../../core/widgets/inline_error.dart';
import '../controllers/roll_scan_controller.dart';

/// Manual fallback for entering a 12-digit `generatedRollId` when the
/// camera cannot read the QR (per requirements §9).
///
/// Returns the validated 12-digit string when confirmed, or `null` if the
/// worker cancelled. Validation is purely format-level — the backend remains
/// the source of truth for whether the roll exists / is mountable.
Future<String?> showManualRollInputDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) => const _ManualRollInputDialog(),
  );
}

class _ManualRollInputDialog extends StatefulWidget {
  const _ManualRollInputDialog();

  @override
  State<_ManualRollInputDialog> createState() => _ManualRollInputDialogState();
}

class _ManualRollInputDialogState extends State<_ManualRollInputDialog> {
  static const String _title = 'إدخال رقم الرول';
  static const String _hint = '٠٠٠٠٠٠٠٠٠٠٠٠';
  static const String _formatHint = 'يجب أن يتكون رقم الرول من 12 رقمًا';
  static const String _submit = 'تركيب الرول';
  static const String _cancel = 'إلغاء';
  static const String _formatError = 'الرجاء إدخال 12 رقمًا بالضبط';

  final TextEditingController _controller = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _controller.clear();
    _controller.dispose();
    super.dispose();
  }

  void _onSubmit() {
    final String text = _controller.text.trim();
    if (!RollScanController.isValidGeneratedRollId(text)) {
      setState(() => _errorText = _formatError);
      return;
    }
    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
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
            const Text(_formatHint, style: AppTextStyles.label),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              maxLength: 12,
              style: AppTextStyles.h3.copyWith(letterSpacing: 4),
              textAlign: TextAlign.center,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
              ],
              decoration: const InputDecoration(
                hintText: _hint,
                counterText: '',
                prefixIcon: Icon(
                  Icons.qr_code_rounded,
                  color: AppColors.primary,
                ),
              ),
              onSubmitted: (_) => _onSubmit(),
              onChanged: (_) {
                if (_errorText != null) setState(() => _errorText = null);
              },
            ),
            if (_errorText != null) ...[
              const SizedBox(height: 12),
              InlineError(message: _errorText!),
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
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppPrimaryButton(
                  label: _submit,
                  icon: Icons.check_rounded,
                  onPressed: _onSubmit,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
