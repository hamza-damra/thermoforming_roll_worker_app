import '../../../core/api/api_error_parser.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/errors/error_code.dart';
import '../../../core/storage/secure_token_storage.dart';
import '../../../core/storage/session_index_storage.dart';
import '../domain/entities/batch_auth_outcome.dart';
import '../domain/entities/roll_worker_session.dart';
import '../domain/session_batch_repository.dart';
import 'dto/batch_session_entry_response.dart';
import 'dto/batch_session_start_response.dart';
import 'session_batch_api.dart';

class SessionBatchRepositoryImpl implements SessionBatchRepository {
  SessionBatchRepositoryImpl({
    required SessionBatchApi api,
    required SecureTokenStorage tokenStorage,
    required SessionIndexStorage indexStorage,
  }) : _api = api,
       _tokenStorage = tokenStorage,
       _indexStorage = indexStorage;

  final SessionBatchApi _api;
  final SecureTokenStorage _tokenStorage;
  final SessionIndexStorage _indexStorage;

  @override
  Future<BatchAuthResult> startBatch({
    required String pin,
    required Set<int> shiftLineIds,
  }) async {
    try {
      final BatchSessionStartResponse dto = await _api.startBatch(
        pin: pin,
        shiftLineIds: shiftLineIds,
      );
      // Persist every raw token immediately, then drop them from memory by
      // mapping each entry to a token-less domain session.
      final Map<int, RollWorkerSession> sessions = <int, RollWorkerSession>{};
      for (final BatchSessionEntryResponse entry in dto.sessions) {
        await _tokenStorage.writeSessionToken(
          shiftLineId: entry.shiftLineId,
          token: entry.sessionToken,
        );
        sessions[entry.shiftLineId] = _sessionFromEntry(
          entry: entry,
          rollWorkerOperatorId: dto.rollWorkerOperatorId,
          rollWorkerName: dto.rollWorkerName,
        );
      }
      // Merge new ids into the persisted index so app launch knows which
      // lines to restore. We union with existing ids — there may already
      // be sessions from a previous batch that weren't part of this call.
      final Set<int> existing = await _indexStorage.readIds();
      await _indexStorage.writeIds(<int>{...existing, ...sessions.keys});

      return BatchAuthSuccessResult(
        BatchAuthOutcome(
          rollWorkerOperatorId: dto.rollWorkerOperatorId,
          rollWorkerName: dto.rollWorkerName,
          sessions: sessions,
        ),
      );
    } catch (error, stack) {
      final AppFailure failure = ApiErrorParser.parse(error, stack);
      return BatchAuthFailureResult(
        failure,
        conflictShiftLineIds: _extractConflictIds(failure),
      );
    }
  }

  RollWorkerSession _sessionFromEntry({
    required BatchSessionEntryResponse entry,
    required int rollWorkerOperatorId,
    required String rollWorkerName,
  }) {
    return RollWorkerSession(
      sessionId: entry.sessionId,
      rollWorkerOperatorId: rollWorkerOperatorId,
      rollWorkerName: rollWorkerName,
      thermoformingShiftId: entry.thermoformingShiftId,
      thermoformingShiftLineId: entry.shiftLineId,
      thermoformingLineId: entry.thermoformingLineId,
      palletizingLineId: entry.palletizingLineId,
      startedAt: entry.startedAt,
      startedAtDisplay: entry.startedAtDisplay,
    );
  }

  /// Pulls per-line conflict ids out of `details.shiftLineId` for the four
  /// per-line failure codes. Returns null for global failures so the
  /// controller can route them as inline errors instead of picker recovery.
  Set<int>? _extractConflictIds(AppFailure failure) {
    if (failure is! BusinessFailure) return null;
    switch (failure.code) {
      case ErrorCode.thermoformingShiftLineNotFound:
      case ErrorCode.rollWorkerSessionLineInactive:
      case ErrorCode.rollWorkerSessionLineUsedByOtherWorker:
      case ErrorCode.rollWorkerSessionLineDuplicate:
        final Object? raw = failure.details?['shiftLineId'];
        if (raw is num) return <int>{raw.toInt()};
        return null;
      default:
        return null;
    }
  }
}
