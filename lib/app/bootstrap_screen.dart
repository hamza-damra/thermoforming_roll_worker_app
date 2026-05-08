import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../core/widgets/app_scaffold.dart';
import '../features/home/presentation/screens/roll_worker_home_screen.dart';
import '../features/roll_worker_auth/presentation/controllers/roll_worker_auth_controller.dart';
import '../features/roll_worker_auth/presentation/controllers/roll_worker_auth_state.dart';
import '../features/roll_worker_auth/presentation/screens/pin_screen.dart';
import '../features/shift_line/presentation/controllers/selected_shift_line_provider.dart';
import '../features/shift_line/presentation/screens/waiting_for_line_screen.dart';

/// Top-level state-driven entry point. Decides between:
///   - [WaitingForLineScreen] when no shift-line is selected (production
///     default until backend ships the picker — §7 gap),
///   - [PinScreen] when a shift-line is selected but no active session,
///   - [AuthenticatedHomePlaceholder] when a session is active.
///
/// Also responsible for two cross-cutting concerns:
///   - Surfaces a cascade snackbar in Arabic whenever the active line or
///     session disappears silently (LineGone, or silent-loss
///     Unauthenticated).
///   - Refreshes the current session when the app comes back to foreground
///     via `WidgetsBindingObserver`. Lightweight only — no scan / mount /
///     reprint refresh until later stages.
///
/// Stage 5 will replace [AuthenticatedHomePlaceholder] with the real Roll
/// Worker home (mount card, scan, close, product-switch, reprint).
class BootstrapScreen extends ConsumerStatefulWidget {
  const BootstrapScreen({super.key});

  /// Shown as a snackbar whenever the active shift-line or roll-worker
  /// session disappears outside of a deliberate logout.
  static const String cascadeMessage =
      'تم إنهاء الخط أو جلسة عامل الرولات، تم تحديث الحالة';

  @override
  ConsumerState<BootstrapScreen> createState() => _BootstrapScreenState();
}

class _BootstrapScreenState extends ConsumerState<BootstrapScreen>
    with WidgetsBindingObserver {
  int? _checkedFor;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    // Re-discover the current session whenever the app returns from
    // background. Other refresh flows (scan / mount / reprint) deliberately
    // do NOT run here — they belong to later stages and shouldn't fire on
    // resume during Stage 4.
    if (lifecycle != AppLifecycleState.resumed) return;
    final int? id = ref.read(selectedShiftLineIdProvider);
    if (id == null) return;
    final RollWorkerAuthState current = ref.read(
      rollWorkerAuthControllerProvider(id),
    );
    if (current is RollWorkerAuthAuthenticating) return;
    ref.read(rollWorkerAuthControllerProvider(id).notifier).checkSession();
  }

  @override
  Widget build(BuildContext context) {
    final int? shiftLineId = ref.watch(selectedShiftLineIdProvider);
    if (shiftLineId == null) return const WaitingForLineScreen();

    // Snackbar wiring — only meaningful while a shift-line is selected.
    ref.listen<RollWorkerAuthState>(
      rollWorkerAuthControllerProvider(shiftLineId),
      _maybeShowCascadeSnackbar,
    );

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
      RollWorkerAuthAuthenticated(:final session) => RollWorkerHomeScreen(
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

  void _maybeShowCascadeSnackbar(
    RollWorkerAuthState? prev,
    RollWorkerAuthState next,
  ) {
    final bool prevWasLineGone = prev is RollWorkerAuthLineGone;
    final bool prevWasSilentLoss =
        prev is RollWorkerAuthUnauthenticated && prev.silentSessionLoss;
    final bool becameLineGone = next is RollWorkerAuthLineGone;
    final bool becameSilentLoss =
        next is RollWorkerAuthUnauthenticated && next.silentSessionLoss;

    final bool show =
        (becameLineGone && !prevWasLineGone) ||
        (becameSilentLoss && !prevWasSilentLoss);
    if (!show) return;

    // Replace any previous snackbar so rapid transitions don't queue.
    final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(
      context,
    );
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(BootstrapScreen.cascadeMessage),
          duration: Duration(seconds: 4),
        ),
      );
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
