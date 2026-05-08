import '../../../core/api/api_error_parser.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/errors/error_code.dart';
import '../../../core/storage/secure_token_storage.dart';
import '../domain/entities/roll_worker_session.dart';
import '../domain/roll_worker_auth_repository.dart';
import 'dto/roll_worker_auth_response.dart';
import 'dto/roll_worker_session_response.dart';
import 'roll_worker_auth_api.dart';

class RollWorkerAuthRepositoryImpl implements RollWorkerAuthRepository {
  RollWorkerAuthRepositoryImpl({
    required RollWorkerAuthApi api,
    required SecureTokenStorage storage,
  }) : _api = api,
       _storage = storage;

  final RollWorkerAuthApi _api;
  final SecureTokenStorage _storage;

  @override
  Future<RollWorkerAuthResult> login({
    required int shiftLineId,
    required String pin,
  }) async {
    try {
      final RollWorkerAuthResponse dto = await _api.login(
        shiftLineId: shiftLineId,
        pin: pin,
      );
      // Persist the raw token immediately, then drop it from memory by
      // returning the domain entity (which has no sessionToken field).
      await _storage.writeSessionToken(
        shiftLineId: shiftLineId,
        token: dto.sessionToken,
      );
      return RollWorkerAuthSuccess(_sessionFromAuth(dto));
    } catch (error, stack) {
      return RollWorkerAuthFailure(ApiErrorParser.parse(error, stack));
    }
  }

  @override
  Future<RollWorkerAuthResult> getCurrentSession(int shiftLineId) async {
    try {
      final RollWorkerSessionResponse dto = await _api.getCurrentSession(
        shiftLineId,
      );
      return RollWorkerAuthSuccess(_sessionFromCurrent(dto));
    } catch (error, stack) {
      final AppFailure failure = ApiErrorParser.parse(error, stack);
      // Cascade-on-end / no-active-session always invalidates any locally
      // stored token. Other failures (network, unknown) leave it alone so
      // the UI can retry without re-authenticating.
      if (failure is BusinessFailure &&
          (failure.code == ErrorCode.rollWorkerSessionRequired ||
              failure.code == ErrorCode.thermoformingShiftLineNotActive ||
              failure.code == ErrorCode.thermoformingShiftLineNotFound)) {
        await _storage.clearSessionToken(shiftLineId);
      }
      return RollWorkerAuthFailure(failure);
    }
  }

  @override
  Future<void> logout(int shiftLineId) async {
    final String? token = await _storage.readSessionToken(shiftLineId);
    // Always clear the local token first so a network failure can't strand
    // the device in a logged-in state.
    await _storage.clearSessionToken(shiftLineId);
    if (token == null) return;
    try {
      await _api.logout(shiftLineId: shiftLineId, sessionToken: token);
    } catch (_) {
      // Idempotent on the backend; swallow transport errors so the UI can
      // route to the PIN screen anyway.
    }
  }

  @override
  Future<String?> readStoredToken(int shiftLineId) =>
      _storage.readSessionToken(shiftLineId);

  @override
  Future<void> clearStoredToken(int shiftLineId) =>
      _storage.clearSessionToken(shiftLineId);

  RollWorkerSession _sessionFromAuth(RollWorkerAuthResponse dto) {
    return RollWorkerSession(
      sessionId: dto.sessionId,
      rollWorkerOperatorId: dto.rollWorkerOperatorId,
      rollWorkerName: dto.rollWorkerName,
      thermoformingShiftId: dto.thermoformingShiftId,
      thermoformingShiftLineId: dto.thermoformingShiftLineId,
      thermoformingLineId: dto.thermoformingLineId,
      palletizingLineId: dto.palletizingLineId,
      startedAt: dto.startedAt,
      startedAtDisplay: dto.startedAtDisplay,
    );
  }

  RollWorkerSession _sessionFromCurrent(RollWorkerSessionResponse dto) {
    return RollWorkerSession(
      sessionId: dto.sessionId,
      rollWorkerOperatorId: dto.rollWorkerOperatorId,
      rollWorkerName: dto.rollWorkerName,
      thermoformingShiftId: dto.thermoformingShiftId,
      thermoformingShiftLineId: dto.thermoformingShiftLineId,
      thermoformingLineId: dto.thermoformingLineId,
      palletizingLineId: dto.palletizingLineId,
      startedAt: dto.startedAt,
      startedAtDisplay: dto.startedAtDisplay,
      lastUsedAt: dto.lastUsedAt,
      lastUsedAtDisplay: dto.lastUsedAtDisplay,
      status: dto.status,
    );
  }
}
