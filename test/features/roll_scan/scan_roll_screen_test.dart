import 'package:flutter_test/flutter_test.dart';
import 'package:thermoforming_roll_worker/core/errors/error_code.dart';
import 'package:thermoforming_roll_worker/features/roll_scan/presentation/screens/scan_roll_screen.dart';
import 'package:thermoforming_roll_worker/features/roll_scan/presentation/widgets/roll_scan_blocked_dialog.dart';

/// `blockedKindFor` decides blocking-dialog vs. inline-error + camera re-arm.
/// Its `_ => null` arm means a forgotten code compiles clean and passes every
/// other test while silently putting a terminal roll back in the retry loop —
/// so each terminal code is pinned here explicitly.
void main() {
  group('ScanRollScreen.blockedKindFor', () {
    const Map<ErrorCode, RollScanBlockedKind> terminal =
        <ErrorCode, RollScanBlockedKind>{
          ErrorCode.rollSentToGrindingNotReusable: RollScanBlockedKind.grinding,
          ErrorCode.rollAlreadyConsumed: RollScanBlockedKind.consumed,
          ErrorCode.rollAdminCancelled: RollScanBlockedKind.adminCancelled,
          ErrorCode.rollReconciledOutOfStock:
              RollScanBlockedKind.reconciledOutOfStock,
        };

    terminal.forEach((ErrorCode code, RollScanBlockedKind kind) {
      test('${code.wireValue} → $kind (blocking dialog, no retry)', () {
        expect(ScanRollScreen.blockedKindFor(code), kind);
      });
    });

    test('every RollScanBlockedKind is reachable from some error code', () {
      expect(
        terminal.values.toSet(),
        RollScanBlockedKind.values.toSet(),
        reason:
            'A kind no code maps to is dead UI — wire it up in blockedKindFor.',
      );
    });

    test('retryable codes fall through to the inline error', () {
      // Controls: these are transient/correctable, so the camera must re-arm.
      expect(ScanRollScreen.blockedKindFor(ErrorCode.rollNotFound), isNull);
      expect(
        ScanRollScreen.blockedKindFor(ErrorCode.rollTypeNotAllowedForProduct),
        isNull,
      );
      expect(ScanRollScreen.blockedKindFor(ErrorCode.unknown), isNull);
    });
  });
}
