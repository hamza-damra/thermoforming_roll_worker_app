import 'package:flutter_test/flutter_test.dart';
import 'package:thermoforming_roll_worker/features/home/data/dto/shift_line_summary_response.dart';
import 'package:thermoforming_roll_worker/features/home/domain/entities/line_takeover.dart';

Map<String, dynamic> _baseJson() => <String, dynamic>{
  'shiftLineId': 800,
  'thermoformingLineCode': 'TH-01',
  'thermoformingLineName': 'خط التشكيل 1',
  'completedRollsInSession': 5,
  'completedRollsByCurrentWorker': 2,
};

void main() {
  group('TakeoverStatus.fromWire', () {
    test('maps known wire values', () {
      expect(TakeoverStatus.fromWire('PENDING'), TakeoverStatus.pending);
      expect(TakeoverStatus.fromWire('ACCEPTED'), TakeoverStatus.accepted);
      expect(
        TakeoverStatus.fromWire('POST_ACCEPT_TIMEOUT_AUTO_RELEASED'),
        TakeoverStatus.postAcceptTimeoutAutoReleased,
      );
    });

    test('unknown / null map to unknown without throwing', () {
      expect(TakeoverStatus.fromWire('SOMETHING_NEW'), TakeoverStatus.unknown);
      expect(TakeoverStatus.fromWire(null), TakeoverStatus.unknown);
    });
  });

  group('LineTakeover getters', () {
    test('effectivePendingExpiry prefers the absolute timestamp', () {
      final DateTime expires = DateTime(2026, 5, 16, 12);
      final LineTakeover t = LineTakeover(
        status: TakeoverStatus.pending,
        observedAt: DateTime(2026, 5, 16, 11),
        expiresAt: expires,
        remainingSeconds: 30,
      );
      expect(t.effectivePendingExpiry, expires);
    });

    test('effectivePendingExpiry falls back to observedAt + remainingSeconds',
        () {
      final DateTime observed = DateTime(2026, 5, 16, 11);
      final LineTakeover t = LineTakeover(
        status: TakeoverStatus.pending,
        observedAt: observed,
        remainingSeconds: 600,
      );
      expect(t.effectivePendingExpiry, observed.add(const Duration(minutes: 10)));
    });

    test('isActive / forcesWorkBlock reflect the status', () {
      LineTakeover withStatus(TakeoverStatus s) =>
          LineTakeover(status: s, observedAt: DateTime(2026));

      expect(withStatus(TakeoverStatus.pending).isActive, isTrue);
      expect(withStatus(TakeoverStatus.accepted).isActive, isTrue);
      expect(withStatus(TakeoverStatus.completed).isActive, isFalse);
      expect(withStatus(TakeoverStatus.rejected).isActive, isFalse);

      expect(withStatus(TakeoverStatus.pending).forcesWorkBlock, isFalse);
      expect(
        withStatus(TakeoverStatus.timeoutAutoReleased).forcesWorkBlock,
        isTrue,
      );
      expect(
        withStatus(TakeoverStatus.postAcceptTimeoutAutoReleased).forcesWorkBlock,
        isTrue,
      );
    });
  });

  group('ShiftLineSummaryResponse takeover parsing', () {
    test('absent fields → takeover null, blocked false', () {
      final summary = ShiftLineSummaryResponse.fromJson(_baseJson()).toEntity();
      expect(summary.takeover, isNull);
      expect(summary.blocked, isFalse);
      expect(summary.blockedReason, isNull);
    });

    test('blocked + blockedReason are parsed', () {
      final json = _baseJson()
        ..['blocked'] = true
        ..['blockedReason'] = 'الخط في وضع تسليم';
      final summary = ShiftLineSummaryResponse.fromJson(json).toEntity();
      expect(summary.blocked, isTrue);
      expect(summary.blockedReason, 'الخط في وضع تسليم');
    });

    test('nested pendingTakeoverRequest builds a LineTakeover', () {
      final json = _baseJson()
        ..['takeoverRequestStatus'] = 'PENDING'
        ..['pendingTakeoverRequest'] = <String, dynamic>{
          'id': 4321,
          'status': 'PENDING',
          'requestedByOperatorName': 'سامي',
          'currentOperatorName': 'خالد',
          'expiresAt': '2026-05-16T12:00:00Z',
          'remainingSeconds': 540,
          'handoverRemainingSeconds': 300,
        };
      final summary = ShiftLineSummaryResponse.fromJson(json).toEntity();
      final LineTakeover t = summary.takeover!;
      expect(t.status, TakeoverStatus.pending);
      expect(t.requestId, 4321);
      expect(t.requestedByOperatorName, 'سامي');
      expect(t.currentOperatorName, 'خالد');
      expect(t.expiresAt, DateTime.parse('2026-05-16T12:00:00Z'));
      expect(t.remainingSeconds, 540);
      expect(t.handoverRemainingSeconds, 300);
    });

    test('flat takeover* fields are used as a fallback', () {
      final json = _baseJson()
        ..['takeoverRequestStatus'] = 'ACCEPTED'
        ..['takeoverRemainingSeconds'] = 480
        ..['takeoverHandoverRemainingSeconds'] = 250
        ..['takeoverRequestedByOperatorName'] = 'سامي'
        ..['takeoverCurrentOperatorName'] = 'خالد';
      final summary = ShiftLineSummaryResponse.fromJson(json).toEntity();
      final LineTakeover t = summary.takeover!;
      expect(t.status, TakeoverStatus.accepted);
      expect(t.remainingSeconds, 480);
      expect(t.handoverRemainingSeconds, 250);
      expect(t.requestedByOperatorName, 'سامي');
      expect(t.currentOperatorName, 'خالد');
    });

    test('unknown takeover status does not crash, maps to unknown', () {
      final json = _baseJson()..['takeoverRequestStatus'] = 'BRAND_NEW_STATUS';
      final summary = ShiftLineSummaryResponse.fromJson(json).toEntity();
      expect(summary.takeover!.status, TakeoverStatus.unknown);
    });
  });

  group('ShiftLineSummaryResponse line-state parsing', () {
    test('absent line-state fields → no operator, no product, not pending', () {
      final summary = ShiftLineSummaryResponse.fromJson(_baseJson()).toEntity();
      expect(summary.activeOperatorId, isNull);
      expect(summary.activeOperatorName, isNull);
      expect(summary.noActiveOperator, isTrue);
      expect(summary.activeProduct, isNull);
      expect(summary.handoverPending, isFalse);
      expect(summary.lineLifecycleStatus, isNull);
    });

    test('active operator + current product + lifecycle fields are parsed', () {
      final json = _baseJson()
        ..['activeOperatorId'] = 77
        ..['activeOperatorName'] = 'خالد'
        ..['currentProductTypeId'] = 6
        ..['currentProductName'] = 'Blue 10kg'
        ..['handoverPending'] = true
        ..['lineLifecycleStatus'] = 'ACTIVE';
      final summary = ShiftLineSummaryResponse.fromJson(json).toEntity();
      expect(summary.activeOperatorId, 77);
      expect(summary.activeOperatorName, 'خالد');
      expect(summary.noActiveOperator, isFalse);
      expect(summary.activeProduct?.productId, 6);
      expect(summary.activeProduct?.name, 'Blue 10kg');
      expect(summary.handoverPending, isTrue);
      expect(summary.lineLifecycleStatus, 'ACTIVE');
    });

    test('current product needs both id and name — partial → null', () {
      final json = _baseJson()..['currentProductName'] = 'Blue 10kg';
      final summary = ShiftLineSummaryResponse.fromJson(json).toEntity();
      expect(summary.activeProduct, isNull);
    });
  });
}
