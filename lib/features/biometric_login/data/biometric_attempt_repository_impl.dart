import '../../../core/api/api_error_parser.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/errors/error_code.dart';
import '../domain/biometric_attempt_repository.dart';
import '../domain/entities/biometric_attempt_status.dart';
import 'biometric_attempt_api.dart';

class BiometricAttemptRepositoryImpl implements BiometricAttemptRepository {
  BiometricAttemptRepositoryImpl({required BiometricAttemptApi api})
    : _api = api;

  final BiometricAttemptApi _api;

  @override
  Future<BiometricStatusResult> getStatus({
    required String? statusPath,
    required String attemptToken,
  }) async {
    try {
      final BiometricAttemptStatusResponse response = await _api.getStatus(
        statusPath: statusPath,
        attemptToken: attemptToken,
      );
      return BiometricStatusAnswered(response);
    } catch (error, stack) {
      final AppFailure failure = ApiErrorParser.parse(error, stack);
      if (_isAttemptExpired(failure)) {
        return const BiometricStatusAttemptExpired();
      }
      return BiometricStatusUnreachable(failure);
    }
  }

  /// 410 means "unknown or expired attempt". The code is the contract; the
  /// bare status also counts so a 410 whose envelope got mangled (proxy page)
  /// still ends the loop instead of polling a dead attempt forever.
  static bool _isAttemptExpired(AppFailure failure) => switch (failure) {
    BusinessFailure(:final ErrorCode code, :final int? statusCode) =>
      code == ErrorCode.biometricLoginAttemptExpired || statusCode == 410,
    ServerFailure(:final int statusCode) => statusCode == 410,
    _ => false,
  };
}
