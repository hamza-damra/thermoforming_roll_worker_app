import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/errors/biometric_denial.dart';
import '../../../../core/errors/error_code.dart';
import '../../../../core/errors/error_messages_ar.dart';
import '../../../roll_worker_auth/domain/session_batch_repository.dart';
import '../../domain/biometric_attempt_repository.dart';
import '../../domain/entities/biometric_attempt_status.dart';
import 'biometric_poll_config.dart';

/// Re-sends the original login with the identical body. Supplied by the login
/// flow, which captures the PIN and line ids in the closure — so they live
/// exactly as long as the fingerprint dialog, and are never stored.
typedef BiometricLoginResubmit = Future<BatchAuthResult> Function();

/// Injectable sleep so tests can drive the back-off without real time.
typedef BiometricDelay = Future<void> Function(Duration duration);

/// What the fingerprint dialog shows (handoff §5).
enum BiometricAttemptPhase {
  /// Long-polling; no valid fingerprint yet.
  waiting,

  /// Long-polling; the terminal is offline.
  deviceOffline,

  /// A status call failed; backing off before the next one.
  network,

  /// A resubmit of the original login is in flight.
  resubmitting,

  /// Nothing to poll (410, or a 403 without an attempt): the worker scans,
  /// then taps «إعادة المحاولة».
  retry,

  /// `MAPPING_MISSING` / `MAPPING_DISABLED`: only a SYSTEM_ADMIN can help.
  contactAdmin,

  /// The resubmitted login returned 2xx. Terminal.
  succeeded,

  /// The resubmitted login failed for a non-biometric reason (for example the
  /// PIN changed meanwhile). Terminal: the dialog closes and the login screen
  /// shows the error.
  failed,
}

@immutable
class BiometricAttemptState {
  const BiometricAttemptState(this.phase, {this.message, this.result});

  final BiometricAttemptPhase phase;

  /// Server wording for this state — the 403 `message` that put the dialog
  /// here (or its verbatim copy for a `MAPPING_*` status answer, which carries
  /// no message). Null when the dialog should use its own §10 text.
  final String? message;

  /// The login outcome handed back when the dialog closes: set for
  /// [BiometricAttemptPhase.succeeded], [BiometricAttemptPhase.failed] and
  /// [BiometricAttemptPhase.contactAdmin].
  final BatchAuthResult? result;
}

/// Drives one biometric login attempt:
/// `waiting ⇄ deviceOffline → resubmitting → (succeeded | new attempt | failed)`.
///
/// Owned by the fingerprint dialog and disposed with it. Holds the attempt
/// token in memory only; [close] (dialog closed, «إلغاء») stops the loop and
/// discards it.
///
/// Rules (handoff §8):
/// - `PENDING` / `DEVICE_UNAVAILABLE` → the next long-poll goes out at once.
/// - `VERIFIED` / `ENFORCEMENT_SUSPENDED` / `NOT_REQUIRED` → re-submit the
///   original login **once**. Another biometric 403 replaces the attempt (new
///   token) and polling restarts; a new status answer is needed before any
///   further resubmit, so resubmits never loop.
/// - A failed status call backs off and keeps trying until the server answers;
///   only its 410 ends the attempt — the device clock is never consulted.
/// - [pollNow] (app resume) cuts a back-off short or replaces a long-poll that
///   may have died while the app was in the background.
class BiometricLoginAttemptController extends ChangeNotifier {
  BiometricLoginAttemptController({
    required BiometricDenial denial,
    required BiometricAttemptRepository repository,
    required BiometricLoginResubmit resubmit,
    BiometricPollConfig config = const BiometricPollConfig(),
    BiometricDelay? delay,
  }) : _initialDenial = denial,
       _repository = repository,
       _resubmit = resubmit,
       _config = config,
       _delay = delay ?? Future<void>.delayed;

  final BiometricAttemptRepository _repository;
  final BiometricLoginResubmit _resubmit;
  final BiometricPollConfig _config;
  final BiometricDelay _delay;

  /// Consumed (and dropped) by [start].
  BiometricDenial? _initialDenial;

  String? _attemptToken;
  String? _statusPath;

  /// Bumped whenever the running poll loop must stop (new attempt, resubmit,
  /// resume restart, close). A loop that finds its id stale exits and its
  /// in-flight answer is ignored.
  int _loopId = 0;

  bool _closed = false;
  bool _disposed = false;
  bool _resubmitInFlight = false;
  Completer<void>? _wake;

  BiometricAttemptState _state = const BiometricAttemptState(
    BiometricAttemptPhase.waiting,
  );
  BiometricAttemptState get state => _state;

  /// Whether an attempt token is held right now.
  @visibleForTesting
  bool get holdsAttemptToken => _attemptToken != null;

  /// Applies the denial that opened the dialog: polls, or settles directly on
  /// retry / contact-admin when there is nothing to poll.
  void start() {
    final BiometricDenial? denial = _initialDenial;
    _initialDenial = null;
    if (denial == null || _closed) return;
    _adopt(denial);
  }

  /// Polls immediately (app resume). No-op unless an attempt is being polled.
  void pollNow() {
    if (_closed || _resubmitInFlight || _attemptToken == null) return;
    if (_wakeUp()) return;
    _startLoop();
  }

  /// «إعادة المحاولة»: re-submits the original login. Only in
  /// [BiometricAttemptPhase.retry].
  Future<void> retry() async {
    if (_closed || _state.phase != BiometricAttemptPhase.retry) return;
    await _resubmitOnce();
  }

