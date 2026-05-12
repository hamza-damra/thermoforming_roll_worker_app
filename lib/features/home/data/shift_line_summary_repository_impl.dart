import '../../../core/api/api_error_parser.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/errors/error_code.dart';
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
      return SummaryFailure(failure);
    }
  }
}
