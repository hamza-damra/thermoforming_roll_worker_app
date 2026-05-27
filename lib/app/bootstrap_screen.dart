import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/diagnostics/refresh_log.dart';
import '../core/theme/app_colors.dart';
import '../core/widgets/app_scaffold.dart';
import '../features/home/presentation/screens/multi_line_home_shell.dart';
import '../features/roll_worker_auth/presentation/controllers/multi_line_session_registry.dart';
import '../features/roll_worker_auth/presentation/controllers/multi_line_session_registry_state.dart';
import '../features/sessions_me/presentation/controllers/sessions_me_controller.dart';
import '../features/sessions_me/presentation/controllers/sse_lifecycle_controller.dart';
import '../features/shift_line/presentation/controllers/roll_worker_bootstrap_controller.dart';
import '../features/shift_line/presentation/screens/active_shift_line_picker_screen.dart';

/// Top-level state-driven entry point. Decides between:
///   - [_CheckingScaffold] while the registry is restoring from storage,
///   - [ActiveShiftLinePickerScreen] when no active sessions exist,
///   - [MultiLineHomeShell] when one or more active sessions exist.
///
/// Cross-cutting concerns:
///   - Fires the cascade snackbar only when the lost shift-line was the
///     currently-active one OR when the registry just transitioned from
///     `RegistryActive` to `RegistryEmpty`. Non-active line losses
///     surface as the chip disappearing.
///   - On app-resume, re-fetches the active-shift-line options AND
///     re-discovers each persisted session via
///     [MultiLineSessionRegistry.restoreFromStorage] so a line that was
///     ended in the operator app disappears from both the picker and
///     the home shell.
class BootstrapScreen extends ConsumerStatefulWidget {
  const BootstrapScreen({super.key});

  /// Shown as a snackbar when the active shift-line or its session
  /// disappears outside of a deliberate logout.
  static const String cascadeMessage =
      'تم إنهاء الخط أو جلسة عامل الرولات، تم تحديث الحالة';

  @override
  ConsumerState<BootstrapScreen> createState() => _BootstrapScreenState();
}

class _BootstrapScreenState extends ConsumerState<BootstrapScreen>
    with WidgetsBindingObserver {
  bool _restoreScheduled = false;

  /// Guards against re-entrant resume cascades — a quick back-and-forth
  /// foreground/background flip used to fan out 3+ refreshes simultaneously,
  /// causing PageView/summary controllers to emit two visible state
  /// transitions in fast succession (the resume-flicker root cause).
  bool _resumeInFlight = false;

  /// When the most recent resume cascade started. We coalesce another
  /// resume that fires within [_resumeCoalesceWindow] of the previous one —
  /// SSE/network blips can re-fire `AppLifecycleState.resumed` without the
  /// worker actually leaving the app.
  DateTime? _lastResumeAt;
  static const Duration _resumeCoalesceWindow = Duration(seconds: 1);

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
    if (lifecycle != AppLifecycleState.resumed) return;
    unawaited(_handleResume());
  }

  /// Serializes the resume cascade so the picker, the session registry, and
  /// the post-login `/sessions/me` refresh run one after another instead of
  /// in parallel. Eliminates the simultaneous double-state-transition that
  /// caused the visible 2–3 blink flicker on resume.
  Future<void> _handleResume() async {
    final DateTime now = DateTime.now();
    if (_resumeInFlight) return;
    if (_lastResumeAt != null &&
        now.difference(_lastResumeAt!) < _resumeCoalesceWindow) {
      return;
    }
    _resumeInFlight = true;
    _lastResumeAt = now;
    refreshLog('app resumed (bootstrap) → serialized refresh cascade');
    try {
      await ref
          .read(rollWorkerBootstrapControllerProvider.notifier)
          .refresh(trigger: 'app-resume', background: true);
      await ref
          .read(multiLineSessionRegistryProvider.notifier)
          .restoreFromStorage();
      await ref
          .read(sessionsMeControllerProvider.notifier)
          .refresh(trigger: 'app-resume');
    } finally {
      _resumeInFlight = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_restoreScheduled) {
      _restoreScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Start the global SSE subscription BEFORE the registry restore so
        // any post-login refresh that follows can already react to frames.
        ref.read(sseLifecycleControllerProvider.notifier).start();
        ref
            .read(multiLineSessionRegistryProvider.notifier)
            .restoreFromStorage();
      });
    }

    ref.listen<MultiLineSessionRegistryState>(
      multiLineSessionRegistryProvider,
      _maybeShowCascadeSnackbar,
    );

    final MultiLineSessionRegistryState state = ref.watch(
      multiLineSessionRegistryProvider,
    );

    return switch (state) {
      RegistryRestoring() => const _CheckingScaffold(),
      RegistryEmpty() => const ActiveShiftLinePickerScreen(),
      RegistryActive() => const MultiLineHomeShell(),
    };
  }

  void _maybeShowCascadeSnackbar(
    MultiLineSessionRegistryState? prev,
    MultiLineSessionRegistryState next,
  ) {
    final bool show = _shouldShowCascade(prev, next);
    if (!show) return;
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
    // Clear the lastEvent so a subsequent rebuild doesn't re-fire.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(multiLineSessionRegistryProvider.notifier).clearLastEvent();
    });
  }

  bool _shouldShowCascade(
    MultiLineSessionRegistryState? prev,
    MultiLineSessionRegistryState next,
  ) {
    // Active → Empty transition with a LineLost event: registry just
    // emptied via cascade (not deliberate logout).
    if (prev is RegistryActive &&
        next is RegistryEmpty &&
        next.lastEvent is LineLost) {
      return true;
    }
    // Active line was lost while other lines remain.
    if (prev is RegistryActive && next is RegistryActive) {
      final RegistryEvent? event = next.lastEvent;
      if (event is LineLost && event.shiftLineId == prev.activeShiftLineId) {
        return true;
      }
    }
    return false;
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
