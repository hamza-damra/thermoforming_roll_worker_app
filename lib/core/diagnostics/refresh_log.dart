import 'package:flutter/foundation.dart';

/// Temporary diagnostic logging for the adaptive state-refresh work.
///
/// Traces the refresh pipeline so field QA can tell, from `flutter logs` /
/// `adb logcat`, whether an SSE event arrived and which refresh path it
/// triggered (summary / picker / bootstrap) and what the REST result said.
///
/// No-op in release builds. Search for `refreshLog(` to strip these once the
/// SSE→REST refresh path is confirmed stable in production.
void refreshLog(String message) {
  if (!kDebugMode) return;
  debugPrint('[RollWorkerRefresh] $message');
}
