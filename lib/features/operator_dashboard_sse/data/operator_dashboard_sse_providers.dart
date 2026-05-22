import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_providers.dart';
import '../../../core/storage/secure_token_storage.dart';
import '../../../core/storage/storage_providers.dart';
import 'operator_dashboard_sse_client.dart';

/// Builds an [OperatorDashboardSseClient] whose token lookup is bound to a
/// specific shift-line's stored roll-worker session token. The token is
/// read on every (re)connect so a token rotation is picked up without
/// recreating the client.
final operatorDashboardSseClientForLineProvider =
    Provider.family<OperatorDashboardSseClient, int>((ref, shiftLineId) {
      final SecureTokenStorage storage = ref.watch(secureTokenStorageProvider);
      return OperatorDashboardSseClient(
        source: DioSseByteStreamSource(ref.watch(dioProvider)),
        tokenLookup: () => storage.readSessionToken(shiftLineId),
      );
    });
