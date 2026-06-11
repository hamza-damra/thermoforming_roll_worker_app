import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/error_messages_ar.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_primary_button.dart';
import '../../../../core/widgets/app_secondary_button.dart';
import '../../../../core/widgets/directional_chevron.dart';
import '../../../../core/widgets/inline_error.dart';
import '../../../previous_roll/presentation/widgets/remaining_weight_field.dart';
import '../../../previous_roll/presentation/widgets/remaining_weight_validation.dart';
import '../../domain/entities/roll_worker_takeover.dart';
import '../controllers/takeover_controller.dart';
import '../controllers/takeover_state.dart';

/// In-place takeover screen (V104). Shown by [RollWorkerAuthOverlay] when
/// login returns `ROLL_WORKER_TAKEOVER_REQUIRED`, replacing the PIN card on the
/// same dimmed backdrop. Offers exactly two resolutions; "remains mounted"
/// prompts for the current physical weight. The consumed weight is credited to
/// the PREVIOUS worker — never the incoming declarer.
class RollWorkerTakeoverCard extends ConsumerStatefulWidget {
  const RollWorkerTakeoverCard({
    super.key,
    required this.shiftLineId,
    required this.accentColor,
    required this.details,
    required this.pin,
    required this.onCancel,
  });

  final int shiftLineId;
  final Color accentColor;
  final RollWorkerTakeoverRequiredDetails details;

  /// The incoming worker's PIN, captured at the failed login.
  final String pin;

  /// Returns the overlay to the PIN card.
  final VoidCallback onCancel;

  static const String subtitle = 'الرجاء تحديد حالة الرول الحالية';
  static const String creditNote =
      'الوزن المستهلك سيُحتسب للموظف السابق، وليس لك.';
  static const String optionFullConsume = 'استهلاك كامل وإنزال الرول';
  static const String optionRemainsMounted = 'الرول ما زال مركب';
  static const String weightPromptTitle =
      'أدخل الوزن الحالي الموجود فعلياً على الرول';
  static const String cancel = 'إلغاء';
  static const String back = 'رجوع';
  static const String confirm = 'تأكيد';

  @override
  ConsumerState<RollWorkerTakeoverCard> createState() =>
      _RollWorkerTakeoverCardState();
}

enum _Step { choose, weight }

