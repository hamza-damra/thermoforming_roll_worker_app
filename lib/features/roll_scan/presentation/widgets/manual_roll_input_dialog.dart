import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_primary_button.dart';
import '../../../../core/widgets/app_secondary_button.dart';
import '../controllers/roll_scan_controller.dart';

/// Manual fallback for entering a 12-digit `generatedRollId` when the
/// camera cannot read the QR (per requirements §9).
///
/// Returns the validated 12-digit string when confirmed, or `null` if the
/// worker cancelled. Validation is purely format-level — the backend remains
/// the source of truth for whether the roll exists / is mountable.
Future<String?> showManualRollInputDialog(
  BuildContext context, {
  Color? accent,
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) => _ManualRollInputDialog(accent: accent),
  );
}

class _ManualRollInputDialog extends StatefulWidget {
  const _ManualRollInputDialog({this.accent});

  /// Active line accent — tints the QR icon, the focused input border, the
  /// cursor and the confirm button. Falls back to the brand primary when null.
  final Color? accent;

  @override
  State<_ManualRollInputDialog> createState() => _ManualRollInputDialogState();
}

class _ManualRollInputDialogState extends State<_ManualRollInputDialog> {
  static const int _digits = 12;
  static const String _title = 'إدخال رقم الرول';
  // A clear example, NOT a row of dots — styled faint via the hint style.
  static const String _hint = 'مثال: 018000000004';
  static const String _formatHint = 'يجب أن يتكون رقم الرول من 12 رقمًا';
  static const String _submit = 'تركيب الرول';
  static const String _cancel = 'إلغاء';

  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.clear();
    _controller.dispose();
    super.dispose();
  }

  /// Trimmed current value — digits only by construction (input formatter).
  String get _value => _controller.text.trim();

  bool get _canSubmit => RollScanController.isValidGeneratedRollId(_value);

  void _onSubmit() {
    if (!_canSubmit) return;
    Navigator.of(context).pop(_value);
  }

  @override
  Widget build(BuildContext context) {
    final Color accent = widget.accent ?? AppColors.primary;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(_title, style: AppTextStyles.h3),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text(_formatHint, style: AppTextStyles.label),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              maxLength: _digits,
              // Numeric value reads LTR even inside the RTL dialog; centered
              // and large for factory-floor legibility.
              textAlign: TextAlign.center,
              textDirection: TextDirection.ltr,
              showCursor: true,
              cursorWidth: 2.5,
              cursorColor: accent,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                letterSpacing: 3,
                color: AppColors.textPrimary,
              ),
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(_digits),
              ],
              decoration: InputDecoration(
                hintText: _hint,
                hintStyle: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary.withValues(alpha: 0.5),
                  letterSpacing: 2,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 18,
                  horizontal: 12,
                ),
                prefixIcon: Icon(Icons.qr_code_rounded, color: accent),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.border,
                    width: 1.2,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: accent, width: 2),
                ),
              ),
              // Clean "8/12" counter instead of the default Material counter.
              buildCounter:
                  (
                    BuildContext context, {
                    required int currentLength,
                    required bool isFocused,
                    int? maxLength,
                  }) => Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '$currentLength/$maxLength',
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.ltr,
                      style: AppTextStyles.caption.copyWith(
                        color: currentLength == maxLength
                            ? accent
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _onSubmit(),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        actions: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: AppSecondaryButton(
                  label: _cancel,
                  color: accent,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                // No leading icon: the icon + the half-width Expanded cell
                // squeezed the Arabic label into an ellipsis ("تركيب…"). Text
                // alone renders the full "تركيب الرول". Disabled until exactly
                // 12 digits are entered.
                child: AppPrimaryButton(
                  label: _submit,
                  color: accent,
                  onPressed: _canSubmit ? _onSubmit : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
