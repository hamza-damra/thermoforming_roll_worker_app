import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Numeric PIN entry field. Stage 3 accepts any non-empty digit string;
/// the backend is the source of truth for PIN validity.
class PinInput extends StatefulWidget {
  const PinInput({
    super.key,
    required this.controller,
    required this.enabled,
    this.maxLength = 6,
    this.autofocus = true,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final bool enabled;
  final int maxLength;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;

  @override
  State<PinInput> createState() => _PinInputState();
}

class _PinInputState extends State<PinInput> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      enabled: widget.enabled,
      autofocus: widget.autofocus,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.done,
      obscureText: _obscure,
      maxLength: widget.maxLength,
      style: AppTextStyles.h3.copyWith(
        letterSpacing: 8,
        color: AppColors.textPrimary,
      ),
      textAlign: TextAlign.center,
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.digitsOnly,
      ],
      onSubmitted: widget.onSubmitted,
      decoration: InputDecoration(
        hintText: '••••',
        counterText: '',
        prefixIcon: const Icon(Icons.lock_rounded, color: AppColors.primary),
        suffixIcon: IconButton(
          tooltip: _obscure ? 'إظهار' : 'إخفاء',
          icon: Icon(
            _obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded,
            color: AppColors.textSecondary,
          ),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
    );
  }
}
