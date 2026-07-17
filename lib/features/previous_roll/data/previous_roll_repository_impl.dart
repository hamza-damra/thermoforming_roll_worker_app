import '../../../core/api/api_error_parser.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/errors/error_code.dart';
import '../../../core/storage/secure_token_storage.dart';
import '../domain/previous_roll_repository.dart';
import 'dto/previous_roll_resolution_response.dart';
import 'previous_roll_api.dart';

class PreviousRollRepositoryImpl implements PreviousRollRepository {
  PreviousRollRepositoryImpl({
    required PreviousRollApi api,
    required SecureTokenStorage storage,
  }) : _api = api,
       _storage = storage;

  final PreviousRollApi _api;
  final SecureTokenStorage _storage;

  @override
  Future<PreviousRollResult> fullConsume({required int shiftLineId}) {
    return _send(
      shiftLineId: shiftLineId,
      call: (String token) =>
          _api.fullConsume(shiftLineId: shiftLineId, sessionToken: token),
    );
  }

  @override
  Future<PreviousRollResult> returnRemaining({
    required int shiftLineId,
    required double remainingWeightKg,
    required String reasonText,
  }) {
    return _send(
      shiftLineId: shiftLineId,
      call: (String token) => _api.returnRemaining(
        shiftLineId: shiftLineId,
        remainingWeightKg: remainingWeightKg,
        reasonText: reasonText,
        sessionToken: token,
      ),
    );
  }

  @override
  Future<PreviousRollResult> sendToGrinding({
    required int shiftLineId,
    required double remainingWeightKg,
    required String reasonText,
  }) {
    return _send(
      shiftLineId: shiftLineId,
      call: (String token) => _api.sendToGrinding(
        shiftLineId: shiftLineId,
        remainingWeightKg: remainingWeightKg,
        reasonText: reasonText,
        sessionToken: token,
      ),
    );
  }

  Future<PreviousRollResult> _send({
    required int shiftLineId,
    required Future<PreviousRollResolutionResponse> Function(String token) call,
  }) async {
    final String? token = await _storage.readSessionToken(shiftLineId);
    if (token == null || token.isEmpty) {
      return const PreviousRollFailure(
        BusinessFailure(code: ErrorCode.rollWorkerSessionRequired),
      );
    }
    try {
      final PreviousRollResolutionResponse dto = await call(token);
      return PreviousRollSuccess(dto.toEntity());
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
      return PreviousRollFailure(failure);
    }
  }
}