class _RollWorkerTakeoverCardState
    extends ConsumerState<RollWorkerTakeoverCard> {
  final TextEditingController _weightController = TextEditingController();
  _Step _step = _Step.choose;

  /// `true` once the worker has typed in the weight step — suppresses an
  /// error the instant the step opens.
  bool _touched = false;

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  double? get _maxWeight => widget.details.lastKnownWeightKg;

  double? _parseWeight() => double.tryParse(_weightController.text.trim());

  /// Live validation for the "remains mounted" declared weight. The new
  /// worker keeps the roll mounted only when it still has material, so the
  /// weight must be `> 0` (a finished roll is "استهلاك كامل") and not exceed
  /// the last known weight.
  String? get _weightError => RemainingWeightValidation.validate(
    _weightController.text,
    maxAllowedKg: _maxWeight,
  );

  bool get _canSubmitWeight => _weightError == null;

  void _submitFullConsume() {
    ref
        .read(takeoverControllerProvider(widget.shiftLineId).notifier)
        .submit(
          action: RollWorkerTakeoverAction.fullConsumptionAndClose,
          pin: widget.pin,
        );
  }

  void _submitRemainsMounted() {
    if (!_canSubmitWeight) {
      setState(() => _touched = true);
      return;
    }
    ref
        .read(takeoverControllerProvider(widget.shiftLineId).notifier)
        .submit(
          action: RollWorkerTakeoverAction.rollRemainsMounted,
          pin: widget.pin,
          currentWeightKg: _parseWeight(),
        );
  }

  void _cancel() {
    ref.read(takeoverControllerProvider(widget.shiftLineId).notifier).cancel();
    widget.onCancel();
  }

  String get _title {
    final String name = widget.details.previousWorkerName.trim();
    final String who = name.isEmpty ? 'الموظف السابق' : name;
    return 'يوجد رول مركب لم يتم إنزاله من: $who';
  }

  String? get _contextLine {
    final double? w = widget.details.lastKnownWeightKg;
    final String? roll = widget.details.generatedRollId;
    final List<String> parts = <String>[
      if (w != null) 'الوزن المسجّل: ${w.toStringAsFixed(3)} كغ',
      if (roll != null) 'الرول: $roll',
    ];
    return parts.isEmpty ? null : parts.join(' — ');
  }

  @override
  Widget build(BuildContext context) {
    final TakeoverState state = ref.watch(
      takeoverControllerProvider(widget.shiftLineId),
    );
    final bool submitting = state is TakeoverSubmitting;
    final String? backendError = state is TakeoverFailureState
        ? arabicMessageFor(state.failure)
        : null;
    final Color accent = widget.accentColor;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: PopScope(
        canPop: false,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {},
          child: Container(
            color: Colors.black.withValues(alpha: 0.45),
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 24,
                ),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 420),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: accent.withValues(alpha: 0.22),
                        blurRadius: 26,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withValues(alpha: 0.14),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.swap_horiz_rounded,
                              color: AppColors.warning,
                              size: 36,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _title,
                          style: AppTextStyles.h3,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          RollWorkerTakeoverCard.subtitle,
                          style: AppTextStyles.body,
                          textAlign: TextAlign.center,
                        ),
                        if (_contextLine != null) ...<Widget>[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceMuted,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _contextLine!,
                              style: AppTextStyles.caption,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        _CreditNote(),
                        const SizedBox(height: 18),
                        if (_step == _Step.choose)
                          ..._buildChoose(submitting, accent)
                        else
                          ..._buildWeight(submitting, accent),
                        if (backendError != null) ...<Widget>[
                          const SizedBox(height: 12),
                          InlineError(message: backendError),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildChoose(bool submitting, Color accent) {
    return <Widget>[
      _ChoiceTile(
        icon: Icons.check_circle_outline_rounded,
        label: RollWorkerTakeoverCard.optionFullConsume,
        color: accent,
        enabled: !submitting,
        onTap: _submitFullConsume,
      ),
      const SizedBox(height: 10),
      _ChoiceTile(
        icon: Icons.layers_outlined,
        label: RollWorkerTakeoverCard.optionRemainsMounted,
        color: accent,
        enabled: !submitting,
        onTap: () => setState(() {
          _step = _Step.weight;
          _touched = false;
        }),
      ),
      const SizedBox(height: 14),
      AppSecondaryButton(
        label: RollWorkerTakeoverCard.cancel,
        color: accent,
        onPressed: submitting ? null : _cancel,
      ),
      if (submitting) ...<Widget>[
        const SizedBox(height: 12),
        Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: accent),
          ),
        ),
      ],
    ];
  }

  List<Widget> _buildWeight(bool submitting, Color accent) {
    return <Widget>[
      const Text(
        RollWorkerTakeoverCard.weightPromptTitle,
        style: AppTextStyles.label,
      ),
      const SizedBox(height: 8),
      RemainingWeightField(
        controller: _weightController,
        maxAllowedKg: _maxWeight,
        enabled: !submitting,
        errorText: _touched ? _weightError : null,
        accent: accent,
        onChanged: (_) => setState(() => _touched = true),
      ),
      const SizedBox(height: 16),
      Row(
        children: <Widget>[
          Expanded(
            child: AppSecondaryButton(
              label: RollWorkerTakeoverCard.back,
              color: accent,
              onPressed: submitting
                  ? null
                  : () => setState(() {
                      _step = _Step.choose;
                      _touched = false;
                    }),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: AppPrimaryButton(
              label: RollWorkerTakeoverCard.confirm,
              color: accent,
              isLoading: submitting,
              onPressed: (submitting || !_canSubmitWeight)
                  ? null
                  : _submitRemainsMounted,
            ),
          ),
        ],
      ),
    ];
  }
}

class _CreditNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.30)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: AppColors.warning,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              RollWorkerTakeoverCard.creditNote,
              style: AppTextStyles.caption.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
    required this.enabled,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(
              color: enabled ? color : AppColors.border,
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: <Widget>[
              Icon(icon, size: 24, color: enabled ? color : AppColors.border),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const DirectionalChevron(),
            ],
          ),
        ),
      ),
    );
  }
}
