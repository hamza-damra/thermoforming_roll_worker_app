import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/biometric_denial.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_primary_button.dart';
import '../../../../core/widgets/app_secondary_button.dart';
import '../../../roll_worker_auth/domain/session_batch_repository.dart';
import '../../data/biometric_login_providers.dart';
import '../controllers/biometric_login_attempt_controller.dart';
import '../controllers/biometric_poll_config.dart';
import 'biometric_login_strings.dart';

/// Opens the fingerprint dialog for a login the biometric gate refused.
///
/// Completes with the login outcome to apply once the dialog closes — the
/// resubmitted login's success or non-biometric failure, or a contact-admin
/// failure — or null when the worker tapped «إلغاء».
///
/// Modal: no outside-tap dismiss, no back button, and no way around the check
/// (handoff §3) — the only exits are a completed login, «إلغاء» and «حسنًا».
Future<BatchAuthResult?> showBiometricLoginDialog(
  BuildContext context, {
  required BiometricDenial denial,
  required BiometricLoginResubmit resubmit,
  Color? accent,
}) {
  return showDialog<BatchAuthResult?>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) => BiometricLoginDialog(
      denial: denial,
      resubmit: resubmit,
      accent: accent,
    ),
  );
}

class BiometricLoginDialog extends ConsumerStatefulWidget {
  const BiometricLoginDialog({
    super.key,
    required this.denial,
    required this.resubmit,
    this.accent,
  });

  final BiometricDenial denial;
  final BiometricLoginResubmit resubmit;

  /// Active line accent for the icon and primary button.
  final Color? accent;

  @override
  ConsumerState<BiometricLoginDialog> createState() =>
      _BiometricLoginDialogState();
}

