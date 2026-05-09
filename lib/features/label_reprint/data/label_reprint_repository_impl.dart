import '../../../core/api/api_error_parser.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/errors/error_code.dart';
import '../../../core/storage/secure_token_storage.dart';
import '../domain/label_reprint_repository.dart';
import 'dto/roll_label_reprint_response.dart';
import 'label_reprint_api.dart';

class LabelReprintRepositoryImpl implements LabelReprintRepository {
  LabelReprintRepositoryImpl({
    required LabelReprintApi api,
    required SecureTokenStorage storage,
  }) : _api = api,
       _storage = storage;

  final LabelReprintApi _api;
  final SecureTokenStorage _storage;

  @override
  Future<LabelReprintResult> fetchLabel({
    required int shiftLineId,
    required String generatedRollId,
  }) async {
    final String? token = await _storage.readSessionToken(shiftLineId);
    if (token == null || token.isEmpty) {
      return const LabelReprintFailureResult(
        BusinessFailure(code: ErrorCode.rollWorkerSessionRequired),
      );
    }
    try {
      final RollLabelReprintResponse dto = await _api.fetchLabel(
        generatedRollId: generatedRollId,
        sessionToken: token,
      );
      return LabelReprintSuccess(dto.toEntity());
    } catch (error, stack) {
      final AppFailure failure = ApiErrorParser.parse(error, stack);
      // Reprint is read-only and uses a looser session check, but if the
      // session is no longer valid the local token must still be cleared.
      if (failure is BusinessFailure &&
          failure.code == ErrorCode.rollWorkerSessionRequired) {
        await _storage.clearSessionToken(shiftLineId);
      }
      return LabelReprintFailureResult(failure);
    }
  }
}
