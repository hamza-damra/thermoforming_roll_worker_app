import 'dart:async';

import 'package:thermoforming_roll_worker/features/shift_line/data/roll_worker_lines_sse_client.dart';
import 'package:thermoforming_roll_worker/features/shift_line/domain/entities/roll_worker_lines_event.dart';

/// Test double for [RollWorkerLinesSseClient].
///
/// `subscribe()` returns a broadcast stream the test drives via [emit]. It
/// opens no sockets and starts no timers, so widget / controller tests stay
/// free of the real reconnect machinery and pending-timer failures.
class FakeRollWorkerLinesSseClient implements RollWorkerLinesSseClient {
  final StreamController<RollWorkerLinesStreamItem> _controller =
      StreamController<RollWorkerLinesStreamItem>.broadcast();

  @override
  Stream<RollWorkerLinesStreamItem> subscribe() => _controller.stream;

  /// Pushes one item to every current `subscribe()` listener.
  void emit(RollWorkerLinesStreamItem item) {
    if (!_controller.isClosed) _controller.add(item);
  }

  Future<void> dispose() => _controller.close();
}
