import '../../../core/errors/app_failure.dart';
import 'entities/shift_line_summary.dart';

sealed class SummaryResult {
  const SummaryResult();
}

class SummarySuccess extends SummaryResult {
  const SummarySuccess(this.summary);
  final ShiftLineSummary summary;
}

class SummaryFailure extends SummaryResult {
  const SummaryFailure(this.failure);
  final AppFailure failure;
}

abstract class ShiftLineSummaryRepository {
  Future<SummaryResult> fetchSummary({required int shiftLineId});
}
