import 'package:flutter_test/flutter_test.dart';
import 'package:thermoforming_roll_worker/core/errors/error_code.dart';
import 'package:thermoforming_roll_worker/features/roll_search/data/dto/roll_production_time_search_response.dart';
import 'package:thermoforming_roll_worker/features/roll_search/domain/entities/roll_search_outcome.dart';

Map<String, dynamic> _roll({
  int rollId = 11,
  String generatedRollId = '777000000011',
  bool mountable = true,
  Map<String, dynamic>? blocked,
}) => <String, dynamic>{
  'rollId': rollId,
  'generatedRollId': generatedRollId,
  'producedAt': '2026-09-30T11:05:37Z',
  'rollTypeId': 70,
  'rollTypeRollCode': 'TT-1S B250 White',
  'rollTypeDisplayName': 'TT-1S B250',
  'colorName': 'White',
  'productionKind': 'NORMAL',
  'producedWeightKg': 250.5,
  'currentWeightKg': 120,
  'consumptionState': 'AVAILABLE',
  'consumptionStateLabel': 'متاح',
  'mountable': mountable,
  'mountBlockedReason': ?blocked,
};

void main() {
  test('FOUND parses the single roll', () {
    final RollSearchOutcome o = RollProductionTimeSearchResponse.parse(
      <String, dynamic>{
        'status': 'FOUND',
        'searchedLocalMinute': '2026-09-30T14:05',
        'matchCount': 1,
        'roll': _roll(),
      },
    );
    expect(o.status, RollSearchStatus.found);
    expect(o.matchCount, 1);
    expect(o.searchedLocalMinute, '2026-09-30T14:05');
    expect(o.matches, hasLength(1));
    final RollSearchMatch m = o.matches.single;
    expect(m.rollId, 11);
    expect(m.generatedRollId, '777000000011');
    expect(m.rollTypeRollCode, 'TT-1S B250 White');
    expect(m.rollTypeDisplayName, 'TT-1S B250');
    expect(m.colorName, 'White');
    expect(m.productionKind, 'NORMAL');
    expect(m.producedWeightKg, 250.5);
    expect(m.currentWeightKg, 120.0);
    expect(m.consumptionState, 'AVAILABLE');
    expect(m.consumptionStateLabel, 'متاح');
    expect(m.mountable, isTrue);
    expect(m.mountRefusal, isNull);
    expect(o.isTruncated, isFalse);
  });

  test('producedAt parses as a UTC instant', () {
    final RollSearchMatch m = RollProductionTimeSearchResponse.parse(
      <String, dynamic>{'status': 'FOUND', 'matchCount': 1, 'roll': _roll()},
    ).matches.single;
    expect(m.producedAt!.isUtc, isTrue);
    expect(m.producedAt, DateTime.utc(2026, 9, 30, 11, 5, 37));
  });

  test('NOT_FOUND has no matches', () {
    final RollSearchOutcome o = RollProductionTimeSearchResponse.parse(
      <String, dynamic>{
        'status': 'NOT_FOUND',
        'searchedLocalMinute': '2026-09-30T14:05',
        'matchCount': 0,
      },
    );
    expect(o.status, RollSearchStatus.notFound);
    expect(o.matches, isEmpty);
    expect(o.matchCount, 0);
  });

  test('MULTIPLE_MATCHES parses candidates in order and flags truncation', () {
    final RollSearchOutcome o = RollProductionTimeSearchResponse.parse(
      <String, dynamic>{
        'status': 'MULTIPLE_MATCHES',
        'matchCount': 12,
        'candidates': <Map<String, dynamic>>[
          _roll(rollId: 1, generatedRollId: '777000000001'),
          _roll(rollId: 2, generatedRollId: '777000000002'),
        ],
      },
    );
    expect(o.status, RollSearchStatus.multipleMatches);
    expect(o.matchCount, 12);
    expect(
      o.matches.map((RollSearchMatch m) => m.generatedRollId),
      <String>['777000000001', '777000000002'],
    );
    expect(o.isTruncated, isTrue);
  });

  test('missing matchCount falls back to the number of matches', () {
    final RollSearchOutcome o = RollProductionTimeSearchResponse.parse(
      <String, dynamic>{
        'status': 'MULTIPLE_MATCHES',
        'candidates': <Map<String, dynamic>>[_roll(), _roll(rollId: 2)],
      },
    );
    expect(o.matchCount, 2);
  });

  test('refusal is mapped to a BusinessFailure with code and details', () {
    final RollSearchMatch m = RollProductionTimeSearchResponse.parse(
      <String, dynamic>{
        'status': 'FOUND',
        'matchCount': 1,
        'roll': _roll(
          mountable: false,
          blocked: <String, dynamic>{
            'code': 'ROLL_ALREADY_CONSUMED',
            'message': 'msg',
            'details': <String, dynamic>{'rollNumber': '777000000011'},
          },
        ),
      },
    ).matches.single;
    expect(m.mountable, isFalse);
    expect(m.mountRefusal!.code, ErrorCode.rollAlreadyConsumed);
    expect(m.mountRefusal!.serverMessage, 'msg');
    expect(m.mountRefusal!.details, <String, dynamic>{
      'rollNumber': '777000000011',
    });
  });

  test('refusal codes map to their ErrorCode', () {
    const Map<String, ErrorCode> cases = <String, ErrorCode>{
      'SHIFT_LINE_ALREADY_HAS_ACTIVE_ROLL':
          ErrorCode.shiftLineAlreadyHasActiveRoll,
      'ROLL_GRINDING_APPROVAL_PENDING': ErrorCode.rollGrindingApprovalPending,
      'ROLL_SCRAP_RESERVED_FOR_GRINDING':
          ErrorCode.rollScrapReservedForGrinding,
      'ROLL_TYPE_NOT_ALLOWED_FOR_PRODUCT':
          ErrorCode.rollTypeNotAllowedForProduct,
    };
    cases.forEach((String wire, ErrorCode code) {
      final RollSearchMatch m = RollProductionTimeSearchResponse.parse(
        <String, dynamic>{
          'status': 'FOUND',
          'matchCount': 1,
          'roll': _roll(
            mountable: false,
            blocked: <String, dynamic>{'code': wire},
          ),
        },
      ).matches.single;
      expect(m.mountRefusal!.code, code, reason: wire);
    });
  });

  test('non-mountable without a reason is still non-mountable (code unknown)',
      () {
    final RollSearchMatch m = RollProductionTimeSearchResponse.parse(
      <String, dynamic>{
        'status': 'FOUND',
        'matchCount': 1,
        'roll': _roll(mountable: false),
      },
    ).matches.single;
    expect(m.mountable, isFalse);
    expect(m.mountRefusal, isNotNull);
    expect(m.mountRefusal!.code, ErrorCode.unknown);
  });

  test('a missing mountable flag is treated as not mountable', () {
    final Map<String, dynamic> roll = _roll()..remove('mountable');
    final RollSearchMatch m = RollProductionTimeSearchResponse.parse(
      <String, dynamic>{'status': 'FOUND', 'matchCount': 1, 'roll': roll},
    ).matches.single;
    expect(m.mountable, isFalse);
  });

  test('optional fields may be omitted', () {
    final RollSearchMatch m = RollProductionTimeSearchResponse.parse(
      <String, dynamic>{
        'status': 'FOUND',
        'matchCount': 1,
        'roll': <String, dynamic>{
          'rollId': 5,
          'generatedRollId': '777000000005',
          'mountable': true,
        },
      },
    ).matches.single;
    expect(m.producedAt, isNull);
    expect(m.producedWeightKg, isNull);
    expect(m.colorName, isNull);
    expect(m.consumptionState, 'AVAILABLE');
  });

  test('unknown or missing status throws FormatException', () {
    expect(
      () => RollProductionTimeSearchResponse.parse(<String, dynamic>{
        'status': 'WHATEVER',
      }),
      throwsFormatException,
    );
    expect(
      () => RollProductionTimeSearchResponse.parse(<String, dynamic>{}),
      throwsFormatException,
    );
  });

  test('FOUND without a roll object, or a match without ids, throws', () {
    expect(
      () => RollProductionTimeSearchResponse.parse(<String, dynamic>{
        'status': 'FOUND',
        'matchCount': 1,
      }),
      throwsFormatException,
    );
    expect(
      () => RollProductionTimeSearchResponse.parse(<String, dynamic>{
        'status': 'FOUND',
        'matchCount': 1,
        'roll': <String, dynamic>{'mountable': true},
      }),
      throwsFormatException,
    );
  });
}
