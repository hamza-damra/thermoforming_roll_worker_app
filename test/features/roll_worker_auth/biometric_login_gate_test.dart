import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:thermoforming_roll_worker/core/errors/app_failure.dart';
import 'package:thermoforming_roll_worker/core/errors/biometric_denial.dart';
import 'package:thermoforming_roll_worker/core/errors/error_code.dart';
import 'package:thermoforming_roll_worker/core/errors/error_messages_ar.dart';
import 'package:thermoforming_roll_worker/core/storage/session_index_storage.dart';
import 'package:thermoforming_roll_worker/core/storage/storage_providers.dart';
import 'package:thermoforming_roll_worker/core/theme/app_theme.dart';
import 'package:thermoforming_roll_worker/features/biometric_login/data/biometric_login_providers.dart';
import 'package:thermoforming_roll_worker/features/biometric_login/domain/biometric_attempt_repository.dart';
import 'package:thermoforming_roll_worker/features/biometric_login/domain/entities/biometric_attempt_status.dart';
import 'package:thermoforming_roll_worker/features/biometric_login/presentation/controllers/biometric_poll_config.dart';
import 'package:thermoforming_roll_worker/features/biometric_login/presentation/widgets/biometric_login_dialog.dart';
import 'package:thermoforming_roll_worker/features/biometric_login/presentation/widgets/biometric_login_strings.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/data/roll_worker_auth_providers.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/domain/entities/batch_auth_outcome.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/domain/entities/roll_worker_session.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/domain/session_batch_repository.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/presentation/controllers/batch_auth_controller.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/presentation/controllers/batch_auth_state.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/presentation/controllers/multi_line_session_registry.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/presentation/controllers/multi_line_session_registry_state.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/presentation/widgets/roll_worker_auth_overlay.dart';

/// End-to-end through the real overlay → BatchAuthController → dialog →
/// attempt controller chain; only the two HTTP repositories are faked.
class _MockBatchRepo extends Mock implements SessionBatchRepository {}

class _MockIndexRaw extends Mock implements FlutterSecureStorage {}

/// Status endpoint that holds every long-poll until the test answers it.
class _HeldStatusRepo implements BiometricAttemptRepository {
  final List<Completer<BiometricStatusResult>> polls =
      <Completer<BiometricStatusResult>>[];
  final List<String> tokensSeen = <String>[];

  @override
  Future<BiometricStatusResult> getStatus({
    required String? statusPath,
    required String attemptToken,
  }) {
    tokensSeen.add(attemptToken);
    final Completer<BiometricStatusResult> c =
        Completer<BiometricStatusResult>();
    polls.add(c);
    return c.future;
  }

  void answer(BiometricAttemptStatus status) => polls.last.complete(
    BiometricStatusAnswered(BiometricAttemptStatusResponse(status: status)),
  );
}

const int _kShiftLineId = 800;
const String _token = 'q3Jx8d6cYt0H1m0yF3kZ0wS9gQx8B7nV2rP5aL4eK1c';
const String _token2 = 'second-attempt-token-secret';
const String _requiredMsg =
    'يرجى تمرير البصمة على جهاز البصمة ثم إعادة المحاولة.';
const String _mappingMsg =
    'لم يتم ربط بصمتك بحسابك بعد. يرجى مراجعة مسؤول النظام.';

BatchAuthOutcome _outcome() => BatchAuthOutcome(
  rollWorkerOperatorId: 77,
  rollWorkerName: 'Yusuf',
  sessions: <int, RollWorkerSession>{
    _kShiftLineId: RollWorkerSession(
      sessionId: 1,
      rollWorkerOperatorId: 77,
      rollWorkerName: 'Yusuf',
      thermoformingShiftId: 9001,
      thermoformingShiftLineId: _kShiftLineId,
      thermoformingLineId: 11,
      palletizingLineId: 21,
      startedAt: DateTime.utc(2026, 9, 24, 8),
    ),
  },
);

BatchAuthResult _denied({
  String code = 'BIOMETRIC_VERIFICATION_REQUIRED',
  String message = _requiredMsg,
  String? token = _token,
}) => BatchAuthFailureResult(
  BiometricDenialFailure(
    denial: BiometricDenial(
      code: code,
      message: message,
      validitySeconds: 300,
      attemptAvailable: token != null,
      attemptToken: token,
      statusPath: '/api/v1/auth/biometric/login-attempts/status',
    ),
    statusCode: 403,
  ),
);

class _Harness {
  _Harness(this.container, this.batch, this.status, this.indexRaw);
  final ProviderContainer container;
  final _MockBatchRepo batch;
  final _HeldStatusRepo status;
  final _MockIndexRaw indexRaw;

