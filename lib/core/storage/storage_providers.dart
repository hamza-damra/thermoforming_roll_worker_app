import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'secure_token_storage.dart';

/// Single [SecureTokenStorage] instance shared across the app.
final Provider<SecureTokenStorage> secureTokenStorageProvider =
    Provider<SecureTokenStorage>((ref) => SecureTokenStorage());
