import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'storage_keys.dart';

/// Secure store for roll-worker session tokens.
///
/// Tokens are scoped per shift-line via [StorageKeys.rollWorkerSessionToken].
/// On Android the underlying store is `EncryptedSharedPreferences`; on iOS,
/// the Keychain. Tokens are never read into logs and never surfaced to UI.
///
/// Usage:
/// ```
/// final storage = SecureTokenStorage();
/// await storage.writeSessionToken(shiftLineId: 800, token: rawToken);
/// final token = await storage.readSessionToken(800);
/// await storage.clearSessionToken(800);
/// ```
class SecureTokenStorage {
  /// Default constructor uses platform-secure storage.
  SecureTokenStorage()
    : _storage = const FlutterSecureStorage(
        aOptions: AndroidOptions(encryptedSharedPreferences: true),
        iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
      );

  /// Test/seam constructor — inject a mock or test double.
  @visibleForTesting
  SecureTokenStorage.withStorage(this._storage);

  final FlutterSecureStorage _storage;

  Future<void> writeSessionToken({
    required int shiftLineId,
    required String token,
  }) {
    if (token.isEmpty) {
      throw ArgumentError.value(
        token,
        'token',
        'Session token must not be empty.',
      );
    }
    return _storage.write(
      key: StorageKeys.rollWorkerSessionToken(shiftLineId),
      value: token,
    );
  }

  Future<String?> readSessionToken(int shiftLineId) {
    return _storage.read(key: StorageKeys.rollWorkerSessionToken(shiftLineId));
  }

  Future<void> clearSessionToken(int shiftLineId) {
    return _storage.delete(
      key: StorageKeys.rollWorkerSessionToken(shiftLineId),
    );
  }

  /// Bulk-clear convenience for logout-all / wipe flows. Deletes one key
  /// per id; failures on individual keys propagate (caller should retry the
  /// whole set since storage failures here are unusual).
  Future<void> clearAllSessionTokens(Iterable<int> shiftLineIds) async {
    for (final int id in shiftLineIds) {
      await clearSessionToken(id);
    }
  }

  /// Writes the last shift-line id picked on this device. UX hint only —
  /// not a security boundary.
  Future<void> writeSelectedShiftLineId(int shiftLineId) {
    return _storage.write(
      key: StorageKeys.selectedShiftLineId,
      value: shiftLineId.toString(),
    );
  }

  Future<int?> readSelectedShiftLineId() async {
    final String? raw = await _storage.read(
      key: StorageKeys.selectedShiftLineId,
    );
    if (raw == null || raw.isEmpty) return null;
    return int.tryParse(raw);
  }

  Future<void> clearSelectedShiftLineId() {
    return _storage.delete(key: StorageKeys.selectedShiftLineId);
  }
}
