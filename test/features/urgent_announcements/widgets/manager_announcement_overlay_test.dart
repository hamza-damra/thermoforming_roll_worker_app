import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:thermoforming_roll_worker/core/errors/app_failure.dart';
import 'package:thermoforming_roll_worker/core/errors/error_code.dart';
import 'package:thermoforming_roll_worker/core/errors/error_messages_ar.dart';
import 'package:thermoforming_roll_worker/core/storage/session_index_storage.dart';
import 'package:thermoforming_roll_worker/core/storage/storage_providers.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/data/roll_worker_auth_providers.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/domain/entities/roll_worker_session.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/domain/roll_worker_auth_repository.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/presentation/controllers/multi_line_session_registry.dart';
import 'package:thermoforming_roll_worker/features/urgent_announcements/data/urgent_announcements_providers.dart';
import 'package:thermoforming_roll_worker/features/urgent_announcements/domain/entities/manager_announcement.dart';
import 'package:thermoforming_roll_worker/features/urgent_announcements/domain/urgent_announcements_repository.dart';
import 'package:thermoforming_roll_worker/features/urgent_announcements/presentation/widgets/manager_announcement_overlay.dart';
import 'package:thermoforming_roll_worker/features/urgent_announcements/presentation/widgets/urgent_announcement_strings.dart';

class _MockRepo extends Mock implements UrgentAnnouncementsRepository {}

class _MockAuthRepo extends Mock implements RollWorkerAuthRepository {}

class _MockRawStorage extends Mock implements FlutterSecureStorage {}

const String kCreatedAtDisplay = '2026-07-31، 12:00 مساءً';

RollWorkerSession _session(int shiftLineId) => RollWorkerSession(
  sessionId: shiftLineId * 10,
  rollWorkerOperatorId: 7,
  rollWorkerName: 'Ahmad',
  thermoformingShiftId: 900,
  thermoformingShiftLineId: shiftLineId,
  thermoformingLineId: shiftLineId + 100,
  palletizingLineId: shiftLineId + 200,
  startedAt: DateTime.parse('2026-07-31T10:00:00.000+03:00'),
);

/// Logs a worker in (which fetches one pending notice), pumps the overlay, and
/// taps "فهمت" so an ack failure of [ackFailure] is on screen.
Future<void> _pumpAckFailure(
  WidgetTester tester, {
  AppFailure? ackFailure,
}) async {
  final _MockRepo repo = _MockRepo();
  final _MockAuthRepo auth = _MockAuthRepo();
  final _MockRawStorage raw = _MockRawStorage();

  when(() => raw.read(key: any<String>(named: 'key')))
      .thenAnswer((_) async => null);
  when(
    () => raw.write(
      key: any<String>(named: 'key'),
      value: any<String>(named: 'value'),
    ),
  ).thenAnswer((_) async {});
  when(() => auth.clearStoredToken(any<int>())).thenAnswer((_) async {});
  when(repo.fetchPending).thenAnswer(
    (_) async => const PendingAnnouncementsSuccess(<ManagerAnnouncement>[
      ManagerAnnouncement(id: 1, createdAtDisplay: kCreatedAtDisplay),
    ]),
  );
  if (ackFailure != null) {
    when(() => repo.ack(any<int>()))
        .thenAnswer((_) async => AckFailure(ackFailure));
  }

  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[
      rollWorkerAuthRepositoryProvider.overrideWithValue(auth),
      sessionIndexStorageProvider.overrideWithValue(
        SessionIndexStorage.withStorage(raw),
      ),
      urgentAnnouncementsRepositoryProvider.overrideWithValue(repo),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: ManagerAnnouncementOverlay()),
        ),
      ),
    ),
  );

  await container
      .read(multiLineSessionRegistryProvider.notifier)
      .onBatchSuccess(<int, RollWorkerSession>{81: _session(81)});
  await tester.pumpAndSettle();

  if (ackFailure != null) {
    await tester.tap(find.text(UrgentAnnouncementStrings.ackButton));
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets(
    'PRIVACY: renders only the fixed sanitized copy plus createdAtDisplay',
    (WidgetTester tester) async {
      await _pumpAckFailure(tester);

      expect(find.text(UrgentAnnouncementStrings.title), findsOneWidget);
      expect(find.text(UrgentAnnouncementStrings.message), findsOneWidget);
      expect(find.text(kCreatedAtDisplay), findsOneWidget);
      // Nothing is on screen before an ack is attempted.
      expect(find.text(UrgentAnnouncementStrings.ackError), findsNothing);
    },
  );

  testWidgets('an ordinary ack failure keeps the announcement-specific copy',
      (WidgetTester tester) async {
    await _pumpAckFailure(tester, ackFailure: const NetworkFailure());

    // Transient: "tap again" is the right next step, so the fixed ack string
    // beats the generic mapper text.
    expect(find.text(UrgentAnnouncementStrings.ackError), findsOneWidget);
  });

  testWidgets(
    'a device-key fault shows the device-configuration message, NOT the '
    'ack-retry or session copy',
    (WidgetTester tester) async {
      await _pumpAckFailure(
        tester,
        ackFailure: const BusinessFailure(
          code: ErrorCode.authInvalidCredentials,
          statusCode: 401,
        ),
      );

      expect(
        find.text(arabicForErrorCode(ErrorCode.authInvalidCredentials)),
        findsOneWidget,
      );
      expect(find.text(UrgentAnnouncementStrings.ackError), findsNothing);
      expect(
        find.text(arabicForErrorCode(ErrorCode.rollWorkerSessionRequired)),
        findsNothing,
      );
    },
  );

  testWidgets('a session fault shows the re-authenticate message',
      (WidgetTester tester) async {
    await _pumpAckFailure(
      tester,
      ackFailure: const BusinessFailure(
        code: ErrorCode.rollWorkerSessionRequired,
        statusCode: 401,
      ),
    );

    expect(
      find.text(arabicForErrorCode(ErrorCode.rollWorkerSessionRequired)),
      findsOneWidget,
    );
    expect(find.text(UrgentAnnouncementStrings.ackError), findsNothing);
  });
}