  /// Queue of answers for successive `startBatch` calls.
  final List<BatchAuthResult> logins = <BatchAuthResult>[];
  int loginCalls = 0;
}

_Harness _harness() {
  final batch = _MockBatchRepo();
  final status = _HeldStatusRepo();
  final raw = _MockIndexRaw();
  when(
    () => raw.read(key: any<String>(named: 'key')),
  ).thenAnswer((_) async => null);
  when(
    () => raw.write(
      key: any<String>(named: 'key'),
      value: any<String>(named: 'value'),
    ),
  ).thenAnswer((_) async {});

  final container = ProviderContainer(
    overrides: <Override>[
      sessionBatchRepositoryProvider.overrideWithValue(batch),
      sessionIndexStorageProvider.overrideWithValue(
        SessionIndexStorage.withStorage(raw),
      ),
      biometricAttemptRepositoryProvider.overrideWithValue(status),
      biometricPollConfigProvider.overrideWithValue(
        const BiometricPollConfig(minPollSpacing: Duration.zero),
      ),
    ],
  );
  addTearDown(container.dispose);

  final _Harness h = _Harness(container, batch, status, raw);
  when(
    () => batch.startBatch(pin: '1234', shiftLineIds: <int>{_kShiftLineId}),
  ).thenAnswer((_) async {
    h.loginCalls++;
    return h.logins.removeAt(0);
  });
  return h;
}

Widget _wrap(_Harness h) => UncontrolledProviderScope(
  container: h.container,
  child: MaterialApp(
    theme: AppTheme.light(),
    home: const Scaffold(
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: RollWorkerAuthOverlay(
              shiftLineId: _kShiftLineId,
              accentColor: Colors.teal,
            ),
          ),
        ],
      ),
    ),
  ),
);

