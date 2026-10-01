import '../../../core/api/api_error_parser.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/errors/error_code.dart';
import '../../../core/errors/failure_classification.dart';
import '../../../core/storage/secure_token_storage.dart';
import '../domain/entities/production_time_input.dart';
import '../domain/entities/roll_search_outcome.dart';
import '../domain/roll_search_repository.dart';
import 'roll_search_api.dart';

class RollSearchRepositoryImpl implements RollSearchRepository {
  RollSearchRepositoryImpl({
    required RollSearchApi api,
    required SecureTokenStorage storage,
  }) : _api = api,
       _storage = storage;

  final RollSearchApi _api;
  final SecureTokenStorage _storage;

  @override
  Future<RollSearchResult> searchByProductionTime({
    required int shiftLineId,
    required ProductionTimeQuery query,
  }) async {
    final String? token = await _storage.readSessionToken(shiftLineId);
    if (token == null || token.isEmpty) {
      return const RollSearchFailure(
        BusinessFailure(code: ErrorCode.rollWorkerSessionRequired),
      );
    }
    try {
      final RollSearchOutcome outcome = await _api.searchByProductionTime(
        shiftLineId: shiftLineId,
        query: query,
        sessionToken: token,
      );
      return RollSearchSuccess(outcome);
    } catch (error, stack) {
      final AppFailure failure = ApiErrorParser.parse(error, stack);
      // Same token policy as the scan: only a session-loss cascade clears it;
      // a device-key fault or a bad time entry leaves the session usable.
      if (isSessionLossCascade(failure)) {
        await _storage.clearSessionToken(shiftLineId);
      }
      return RollSearchFailure(failure);
    }
  }
}
