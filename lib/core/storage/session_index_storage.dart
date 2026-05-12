import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'storage_keys.dart';

/// Persists the set of shift-line ids the device currently holds an
/// active roll-worker session for. Read on app launch to drive per-line
/// `/current` restoration; written on every batch-start and on every
/// per-line logout / cascade-loss.
///
/// The blob is JSON-encoded (`[101,102]`). It carries no secret material —
/// the per-line tokens live in [SecureTokenStorage] under a different key.
/// Stored via [FlutterSecureStorage] purely so we don't need to add a new
/// `shared_preferences` dependency for one tiny non-secret blob.
class SessionIndexStorage {
  SessionIndexStorage()
    : _storage = const FlutterSecureStorage(
        aOptions: AndroidOptions(encryptedSharedPreferences: true),
        iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
      );

  @visibleForTesting
  SessionIndexStorage.withStorage(this._storage);

  final FlutterSecureStorage _storage;

  Future<Set<int>> readIds() async {
    final String? raw = await _storage.read(
      key: StorageKeys.rollWorkerActiveShiftLineIds,
    );
    if (raw == null || raw.isEmpty) return <int>{};
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! List) return <int>{};
      return decoded.whereType<num>().map((n) => n.toInt()).toSet();
    } on FormatException {
      return <int>{};
    }
  }

  Future<void> writeIds(Set<int> ids) {
    final String encoded = jsonEncode(ids.toList(growable: false));
    return _storage.write(
      key: StorageKeys.rollWorkerActiveShiftLineIds,
      value: encoded,
    );
  }

  Future<void> clear() {
    return _storage.delete(key: StorageKeys.rollWorkerActiveShiftLineIds);
  }
}