/// The dialog shows an indeterminate progress bar while polling, so these
/// tests pump frames explicitly instead of `pumpAndSettle`.
Future<void> _frames(WidgetTester tester, [int n = 6]) async {
  for (int i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _login(WidgetTester tester, _Harness h) async {
  await tester.pumpWidget(_wrap(h));
  await tester.pump();
  await tester.enterText(find.byType(TextField), '1234');
  await tester.pump();
  await tester.tap(find.text(RollWorkerAuthOverlay.submitLabel));
  await _frames(tester);
}

Finder get _dialog => find.byType(BiometricLoginDialog);

bool _registryActive(_Harness h) =>
    h.container.read(multiLineSessionRegistryProvider) is RegistryActive;

void main() {
  setUpAll(() {
    registerFallbackValue(<int>{});
  });

  testWidgets(
    'the attempt token never reaches a debug log line during the whole flow',
    (WidgetTester tester) async {
      // Capture every debug log line for the whole flow (restored before the
      // body ends — the binding checks foundation debug vars right after).
      final List<String> logs = <String>[];
      final DebugPrintCallback original = debugPrint;
      debugPrint = (String? m, {int? wrapWidth}) => logs.add(m ?? '');

      final _Harness h = _harness();
      h.logins
        ..add(_denied())
        ..add(BatchAuthSuccessResult(_outcome()));

      try {
        await _login(tester, h);
        h.status.answer(BiometricAttemptStatus.verified);
        await _frames(tester);
      } finally {
        debugPrint = original;
      }
      expect(logs.join('\n'), isNot(contains(_token)));
      expect(h.loginCalls, 2);
    },
  );

  testWidgets(
    'login → 403 with token → dialog waits → scan (VERIFIED) → one resubmit '
    '→ dialog closes and the login completes like a normal one',
    (WidgetTester tester) async {
      final _Harness h = _harness();
      h.logins
        ..add(_denied())
        ..add(BatchAuthSuccessResult(_outcome()));

      await _login(tester, h);

      // Waiting state: no wrong-PIN error, no session yet.
      expect(_dialog, findsOneWidget);
      expect(find.text(BiometricLoginStrings.title), findsOneWidget);
      expect(find.text(BiometricLoginStrings.waiting), findsOneWidget);
      expect(find.text(BiometricLoginStrings.waitingSecondary), findsOneWidget);
      expect(find.text(_requiredMsg), findsOneWidget, reason: 'server text');
      expect(find.text(BiometricLoginStrings.cancelButton), findsOneWidget);
      expect(find.text(arabicForErrorCode(ErrorCode.operatorPinInvalid)), findsNothing);
      expect(_registryActive(h), isFalse);
      expect(h.status.tokensSeen, <String>[_token]);

      // The worker scans; the held long-poll answers.
      h.status.answer(BiometricAttemptStatus.verified);
      await _frames(tester);

      expect(_dialog, findsNothing);
      expect(h.loginCalls, 2, reason: 'exactly one resubmit');
      verify(
        () => h.batch.startBatch(pin: '1234', shiftLineIds: <int>{_kShiftLineId}),
      ).called(2);
      expect(_registryActive(h), isTrue);
      expect(h.status.polls, hasLength(1), reason: 'polling stopped');

      // The token was never persisted.
      final List<Object?> writes = verify(
        () => h.indexRaw.write(
          key: any<String>(named: 'key'),
          value: captureAny<String>(named: 'value'),
        ),
      ).captured;
      expect(writes.join(' '), isNot(contains(_token)));
    },
  );

  testWidgets('a non-biometric 403 keeps its inline handling — no dialog', (
    WidgetTester tester,
  ) async {
    final _Harness h = _harness();
    h.logins.add(
      const BatchAuthFailureResult(
        BusinessFailure(code: ErrorCode.rollWorkerNotAllowed, statusCode: 403),
      ),
    );

    await _login(tester, h);

    expect(_dialog, findsNothing);
    expect(find.text(RollWorkerAuthOverlay.unauthorizedHelper), findsOneWidget);
    expect(h.status.tokensSeen, isEmpty);
  });

  testWidgets('«إلغاء» stops polling and re-enables the PIN overlay', (
    WidgetTester tester,
  ) async {
    final _Harness h = _harness();
    h.logins.add(_denied());

    await _login(tester, h);
    expect(_dialog, findsOneWidget);

    await tester.tap(find.text(BiometricLoginStrings.cancelButton));
    await _frames(tester);

    expect(_dialog, findsNothing);
    expect(
      h.container.read(batchAuthControllerProvider),
      isA<BatchAuthInitial>(),
    );
    // The held poll answering late does not resubmit.
    h.status.answer(BiometricAttemptStatus.verified);
    await _frames(tester);
    expect(h.loginCalls, 1);
    expect(h.status.polls, hasLength(1));
    expect(_registryActive(h), isFalse);

    // The overlay is usable again: a fresh login goes through.
    h.logins.add(BatchAuthSuccessResult(_outcome()));
    await tester.enterText(find.byType(TextField), '1234');
    await tester.pump();
    await tester.tap(find.text(RollWorkerAuthOverlay.submitLabel));
    await _frames(tester);
    expect(h.loginCalls, 2);
    expect(_registryActive(h), isTrue);
  });

  testWidgets('MAPPING_MISSING → contact admin → «حسنًا» → server message inline', (
    WidgetTester tester,
  ) async {
    final _Harness h = _harness();
    h.logins.add(
      _denied(code: 'BIOMETRIC_MAPPING_MISSING', message: _mappingMsg, token: null),
    );

    await _login(tester, h);

    expect(_dialog, findsOneWidget);
    expect(find.text(_mappingMsg), findsOneWidget);
    expect(find.text(BiometricLoginStrings.okButton), findsOneWidget);
    expect(find.text(BiometricLoginStrings.retryButton), findsNothing);
    expect(h.status.tokensSeen, isEmpty, reason: 'never polled');

    await tester.tap(find.text(BiometricLoginStrings.okButton));
    await _frames(tester);

    expect(_dialog, findsNothing);
    expect(find.text(_mappingMsg), findsOneWidget, reason: 'inline on overlay');
    expect(h.loginCalls, 1, reason: 'no automatic retry');
  });

  testWidgets(
    '403 without a token → retry state → «إعادة المحاولة» re-submits the '
    'login without re-typing the PIN',
    (WidgetTester tester) async {
      final _Harness h = _harness();
      h.logins
        ..add(_denied(token: null))
        ..add(BatchAuthSuccessResult(_outcome()));

      await _login(tester, h);

      expect(find.text(_requiredMsg), findsOneWidget);
      expect(find.text(BiometricLoginStrings.retryButton), findsOneWidget);
      expect(h.status.tokensSeen, isEmpty);

      await tester.tap(find.text(BiometricLoginStrings.retryButton));
      await _frames(tester);

      expect(h.loginCalls, 2);
      expect(_dialog, findsNothing);
      expect(_registryActive(h), isTrue);
    },
  );

  testWidgets('410 → retry state with the dialog\'s own text', (
    WidgetTester tester,
  ) async {
    final _Harness h = _harness();
    h.logins.add(_denied());

    await _login(tester, h);
    h.status.polls.last.complete(const BiometricStatusAttemptExpired());
    await _frames(tester);

    expect(find.text(BiometricLoginStrings.retry), findsOneWidget);
    expect(find.text(BiometricLoginStrings.retryButton), findsOneWidget);
  });

  testWidgets(
    'resubmit meets an expired fingerprint → new attempt (new token) in the '
    'same dialog, no resubmit loop',
    (WidgetTester tester) async {
      final _Harness h = _harness();
      h.logins
        ..add(_denied())
        ..add(
          _denied(
            code: 'BIOMETRIC_VERIFICATION_EXPIRED',
            message: 'انتهت صلاحية التحقق بالبصمة.',
            token: _token2,
          ),
        );

      await _login(tester, h);
      h.status.answer(BiometricAttemptStatus.verified);
      await _frames(tester);

      expect(_dialog, findsOneWidget);
      expect(find.text('انتهت صلاحية التحقق بالبصمة.'), findsOneWidget);
      expect(h.loginCalls, 2);
      expect(h.status.tokensSeen, <String>[_token, _token2]);
    },
  );

  testWidgets(
    'resubmit returns a normal credential error → dialog closes, error inline',
    (WidgetTester tester) async {
      final _Harness h = _harness();
      h.logins
        ..add(_denied())
        ..add(
          const BatchAuthFailureResult(
            BusinessFailure(code: ErrorCode.operatorPinInvalid),
          ),
        );

      await _login(tester, h);
      h.status.answer(BiometricAttemptStatus.notRequired);
      await _frames(tester);

      expect(_dialog, findsNothing);
      expect(
        find.text(arabicForErrorCode(ErrorCode.operatorPinInvalid)),
        findsOneWidget,
      );
      expect(_registryActive(h), isFalse);
    },
  );

  testWidgets('device offline from the 403, then from the status', (
    WidgetTester tester,
  ) async {
    final _Harness h = _harness();
    h.logins.add(
      _denied(code: 'BIOMETRIC_DEVICE_UNAVAILABLE', message: 'offline-server'),
    );

    await _login(tester, h);
    expect(find.text('offline-server'), findsOneWidget);

    h.status.answer(BiometricAttemptStatus.pending);
    await _frames(tester);
    expect(find.text(BiometricLoginStrings.waiting), findsOneWidget);

    h.status.answer(BiometricAttemptStatus.deviceUnavailable);
    await _frames(tester);
    expect(find.text(BiometricLoginStrings.deviceOffline), findsOneWidget);
    expect(h.status.polls, hasLength(3), reason: 'still polling');
  });

  testWidgets('a failed status call shows the network state and backs off', (
    WidgetTester tester,
  ) async {
    final _Harness h = _harness();
    h.logins.add(_denied());

    await _login(tester, h);
    h.status.polls.last.complete(
      const BiometricStatusUnreachable(NetworkFailure()),
    );
    await _frames(tester, 2);

    expect(find.text(BiometricLoginStrings.network), findsOneWidget);
    expect(h.status.polls, hasLength(1));

    await tester.pump(const Duration(seconds: 1));
    expect(h.status.polls, hasLength(2), reason: 'retried after 1 s');
  });

  testWidgets('app resume polls immediately', (WidgetTester tester) async {
    final _Harness h = _harness();
    h.logins.add(_denied());

    await _login(tester, h);
    expect(h.status.polls, hasLength(1));

    for (final AppLifecycleState s in <AppLifecycleState>[
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(s);
    }
    await _frames(tester, 2);

    expect(h.status.polls, hasLength(2));
  });

  testWidgets('two quick taps on «دخول» → one login, one dialog', (
    WidgetTester tester,
  ) async {
    final _Harness h = _harness();
    h.logins.add(_denied());

    await tester.pumpWidget(_wrap(h));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '1234');
    await tester.pump();
    await tester.tap(find.text(RollWorkerAuthOverlay.submitLabel));
    await tester.tap(
      find.text(RollWorkerAuthOverlay.submitLabel),
      warnIfMissed: false,
    );
    await _frames(tester);

    expect(h.loginCalls, 1);
    expect(_dialog, findsOneWidget);
  });

  testWidgets('the dialog cannot be dismissed by the back button or outside tap', (
    WidgetTester tester,
  ) async {
    final _Harness h = _harness();
    h.logins.add(_denied());

    await _login(tester, h);
    await tester.tapAt(const Offset(5, 5));
    await _frames(tester, 2);
    expect(_dialog, findsOneWidget);

    final NavigatorState nav = tester.state(find.byType(Navigator).first);
    await nav.maybePop();
    await _frames(tester, 2);
    expect(_dialog, findsOneWidget);
  });
}
