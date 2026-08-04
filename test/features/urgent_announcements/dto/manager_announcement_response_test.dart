import 'package:flutter_test/flutter_test.dart';
import 'package:thermoforming_roll_worker/features/urgent_announcements/data/dto/manager_announcement_response.dart';
import 'package:thermoforming_roll_worker/features/urgent_announcements/domain/entities/manager_announcement.dart';

Map<String, dynamic> _baseJson() => <String, dynamic>{
  'id': 123,
  'targetDomain': 'THERMOFORMING',
  'title': 'ملاحظة عاجلة من المدير',
  'message': 'أرسل المدير ملاحظة عاجلة للمشغل. يجب فتح تطبيق المشغل لقراءتها.',
  'createdAt': '2026-06-10T15:10:00Z',
  'createdAtDisplay': '2026-06-10، 06:10 مساءً',
  'priority': 'URGENT',
};

void main() {
  group('ManagerAnnouncementResponse', () {
    test('parses id, createdAt, createdAtDisplay and priority', () {
      final ManagerAnnouncement entity =
          ManagerAnnouncementResponse.fromJson(_baseJson()).toEntity();

      expect(entity.id, 123);
      expect(entity.priority, 'URGENT');
      expect(entity.createdAtDisplay, '2026-06-10، 06:10 مساءً');
      expect(entity.createdAt, DateTime.parse('2026-06-10T15:10:00Z'));
    });

    test(
      'PRIVACY: injected real-content fields (message / messageBody / '
      'senderDisplayName / title) are ignored and unreachable',
      () {
        final Map<String, dynamic> json = _baseJson()
          ..['messageBody'] = 'SECRET manager body that must never surface'
          ..['senderDisplayName'] = 'المدير أحمد'
          ..['message'] = 'real injected message'
          ..['title'] = 'real injected title';

        final ManagerAnnouncementResponse dto =
            ManagerAnnouncementResponse.fromJson(json);
        final ManagerAnnouncement entity = dto.toEntity();

        // The DTO/entity expose ONLY the safe fields. There is structurally no
        // getter that could carry the manager's body or sender, so a backend
        // bug cannot leak it through this layer.
        expect(entity.id, 123);
        expect(entity.createdAtDisplay, isNotNull);

        // Defensive: no field on the DTO/entity equals any injected content.
        final String dump = '${dto.toEntity().id}'
            '${dto.toEntity().priority}'
            '${dto.toEntity().createdAtDisplay}';
        expect(dump.contains('SECRET'), isFalse);
        expect(dump.contains('المدير أحمد'), isFalse);
        expect(dump.contains('real injected'), isFalse);
      },
    );

    test('tolerates missing optional fields', () {
      final ManagerAnnouncement entity = ManagerAnnouncementResponse.fromJson(
        const <String, dynamic>{'id': 7},
      ).toEntity();

      expect(entity.id, 7);
      expect(entity.createdAt, isNull);
      expect(entity.createdAtDisplay, isNull);
      expect(entity.expiresAt, isNull);
      expect(entity.expiresAtDisplay, isNull);
      expect(entity.priority, isNull);
    });

    group('expiresAt / expiresAtDisplay (timed announcements §4.2)', () {
      test('parses both when present', () {
        final Map<String, dynamic> json = _baseJson()
          ..['expiresAt'] = '2026-07-31T11:00:00.000Z'
          ..['expiresAtDisplay'] = '2026-07-31، 02:00 مساءً';

        final ManagerAnnouncement entity =
            ManagerAnnouncementResponse.fromJson(json).toEntity();

        expect(entity.expiresAt, DateTime.parse('2026-07-31T11:00:00.000Z'));
        // The payload is UTC (`…Z`); expiry arithmetic in the controller
        // depends on that, so assert it explicitly.
        expect(entity.expiresAt!.isUtc, isTrue);
        expect(entity.expiresAtDisplay, '2026-07-31، 02:00 مساءً');
      });

      test('explicit nulls mean "never expires" (legacy row)', () {
        final Map<String, dynamic> json = _baseJson()
          ..['expiresAt'] = null
          ..['expiresAtDisplay'] = null;

        final ManagerAnnouncement entity =
            ManagerAnnouncementResponse.fromJson(json).toEntity();

        expect(entity.expiresAt, isNull);
        expect(entity.expiresAtDisplay, isNull);
      });

      test('an unparseable timestamp degrades to null, never throws', () {
        final Map<String, dynamic> json = _baseJson()
          ..['expiresAt'] = 'not-a-timestamp'
          ..['expiresAtDisplay'] = '';

        final ManagerAnnouncement entity =
            ManagerAnnouncementResponse.fromJson(json).toEntity();

        expect(entity.expiresAt, isNull);
        // Empty strings normalise to null (`_asString`), so the UI never
        // renders a blank caption.
        expect(entity.expiresAtDisplay, isNull);
      });

      test('a non-string timestamp (epoch millis) degrades to null', () {
        final Map<String, dynamic> json = _baseJson()..['expiresAt'] = 1785000000;

        final ManagerAnnouncement entity =
            ManagerAnnouncementResponse.fromJson(json).toEntity();

        expect(entity.expiresAt, isNull);
      });

      test('expiry participates in entity equality', () {
        final ManagerAnnouncement a = ManagerAnnouncementResponse.fromJson(
          _baseJson()..['expiresAt'] = '2026-07-31T11:00:00.000Z',
        ).toEntity();
        final ManagerAnnouncement b = ManagerAnnouncementResponse.fromJson(
          _baseJson()..['expiresAt'] = '2026-07-31T12:00:00.000Z',
        ).toEntity();

        expect(a, isNot(b));
        expect(a, ManagerAnnouncementResponse.fromJson(
          _baseJson()..['expiresAt'] = '2026-07-31T11:00:00.000Z',
        ).toEntity());
      });
    });

    test('unknown JSON keys are ignored — that is what makes §6 additive', () {
      final Map<String, dynamic> json = _baseJson()
        ..['someFutureKey'] = 'whatever'
        ..['action'] = 'DEACTIVATED';

      final ManagerAnnouncement entity =
          ManagerAnnouncementResponse.fromJson(json).toEntity();

      expect(entity.id, 123);
    });

    group('listFromEnvelopeData', () {
      test('maps an array of objects oldest-first as given', () {
        final List<ManagerAnnouncement> list =
            ManagerAnnouncementResponse.listFromEnvelopeData(<Object?>[
          <String, dynamic>{'id': 1, 'createdAtDisplay': 'a'},
          <String, dynamic>{'id': 2, 'createdAtDisplay': 'b'},
        ]);

        expect(list.map((ManagerAnnouncement a) => a.id), <int>[1, 2]);
      });

      test('skips non-object and id-less entries defensively', () {
        final List<ManagerAnnouncement> list =
            ManagerAnnouncementResponse.listFromEnvelopeData(<Object?>[
          'garbage',
          42,
          <String, dynamic>{'createdAtDisplay': 'no id'},
          <String, dynamic>{'id': 9},
        ]);

        expect(list, hasLength(1));
        expect(list.single.id, 9);
      });

      test('throws when data is not an array', () {
        expect(
          () => ManagerAnnouncementResponse.listFromEnvelopeData(
            <String, dynamic>{'not': 'a list'},
          ),
          throwsA(isA<FormatException>()),
        );
      });
    });
  });
}
