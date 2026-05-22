import 'package:flutter_test/flutter_test.dart';
import 'package:thermoforming_roll_worker/features/operator_dashboard_sse/data/sse_frame_parser.dart';
import 'package:thermoforming_roll_worker/features/operator_dashboard_sse/domain/entities/operator_dashboard_event.dart';

OperatorDashboardEvent? _parse(String reason) {
  return OperatorDashboardFrameParser.parse(
    RawSseEvent(
      name: 'operator-dashboard-changed',
      data: '{"lineId":10,"reason":"$reason"}',
    ),
  );
}

void main() {
  group('Line Takeover SSE events', () {
    test('LINE_TAKEOVER_* reasons map to typed enum values', () {
      expect(
        _parse('LINE_TAKEOVER_REQUESTED')!.reason,
        OperatorDashboardReason.lineTakeoverRequested,
      );
      expect(
        _parse('LINE_TAKEOVER_ACCEPTED')!.reason,
        OperatorDashboardReason.lineTakeoverAccepted,
      );
      expect(
        _parse('LINE_TAKEOVER_REJECTED')!.reason,
        OperatorDashboardReason.lineTakeoverRejected,
      );
      expect(
        _parse('LINE_TAKEOVER_TIMEOUT_AUTO_RELEASED')!.reason,
        OperatorDashboardReason.lineTakeoverTimeoutAutoReleased,
      );
      expect(
        _parse('LINE_TAKEOVER_POST_ACCEPT_TIMEOUT_AUTO_RELEASED')!.reason,
        OperatorDashboardReason.lineTakeoverPostAcceptTimeoutAutoReleased,
      );
      expect(
        _parse('LINE_TAKEOVER_COMPLETED')!.reason,
        OperatorDashboardReason.lineTakeoverCompleted,
      );
      expect(
        _parse('LINE_STATE_CHANGED')!.reason,
        OperatorDashboardReason.lineStateChanged,
      );
    });

    test(
      'takeover events carry no typed payload → notification-only (REST refetch)',
      () {
        final OperatorDashboardEvent event = _parse('LINE_TAKEOVER_REQUESTED')!;
        expect(event.payload, isNull);
        expect(event.isNotificationOnly, isTrue);
      },
    );
  });
}
