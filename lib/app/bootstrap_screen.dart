import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../core/widgets/app_scaffold.dart';
import '../features/roll_worker_auth/presentation/controllers/roll_worker_auth_controller.dart';
import '../features/roll_worker_auth/presentation/controllers/roll_worker_auth_state.dart';
import '../features/roll_worker_auth/presentation/screens/authenticated_home_placeholder.dart';
import '../features/roll_worker_auth/presentation/screens/pin_screen.dart';
import '../features/shift_line/presentation/controllers/selected_shift_line_provider.dart';
import '../features/shift_line/presentation/screens/waiting_for_line_screen.dart';

/// Top-level state-driven entry point. Decides between:
///   - [WaitingForLineScreen] when no shift-line is selected (production
///     default until backend ships the picker — §7 gap),
///   - [PinScreen] when a shift-line is selected but no active session,
///   - [AuthenticatedHomePlaceholder] when a session is active.
///
/// Stage 5 will replace [AuthenticatedHomePlaceholder] with the real Roll
/// Worker home (mount card, scan, close, product-switch, reprint).
class BootstrapScreen extends ConsumerStatefulWidget {
  const BootstrapScreen({super.key});

  @override
  ConsumerState<BootstrapScreen> createState() => _BootstrapScreenState();
}

class _BootstrapScreenState extends ConsumerState<BootstrapScreen> {
  int? _checkedFor;

  @override
  Widget build(BuildContext context) {
    final int? shiftLineId = ref.watch(selectedShiftLineIdProvider);
    if (shiftLineId == null) return const WaitingForLineScreen();

    final RollWorkerAuthState authState = ref.watch(
      rollWorkerAuthControllerProvider(shiftLineId),
    );

    // First time we see a shiftLineId, kick off the session-current check.
    if (_checkedFor != shiftLineId && authState is RollWorkerAuthInitial) {
      _checkedFor = shiftLineId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(rollWorkerAuthControllerProvider(shiftLineId).notifier)
            .checkSession();
      });
    }

    // If the line was reported gone, drop the selected-shift-line and
    // surface the waiting screen on the next frame.
    if (authState is RollWorkerAuthLineGone) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(selectedShiftLineIdProvider.notifier).clear();
      });
      return const WaitingForLineScreen();
    }

    return switch (authState) {
      RollWorkerAuthAuthenticated(:final session) =>
        AuthenticatedHomePlaceholder(
          shiftLineId: shiftLineId,
          session: session,
        ),
      RollWorkerAuthInitial() ||
      RollWorkerAuthChecking() => const _CheckingScaffold(),
      RollWorkerAuthUnauthenticated() ||
      RollWorkerAuthAuthenticating() => PinScreen(shiftLineId: shiftLineId),
      RollWorkerAuthLineGone() => const WaitingForLineScreen(),
    };
  }
}

class _CheckingScaffold extends StatelessWidget {
  const _CheckingScaffold();

  @override
  Widget build(BuildContext context) {
    return const AppScaffold(
      title: 'تطبيق عامل الرولات',
      body: Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
        ),
      ),
    );
  }
}
