import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'secure_token_storage.dart';
import 'session_index_storage.dart';

/// Single [SecureTokenStorage] instance shared across the app.
final Provider<SecureTokenStorage> secureTokenStorageProvider =
    Provider<SecureTokenStorage>((ref) => SecureTokenStorage());

/// Single [SessionIndexStorage] instance — the JSON list of currently-active
/// shift-line ids used to drive app-launch restore.
final Provider<SessionIndexStorage> sessionIndexStorageProvider =
    Provider<SessionIndexStorage>((ref) => SessionIndexStorage());
