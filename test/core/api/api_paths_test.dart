import 'package:flutter_test/flutter_test.dart';
import 'package:thermoforming_roll_worker/core/api/api_paths.dart';

void main() {
  group('ApiPaths', () {
    const int shiftLineId = 800;
    const String generatedRollId = '777000000001';

    test('sessions start-batch path is the multi-line auth entry point', () {
      expect(
        ApiPaths.sessionsStartBatch,
        '/api/v1/thermoforming-roll-app/sessions/start-batch',
      );
    });

    test('roll-worker session current path', () {
      expect(
        ApiPaths.rollWorkerSessionCurrent(shiftLineId),
        '/api/v1/thermoforming-roll-app/shift-lines/800/roll-worker-session/current',
      );
    });

    test('roll-worker logout path', () {
      expect(
        ApiPaths.rollWorkerLogout(shiftLineId),
        '/api/v1/thermoforming-roll-app/shift-lines/800/roll-worker-logout',
      );
    });

    test('scan roll path', () {
      expect(
        ApiPaths.scanRoll(shiftLineId),
        '/api/v1/thermoforming-roll-app/shift-lines/800/scan-roll',
      );
    });

    test('previous-roll full-consume path', () {
      expect(
        ApiPaths.previousRollFullConsume(shiftLineId),
        '/api/v1/thermoforming-roll-app/shift-lines/800/previous-roll/full-consume',
      );
    });

    test('previous-roll return path', () {
      expect(
        ApiPaths.previousRollReturn(shiftLineId),
        '/api/v1/thermoforming-roll-app/shift-lines/800/previous-roll/return',
      );
    });

    test('previous-roll grinding path', () {
      expect(
        ApiPaths.previousRollGrinding(shiftLineId),
        '/api/v1/thermoforming-roll-app/shift-lines/800/previous-roll/grinding',
      );
    });

    test('product-switch path', () {
      expect(
        ApiPaths.productSwitch(shiftLineId),
        '/api/v1/thermoforming-roll-app/shift-lines/800/product-switch',
      );
    });

    test('reprint-label path encodes generatedRollId', () {
      expect(
        ApiPaths.reprintRollLabel(generatedRollId),
        '/api/v1/thermoforming-roll-app/rolls/777000000001/reprint-label',
      );
    });

    test('every path is under the roll-app namespace', () {
      final List<String> paths = <String>[
        ApiPaths.sessionsStartBatch,
        ApiPaths.rollWorkerSessionCurrent(shiftLineId),
        ApiPaths.rollWorkerLogout(shiftLineId),
        ApiPaths.scanRoll(shiftLineId),
        ApiPaths.previousRollFullConsume(shiftLineId),
        ApiPaths.previousRollReturn(shiftLineId),
        ApiPaths.previousRollGrinding(shiftLineId),
        ApiPaths.productSwitch(shiftLineId),
        ApiPaths.reprintRollLabel(generatedRollId),
      ];
      for (final String path in paths) {
        expect(
          path.startsWith('/api/v1/thermoforming-roll-app/'),
          isTrue,
          reason: '$path is outside the Roll Worker namespace',
        );
      }
    });

    test('no path leaks Operator/Palletizing namespaces', () {
      final List<String> forbidden = <String>[
        '/api/v1/thermoforming-app/auth',
        '/api/v1/thermoforming-app/shifts',
        '/api/v1/thermoforming-app/shift-lines',
        '/api/v1/palletizing-line/lines',
        'create-pallet',
        'authorize-pin',
        'select-product',
      ];
      final List<String> paths = <String>[
        ApiPaths.sessionsStartBatch,
        ApiPaths.rollWorkerSessionCurrent(shiftLineId),
        ApiPaths.rollWorkerLogout(shiftLineId),
        ApiPaths.scanRoll(shiftLineId),
        ApiPaths.previousRollFullConsume(shiftLineId),
        ApiPaths.previousRollReturn(shiftLineId),
        ApiPaths.previousRollGrinding(shiftLineId),
        ApiPaths.productSwitch(shiftLineId),
        ApiPaths.reprintRollLabel(generatedRollId),
      ];
      for (final String path in paths) {
        for (final String banned in forbidden) {
          expect(
            path.contains(banned),
            isFalse,
            reason: '$path contains forbidden fragment "$banned"',
          );
        }
      }
    });
  });
}
