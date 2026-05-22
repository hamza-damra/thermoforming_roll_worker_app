import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_providers.dart';
import 'roll_worker_lines_sse_client.dart';

/// Builds the pre-login [RollWorkerLinesSseClient] for the global
/// `/thermoforming-roll-app/events` channel. Device-key authenticated only —
/// no session token is attached (see [DioRollWorkerEventsByteStreamSource]).
final Provider<RollWorkerLinesSseClient> rollWorkerLinesSseClientProvider =
    Provider<RollWorkerLinesSseClient>(
      (ref) => RollWorkerLinesSseClient(
        source: DioRollWorkerEventsByteStreamSource(ref.watch(dioProvider)),
      ),
    );
