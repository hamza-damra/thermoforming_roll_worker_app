/// The `X-Biometric-Attempt-Token` header — the only credential on the
/// biometric attempt-status long-poll (no device key, no session token).
///
/// The token is a secret: it is set per request by the biometric status API
/// and its value is never logged by [RedactingLoggerInterceptor].
class BiometricAttemptToken {
  BiometricAttemptToken._();

  static const String headerName = 'X-Biometric-Attempt-Token';

  /// Request headers carrying [token].
  static Map<String, String> header(String token) => <String, String>{
    headerName: token,
  };
}
