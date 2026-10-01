import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_primary_button.dart';
import '../../domain/entities/production_time_input.dart';
import '../roll_search_strings.dart';

/// The five numeric fields (سنة، شهر، يوم، ساعة، دقيقة) plus صباحاً / مساء —
/// no date or time picker. The time row reads left to right like the label
/// (`09:14 مساء`); the date row keeps the app's right-to-left order, which
/// shows it as `يوم  شهر  سنة`, again like the label (`dd-MM-yyyy`).
///
/// Built for speed: numeric keyboard, a field's text is selected when it gets
/// focus so typing replaces it, and focus moves on as soon as a field is
/// complete. Errors appear once the worker presses بحث.
class ProductionTimeForm extends StatefulWidget {
  const ProductionTimeForm({
    super.key,
    required this.onSearch,
    this.initialYear,
    this.initialMonth,
    this.isSearching = false,
    this.accent,
  });

  final ValueChanged<ProductionTimeQuery> onSearch;

  /// Prefilled from today's factory date; the day is left for the worker so
  /// an older label is never searched on today's date by accident.
  final int? initialYear;
  final int? initialMonth;

  final bool isSearching;
  final Color? accent;

  @override
  State<ProductionTimeForm> createState() => _ProductionTimeFormState();
}

class _ProductionTimeFormState extends State<ProductionTimeForm> {
  static const List<ProductionTimeField> _order = <ProductionTimeField>[
    ProductionTimeField.year,
    ProductionTimeField.month,
    ProductionTimeField.day,
    ProductionTimeField.hour,
    ProductionTimeField.minute,
  ];

  late final Map<ProductionTimeField, TextEditingController> _text =
      <ProductionTimeField, TextEditingController>{
        for (final ProductionTimeField f in _order) f: TextEditingController(),
      };
  late final Map<ProductionTimeField, FocusNode> _focus =
      <ProductionTimeField, FocusNode>{
        for (final ProductionTimeField f in _order) f: FocusNode(),
      };

  ClockPeriod? _period;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialYear != null) {
      _text[ProductionTimeField.year]!.text = '${widget.initialYear}';
    }
    if (widget.initialMonth != null) {
      _text[ProductionTimeField.month]!.text = '${widget.initialMonth}';
    }
    for (final ProductionTimeField f in _order) {
      _focus[f]!.addListener(() => _selectAllOnFocus(f));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus[_firstEmptyField()]!.requestFocus();
    });
  }

  @override
  void dispose() {
    for (final TextEditingController c in _text.values) {
      c.dispose();
    }
    for (final FocusNode n in _focus.values) {
      n.dispose();
    }
    super.dispose();
  }

  ProductionTimeInput get _input => ProductionTimeInput(
    year: _text[ProductionTimeField.year]!.text,
    month: _text[ProductionTimeField.month]!.text,
    day: _text[ProductionTimeField.day]!.text,
    hour: _text[ProductionTimeField.hour]!.text,
    minute: _text[ProductionTimeField.minute]!.text,
    period: _period,
  );

  ProductionTimeField _firstEmptyField() => _order.firstWhere(
    (ProductionTimeField f) => _text[f]!.text.isEmpty,
    orElse: () => ProductionTimeField.day,
  );

  void _selectAllOnFocus(ProductionTimeField field) {
    if (!_focus[field]!.hasFocus) return;
    final TextEditingController c = _text[field]!;
    c.selection = TextSelection(baseOffset: 0, extentOffset: c.text.length);
  }

  /// Moves on once no further digit could still belong to [field]: the
  /// maximum length is reached, or the first digit already rules out a
  /// second one (month 2–9, day 4–9, hour 2–9).
  void _onChanged(ProductionTimeField field, String value) {
    setState(() {});
    if (value.length >= _maxLength(field) || _completeAtOneDigit(field, value)) {
      final int next = _order.indexOf(field) + 1;
      if (next < _order.length) {
        _focus[_order[next]]!.requestFocus();
      } else {
        _focus[field]!.unfocus();
      }
    }
  }

  static bool _completeAtOneDigit(ProductionTimeField field, String value) {
    if (value.length != 1) return false;
    final int digit = int.parse(value);
    return switch (field) {
      ProductionTimeField.month => digit >= 2,
      ProductionTimeField.day => digit >= 4,
      ProductionTimeField.hour => digit >= 2,
      _ => false,
    };
  }

  static int _maxLength(ProductionTimeField field) =>
      field == ProductionTimeField.year ? 4 : 2;

  void _submit() {
    final ProductionTimeInput input = _input;
    final Map<ProductionTimeField, String> errors = input.validate();
    setState(() => _submitted = true);
    if (errors.isNotEmpty) {
      final ProductionTimeField first = errors.keys.first;
      if (first != ProductionTimeField.period) _focus[first]!.requestFocus();
      return;
    }
    FocusScope.of(context).unfocus();
    widget.onSearch(input.toQuery()!);
  }

  @override
  Widget build(BuildContext context) {
    final Color accent = widget.accent ?? AppColors.primary;
    final ProductionTimeInput input = _input;
    final Map<ProductionTimeField, String> errors = _submitted
        ? input.validate()
        : const <ProductionTimeField, String>{};
    final ({String weekday, String date, String time})? preview = input
        .labelPreview();

    Widget box(ProductionTimeField f, String label, {int flex = 2}) => Expanded(
      flex: flex,
      child: _NumberBox(
        field: f,
        label: label,
        controller: _text[f]!,
        focusNode: _focus[f]!,
        maxLength: _maxLength(f),
        hasError: errors.containsKey(f),
        accent: accent,
        onChanged: (String v) => _onChanged(f, v),
      ),
    );

    return AppCard(
      elevated: true,
      accent: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text(RollSearchStrings.formTitle, style: AppTextStyles.h3),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              box(ProductionTimeField.year, RollSearchStrings.year, flex: 3),
              const SizedBox(width: 8),
              box(ProductionTimeField.month, RollSearchStrings.month),
              const SizedBox(width: 8),
              box(ProductionTimeField.day, RollSearchStrings.day),
            ],
          ),
          const SizedBox(height: 12),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                box(ProductionTimeField.hour, RollSearchStrings.hour),
                const Padding(
                  padding: EdgeInsets.fromLTRB(6, 0, 6, 14),
                  child: Text(':', style: AppTextStyles.h2),
                ),
                box(ProductionTimeField.minute, RollSearchStrings.minute),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: _PeriodToggle(
                    value: _period,
                    hasError: errors.containsKey(ProductionTimeField.period),
                    accent: accent,
                    onChanged: (ClockPeriod p) => setState(() => _period = p),
                  ),
                ),
              ],
            ),
          ),
          if (errors.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              errors.values.first,
              key: const Key('productionTimeForm.error'),
              style: AppTextStyles.errorInline,
            ),
          ],
          if (preview != null) ...<Widget>[
            const SizedBox(height: 12),
            _LabelPreview(preview: preview, accent: accent),
          ],
          const SizedBox(height: 14),
          AppPrimaryButton(
            label: RollSearchStrings.search,
            icon: Icons.search_rounded,
            color: accent,
            isLoading: widget.isSearching,
            onPressed: widget.isSearching ? null : _submit,
          ),
        ],
      ),
    );
  }
}