  /// Stops polling for good and discards the token. Idempotent.
  void close() {
    if (_closed) return;
    _closed = true;
    _loopId++;
    _initialDenial = null;
    _discardAttempt();
    _wakeUp();
  }

  @override
  void dispose() {
    close();
    _disposed = true;
    super.dispose();
  }

  void _adopt(BiometricDenial denial) {
    _loopId++;
    _discardAttempt();
    if (denial.isMappingProblem) {
      _emit(
        BiometricAttemptState(
          BiometricAttemptPhase.contactAdmin,
          message: denial.message,
          result: BatchAuthFailureResult(
            BiometricDenialFailure(denial: denial.withoutAttempt()),
          ),
        ),
      );
      return;
    }
    if (!denial.hasAttempt) {
      _emit(
        BiometricAttemptState(
          BiometricAttemptPhase.retry,
          message: denial.message,
        ),
      );
      return;
    }
    _attemptToken = denial.attemptToken;
    _statusPath = denial.statusPath;
    _emit(
      BiometricAttemptState(
        denial.isDeviceUnavailable
            ? BiometricAttemptPhase.deviceOffline
            : BiometricAttemptPhase.waiting,
        message: denial.message,
      ),
    );
    _startLoop();
  }

  void _startLoop() {
    final int id = ++_loopId;
    unawaited(_pollLoop(id));
  }

  bool _isLive(int id) => !_closed && id == _loopId;

  Future<void> _pollLoop(int id) async {
    int failures = 0;
    while (_isLive(id)) {
      final String? token = _attemptToken;
      if (token == null) return;
      final Stopwatch watch = Stopwatch()..start();
      final BiometricStatusResult result = await _repository.getStatus(
        statusPath: _statusPath,
        attemptToken: token,
      );
      if (!_isLive(id)) return;
      switch (result) {
        case BiometricStatusAnswered(:final BiometricAttemptStatusResponse response):
          failures = 0;
          switch (response.status) {
            case BiometricAttemptStatus.verified:
            case BiometricAttemptStatus.enforcementSuspended:
            case BiometricAttemptStatus.notRequired:
              unawaited(_resubmitOnce());
              return;
            case BiometricAttemptStatus.mappingMissing:
              _contactAdmin(ErrorCode.biometricMappingMissing);
              return;
            case BiometricAttemptStatus.mappingDisabled:
              _contactAdmin(ErrorCode.biometricMappingDisabled);
              return;
            case BiometricAttemptStatus.deviceUnavailable:
              _emitPolling(BiometricAttemptPhase.deviceOffline);
            case BiometricAttemptStatus.pending:
              _emitPolling(BiometricAttemptPhase.waiting);
          }
          final Duration elapsed = watch.elapsed;
          if (elapsed < _config.minPollSpacing) {
            await _sleep(_config.minPollSpacing - elapsed);
          }
        case BiometricStatusAttemptExpired():
          _discardAttempt();
          _emit(const BiometricAttemptState(BiometricAttemptPhase.retry));
          return;
        case BiometricStatusUnreachable():
          _emit(const BiometricAttemptState(BiometricAttemptPhase.network));
          await _sleep(_config.backoffFor(failures++));
      }
    }
  }

  /// Resubmits the original login once, then acts on its answer.
  Future<void> _resubmitOnce() async {
    if (_closed || _resubmitInFlight) return;
    _resubmitInFlight = true;
    _loopId++;
    _discardAttempt();
    _emit(const BiometricAttemptState(BiometricAttemptPhase.resubmitting));
    BatchAuthResult result;
    try {
      result = await _resubmit();
    } catch (error) {
      result = BatchAuthFailureResult(UnknownFailure(cause: error));
    } finally {
      _resubmitInFlight = false;
    }
    if (_closed) return;
    switch (result) {
      case BatchAuthSuccessResult():
        _emit(
          BiometricAttemptState(BiometricAttemptPhase.succeeded, result: result),
        );
      case BatchAuthFailureResult(
        failure: final BiometricDenialFailure denied,
      ):
        // Fingerprint expired in between, or a new reason: a fresh attempt.
        _adopt(denied.denial);
      case BatchAuthFailureResult():
        _emit(
          BiometricAttemptState(BiometricAttemptPhase.failed, result: result),
        );
    }
  }

  /// A `MAPPING_*` status answer carries no message, so the dialog shows the
  /// verbatim copy of the server's own wording for that code.
  void _contactAdmin(ErrorCode code) {
    _discardAttempt();
    _emit(
      BiometricAttemptState(
        BiometricAttemptPhase.contactAdmin,
        message: arabicForErrorCode(code),
        result: BatchAuthFailureResult(BusinessFailure(code: code)),
      ),
    );
  }

  /// A status answer only changes the phase; the 403 wording is kept while
  /// the phase it described still holds.
  void _emitPolling(BiometricAttemptPhase phase) {
    if (_state.phase == phase) return;
    _emit(BiometricAttemptState(phase));
  }

  Future<void> _sleep(Duration duration) async {
    final Completer<void> wake = Completer<void>();
    _wake = wake;
    await Future.any<void>(<Future<void>>[_delay(duration), wake.future]);
    if (identical(_wake, wake)) _wake = null;
  }

  /// Ends a pending [_sleep] early. Returns whether one was pending.
  bool _wakeUp() {
    final Completer<void>? wake = _wake;
    _wake = null;
    if (wake == null || wake.isCompleted) return false;
    wake.complete();
    return true;
  }

  void _discardAttempt() {
    _attemptToken = null;
    _statusPath = null;
  }

  void _emit(BiometricAttemptState next) {
    if (_disposed) return;
    _state = next;
    notifyListeners();
  }
}
