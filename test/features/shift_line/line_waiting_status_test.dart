import 'package:flutter_test/flutter_test.dart';
import 'package:thermoforming_roll_worker/features/shift_line/domain/entities/roll_worker_bootstrap_line.dart';
import 'package:thermoforming_roll_worker/features/shift_line/presentation/widgets/line_waiting_status.dart';

RollWorkerBootstrapLine _line({
  int? shiftLineId,
  String lifecycle = 'NO_ACTIVE_SHIFT',
  bool handoverPending = false,
  String? takeoverRequestStatus,
  String? blockedReason,
}) => RollWorkerBootstrapLine(
  thermoformingLineId: 1,
  lineCode: 'TH-01',
  lineName: 'Thermo 1',
  machineNumber: 1,
  palletizingLineId: 2,
  productionLineId: 2,
  palletizingLineCode: 'PL-01',
  palletizingLineName: 'Palletizer 1',
  shiftLineId: shiftLineId,
  thermoformingShiftId: 9,
  currentProductTypeId: null,
  currentProductTypeName: null,
  activeOperatorId: null,
  activeOperatorName: null,
  currentRollId: null,
  currentRollGeneratedRollId: null,
  currentRollTypeCode: null,
  currentRollTypeName: null,
  currentRollLastKnownWeightKg: null,
  selectable: false,
  canStartRollWorkerSession: false,
  blocked: blockedReason != null,
  blockedReason: blockedReason,
  handoverPending: handoverPending,
  takeoverRequestStatus: takeoverRequestStatus,
  takeoverIncomingOperatorName: null,
  lineLifecycleStatus: lifecycle,
  updatedAt: null,
);

void main() {
  group('LineWaitingStatus.reasonFor', () {
    test('NO_ACTIVE_SHIFT lifecycle → noActiveShift', () {
      expect(
        LineWaitingStatus.reasonFor(_line(lifecycle: 'NO_ACTIVE_SHIFT')),
        LineWaitingReason.noActiveShift,
      );
    });

    test('null shiftLineId on an unknown lifecycle → noActiveShift', () {
      expect(
        LineWaitingStatus.reasonFor(_line(lifecycle: 'ACTIVE')),
        LineWaitingReason.noActiveShift,
      );
    });

    test('handoverPending flag → pendingHandover', () {
      expect(
        LineWaitingStatus.reasonFor(
          _line(shiftLineId: 5, lifecycle: 'ACTIVE', handoverPending: true),
        ),
        LineWaitingReason.pendingHandover,
      );
    });

    test('PENDING_HANDOVER lifecycle → pendingHandover', () {
      expect(
        LineWaitingStatus.reasonFor(
          _line(shiftLineId: 5, lifecycle: 'PENDING_HANDOVER'),
        ),
        LineWaitingReason.pendingHandover,
      );
    });

    test('takeoverRequestStatus set → takeover', () {
      expect(
        LineWaitingStatus.reasonFor(
          _line(
            shiftLineId: 5,
            lifecycle: 'ACTIVE',
            takeoverRequestStatus: 'PENDING',
          ),
        ),
        LineWaitingReason.takeover,
      );
    });

    test('TAKEOVER_* lifecycle → takeover', () {
      expect(
        LineWaitingStatus.reasonFor(
          _line(shiftLineId: 5, lifecycle: 'TAKEOVER_APPROVED'),
        ),
        LineWaitingReason.takeover,
      );
    });

    test('takeover outranks a concurrent handover flag', () {
      expect(
        LineWaitingStatus.reasonFor(
          _line(
            shiftLineId: 5,
            lifecycle: 'TAKEOVER_PENDING',
            handoverPending: true,
            takeoverRequestStatus: 'PENDING',
          ),
        ),
        LineWaitingReason.takeover,
      );
    });
  });

  group('LineWaitingStatus copy', () {
    test('pill labels never leak raw backend tokens', () {
      for (final RollWorkerBootstrapLine line in <RollWorkerBootstrapLine>[
        _line(lifecycle: 'NO_ACTIVE_SHIFT'),
        _line(shiftLineId: 5, lifecycle: 'PENDING_HANDOVER'),
        _line(shiftLineId: 5, lifecycle: 'TAKEOVER_PENDING'),
      ]) {
        final String label = LineWaitingStatus.pillLabelFor(line);
        expect(label, isNot(contains('_')));
        expect(label, isNot(matches(RegExp('[A-Z]'))));
      }
    });

    test('dialog body matches the classified reason', () {
      expect(
        LineWaitingStatus.dialogBodyFor(_line(lifecycle: 'NO_ACTIVE_SHIFT')),
        LineWaitingStatus.dialogBodyNoActiveShift,
      );
      expect(
        LineWaitingStatus.dialogBodyFor(
          _line(shiftLineId: 5, lifecycle: 'PENDING_HANDOVER'),
        ),
        LineWaitingStatus.dialogBodyHandover,
      );
      expect(
        LineWaitingStatus.dialogBodyFor(
          _line(shiftLineId: 5, lifecycle: 'TAKEOVER_PENDING'),
        ),
        LineWaitingStatus.dialogBodyTakeover,
      );
    });

    test('handover & takeover use the warning accent; plain waiting does not', () {
      expect(
        LineWaitingStatus.isWarningReason(_line(lifecycle: 'NO_ACTIVE_SHIFT')),
        isFalse,
      );
      expect(
        LineWaitingStatus.isWarningReason(
          _line(shiftLineId: 5, lifecycle: 'PENDING_HANDOVER'),
        ),
        isTrue,
      );
      expect(
        LineWaitingStatus.isWarningReason(
          _line(shiftLineId: 5, lifecycle: 'TAKEOVER_PENDING'),
        ),
        isTrue,
      );
    });
  });
}
