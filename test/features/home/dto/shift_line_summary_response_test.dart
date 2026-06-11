import 'package:flutter_test/flutter_test.dart';
import 'package:thermoforming_roll_worker/features/home/data/dto/shift_line_summary_response.dart';
import 'package:thermoforming_roll_worker/features/home/domain/entities/allowed_roll.dart';
import 'package:thermoforming_roll_worker/features/home/domain/entities/shift_line_summary.dart';

Map<String, dynamic> _baseJson() => <String, dynamic>{
  'shiftLineId': 102,
  'thermoformingLineCode': 'TH-01',
  'thermoformingLineName': 'خط التشكيل 1',
  'completedRollsInSession': 5,
  'completedRollsByCurrentWorker': 5,
};

Map<String, dynamic> _consumedRollJson({
  int consumptionItemId = 900,
  int rollId = 12345,
  String generatedRollId = '001000000123',
  String rollTypeCode = 'TP-1',
  String rollTypeName = 'White',
  double startWeightKg = 200.0,
  double endWeightKg = 0.0,
  double consumedWeightKg = 200.0,
  double? remainingWeightKg,
  String closedReason = 'FULL_CONSUMPTION',
  String remainderAction = 'NONE',
  String endedAt = '2026-05-23T10:00:00.000Z',
  String endedAtDisplay = '23 أيار، 10:00 ص',
}) => <String, dynamic>{
  'consumptionItemId': consumptionItemId,
  'rollId': rollId,
  'generatedRollId': generatedRollId,
  'rollTypeCode': rollTypeCode,
  'rollTypeName': rollTypeName,
  'startWeightKg': startWeightKg,
  'endWeightKg': endWeightKg,
  'consumedWeightKg': consumedWeightKg,
  'remainingWeightKg': ?remainingWeightKg,
  'closedReason': closedReason,
  'remainderAction': remainderAction,
  'endedAt': endedAt,
  'endedAtDisplay': endedAtDisplay,
};

