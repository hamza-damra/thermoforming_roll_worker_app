import '../../../core/errors/app_failure.dart';
import '../../shift_line/domain/entities/roll_worker_bootstrap_line.dart';
import 'entities/roll_worker_me.dart';

// ─── /sessions/me ───────────────────────────────────────────────────────────

sealed class SessionsMeResult {
  const SessionsMeResult();
}

class SessionsMeSuccess extends SessionsMeResult {
  const SessionsMeSuccess(this.me);
  final RollWorkerMe me;
}

class SessionsMeFailure extends SessionsMeResult {
  const SessionsMeFailure(this.failure);
  final AppFailure failure;
}

// ─── /sessions/me/joinable-lines ────────────────────────────────────────────

sealed class JoinableLinesResult {
  const JoinableLinesResult();
}

class JoinableLinesSuccess extends JoinableLinesResult {
  const JoinableLinesSuccess(this.lines);
  final List<RollWorkerBootstrapLine> lines;
}

class JoinableLinesFailure extends JoinableLinesResult {
  const JoinableLinesFailure(this.failure);
  final AppFailure failure;
}

// ─── /sessions/leave-all ───────────────────────────────────────────────────

sealed class LeaveAllResult {
  const LeaveAllResult();
}

class LeaveAllSuccess extends LeaveAllResult {
  const LeaveAllSuccess();
}

class LeaveAllFailure extends LeaveAllResult {
  const LeaveAllFailure(this.failure);
  final AppFailure failure;
}

/// Repository for the three unified post-login endpoints introduced in the
/// realtime + line-management handoff §2.3.
///
/// All three require any one of the worker's active session tokens in the
/// `X-Session-Token` header — the impl resolves a token from
/// [SessionsMeTokenSelector] / [SecureTokenStorage]. Empty token set short-
/// circuits to an `UnknownFailure` because none of these endpoints are
/// reachable without a session.
abstract class SessionsMeRepository {
  Future<SessionsMeResult> fetchMe();
  Future<JoinableLinesResult> fetchJoinableLines();

  /// Single-shot bulk logout. On success the impl wipes every per-line
  /// token from secure storage and clears the session index — callers do
  /// not need to do this themselves.
  Future<LeaveAllResult> leaveAll();
}
