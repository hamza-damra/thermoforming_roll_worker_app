import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/errors/error_code.dart';
import '../../data/roll_worker_auth_providers.dart';
import '../../domain/roll_worker_auth_repository.dart';
import 'roll_worker_auth_state.dart';

class RollWorkerAuthController
    extends FamilyNotifier<RollWorkerAuthState, int> {
  late int _shiftLineId;

  @override
  RollWorkerAuthState build(int arg) {
    _shiftLineId = arg;
    return const RollWorkerAuthInitial();
  }

  RollWorkerAuthRepository get _repo =>
      ref.read(rollWorkerAuthRepositoryProvider);

  /// Discovery call — used on app launch / app resume.
  /// Wraps `GET /roll-worker-session/current` for [_shiftLineId].
  Future<void> checkSession() async {
    if (state is RollWorkerAuthAuthenticating) return;
    state = const RollWorkerAuthChecking();
    final RollWorkerAuthResult result = await _repo.getCurrentSession(
      _shiftLineId,
    );
    switch (result) {
      case RollWorkerAuthSuccess(:final session):
        if (session.isActive) {
          state = RollWorkerAuthAuthenticated(session);
        } else {
          await _repo.clearStoredToken(_shiftLineId);
          state = const RollWorkerAuthUnauthenticated();
        }
      case RollWorkerAuthFailure(:final failure):
        state = _stateFromFailure(failure);
    }
  }

  /// Submits the PIN. Idempotent against rapid double-taps.
  Future<void> login(String pin) async {
    if (state is RollWorkerAuthAuthenticating) return;
    if (pin.isEmpty) {
      state = const RollWorkerAuthUnauthenticated(
        lastFailure: BusinessFailure(code: ErrorCode.operatorPinInvalid),
      );
      return;
    }
    state = const RollWorkerAuthAuthenticating();
    final RollWorkerAuthResult result = await _repo.login(
      shiftLineId: _shiftLineId,
      pin: pin,
    );
    switch (result) {
      case RollWorkerAuthSuccess(:final session):
        state = RollWorkerAuthAuthenticated(session);
      case RollWorkerAuthFailure(:final failure):
        state = _stateFromFailure(failure, fromLogin: true);
    }
  }

  /// Clears the local token (after attempting backend logout) and routes the
  /// UI back to the PIN screen.
  Future<void> logout() async {
    await _repo.logout(_shiftLineId);
    state = const RollWorkerAuthUnauthenticated();
  }

  /// Used by other features (Stage 5+) to react to mid-flow
  /// `ROLL_WORKER_SESSION_REQUIRED`: clear the token and surface the PIN
  /// screen on the next frame.
  Future<void> notifySessionLost() async {
    await _repo.clearStoredToken(_shiftLineId);
    state = const RollWorkerAuthUnauthenticated();
  }

  RollWorkerAuthState _stateFromFailure(
    AppFailure failure, {
    bool fromLogin = false,
  }) {
    if (failure is BusinessFailure) {
      switch (failure.code) {
        case ErrorCode.thermoformingShiftLineNotFound:
        case ErrorCode.thermoformingShiftLineNotActive:
          return const RollWorkerAuthLineGone();
        case ErrorCode.rollWorkerSessionRequired:
          // Surface as plain unauthenticated — no inline error needed when
          // we just discovered there's no session.
          return const RollWorkerAuthUnauthenticated();
        case ErrorCode.rollWorkerNotAllowed:
        case ErrorCode.operatorPinInvalid:
        case ErrorCode.operatorPinLocked:
          return RollWorkerAuthUnauthenticated(lastFailure: failure);
        // Other business failures during login → inline error;
        // during discovery → silent unauthenticated.
        default:
          return RollWorkerAuthUnauthenticated(
            lastFailure: fromLogin ? failure : null,
          );
      }
    }
    // Network / server / unknown:
    //   - During login → inline error so the worker knows what happened.
    //   - During silent discovery → keep the user on the PIN screen but
    //     don't surface a confusing error message.
    return RollWorkerAuthUnauthenticated(
      lastFailure: fromLogin ? failure : null,
    );
  }
}

final rollWorkerAuthControllerProvider =
    NotifierProvider.family<RollWorkerAuthController, RollWorkerAuthState, int>(
      RollWorkerAuthController.new,
    );