void main() {
  group('ShiftLineSummaryResponse', () {
    test('parses the renamed completedRollsInSession counter', () {
      final ShiftLineSummaryResponse dto =
          ShiftLineSummaryResponse.fromJson(_baseJson());

      expect(dto.completedRollsInSession, 5);
      expect(dto.completedRollsByCurrentWorker, 5);
      expect(dto.toEntity().completedRollsInSession, 5);
    });

    group('V104 productivity fields', () {
      test('parses consumedWeightKgInSession + rollsContributedInSession', () {
        final Map<String, dynamic> json = _baseJson()
          ..['consumedWeightKgInSession'] = 142.5
          ..['rollsContributedInSession'] = 3;

        final ShiftLineSummary entity =
            ShiftLineSummaryResponse.fromJson(json).toEntity();
        expect(entity.consumedWeightKgInSession, 142.5);
        expect(entity.rollsContributedInSession, 3);
      });

      test('defaults to null kg + 0 rolls on legacy data (fields absent)', () {
        final ShiftLineSummary entity =
            ShiftLineSummaryResponse.fromJson(_baseJson()).toEntity();
        expect(entity.consumedWeightKgInSession, isNull);
        expect(entity.rollsContributedInSession, 0);
      });
    });

    test('parses a consumedRolls array with one full-consumption item', () {
      final Map<String, dynamic> json = _baseJson()
        ..['consumedRolls'] = <Map<String, dynamic>>[_consumedRollJson()];

      final ShiftLineSummary entity =
          ShiftLineSummaryResponse.fromJson(json).toEntity();

      expect(entity.consumedRolls, hasLength(1));
      final ConsumedRoll roll = entity.consumedRolls.first;
      expect(roll.consumptionItemId, 900);
      expect(roll.rollId, 12345);
      expect(roll.generatedRollId, '001000000123');
      expect(roll.rollTypeCode, 'TP-1');
      expect(roll.startWeightKg, 200.0);
      expect(roll.consumedWeightKg, 200.0);
      expect(roll.remainingWeightKg, isNull);
      expect(roll.closedReason, 'FULL_CONSUMPTION');
      expect(roll.remainderAction, 'NONE');
      expect(roll.endedAtDisplay, '23 أيار، 10:00 ص');
      expect(roll.endedAt, DateTime.utc(2026, 5, 23, 10, 0, 0));
    });

    test('parses a partial-return item with remainingWeightKg', () {
      final Map<String, dynamic> json = _baseJson()
        ..['consumedRolls'] = <Map<String, dynamic>>[
          _consumedRollJson(
            consumptionItemId: 901,
            startWeightKg: 200.0,
            endWeightKg: 30.0,
            consumedWeightKg: 170.0,
            remainingWeightKg: 30.0,
            closedReason: 'PARTIAL_RETURN',
            remainderAction: 'RETURN',
          ),
        ];

      final ConsumedRoll roll =
          ShiftLineSummaryResponse.fromJson(json).toEntity().consumedRolls.first;

      expect(roll.consumedWeightKg, 170.0);
      expect(roll.remainingWeightKg, 30.0);
      expect(roll.closedReason, 'PARTIAL_RETURN');
      expect(roll.remainderAction, 'RETURN');
    });

    test(
      'absent consumedRolls key tolerates older backends and yields []',
      () {
        final ShiftLineSummary entity =
            ShiftLineSummaryResponse.fromJson(_baseJson()).toEntity();

        expect(entity.consumedRolls, isEmpty);
      },
    );

    test('malformed consumedRolls (non-list) is treated as empty', () {
      final Map<String, dynamic> json = _baseJson()
        ..['consumedRolls'] = 'not-a-list';

      final ShiftLineSummary entity =
          ShiftLineSummaryResponse.fromJson(json).toEntity();

      expect(entity.consumedRolls, isEmpty);
    });

    test('explicit empty consumedRolls list yields []', () {
      final Map<String, dynamic> json = _baseJson()
        ..['consumedRolls'] = <Map<String, dynamic>>[];

      final ShiftLineSummary entity =
          ShiftLineSummaryResponse.fromJson(json).toEntity();

      expect(entity.consumedRolls, isEmpty);
    });
  });

  group('ShiftLineSummaryResponse allowedRolls', () {
    test('a single allowed roll parses every field correctly', () {
      final Map<String, dynamic> json = _baseJson()
        ..['allowedRolls'] = <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 70,
            'code': 'TP-1',
            'name': 'Thin PP',
            'colorName': 'White',
            'thicknessStandardMm': 0.0300,
            'displayName': 'TP-1 / Thin PP',
            'preferred': true,
            'active': true,
          },
        ];

      final ShiftLineSummary entity =
          ShiftLineSummaryResponse.fromJson(json).toEntity();

      expect(entity.allowedRolls, hasLength(1));
      final AllowedRoll roll = entity.allowedRolls.first;
      expect(roll.id, 70);
      expect(roll.code, 'TP-1');
      expect(roll.name, 'Thin PP');
      expect(roll.colorName, 'White');
      expect(roll.thicknessStandardMm, 0.03);
      expect(roll.displayName, 'TP-1 / Thin PP');
      expect(roll.preferred, isTrue);
      expect(roll.active, isTrue);
      expect(roll.resolvedDisplayName, 'TP-1 / Thin PP');
    });

    test('multiple allowed rolls preserve backend order', () {
      final Map<String, dynamic> json = _baseJson()
        ..['allowedRolls'] = <Map<String, dynamic>>[
          <String, dynamic>{'id': 70, 'displayName': 'A', 'preferred': true},
          <String, dynamic>{'id': 71, 'displayName': 'B'},
          <String, dynamic>{'id': 72, 'displayName': 'C'},
        ];

      final List<AllowedRoll> rolls =
          ShiftLineSummaryResponse.fromJson(json).toEntity().allowedRolls;

      expect(rolls.map((AllowedRoll r) => r.id).toList(), <int>[70, 71, 72]);
      expect(rolls.map((AllowedRoll r) => r.displayName).toList(),
          <String>['A', 'B', 'C']);
    });

    test('explicit empty allowedRolls list yields []', () {
      final Map<String, dynamic> json = _baseJson()
        ..['allowedRolls'] = <Map<String, dynamic>>[];

      expect(
        ShiftLineSummaryResponse.fromJson(json).toEntity().allowedRolls,
        isEmpty,
      );
    });

    test('absent / null / malformed allowedRolls tolerates older backends', () {
      // Absent key.
      expect(
        ShiftLineSummaryResponse.fromJson(_baseJson()).toEntity().allowedRolls,
        isEmpty,
      );
      // Explicit null.
      expect(
        ShiftLineSummaryResponse.fromJson(_baseJson()..['allowedRolls'] = null)
            .toEntity()
            .allowedRolls,
        isEmpty,
      );
      // Malformed (non-list).
      expect(
        ShiftLineSummaryResponse.fromJson(
          _baseJson()..['allowedRolls'] = 'not-a-list',
        ).toEntity().allowedRolls,
        isEmpty,
      );
    });

    test('null optional fields do not crash and fall back for display', () {
      final Map<String, dynamic> json = _baseJson()
        ..['allowedRolls'] = <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 5,
            'code': null,
            'name': null,
            'colorName': null,
            'thicknessStandardMm': null,
            'displayName': null,
          },
        ];

      final AllowedRoll roll =
          ShiftLineSummaryResponse.fromJson(json).toEntity().allowedRolls.first;

      expect(roll.code, isNull);
      expect(roll.name, isNull);
      expect(roll.colorName, isNull);
      expect(roll.thicknessStandardMm, isNull);
      expect(roll.displayName, isNull);
      // displayName → code → name → generic placeholder.
      expect(roll.resolvedDisplayName, AllowedRoll.unknownLabel);
    });

    test('displayName falls back to code, then name', () {
      final Map<String, dynamic> codeOnly = _baseJson()
        ..['allowedRolls'] = <Map<String, dynamic>>[
          <String, dynamic>{'id': 1, 'code': 'TP-9', 'name': 'Nine'},
        ];
      expect(
        ShiftLineSummaryResponse.fromJson(codeOnly)
            .toEntity()
            .allowedRolls
            .first
            .resolvedDisplayName,
        'TP-9',
      );

      final Map<String, dynamic> nameOnly = _baseJson()
        ..['allowedRolls'] = <Map<String, dynamic>>[
          <String, dynamic>{'id': 1, 'name': 'Only Name'},
        ];
      expect(
        ShiftLineSummaryResponse.fromJson(nameOnly)
            .toEntity()
            .allowedRolls
            .first
            .resolvedDisplayName,
        'Only Name',
      );
    });

    test('preferred defaults to false when missing/null', () {
      final Map<String, dynamic> json = _baseJson()
        ..['allowedRolls'] = <Map<String, dynamic>>[
          <String, dynamic>{'id': 1, 'displayName': 'X'},
          <String, dynamic>{'id': 2, 'displayName': 'Y', 'preferred': null},
        ];

      final List<AllowedRoll> rolls =
          ShiftLineSummaryResponse.fromJson(json).toEntity().allowedRolls;
      expect(rolls[0].preferred, isFalse);
      expect(rolls[1].preferred, isFalse);
    });

    test('active defaults to true unless backend explicitly says false', () {
      final Map<String, dynamic> json = _baseJson()
        ..['allowedRolls'] = <Map<String, dynamic>>[
          <String, dynamic>{'id': 1, 'displayName': 'Default'},
          <String, dynamic>{'id': 2, 'displayName': 'Off', 'active': false},
        ];

      final List<AllowedRoll> rolls =
          ShiftLineSummaryResponse.fromJson(json).toEntity().allowedRolls;
      expect(rolls[0].active, isTrue);
      expect(rolls[1].active, isFalse);
    });
  });

  group('ShiftLineSummaryResponse mountedRoll', () {
    Map<String, dynamic> mountedRollJson({Object? lastKnownWeightKg = 101.0}) =>
        <String, dynamic>{
          'consumptionItemId': 555,
          'rollId': 67890,
          'generatedRollId': '001000000777',
          'rollTypeCode': 'TP-1',
          'rollTypeName': 'White',
          'lastKnownWeightKg': ?lastKnownWeightKg,
        };

    test('parses the mounted roll including lastKnownWeightKg', () {
      final Map<String, dynamic> json = _baseJson()
        ..['mountedRoll'] = mountedRollJson(lastKnownWeightKg: 101.0);

      final SummaryMountedRoll? roll =
          ShiftLineSummaryResponse.fromJson(json).toEntity().mountedRoll;

      expect(roll, isNotNull);
      expect(roll!.generatedRollId, '001000000777');
      expect(roll.rollTypeName, 'White');
      expect(roll.lastKnownWeightKg, 101.0);
    });

    test('coerces an integer weight to double', () {
      final Map<String, dynamic> json = _baseJson()
        ..['mountedRoll'] = mountedRollJson(lastKnownWeightKg: 75);

      final SummaryMountedRoll roll =
          ShiftLineSummaryResponse.fromJson(json).toEntity().mountedRoll!;

      expect(roll.lastKnownWeightKg, 75.0);
    });

    test('mounted roll with no lastKnownWeightKg → null (not substituted)', () {
      final Map<String, dynamic> json = _baseJson()
        ..['mountedRoll'] = mountedRollJson(lastKnownWeightKg: null);

      final SummaryMountedRoll roll =
          ShiftLineSummaryResponse.fromJson(json).toEntity().mountedRoll!;

      expect(roll.generatedRollId, '001000000777');
      expect(roll.lastKnownWeightKg, isNull);
    });

    test('absent mountedRoll key → null mountedRoll (no-mount state)', () {
      final SummaryMountedRoll? roll =
          ShiftLineSummaryResponse.fromJson(_baseJson()).toEntity().mountedRoll;

      expect(roll, isNull);
    });
  });
}
