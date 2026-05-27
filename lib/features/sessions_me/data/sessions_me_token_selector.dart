import '../../../core/storage/secure_token_storage.dart';
import '../../../core/storage/session_index_storage.dart';

/// Resolves any one of the worker's active per-line session tokens for the
/// `X-Session-Token` header. The three unified endpoints (`/sessions/me`,
/// `/sessions/me/joinable-lines`, `/sessions/leave-all`) accept any token.
///
/// Returns null when the device has no active sessions — the caller must
/// surface `ROLL_WORKER_SESSION_REQUIRED` semantics (route to picker).
///
/// Maintains a small in-memory hint of "last-used id" so retries after a
/// per-line cascade naturally pick a different token without restoring a
/// stale one from storage.
class SessionsMeTokenSelector {
  SessionsMeTokenSelector({
    required SecureTokenStorage tokenStorage,
    required SessionIndexStorage indexStorage,
  }) : _tokenStorage = tokenStorage,
       _indexStorage = indexStorage;

  final SecureTokenStorage _tokenStorage;
  final SessionIndexStorage _indexStorage;

  int? _lastUsedId;

  Future<String?> resolveAnyToken({int? exceptShiftLineId}) async {
    final Set<int> ids = await _indexStorage.readIds();
    final List<int> ordered = <int>[
      // Prefer the last-used id (heap-warm path) unless the caller is
      // explicitly retrying after that token failed.
      if (_lastUsedId != null &&
          _lastUsedId != exceptShiftLineId &&
          ids.contains(_lastUsedId))
        _lastUsedId!,
      for (final int id in ids)
        if (id != exceptShiftLineId && id != _lastUsedId) id,
    ];
    for (final int id in ordered) {
      final String? token = await _tokenStorage.readSessionToken(id);
      if (token != null && token.isNotEmpty) {
        _lastUsedId = id;
        return token;
      }
    }
    return null;
  }

  /// Drops the cached "last-used id" hint. Call after `/leave-all` so a
  /// future call doesn't try to reuse a now-deleted token.
  void reset() {
    _lastUsedId = null;
  }
}
