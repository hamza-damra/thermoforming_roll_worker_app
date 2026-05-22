import 'package:flutter_test/flutter_test.dart';
import 'package:thermoforming_roll_worker/features/operator_dashboard_sse/data/sse_frame_parser.dart';
import 'package:thermoforming_roll_worker/features/operator_dashboard_sse/domain/entities/operator_dashboard_event.dart';

void main() {
  group('SseFrameParser', () {
    test('feeds a single event-data-blank record and emits it once', () {
      final parser = SseFrameParser();
      final events = parser
          .feed('event: connected\ndata: {"v":1}\n\n')
          .toList();
      expect(events, hasLength(1));
      expect(events.single.name, 'connected');
      expect(events.single.data, '{"v":1}');
    });

    test('strips at most one leading space from a data: value', () {
      final parser = SseFrameParser();
      final events = parser.feed('event: x\ndata:  payload\n\n').toList();
      expect(events.single.data, ' payload');
    });

    test('ignores `:` comment lines (heartbeats)', () {
      final parser = SseFrameParser();
      final events = parser
          .feed(': ping\n\nevent: foo\ndata: bar\n\n')
          .toList();
      expect(events, hasLength(1));
      expect(events.single.name, 'foo');
      expect(events.single.data, 'bar');
    });

    test('reassembles a record split across multiple chunks', () {
      final parser = SseFrameParser();
      expect(parser.feed('event: ope').toList(), isEmpty);
      expect(parser.feed('rator-dashboard-changed\n').toList(), isEmpty);
      expect(parser.feed('data: {"line').toList(), isEmpty);
      final emitted = parser
          .feed('Id":10,"reason":"PRODUCT_CHANGED"}\n\nremainder')
          .toList();
      expect(emitted, hasLength(1));
      expect(emitted.single.name, 'operator-dashboard-changed');
      expect(emitted.single.data, '{"lineId":10,"reason":"PRODUCT_CHANGED"}');
    });

    test('handles CRLF line endings by stripping the trailing \\r', () {
      final parser = SseFrameParser();
      final events = parser.feed('event: a\r\ndata: b\r\n\r\n').toList();
      expect(events.single.name, 'a');
      expect(events.single.data, 'b');
    });

    test('concatenates multiple data: lines with newline separators', () {
      final parser = SseFrameParser();
      final events = parser.feed('event: x\ndata: one\ndata: two\n\n').toList();
      expect(events.single.data, 'one\ntwo');
    });

    test(
      'finish() flushes a dangling record with no terminating blank line',
      () {
        final parser = SseFrameParser();
        parser.feed('event: x\ndata: ').toList();
        parser.feed('payload').toList();
        final tail = parser.finish();
        expect(tail, isNotNull);
        expect(tail!.name, 'x');
        expect(tail.data, 'payload');
      },
    );
  });

  group('OperatorDashboardFrameParser.parse', () {
    RawSseEvent changed(String body) =>
        RawSseEvent(name: 'operator-dashboard-changed', data: body);

    test('handshake event is detected via isHandshake', () {
      const raw = RawSseEvent(name: 'connected', data: '{}');
      expect(OperatorDashboardFrameParser.isHandshake(raw), isTrue);
      expect(OperatorDashboardFrameParser.parse(raw), isNull);
    });

    test('returns null for unrelated event names', () {
      const raw = RawSseEvent(name: 'something-else', data: '{}');
      expect(OperatorDashboardFrameParser.parse(raw), isNull);
    });

    test('parses a PRODUCT_CHANGED frame into a typed payload', () {
      final raw = changed(
        '{"lineId":10,"reason":"PRODUCT_CHANGED","affected":["CURRENT_PRODUCT"],'
        '"version":42,"eventId":"f4e2-aaa","occurredAt":"2026-05-14T05:36:42.123Z",'
        '"data":{"machineId":10,"oldProductId":5,"oldProductName":"Red 20kg",'
        '"newProductId":6,"newProductName":"Blue 10kg","changedBy":7,'
        '"currentRollId":999,"compatibilityResult":"compatible",'
        '"timestamp":"2026-05-14T05:36:42.123Z"}}',
      );
      final event = OperatorDashboardFrameParser.parse(raw);
      expect(event, isNotNull);
      expect(event!.lineId, 10);
      expect(event.reason, OperatorDashboardReason.productChanged);
      expect(event.affected, ['CURRENT_PRODUCT']);
      expect(event.version, 42);
      expect(event.eventId, 'f4e2-aaa');
      expect(event.occurredAt, isNotNull);
      final payload = event.payload as ProductChangedPayload;
      expect(payload.machineId, 10);
      expect(payload.newProductId, 6);
      expect(payload.newProductName, 'Blue 10kg');
      expect(payload.oldProductName, 'Red 20kg');
      expect(payload.compatibilityResult, 'compatible');
    });

    test('parses ROLL_CONSUMPTION_SEGMENT_RECORDED payload', () {
      final raw = changed(
        '{"lineId":10,"reason":"ROLL_CONSUMPTION_SEGMENT_RECORDED","data":{'
        '"machineId":10,"rollId":999,"productId":5,"productName":"Red 20kg",'
        '"previousWeight":100.0,"currentWeight":70.0,"consumedWeight":30.0}}',
      );
      final event = OperatorDashboardFrameParser.parse(raw)!;
      final p = event.payload as RollConsumptionSegmentRecordedPayload;
      expect(p.rollId, 999);
      expect(p.previousWeight, 100.0);
      expect(p.currentWeight, 70.0);
      expect(p.consumedWeight, 30.0);
    });

    test('parses ROLL_CONTINUED_WITH_NEW_PRODUCT payload', () {
      final raw = changed(
        '{"lineId":10,"reason":"ROLL_CONTINUED_WITH_NEW_PRODUCT","data":{'
        '"machineId":10,"rollId":999,"rollNumber":"777000000001",'
        '"newProductId":6,"newProductName":"Blue 10kg","currentWeight":70.0,'
        '"mounted":true}}',
      );
      final event = OperatorDashboardFrameParser.parse(raw)!;
      final p = event.payload as RollContinuedWithNewProductPayload;
      expect(p.rollNumber, '777000000001');
      expect(p.newProductName, 'Blue 10kg');
      expect(p.currentWeight, 70.0);
      expect(p.mounted, isTrue);
    });

    test('parses ROLL_RETURNED_REMAINING payload', () {
      final raw = changed(
        '{"lineId":10,"reason":"ROLL_RETURNED_REMAINING","data":{'
        '"machineId":10,"rollId":999,"rollNumber":"777000000001",'
        '"returnedWeight":70.0,"oldProductId":5,"oldProductName":"Red 20kg",'
        '"newProductId":6,"newProductName":"Blue 10kg","labelId":null,'
        '"canPrintLabel":true,"mounted":false}}',
      );
      final event = OperatorDashboardFrameParser.parse(raw)!;
      final p = event.payload as RollReturnedRemainingPayload;
      expect(p.returnedWeight, 70.0);
      expect(p.canPrintLabel, isTrue);
      expect(p.mounted, isFalse);
      expect(p.oldProductName, 'Red 20kg');
      expect(p.newProductName, 'Blue 10kg');
      expect(p.labelId, isNull);
    });

    test(
      'parses MACHINE_ROLL_STATE_UPDATED with no mount → hasNoMount is true',
      () {
        final raw = changed(
          '{"lineId":10,"reason":"MACHINE_ROLL_STATE_UPDATED","data":{'
          '"machineId":10,"activeProductId":6,"activeProductName":"Blue 10kg",'
          '"mountedRollId":null,"mountedRollNumber":null,'
          '"mountedRollCurrentWeight":null,'
          '"mountedRollCompatibleWithActiveProduct":null,'
          '"lastAction":"product_switch_roll_returned"}}',
        );
        final p =
            OperatorDashboardFrameParser.parse(raw)!.payload
                as MachineRollStateUpdatedPayload;
        expect(p.activeProductName, 'Blue 10kg');
        expect(p.hasNoMount, isTrue);
        expect(p.lastAction, 'product_switch_roll_returned');
      },
    );

    test(
      'parses MACHINE_ROLL_STATE_UPDATED with mount intact → hasNoMount is false',
      () {
        final raw = changed(
          '{"lineId":10,"reason":"MACHINE_ROLL_STATE_UPDATED","data":{'
          '"machineId":10,"activeProductId":6,"activeProductName":"Blue 10kg",'
          '"mountedRollId":999,"mountedRollNumber":"777000000001",'
          '"mountedRollCurrentWeight":70.0,'
          '"mountedRollCompatibleWithActiveProduct":true,'
          '"lastAction":"product_switch_roll_continued"}}',
        );
        final p =
            OperatorDashboardFrameParser.parse(raw)!.payload
                as MachineRollStateUpdatedPayload;
        expect(p.hasNoMount, isFalse);
        expect(p.mountedRollId, 999);
        expect(p.mountedRollCurrentWeight, 70.0);
        expect(p.mountedRollCompatibleWithActiveProduct, isTrue);
      },
    );

    test('frame with missing data field yields a notification-only event', () {
      final raw = changed(
        '{"lineId":10,"reason":"PRODUCT_CHANGED","eventId":"id-1"}',
      );
      final event = OperatorDashboardFrameParser.parse(raw)!;
      expect(event.payload, isNull);
      expect(event.isNotificationOnly, isTrue);
    });

    test('frame missing required wrapping fields returns null', () {
      // Missing reason.
      final raw1 = changed('{"lineId":10}');
      expect(OperatorDashboardFrameParser.parse(raw1), isNull);
      // Missing lineId.
      final raw2 = changed('{"reason":"PRODUCT_CHANGED"}');
      expect(OperatorDashboardFrameParser.parse(raw2), isNull);
    });

    test(
      'PRODUCT_CHANGED with missing required field falls back to null payload',
      () {
        // Missing newProductName.
        final raw = changed(
          '{"lineId":10,"reason":"PRODUCT_CHANGED","data":{"machineId":10,'
          '"newProductId":6}}',
        );
        final event = OperatorDashboardFrameParser.parse(raw)!;
        expect(event.payload, isNull);
        expect(event.isNotificationOnly, isTrue);
      },
    );

    test('unknown reason yields null payload but preserves wrapping', () {
      final raw = changed(
        '{"lineId":10,"reason":"BRAND_NEW_REASON","data":{"foo":"bar"}}',
      );
      final event = OperatorDashboardFrameParser.parse(raw)!;
      expect(event.reason, OperatorDashboardReason.unknown);
      expect(event.payload, isNull);
    });
  });
}
