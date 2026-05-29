import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/errors/error_code.dart';
import '../../../../core/errors/error_messages_ar.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../controllers/batch_auth_controller.dart';
import '../controllers/batch_auth_state.dart';

/// Blocking, in-place roll-worker PIN overlay.
///
/// Rendered as a `Positioned.fill` child of the per-machine dashboard
/// `Stack` (never `showDialog`) so the dimmed machine dashboard stays
/// visible behind it — the same pattern as the reference Palletizing app's
/// `PalletizerPinScreen`. Shown when a machine is selectable but the worker
/// has no session for it.
///
/// Business logic is unchanged: it submits a single-line batch via
/// [BatchAuthController.submit] (`{shiftLineId}`) and closes itself simply by
/// being removed from the tree once the registry flips to an active session
/// for this line.
class RollWorkerAuthOverlay extends ConsumerStatefulWidget {
  const RollWorkerAuthOverlay({
    super.key,
    required this.shiftLineId,
    required this.accentColor,
  });

  final int shiftLineId;
  final Color accentColor;

  static const String title = 'تسجيل دخول عامل الرولات';
  static const String helper = 'سجّل دخولك كموظف رولات للبدء بتركيب الرول';
  static const String submitLabel = 'دخول';
  static const int pinLength = 4;

  // Specific copy that beats the generic mapped message.
  static const String lockedHelper =
      'تم قفل الحساب لعدد كبير من المحاولات الخاطئة. يرجى مراجعة المشرف.';
  static const String unauthorizedHelper =
      'هذا الموظف غير مخوّل للعمل كموظف رولات.';

  @override
  ConsumerState<RollWorkerAuthOverlay> createState() =>
      _RollWorkerAuthOverlayState();
}

class _RollWorkerAuthOverlayState
    extends ConsumerState<RollWorkerAuthOverlay> {
  final TextEditingController _pinController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  /// Local, per-overlay flags so a shared (global) [BatchAuthController]
  /// can drive several overlays without cross-talk: only the overlay that
  /// initiated a submit reacts to the result.
  bool _submitting = false;
  String? _error;
  bool _locked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Start from a clean controller so a prior line's failure never
      // pre-flashes on this overlay.
      ref.read(batchAuthControllerProvider.notifier).reset();
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _pinController.clear();
    _pinController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    if (_submitting || _locked) return;
    final String pin = _pinController.text.trim();
    if (pin.length != RollWorkerAuthOverlay.pinLength) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    ref
        .read(batchAuthControllerProvider.notifier)
        .submit(pin, <int>{widget.shiftLineId});
  }

  void _onAuthStateChanged(BatchAuthState? prev, BatchAuthState next) {
    // Only the overlay that submitted should react — guards against the
    // off-screen (kept-alive) sibling tab's overlay reacting to the same
    // shared controller.
    if (!_submitting) return;
    switch (next) {
      case BatchAuthSuccess():
        // Registry now holds a session for this line; the parent tab will
        // rebuild into the live dashboard and remove this overlay. Reset the
        // shared controller so the next machine's overlay starts clean.
        _submitting = false;
        ref.read(batchAuthControllerProvider.notifier).reset();
      case BatchAuthFailure(:final AppFailure failure):
        _pinController.clear();
        final String message = _messageFor(failure);
        // Clear the shared failure so a sibling overlay doesn't inherit it.
        ref.read(batchAuthControllerProvider.notifier).reset();
        if (!mounted) return;
        setState(() {
          _submitting = false;
          _error = message;
          _locked = _isLocked(failure);
        });
        if (!_locked) _focusNode.requestFocus();
      case BatchAuthInitial():
      case BatchAuthSubmitting():
        break;
    }
  }

  bool _isLocked(AppFailure failure) =>
      failure is BusinessFailure &&
      (failure.code == ErrorCode.operatorPinLocked ||
          failure.code == ErrorCode.operatorLocked);

  String _messageFor(AppFailure failure) {
    if (failure is BusinessFailure) {
      if (failure.code == ErrorCode.rollWorkerNotAllowed) {
        return RollWorkerAuthOverlay.unauthorizedHelper;
      }
      if (_isLocked(failure)) return RollWorkerAuthOverlay.lockedHelper;
    }
    return arabicMessageFor(failure);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<BatchAuthState>(batchAuthControllerProvider, _onAuthStateChanged);
    final Color accent = widget.accentColor;
    final bool canSubmit =
        !_submitting &&
        !_locked &&
        _pinController.text.trim().length == RollWorkerAuthOverlay.pinLength;

    return PopScope(
      canPop: false,
      child: GestureDetector(
        // Absorb taps on the dimmed background — no outside dismiss.
        behavior: HitTestBehavior.opaque,
        onTap: () {},
        child: Container(
          color: Colors.black.withValues(alpha: 0.45),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 380),
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
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.badge_rounded,
                          color: accent,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        RollWorkerAuthOverlay.title,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.h2,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        RollWorkerAuthOverlay.helper,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _PinField(
                        controller: _pinController,
                        focusNode: _focusNode,
                        accent: accent,
                        enabled: !_submitting && !_locked,
                        hasError: _error != null,
                        onChanged: () {
                          if (_error != null) {
                            setState(() => _error = null);
                          } else {
                            setState(() {}); // refresh the submit-enabled state
                          }
                        },
                        onSubmitted: _submit,
                      ),
                      if (_error != null) ...<Widget>[
                        const SizedBox(height: 12),
                        _ErrorBox(message: _error!),
                      ],
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: canSubmit ? _submit : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accent,
                            disabledBackgroundColor:
                                accent.withValues(alpha: 0.4),
                            foregroundColor: AppColors.textOnPrimary,
                            minimumSize: const Size.fromHeight(56),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: _submitting
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      AppColors.textOnPrimary,
                                    ),
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    Icon(Icons.login_rounded, size: 22),
                                    SizedBox(width: 10),
                                    Text(
                                      RollWorkerAuthOverlay.submitLabel,
                                      style: AppTextStyles.button,
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 4-digit obscured numeric PIN field styled with the machine accent.
class _PinField extends StatelessWidget {
  const _PinField({
    required this.controller,
    required this.focusNode,
    required this.accent,
    required this.enabled,
    required this.hasError,
    required this.onChanged,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final Color accent;
  final bool enabled;
  final bool hasError;
  final VoidCallback onChanged;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    final Color borderColor = hasError ? AppColors.error : AppColors.border;
    return TextField(
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      autofocus: true,
      textAlign: TextAlign.center,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.done,
      obscureText: true,
      maxLength: RollWorkerAuthOverlay.pinLength,
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(RollWorkerAuthOverlay.pinLength),
      ],
      style: AppTextStyles.h1.copyWith(letterSpacing: 14, color: accent),
      decoration: InputDecoration(
        counterText: '',
        hintText: '● ● ● ●',
        hintStyle: const TextStyle(
          color: AppColors.border,
          letterSpacing: 8,
          fontSize: 22,
        ),
        filled: true,
        fillColor: AppColors.surfaceMuted,
        contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: hasError ? AppColors.error : accent,
            width: 2,
          ),
        ),
      ),
      onChanged: (_) => onChanged(),
      onSubmitted: (_) => onSubmitted(),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.errorBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.error_outline_rounded, size: 20, color: AppColors.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.errorInline,
              textAlign: TextAlign.start,
            ),
          ),
        ],
      ),
    );
  }
}