class _BiometricLoginDialogState extends ConsumerState<BiometricLoginDialog>
    with WidgetsBindingObserver {
  late final BiometricLoginAttemptController _attempt;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _attempt = BiometricLoginAttemptController(
      denial: widget.denial,
      repository: ref.read(biometricAttemptRepositoryProvider),
      resubmit: widget.resubmit,
      config: ref.read(biometricPollConfigProvider),
    )..start();
    // Listen after start(): the initial state is read by the first build, and
    // only later (async) transitions can close the dialog.
    _attempt.addListener(_onAttemptChanged);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _attempt
      ..removeListener(_onAttemptChanged)
      ..dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _attempt.pollNow();
  }

  void _onAttemptChanged() {
    final BiometricAttemptState s = _attempt.state;
    switch (s.phase) {
      case BiometricAttemptPhase.succeeded:
      case BiometricAttemptPhase.failed:
        _close(s.result);
      default:
        break;
    }
  }

  void _close(BatchAuthResult? result) {
    if (_closing || !mounted) return;
    _closing = true;
    _attempt.close();
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final Color accent = widget.accent ?? AppColors.primary;
    return PopScope(
      canPop: false,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Dialog(
          backgroundColor: AppColors.surface,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 28,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: ListenableBuilder(
            listenable: _attempt,
            builder: (BuildContext context, _) =>
                _content(_attempt.state, accent),
          ),
        ),
      ),
    );
  }

  Widget _content(BiometricAttemptState s, Color accent) {
    final _PhaseLook look = _PhaseLook.of(s.phase, accent);
    return SingleChildScrollView(
      key: ValueKey<BiometricAttemptPhase>(s.phase),
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: look.color.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: s.phase == BiometricAttemptPhase.resubmitting
                  ? Padding(
                      padding: const EdgeInsets.all(20),
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(look.color),
                      ),
                    )
                  : Icon(look.icon, size: 38, color: look.color),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            BiometricLoginStrings.title,
            style: AppTextStyles.h2,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          ..._texts(s),
          if (look.polling) ...<Widget>[
            const SizedBox(height: 18),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                minHeight: 4,
                color: look.color,
                backgroundColor: look.color.withValues(alpha: 0.15),
              ),
            ),
          ],
          ..._actions(s, accent),
        ],
      ),
    );
  }

  List<Widget> _texts(BiometricAttemptState s) {
    Widget headline(String text) => Text(
      text,
      style: AppTextStyles.h3,
      textAlign: TextAlign.center,
    );
    Widget body(String text) => Text(
      text,
      style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
      textAlign: TextAlign.center,
    );

    switch (s.phase) {
      case BiometricAttemptPhase.waiting:
        return <Widget>[
          headline(BiometricLoginStrings.waiting),
          if (s.message != null) ...<Widget>[
            const SizedBox(height: 8),
            body(s.message!),
          ],
          const SizedBox(height: 8),
          const Text(
            BiometricLoginStrings.waitingSecondary,
            style: AppTextStyles.caption,
            textAlign: TextAlign.center,
          ),
        ];
      case BiometricAttemptPhase.deviceOffline:
        return <Widget>[
          headline(s.message ?? BiometricLoginStrings.deviceOffline),
        ];
      case BiometricAttemptPhase.network:
        return <Widget>[headline(BiometricLoginStrings.network)];
      case BiometricAttemptPhase.resubmitting:
      case BiometricAttemptPhase.succeeded:
      case BiometricAttemptPhase.failed:
        return <Widget>[headline(BiometricLoginStrings.verifying)];
      case BiometricAttemptPhase.retry:
        return <Widget>[headline(s.message ?? BiometricLoginStrings.retry)];
      case BiometricAttemptPhase.contactAdmin:
        return <Widget>[headline(s.message ?? '')];
    }
  }

  List<Widget> _actions(BiometricAttemptState s, Color accent) {
    Widget cancel() => AppSecondaryButton(
      label: BiometricLoginStrings.cancelButton,
      color: AppColors.textSecondary,
      onPressed: () => _close(null),
    );

    switch (s.phase) {
      case BiometricAttemptPhase.waiting:
      case BiometricAttemptPhase.deviceOffline:
      case BiometricAttemptPhase.network:
        return <Widget>[const SizedBox(height: 20), cancel()];
      case BiometricAttemptPhase.retry:
        return <Widget>[
          const SizedBox(height: 20),
          AppPrimaryButton(
            label: BiometricLoginStrings.retryButton,
            icon: Icons.refresh_rounded,
            color: accent,
            onPressed: _attempt.retry,
          ),
          const SizedBox(height: 10),
          cancel(),
        ];
      case BiometricAttemptPhase.contactAdmin:
        return <Widget>[
          const SizedBox(height: 20),
          AppPrimaryButton(
            label: BiometricLoginStrings.okButton,
            color: accent,
            onPressed: () => _close(s.result),
          ),
        ];
      case BiometricAttemptPhase.resubmitting:
      case BiometricAttemptPhase.succeeded:
      case BiometricAttemptPhase.failed:
        return const <Widget>[];
    }
  }
}

/// Icon, color and activity bar per phase.
class _PhaseLook {
  const _PhaseLook(this.icon, this.color, {this.polling = false});

  factory _PhaseLook.of(BiometricAttemptPhase phase, Color accent) =>
      switch (phase) {
        BiometricAttemptPhase.waiting => _PhaseLook(
          Icons.fingerprint_rounded,
          accent,
          polling: true,
        ),
        BiometricAttemptPhase.deviceOffline => const _PhaseLook(
          Icons.sensors_off_rounded,
          AppColors.offline,
          polling: true,
        ),
        BiometricAttemptPhase.network => const _PhaseLook(
          Icons.wifi_off_rounded,
          AppColors.offline,
          polling: true,
        ),
        BiometricAttemptPhase.resubmitting ||
        BiometricAttemptPhase.succeeded ||
        BiometricAttemptPhase.failed => _PhaseLook(
          Icons.fingerprint_rounded,
          accent,
        ),
        BiometricAttemptPhase.retry => const _PhaseLook(
          Icons.fingerprint_rounded,
          AppColors.warning,
        ),
        BiometricAttemptPhase.contactAdmin => const _PhaseLook(
          Icons.admin_panel_settings_outlined,
          AppColors.error,
        ),
      };

  final IconData icon;
  final Color color;

  /// Shows the indeterminate bar: the dialog is still waiting on the server.
  final bool polling;
}
