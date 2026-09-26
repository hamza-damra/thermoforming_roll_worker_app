import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:thermoforming_roll_worker/core/errors/app_failure.dart';
import 'package:thermoforming_roll_worker/core/errors/biometric_denial.dart';
import 'package:thermoforming_roll_worker/core/errors/error_code.dart';
import 'package:thermoforming_roll_worker/core/errors/error_messages_ar.dart';
import 'package:thermoforming_roll_worker/features/biometric_login/domain/biometric_attempt_repository.dart';
import 'package:thermoforming_roll_worker/features/biometric_login/domain/entities/biometric_attempt_status.dart';
import 'package:thermoforming_roll_worker/features/biometric_login/presentation/controllers/biometric_login_attempt_controller.dart';
import 'package:thermoforming_roll_worker/features/biometric_login/presentation/controllers/biometric_poll_config.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/domain/entities/batch_auth_outcome.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/domain/entities/roll_worker_session.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/domain/session_batch_repository.dart';

const String _token1 = 'token-one-secret';
const String _token2 = 'token-two-secret';

/// Scripted status endpoint. Answers are handed out in order; once the script
/// runs dry, polls park on a future that never completes (a held long-poll).
class _FakeStatusRepo implements BiometricAttemptRepository {
  final List<BiometricStatusResult> script = <BiometricStatusResult>[];
  final List<String> tokensSeen = <String>[];
  final List<String?> pathsSeen = <String?>[];
  Completer<BiometricStatusResult>? parked;

  void answer(BiometricAttemptStatus status) => script.add(
    BiometricStatusAnswered(BiometricAttemptStatusResponse(status: status)),
  );

  @override
  Future<BiometricStatusResult> getStatus({
    required String? statusPath,
    required String attemptToken,
  }) {
    tokensSeen.add(attemptToken);
    pathsSeen.add(statusPath);
    if (script.isNotEmpty) return Future<BiometricStatusResult>.value(script.removeAt(0));
    return (parked = Completer<BiometricStatusResult>()).future;
  }
}

/// Resubmits the original login; answers are scripted in order.
class _FakeResubmit {
  final List<BatchAuthResult> script = <BatchAuthResult>[];
  int calls = 0;

  Future<BatchAuthResult> call() async {
    calls++;
    return script.removeAt(0);
  }
}

BiometricDenial _denial({
  String code = 'BIOMETRIC_VERIFICATION_REQUIRED',
  String message = 'يرجى تمرير البصمة على جهاز البصمة ثم إعادة المحاولة.',
  String? token = _token1,
}) => BiometricDenial(
  code: code,
  message: message,
  validitySeconds: 300,
  attemptAvailable: token != null,
  attemptToken: token,
  statusPath: '/api/v1/auth/biometric/login-attempts/status',
);

BatchAuthResult _success() => BatchAuthSuccessResult(
  BatchAuthOutcome(
    rollWorkerOperatorId: 77,
    rollWorkerName: 'Yusuf',
    sessions: <int, RollWorkerSession>{
      800: RollWorkerSession(
        sessionId: 1,
        rollWorkerOperatorId: 77,
        rollWorkerName: 'Yusuf',
        thermoformingShiftId: 9001,
        thermoformingShiftLineId: 800,
        thermoformingLineId: 11,
        palletizingLineId: 21,
        startedAt: DateTime.utc(2026, 9, 24, 8),
      ),
    },
  ),
);

BatchAuthResult _biometricAgain({String? token = _token2, String? code}) =>
    BatchAuthFailureResult(
      BiometricDenialFailure(
        denial: _denial(
          code: code ?? 'BIOMETRIC_VERIFICATION_EXPIRED',
          message: 'انتهت صلاحية التحقق بالبصمة.',
          token: token,
        ),
        statusCode: 403,
      ),
    );

