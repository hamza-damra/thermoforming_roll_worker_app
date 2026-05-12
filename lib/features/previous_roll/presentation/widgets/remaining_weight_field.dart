import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Numeric weight input shared by the return-remaining and grinding
/// dialogs. Accepts up to 3 decimal places. Validation (`>= 0` and
/// `<= maxAllowedKg`) is owned by the dialog; this widget just emits the
/// raw text.
class RemainingWeightField extends StatelessWidget {
  const RemainingWeightField({
    super.key,
    required this.controller,
    this.maxAllowedKg,
    this.enabled = true,
    this.errorText,
    this.onChanged,
  });

  final TextEditingController controller;
  final double? maxAllowedKg;
  final bool enabled;
  final String? errorText;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(label, style: AppTextStyles.label),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          enabled: enabled,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: false,
          ),
          textInputAction: TextInputAction.done,
          inputFormatters: <TextInputFormatter>[
            // Allow digits and a single dot, up to 3 fractional digits.
            FilteringTextInputFormatter.allow(RegExp(r'^\d{0,5}(\.\d{0,3})?')),
          ],
          textAlign: TextAlign.center,
          style: AppTextStyles.h3,
          decoration: InputDecoration(
            hintText: hint,
            suffixText: 'كغ',
            errorText: errorText,
            prefixIcon: const Icon(
              Icons.scale_rounded,
              color: AppColors.primary,
            ),
          ),
          onChanged: onChanged,
        ),
        const SizedBox(height: 6),
        if (maxAllowedKg != null)
          Text(
            'الحد الأقصى: ${maxAllowedKg!.toStringAsFixed(3)} كغ',
            style: AppTextStyles.caption,
          ),
      ],
    );
  }

  // Prescribed Arabic copy.
  static const String label = 'الوزن المتبقي';
  static const String hint = 'أدخل الوزن المتبقي بالكيلو';
}
