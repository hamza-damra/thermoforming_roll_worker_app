import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_failure.dart';
import '../../domain/entities/shift_line_summary.dart';

@immutable
sealed class ShiftLineSummaryState {
  const ShiftLineSummaryState();
}

/// First paint — no data yet; spinner is shown.
class SummaryLoading extends ShiftLineSummaryState {
  const SummaryLoading();
}

/// Data loaded successfully.
///
/// [isRefreshing] is `true` while a background re-fetch is in flight.
/// The UI keeps showing [summary] during the refresh so there is no blank
/// flash between the old data and the new data.
class SummaryLoaded extends ShiftLineSummaryState {
  const SummaryLoaded(this.summary, {this.isRefreshing = false});

  final ShiftLineSummary summary;
  final bool isRefreshing;

  SummaryLoaded copyWith({bool? isRefreshing}) =>
      SummaryLoaded(summary, isRefreshing: isRefreshing ?? this.isRefreshing);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SummaryLoaded &&
        other.summary == summary &&
        other.isRefreshing == isRefreshing;
  }

  @override
  int get hashCode => Object.hash(summary, isRefreshing);
}

/// Hard failure with no prior data (first load failed).
class SummaryError extends ShiftLineSummaryState {
  const SummaryError(this.failure);

  final AppFailure failure;
}