/// Flushes microtasks so the poll loop runs as far as its script allows.
Future<void> _settle() async {
  for (int i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late _FakeStatusRepo repo;
  late _FakeResubmit resubmit;
  late List<Duration> sleeps;
  late BiometricLoginAttemptController c;

  BiometricLoginAttemptController make(BiometricDenial denial) {
    c = BiometricLoginAttemptController(
      denial: denial,
      repository: repo,
      resubmit: resubmit.call,
      config: const BiometricPollConfig(minPollSpacing: Duration.zero),
      delay: (Duration d) async => sleeps.add(d),
    );
    addTearDown(c.dispose);
    return c;
  }

  setUp(() {
    repo = _FakeStatusRepo();
    resubmit = _FakeResubmit();
    sleeps = <Duration>[];
  });

  group('403 → initial dialog state', () {
    test('with a token: waiting, server message shown, polling starts', () async {
      make(_denial()).start();
      expect(c.state.phase, BiometricAttemptPhase.waiting);
      expect(c.state.message, _denial().message);
      await _settle();
      expect(repo.tokensSeen, <String>[_token1]);
      expect(repo.pathsSeen.single, '/api/v1/auth/biometric/login-attempts/status');
    });

    test('BIOMETRIC_DEVICE_UNAVAILABLE with a token: device offline, polling', () async {
      make(
        _denial(code: 'BIOMETRIC_DEVICE_UNAVAILABLE', message: 'offline'),
      ).start();
      expect(c.state.phase, BiometricAttemptPhase.deviceOffline);
      expect(c.state.message, 'offline');
      await _settle();
      expect(repo.tokensSeen, hasLength(1));
    });

    test('attemptAvailable=false: retry, no polling', () async {
      make(_denial(token: null)).start();
      expect(c.state.phase, BiometricAttemptPhase.retry);
      expect(c.state.message, _denial().message);
      await _settle();
      expect(repo.tokensSeen, isEmpty);
    });

    for (final String code in <String>[
      'BIOMETRIC_MAPPING_MISSING',
      'BIOMETRIC_MAPPING_DISABLED',
    ]) {
      test('$code: contact admin with the server message, no polling', () async {
        make(_denial(code: code, message: 'server says', token: null)).start();
        expect(c.state.phase, BiometricAttemptPhase.contactAdmin);
        expect(c.state.message, 'server says');
        final AppFailure failure =
            (c.state.result! as BatchAuthFailureResult).failure;
        expect(arabicMessageFor(failure), 'server says');
        await _settle();
        expect(repo.tokensSeen, isEmpty);
        expect(resubmit.calls, 0);
      });
    }
  });

  group('status answers', () {
    test('PENDING polls again at once; DEVICE_UNAVAILABLE ⇄ waiting', () async {
      repo
        ..answer(BiometricAttemptStatus.pending)
        ..answer(BiometricAttemptStatus.deviceUnavailable);
      make(_denial()).start();
      await _settle();
      expect(c.state.phase, BiometricAttemptPhase.deviceOffline);
      // The 403 wording described "waiting"; a status-driven phase change
      // falls back to the dialog's own text.
      expect(c.state.message, isNull);
      expect(repo.tokensSeen, <String>[_token1, _token1, _token1]);
      expect(sleeps, isEmpty, reason: 'no wait between long-polls');

      repo.parked!.complete(
        const BiometricStatusAnswered(
          BiometricAttemptStatusResponse(status: BiometricAttemptStatus.pending),
        ),
      );
      await _settle();
      expect(c.state.phase, BiometricAttemptPhase.waiting);
      expect(resubmit.calls, 0);
    });

    test('PENDING keeps the 403 wording while still waiting', () async {
      repo.answer(BiometricAttemptStatus.pending);
      make(_denial()).start();
      await _settle();
      expect(c.state.phase, BiometricAttemptPhase.waiting);
      expect(c.state.message, _denial().message);
    });

    for (final BiometricAttemptStatus status in <BiometricAttemptStatus>[
      BiometricAttemptStatus.verified,
      BiometricAttemptStatus.enforcementSuspended,
      BiometricAttemptStatus.notRequired,
    ]) {
      test('$status → exactly one resubmit → succeeded', () async {
        repo.answer(status);
        resubmit.script.add(_success());
        make(_denial()).start();
        await _settle();

        expect(resubmit.calls, 1);
        expect(c.state.phase, BiometricAttemptPhase.succeeded);
        expect(c.state.result, isA<BatchAuthSuccessResult>());
        expect(repo.tokensSeen, hasLength(1), reason: 'polling stopped');
        expect(c.holdsAttemptToken, isFalse);
      });
    }

    for (final (BiometricAttemptStatus, ErrorCode) pair
        in <(BiometricAttemptStatus, ErrorCode)>[
          (BiometricAttemptStatus.mappingMissing, ErrorCode.biometricMappingMissing),
          (
            BiometricAttemptStatus.mappingDisabled,
            ErrorCode.biometricMappingDisabled,
          ),
        ]) {
      test('${pair.$1} → contact admin, polling stops', () async {
        repo.answer(pair.$1);
        make(_denial()).start();
        await _settle();

        expect(c.state.phase, BiometricAttemptPhase.contactAdmin);
        expect(c.state.message, arabicForErrorCode(pair.$2));
        final AppFailure failure =
            (c.state.result! as BatchAuthFailureResult).failure;
        expect((failure as BusinessFailure).code, pair.$2);
        expect(repo.tokensSeen, hasLength(1));
        expect(resubmit.calls, 0);
        expect(c.holdsAttemptToken, isFalse);
      });
    }

    test('410 → retry; «إعادة المحاولة» re-submits the original login', () async {
      repo.script.add(const BiometricStatusAttemptExpired());
      make(_denial()).start();
      await _settle();

      expect(c.state.phase, BiometricAttemptPhase.retry);
      expect(c.state.message, isNull, reason: 'dialog shows its retry text');
      expect(c.holdsAttemptToken, isFalse);
      expect(resubmit.calls, 0);

      resubmit.script.add(_success());
      await c.retry();
      expect(resubmit.calls, 1);
      expect(c.state.phase, BiometricAttemptPhase.succeeded);
    });

    test('retry() is ignored outside the retry state', () async {
      make(_denial()).start();
      await c.retry();
      expect(resubmit.calls, 0);
    });
  });

  group('resubmit outcomes', () {
    test('another biometric 403 switches to the new attempt — no loop', () async {
      repo.answer(BiometricAttemptStatus.verified);
      resubmit.script.add(_biometricAgain());
      make(_denial()).start();
      await _settle();

      expect(resubmit.calls, 1);
      expect(c.state.phase, BiometricAttemptPhase.waiting);
      expect(c.state.message, 'انتهت صلاحية التحقق بالبصمة.');
      // The next poll carries the NEW token and no second resubmit happens
      // until a new status answer arrives.
      expect(repo.tokensSeen, <String>[_token1, _token2]);

      resubmit.script.add(_success());
      repo.parked!.complete(
        const BiometricStatusAnswered(
          BiometricAttemptStatusResponse(status: BiometricAttemptStatus.verified),
        ),
      );
      await _settle();
      expect(resubmit.calls, 2);
      expect(c.state.phase, BiometricAttemptPhase.succeeded);
    });

    test('a biometric 403 without a token after resubmit → retry', () async {
      repo.answer(BiometricAttemptStatus.verified);
      resubmit.script.add(_biometricAgain(token: null));
      make(_denial()).start();
      await _settle();
      expect(c.state.phase, BiometricAttemptPhase.retry);
      expect(repo.tokensSeen, hasLength(1));
    });

    test('a non-biometric failure (PIN changed) → failed, carries it', () async {
      repo.answer(BiometricAttemptStatus.verified);
      resubmit.script.add(
        const BatchAuthFailureResult(
          BusinessFailure(code: ErrorCode.operatorPinInvalid),
        ),
      );
      make(_denial()).start();
      await _settle();

      expect(c.state.phase, BiometricAttemptPhase.failed);
      final AppFailure failure =
          (c.state.result! as BatchAuthFailureResult).failure;
      expect((failure as BusinessFailure).code, ErrorCode.operatorPinInvalid);
    });
  });

  group('network errors', () {
    test('back off 1 s, 2 s, 4 s, then at most 10 s — and recover', () async {
      for (int i = 0; i < 6; i++) {
        repo.script.add(const BiometricStatusUnreachable(NetworkFailure()));
      }
      repo.answer(BiometricAttemptStatus.pending);
      make(_denial()).start();
      await _settle();

      expect(sleeps, const <Duration>[
        Duration(seconds: 1),
        Duration(seconds: 2),
        Duration(seconds: 4),
        Duration(seconds: 10),
        Duration(seconds: 10),
        Duration(seconds: 10),
      ]);
      expect(c.state.phase, BiometricAttemptPhase.waiting);
      expect(repo.tokensSeen, hasLength(8));
    });

    test('shows the network state while backing off', () async {
      final Completer<void> hold = Completer<void>();
      repo.script.add(const BiometricStatusUnreachable(NetworkFailure()));
      c = BiometricLoginAttemptController(
        denial: _denial(),
        repository: repo,
        resubmit: resubmit.call,
        config: const BiometricPollConfig(minPollSpacing: Duration.zero),
        delay: (_) => hold.future,
      );
      addTearDown(c.dispose);
      c.start();
      await _settle();
      expect(c.state.phase, BiometricAttemptPhase.network);
      expect(repo.tokensSeen, hasLength(1));

      // App resume polls immediately instead of waiting out the back-off.
      repo.answer(BiometricAttemptStatus.pending);
      c.pollNow();
      await _settle();
      // Woken poll → PENDING → next long-poll goes out at once (now held).
      expect(repo.tokensSeen, hasLength(3));
      expect(c.state.phase, BiometricAttemptPhase.waiting);
    });
  });

  group('cancel / close', () {
    test('stops polling and discards the token; late answers are ignored', () async {
      make(_denial()).start();
      await _settle();
      expect(c.holdsAttemptToken, isTrue);
      expect(repo.tokensSeen, hasLength(1));

      c.close();
      expect(c.holdsAttemptToken, isFalse);

      // The in-flight long-poll answers VERIFIED after the cancel.
      repo.parked!.complete(
        const BiometricStatusAnswered(
          BiometricAttemptStatusResponse(status: BiometricAttemptStatus.verified),
        ),
      );
      await _settle();
      expect(resubmit.calls, 0);
      expect(repo.tokensSeen, hasLength(1));
      c.pollNow();
      await _settle();
      expect(repo.tokensSeen, hasLength(1));
    });

    test('pollNow on resume replaces a possibly dead long-poll', () async {
      make(_denial()).start();
      await _settle();
      final Completer<BiometricStatusResult> stale = repo.parked!;

      repo.answer(BiometricAttemptStatus.pending);
      c.pollNow();
      await _settle();
      expect(repo.tokensSeen, hasLength(3));

      // The superseded request answering late changes nothing.
      stale.complete(
        const BiometricStatusAnswered(
          BiometricAttemptStatusResponse(status: BiometricAttemptStatus.verified),
        ),
      );
      await _settle();
      expect(resubmit.calls, 0);
    });
  });
}
