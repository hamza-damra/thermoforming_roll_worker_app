import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../biometric_login/presentation/widgets/biometric_login_dialog.dart';
import '../../domain/session_batch_repository.dart';
import '../controllers/batch_auth_controller.dart';
import '../controllers/batch_auth_state.dart';

/// Runs the fingerprint dialog for a login in [BatchAuthBiometricRequired]
/// and reports its final outcome to [BatchAuthController].
///
/// Returns true when the worker cancelled — the controller is back at
/// [BatchAuthInitial] and the login screen must re-enable itself. Otherwise
/// the controller now holds [BatchAuthSuccess] or [BatchAuthFailure] and the
/// screen's usual state listener takes over, exactly as for a login that
/// never met the gate. The dialog is closed before that state is set, so a
/// listener that pops a route pops its own screen, never the dialog.
Future<bool> runBiometricLoginGate(
  BuildContext context,
  WidgetRef ref,
  BatchAuthBiometricRequired gate, {
  Color? accent,
}) async {
  // Read before awaiting: the screen may be gone by the time the dialog
  // closes, but the (app-scoped) controller still has to hear the outcome.
  final BatchAuthController auth = ref.read(
    batchAuthControllerProvider.notifier,
  );
  final BatchAuthResult? result = await showBiometricLoginDialog(
    context,
    denial: gate.denial,
    resubmit: gate.resubmit,
    accent: accent,
  );
  await auth.completeBiometricGate(result);
  return result == null;
}
