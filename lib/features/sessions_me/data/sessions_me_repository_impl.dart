import '../../../core/api/api_error_parser.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/errors/error_code.dart';
import '../../../core/storage/secure_token_storage.dart';
import '../../../core/storage/session_index_storage.dart';
import '../../shift_line/data/dto/roll_worker_bootstrap_response.dart';
import '../../shift_line/domain/entities/roll_worker_bootstrap_line.dart';
import '../domain/entities/roll_worker_me.dart';
import '../domain/sessions_me_repository.dart';
import 'sessions_me_api.dart';
import 'sessions_me_token_selector.dart';

/// Concrete [SessionsMeRepository]. Handles:
/// - per-call token resolution via [SessionsMeTokenSelector]
/// - one-shot retry on 401 with a different token (handoff "in-flight 401
///   on token rotation" edge case)
/// - bulk local cleanup on `leaveAll` success — wipes every per-line token
///   from secure storage and clears the session-index blob so callers
///   never need to deal with stale local state
class SessionsMeRepositoryImpl implements SessionsMeRepository {
  SessionsMeRepositoryImpl({
    required SessionsMeApi api,
    required SessionsMeTokenSelector tokenSelector,
    required SecureTokenStorage tokenStorage,
    required SessionIndexStorage indexStorage,
  }) : _api = api,
       _tokenSelector = tokenSelector,
       _tokenStorage = tokenStorage,
       _indexStorage = indexStorage;

  final SessionsMeApi _api;
  final SessionsMeTokenSelector _tokenSelector;
  final SecureTokenStorage _tokenStorage;
  final SessionIndexStorage _indexStorage;

  @override
  Future<SessionsMeResult> fetchMe() async {
    return _withTokenRetry<SessionsMeResult>(
      run: (String? token) async {
        final RollWorkerMe me = await _api.fetchMe(token: token);
        return SessionsMeSuccess(me);
      },
      onFailure: SessionsMeFailure.new,
    );
  }

  @override
  Future<JoinableLinesResult> fetchJoinableLines() async {
    return _withTokenRetry<JoinableLinesResult>(
      run: (String? token) async {
        final List<RollWorkerBootstrapLineDto> dtos =
            await _api.fetchJoinableLines(token: token);
        final List<RollWorkerBootstrapLine> lines = dtos
            .map((dto) => dto.toEntity())
            .toList(growable: false);
        return JoinableLinesSuccess(lines);
      },
      onFailure: JoinableLinesFailure.new,
    );
  }

  @override
  Future<LeaveAllResult> leaveAll() async {
    final String? token = await _tokenSelector.resolveAnyToken();
    try {
      await _api.leaveAll(token: token);
    } catch (error, stack) {
      final AppFailure failure = ApiErrorParser.parse(error, stack);
      // 401 (`ROLL_WORKER_SESSION_REQUIRED`) means every token is already
      // invalidated server-side — for leave-all, that IS the desired state,
      // so collapse to success after the local wipe.
      if (!_isTokenRejected(failure)) {
        return LeaveAllFailure(failure);
      }
    }
    // Wipe local state regardless of whether the server actually had any
    // sessions left to end (the endpoint is idempotent server-side; the
    // client should be too).
    final Set<int> existingIds = await _indexStorage.readIds();
    await _tokenStorage.clearAllSessionTokens(existingIds);
    await _indexStorage.writeIds(<int>{});
    _tokenSelector.reset();
    return const LeaveAllSuccess();
  }

  /// Runs [run] with a freshly-resolved token; on a 401-class failure (the
  /// backend `ROLL_WORKER_SESSION_REQUIRED`) tries one more time with a
  /// DIFFERENT token. Avoids surfacing a transient picker-route when only
  /// one of the worker's tokens has been replaced.
  Future<R> _withTokenRetry<R>({
    required Future<R> Function(String? token) run,
    required R Function(AppFailure failure) onFailure,
  }) async {
    final String? token = await _tokenSelector.resolveAnyToken();
    if (token == null) {
      return onFailure(
        const BusinessFailure(code: ErrorCode.rollWorkerSessionRequired),
      );
    }
    try {
      return await run(token);
    } catch (error, stack) {
      final AppFailure failure = ApiErrorParser.parse(error, stack);
      if (!_isTokenRejected(failure)) return onFailure(failure);

      // One-shot retry with a different token (the one we just used was
      // rejected; another may still be valid).
      final String? alt = await _tokenSelector.resolveAnyToken(
        exceptShiftLineId: null,
      );
      if (alt == null || alt == token) return onFailure(failure);
      try {
        return await run(alt);
      } catch (e2, s2) {
        return onFailure(ApiErrorParser.parse(e2, s2));
      }
    }
  }

  /// Deliberately NARROWER than the shared `isSessionLossCascade`: this asks
  /// specifically "did the server reject *this token*?", which is a different
  /// question from "has the worker lost their session?".
  ///
  /// It must stay narrow because it drives two things that would be wrong for
  /// the broader set:
  ///   - the one-shot retry with a *different* token — pointless unless the
  ///     token itself was rejected;
  ///   - collapsing `leaveAll` to success — correct when the server says every
  ///     session is already gone, but NOT for
  ///     `ROLL_OP_SESSION_TOKEN_MISSING`, where the client simply failed to
  ///     send the header and nothing was actually ended.
  ///
  /// A device-key fault is excluded for free: it is a different code entirely.
  bool _isTokenRejected(AppFailure failure) {
    if (failure is BusinessFailure) {
      return failure.code == ErrorCode.rollWorkerSessionRequired;
    }
    return false;
  }
}
