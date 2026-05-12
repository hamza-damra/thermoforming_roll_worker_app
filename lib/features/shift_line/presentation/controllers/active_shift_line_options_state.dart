import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_failure.dart';
import '../../domain/entities/active_shift_line_option.dart';

/// State for the pre-login active-shift-line picker. Sealed so the UI must
/// handle every branch via a `switch` expression.
@immutable
sealed class ActiveShiftLineOptionsState {
  const ActiveShiftLineOptionsState();
}

/// Initial state before the first fetch resolves.
class ActiveShiftLineOptionsInitial extends ActiveShiftLineOptionsState {
  const ActiveShiftLineOptionsInitial();
}

/// A fetch is in flight. The previous list (if any) is preserved so the UI
/// can keep rendering it while a refresh runs in the background.
class ActiveShiftLineOptionsLoading extends ActiveShiftLineOptionsState {
  const ActiveShiftLineOptionsLoading({this.previous = const []});

  final List<ActiveShiftLineOption> previous;
}

/// Last fetch succeeded. An empty list is the empty/waiting state — the UI
/// shows the original `بانتظار فتح خط من تطبيق المشغّل` copy.
class ActiveShiftLineOptionsLoaded extends ActiveShiftLineOptionsState {
  const ActiveShiftLineOptionsLoaded(this.options);

  final List<ActiveShiftLineOption> options;

  bool get isEmpty => options.isEmpty;
}

/// Last fetch failed. The previous list (if any) is preserved so the UI
/// can offer retry without losing context.
class ActiveShiftLineOptionsFailureState extends ActiveShiftLineOptionsState {
  const ActiveShiftLineOptionsFailureState({
    required this.failure,
    this.previous = const [],
  });

  final AppFailure failure;
  final List<ActiveShiftLineOption> previous;
}
