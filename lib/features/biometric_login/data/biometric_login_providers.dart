import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_providers.dart';
import '../domain/biometric_attempt_repository.dart';
import 'biometric_attempt_api.dart';
import 'biometric_attempt_repository_impl.dart';

final Provider<BiometricAttemptApi> biometricAttemptApiProvider =
    Provider<BiometricAttemptApi>((ref) {
      return BiometricAttemptApi(ref.watch(biometricStatusDioProvider));
    });

final Provider<BiometricAttemptRepository> biometricAttemptRepositoryProvider =
    Provider<BiometricAttemptRepository>((ref) {
      return BiometricAttemptRepositoryImpl(
        api: ref.watch(biometricAttemptApiProvider),
      );
    });
