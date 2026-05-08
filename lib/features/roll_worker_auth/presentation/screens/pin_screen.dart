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
import '../controllers/roll_worker_auth_controller.dart';
import '../controllers/roll_worker_auth_state.dart';
import '../widgets/pin_input.dart';

class PinScreen extends ConsumerStatefulWidget {
  const PinScreen({super.key, required this.shiftLineId});

  final int shiftLineId;

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

  @override
  void dispose() {
    // Defensive: clear the buffer before disposing so PIN material doesn't
    // sit in process memory longer than necessary.
    _pinController.clear();
    _pinController.dispose();
    super.dispose();
  }

  bool get _isAuthenticating {
    final RollWorkerAuthState s = ref.read(
      rollWorkerAuthControllerProvider(widget.shiftLineId),
    );
    return s is RollWorkerAuthAuthenticating;
  }

  void _submit() {
    if (_isAuthenticating) return;
    final String pin = _pinController.text.trim();
    if (pin.isEmpty) return;
    ref
        .read(rollWorkerAuthControllerProvider(widget.shiftLineId).notifier)
        .login(pin);
  }

  @override
  Widget build(BuildContext context) {
    final RollWorkerAuthState authState = ref.watch(
      rollWorkerAuthControllerProvider(widget.shiftLineId),
    );

    final bool authenticating = authState is RollWorkerAuthAuthenticating;
    final AppFailure? failure = switch (authState) {
      RollWorkerAuthUnauthenticated(:final lastFailure) => lastFailure,
      _ => null,
    };
    // Wipe PIN whenever an error surfaces so the worker re-types and the
    // buffer doesn't linger.
    if (failure != null && _pinController.text.isNotEmpty) {
      _pinController.clear();
    }

    final bool isLocked =
        failure is BusinessFailure &&
        failure.code == ErrorCode.operatorPinLocked;
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
