import 'package:flutter/foundation.dart';

/// Connection lifecycle for an operator-dashboard SSE subscription.
///
/// Exposed for observability — the UI does not branch on connection
/// status today (errors are silent reconnect loops), but tests assert
/// transitions and a future "offline" banner can read from this.
enum OperatorDashboardSyncStatus {
  /// No subscription yet — either not started or torn down.
  idle,

  /// Subscription open, awaiting the SSE `connected` handshake.
  connecting,

  /// Handshake received, currently consuming events.
  connected,

  /// Underlying socket dropped; the client is backing off before retrying.
  reconnecting,

  /// Session token missing or refused — subscription cannot start until
  /// the registry exposes a valid token (e.g. fresh login).
  unauthenticated,
}

@immutable
class OperatorDashboardSyncState {
  const OperatorDashboardSyncState({
    required this.status,
    this.lastEventId,
    this.lastError,
  });

  const OperatorDashboardSyncState.idle()
    : status = OperatorDashboardSyncStatus.idle,
      lastEventId = null,
      lastError = null;

  final OperatorDashboardSyncStatus status;
  final String? lastEventId;
  final Object? lastError;

  OperatorDashboardSyncState copyWith({
    OperatorDashboardSyncStatus? status,
    String? lastEventId,
    Object? lastError,
    bool clearLastError = false,
  }) {
    return OperatorDashboardSyncState(
      status: status ?? this.status,
      lastEventId: lastEventId ?? this.lastEventId,
      lastError: clearLastError ? null : (lastError ?? this.lastError),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OperatorDashboardSyncState &&
        other.status == status &&
        other.lastEventId == lastEventId &&
        other.lastError == lastError;
  }

  @override
  int get hashCode => Object.hash(status, lastEventId, lastError);
}
