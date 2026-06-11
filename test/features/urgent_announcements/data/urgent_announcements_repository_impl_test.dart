import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:thermoforming_roll_worker/core/errors/app_failure.dart';
import 'package:thermoforming_roll_worker/core/errors/error_code.dart';
import 'package:thermoforming_roll_worker/features/sessions_me/data/sessions_me_token_selector.dart';
import 'package:thermoforming_roll_worker/features/urgent_announcements/data/urgent_announcements_api.dart';
import 'package:thermoforming_roll_worker/features/urgent_announcements/data/urgent_announcements_repository_impl.dart';
import 'package:thermoforming_roll_worker/features/urgent_announcements/domain/entities/manager_announcement.dart';
import 'package:thermoforming_roll_worker/features/urgent_announcements/domain/urgent_announcements_repository.dart';

class _MockApi extends Mock implements UrgentAnnouncementsApi {}

class _MockTokenSelector extends Mock implements SessionsMeTokenSelector {}

DioException _businessError(String code, {int statusCode = 404}) {
  final RequestOptions options = RequestOptions(path: '/x');
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response<dynamic>(
      requestOptions: options,
      statusCode: statusCode,
      data: <String, dynamic>{
        'success': false,
        'error': <String, dynamic>{'code': code},
      },
    ),
  );
}

void main() {
  late _MockApi api;
  late _MockTokenSelector tokens;
  late UrgentAnnouncementsRepositoryImpl repo;

  setUp(() {
    api = _MockApi();
    tokens = _MockTokenSelector();
    repo = UrgentAnnouncementsRepositoryImpl(api: api, tokenSelector: tokens);
  });

  group('fetchPending', () {
    test('returns rollWorkerSessionRequired failure when no token', () async {
      when(() => tokens.resolveAnyToken()).thenAnswer((_) async => null);

      final PendingAnnouncementsResult result = await repo.fetchPending();

      expect(result, isA<PendingAnnouncementsFailure>());
      expect(
        (result as PendingAnnouncementsFailure).failure,
        isA<BusinessFailure>().having(
          (BusinessFailure f) => f.code,
          'code',
          ErrorCode.rollWorkerSessionRequired,
        ),
      );
      verifyNever(() => api.fetchPending(sessionToken: any(named: 'sessionToken')));
    });

    test('returns announcements on success', () async {
      when(() => tokens.resolveAnyToken()).thenAnswer((_) async => 'tok');
      when(
        () => api.fetchPending(sessionToken: any(named: 'sessionToken')),
      ).thenAnswer((_) async => <ManagerAnnouncement>[
        const ManagerAnnouncement(id: 5),
      ]);

      final PendingAnnouncementsResult result = await repo.fetchPending();

      expect(result, isA<PendingAnnouncementsSuccess>());
      expect((result as PendingAnnouncementsSuccess).announcements.single.id, 5);
    });
  });

  group('ack', () {
    test('returns success on a normal ack', () async {
      when(() => tokens.resolveAnyToken()).thenAnswer((_) async => 'tok');
      when(
        () => api.ack(id: any(named: 'id'), sessionToken: any(named: 'sessionToken')),
      ).thenAnswer((_) async {});

      expect(await repo.ack(1), isA<AckSuccess>());
    });

    test(
      'ROLL_ANNOUNCEMENT_NOT_FOUND is mapped to success (already acked/expired)',
      () async {
        when(() => tokens.resolveAnyToken()).thenAnswer((_) async => 'tok');
        when(
          () => api.ack(
            id: any(named: 'id'),
            sessionToken: any(named: 'sessionToken'),
          ),
        ).thenThrow(_businessError('ROLL_ANNOUNCEMENT_NOT_FOUND'));

        expect(await repo.ack(1), isA<AckSuccess>());
      },
    );

    test('a genuine failure is surfaced as AckFailure', () async {
      when(() => tokens.resolveAnyToken()).thenAnswer((_) async => 'tok');
      when(
        () => api.ack(id: any(named: 'id'), sessionToken: any(named: 'sessionToken')),
      ).thenThrow(_businessError('VALIDATION_ERROR', statusCode: 400));

      final AckResult result = await repo.ack(1);
      expect(result, isA<AckFailure>());
    });

    test('returns rollWorkerSessionRequired failure when no token', () async {
      when(() => tokens.resolveAnyToken()).thenAnswer((_) async => null);

      final AckResult result = await repo.ack(1);
      expect(result, isA<AckFailure>());
      expect(
        (result as AckFailure).failure,
        isA<BusinessFailure>().having(
          (BusinessFailure f) => f.code,
          'code',
          ErrorCode.rollWorkerSessionRequired,
        ),
      );
    });
  });
}
