import '../../../core/api/api_error_parser.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/errors/error_code.dart';
import '../../../core/errors/failure_classification.dart';
import '../../../core/storage/secure_token_storage.dart';
import '../domain/shift_line_summary_repository.dart';
import 'shift_line_summary_api.dart';

class ShiftLineSummaryRepositoryImpl implements ShiftLineSummaryRepository {
  ShiftLineSummaryRepositoryImpl({
    required ShiftLineSummaryApi api,
    required SecureTokenStorage storage,
  }) : _api = api,
       _storage = storage;

  final ShiftLineSummaryApi _api;
  final SecureTokenStorage _storage;

  @override
  Future<SummaryResult> fetchSummary({required int shiftLineId}) async {
    final String? token = await _storage.readSessionToken(shiftLineId);
    if (token == null || token.isEmpty) {
      return const SummaryFailure(
        BusinessFailure(code: ErrorCode.rollWorkerSessionRequired),
      );
    }
    try {
      final dto = await _api.fetchSummary(
        shiftLineId: shiftLineId,
        sessionToken: token,
      );
      return SummarySuccess(dto.toEntity());
    } catch (error, stack) {
      final AppFailure failure = ApiErrorParser.parse(error, stack);
      // Only a session/line-state fault invalidates the stored token; a
      // device-key fault leaves the session valid and must preserve it.
      if (isSessionLossCascade(failure)) {
        await _storage.clearSessionToken(shiftLineId);
      }
      return SummaryFailure(failure);
    }
  }
}