class _NumberBox extends StatelessWidget {
  const _NumberBox({
    required this.field,
    required this.label,
    required this.controller,
    required this.focusNode,
    required this.maxLength,
    required this.hasError,
    required this.accent,
    required this.onChanged,
  });

  final ProductionTimeField field;
  final String label;
  final TextEditingController controller;
  final FocusNode focusNode;
  final int maxLength;
  final bool hasError;
  final Color accent;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final Color border = hasError ? AppColors.error : AppColors.border;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label,
          textAlign: TextAlign.center,
          textDirection: TextDirection.rtl,
          style: AppTextStyles.caption,
        ),
        const SizedBox(height: 4),
        TextField(
          key: Key('productionTimeForm.${field.name}'),
          controller: controller,
          focusNode: focusNode,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
          maxLength: maxLength,
          cursorColor: accent,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(maxLength),
          ],
          decoration: InputDecoration(
            counterText: '',
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: border, width: hasError ? 2 : 1.2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: hasError ? AppColors.error : accent,
                width: 2,
              ),
            ),
          ),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

/// صباحاً / مساء, stacked, exactly as the label prints them. Nothing is
/// preselected: a wrong half of the day would find a roll twelve hours off.
class _PeriodToggle extends StatelessWidget {
  const _PeriodToggle({
    required this.value,
    required this.hasError,
    required this.accent,
    required this.onChanged,
  });

  final ClockPeriod? value;
  final bool hasError;
  final Color accent;
  final ValueChanged<ClockPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (final ClockPeriod p in ClockPeriod.values) ...<Widget>[
          if (p != ClockPeriod.values.first) const SizedBox(height: 6),
          _PeriodButton(
            period: p,
            selected: value == p,
            hasError: hasError,
            accent: accent,
            onTap: () => onChanged(p),
          ),
        ],
      ],
    );
  }
}

class _PeriodButton extends StatelessWidget {
  const _PeriodButton({
    required this.period,
    required this.selected,
    required this.hasError,
    required this.accent,
    required this.onTap,
  });

  final ClockPeriod period;
  final bool selected;
  final bool hasError;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color border = selected
        ? accent
        : (hasError ? AppColors.error : AppColors.border);
    return Material(
      color: selected ? accent : AppColors.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        key: Key('productionTimeForm.period.${period.name}'),
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: border, width: selected ? 2 : 1.2),
          ),
          child: Text(
            period.labelText,
            textDirection: TextDirection.rtl,
            style: AppTextStyles.button.copyWith(
              color: selected ? AppColors.textOnPrimary : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

/// The entered minute as the sticker shows it, for a last visual check.
class _LabelPreview extends StatelessWidget {
  const _LabelPreview({required this.preview, required this.accent});

  final ({String weekday, String date, String time}) preview;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.label_outline_rounded, size: 20, color: accent),
          const SizedBox(width: 8),
          const Text('${RollSearchStrings.onLabel}:', style: AppTextStyles.label),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${preview.weekday}  ${preview.date}  ${preview.time}',
              key: const Key('productionTimeForm.labelPreview'),
              style: AppTextStyles.bodyLarge.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
