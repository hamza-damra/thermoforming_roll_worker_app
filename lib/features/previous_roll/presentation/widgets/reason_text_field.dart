import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import 'reason_text_validation.dart';

/// Required multiline reason input shared by the return-remaining and grinding
/// dialogs (V127). The [label] differs per action
/// (`سبب إرجاع المتبقي` / `سبب التوصية بالجرش`), so callers pass it in.
///
/// Caps input at [ReasonTextValidation.maxLength] characters and renders a
/// visible `current / max` counter. Validation (required, non-blank, ≤ max) is
/// owned by the dialog; this widget just emits the raw text and shows the
/// dialog-provided [errorText].
class ReasonTextField extends StatelessWidget {
  const ReasonTextField({
    super.key,
    required this.controller,
    required this.label,
    this.enabled = true,
    this.errorText,
    this.onChanged,
    this.accent,
  });

  final TextEditingController controller;

  /// Field label, e.g. `سبب إرجاع المتبقي` or `سبب التوصية بالجرش`.
  final String label;
  final bool enabled;
  final String? errorText;
  final ValueChanged<String>? onChanged;

  /// Active line accent for the focused border. Falls back to brand primary.
  final Color? accent;

  static const String hint = 'اكتب السبب هنا';

  @override
  Widget build(BuildContext context) {
    final Color color = accent ?? AppColors.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(label, style: AppTextStyles.label),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          enabled: enabled,
          minLines: 2,
          maxLines: 4,
          maxLength: ReasonTextValidation.maxLength,
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          textAlignVertical: TextAlignVertical.top,
          style: AppTextStyles.body,
          // Render the counter as a plain "current / max" so it stays
          // test-findable and reads naturally in Arabic ("0 / 500").
          buildCounter:
              (
                BuildContext context, {
                required int currentLength,
                required bool isFocused,
                int? maxLength,
              }) => Text(
                '$currentLength / ${maxLength ?? ReasonTextValidation.maxLength}',
                style: AppTextStyles.caption,
              ),
          decoration: InputDecoration(
            hintText: hint,
            errorText: errorText,
            alignLabelWithHint: true,
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: color, width: 1.5),
            ),
          ),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
