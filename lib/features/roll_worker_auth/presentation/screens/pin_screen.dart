import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/errors/error_code.dart';
import '../../../../core/errors/error_messages_ar.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_primary_button.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/inline_error.dart';
import '../controllers/batch_auth_controller.dart';
import '../controllers/batch_auth_state.dart';
import '../widgets/pin_input.dart';

/// Multi-line batch session-start PIN entry.
///
/// Pushed onto the navigator from the picker with the worker's selected
/// `shiftLineIds`. Submits PIN exactly once for the whole batch via
/// [BatchAuthController]. On per-line conflict codes, pops back to the
/// picker so the picker can drop offending ids and let the worker retry;
/// on global codes (`OPERATOR_PIN_INVALID`, `OPERATOR_LOCKED`,
/// `ROLL_WORKER_NOT_ALLOWED`, `ROLL_WORKER_SESSION_BATCH_EMPTY`) shows
/// inline error and stays.
class PinScreen extends ConsumerStatefulWidget {
  const PinScreen({super.key, required this.shiftLineIds});

  final Set<int> shiftLineIds;

  static const String title = 'تسجيل دخول عامل الرولات';
  static const String submitLabel = 'دخول';
  static const String pinLabel = 'أدخل رقم PIN الخاص بك';
  static const String pinLockedHelper =
      'تم قفل رقم التعريف بسبب محاولات خاطئة، حاول لاحقًا.';
  static const String unauthorizedHelper =
      'هذا الموظف غير مصرح له كتطبيق عامل الرولات';

  @override
  ConsumerState<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends ConsumerState<PinScreen> {
  final TextEditingController _pinController = TextEditingController();

  static const Set<ErrorCode> _perLineCodes = <ErrorCode>{
    ErrorCode.thermoformingShiftLineNotFound,
    ErrorCode.rollWorkerSessionLineInactive,
    ErrorCode.rollWorkerSessionLineUsedByOtherWorker,
    ErrorCode.rollWorkerSessionLineDuplicate,
  };

  @override
  void dispose() {
    // Defensive: clear the buffer before disposing so PIN material doesn't
    // sit in process memory longer than necessary.
    _pinController.clear();
    _pinController.dispose();
    super.dispose();
  }

  void _submit() {
    final BatchAuthState s = ref.read(batchAuthControllerProvider);
    if (s is BatchAuthSubmitting) return;
    final String pin = _pinController.text.trim();
    if (pin.isEmpty) return;
    ref
        .read(batchAuthControllerProvider.notifier)
        .submit(pin, widget.shiftLineIds);
  }

  void _onAuthStateChanged(BatchAuthState? prev, BatchAuthState next) {
    // Success: registry has been seeded; pop so the bootstrap re-renders
    // into the multi-line home.
    if (next is BatchAuthSuccess) {
      Navigator.of(context).maybePop();
      return;
    }
    // Per-line conflict: pop so the picker can drop the offending ids and
    // re-render with a highlight.
    if (next is BatchAuthFailure &&
        next.failure is BusinessFailure &&
        _perLineCodes.contains((next.failure as BusinessFailure).code)) {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<BatchAuthState>(
      batchAuthControllerProvider,
      _onAuthStateChanged,
    );
    final BatchAuthState authState = ref.watch(batchAuthControllerProvider);

    final bool authenticating = authState is BatchAuthSubmitting;
    final AppFailure? failure = authState is BatchAuthFailure
        ? authState.failure
        : null;
    // Wipe PIN whenever an error surfaces so the worker re-types and the
    // buffer doesn't linger.
    if (failure != null && _pinController.text.isNotEmpty) {
      _pinController.clear();
    }

    final bool isLocked =
        failure is BusinessFailure &&
        (failure.code == ErrorCode.operatorPinLocked ||
            failure.code == ErrorCode.operatorLocked);
    final bool isUnauthorized =
        failure is BusinessFailure &&
        failure.code == ErrorCode.rollWorkerNotAllowed;

    return AppScaffold(
      title: PinScreen.title,
      body: ListView(
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 88,
              height: 88,
              decoration: const BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.badge_rounded,
                size: 44,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            PinScreen.title,
            style: AppTextStyles.h2,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(PinScreen.pinLabel, style: AppTextStyles.label),
                const SizedBox(height: 12),
                PinInput(
                  controller: _pinController,
                  enabled: !authenticating && !isLocked,
                  onSubmitted: (_) => _submit(),
                ),
                if (failure != null) ...[
                  const SizedBox(height: 12),
                  InlineError(
                    message: isUnauthorized
                        ? PinScreen.unauthorizedHelper
                        : isLocked
                        ? PinScreen.pinLockedHelper
                        : arabicMessageFor(failure),
                  ),
                ],
                const SizedBox(height: 16),
                AppPrimaryButton(
                  label: PinScreen.submitLabel,
                  icon: Icons.login_rounded,
                  isLoading: authenticating,
                  onPressed: (authenticating || isLocked) ? null : _submit,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
