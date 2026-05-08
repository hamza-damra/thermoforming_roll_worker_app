import '../../../core/api/api_error_parser.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/errors/error_code.dart';
import '../../../core/storage/secure_token_storage.dart';
import '../domain/roll_scan_repository.dart';
import 'dto/thermoforming_roll_scan_response.dart';
import 'roll_scan_api.dart';

class RollScanRepositoryImpl implements RollScanRepository {
  RollScanRepositoryImpl({
    required RollScanApi api,
    required SecureTokenStorage storage,
  }) : _api = api,
       _storage = storage;

  final RollScanApi _api;
  final SecureTokenStorage _storage;

  @override
  Future<RollScanResult> mountRoll({
    required int shiftLineId,
    required String generatedRollId,
  }) async {
    final String? token = await _storage.readSessionToken(shiftLineId);
    if (token == null || token.isEmpty) {
      // No session token → don't even attempt the call.
      return const RollScanFailure(
        BusinessFailure(code: ErrorCode.rollWorkerSessionRequired),
      );
    }
    try {
      final ThermoformingRollScanResponse dto = await _api.mountRoll(
        shiftLineId: shiftLineId,
        generatedRollId: generatedRollId,
        sessionToken: token,
      );
      return RollScanSuccess(dto.toEntity());
    } catch (error, stack) {
      final AppFailure failure = ApiErrorParser.parse(error, stack);
      // Cascade-on-end / session-loss invalidates the locally stored token.
      // Other failures preserve it so the worker can retry without
      // re-authenticating.
      if (failure is BusinessFailure) {
        switch (failure.code) {
          case ErrorCode.rollWorkerSessionRequired:
          case ErrorCode.thermoformingShiftLineNotActive:
          case ErrorCode.thermoformingShiftLineNotFound:
            await _storage.clearSessionToken(shiftLineId);
          default:
            break;
        }
      }
      return RollScanFailure(failure);
    }
  }
}
