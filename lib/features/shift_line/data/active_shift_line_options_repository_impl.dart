import '../../../core/api/api_error_parser.dart';
import '../domain/active_shift_line_options_repository.dart';
import '../domain/entities/active_shift_line_option.dart';
import 'active_shift_line_options_api.dart';
import 'dto/active_shift_line_option_response.dart';

class ActiveShiftLineOptionsRepositoryImpl
    implements ActiveShiftLineOptionsRepository {
  ActiveShiftLineOptionsRepositoryImpl({required ActiveShiftLineOptionsApi api})
    : _api = api;

  final ActiveShiftLineOptionsApi _api;

  @override
  Future<ActiveShiftLineOptionsResult> fetch() async {
    try {
      final List<ActiveShiftLineOptionResponse> dtos = await _api.fetch();
      final List<ActiveShiftLineOption> options = dtos
          .map((dto) => dto.toEntity())
          .toList(growable: false);
      return ActiveShiftLineOptionsSuccess(options);
    } catch (error, stack) {
      return ActiveShiftLineOptionsFailure(
        ApiErrorParser.parse(error, stack),
      );
    }
  }
}
