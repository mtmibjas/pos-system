/// Auth session value object.
///
/// Two-state sealed type — either nothing yet (login screen), or a
/// valid session with everything cloud-api gave us. Token expiry is
/// stored as-is (no proactive refresh); a stale token surfaces as a
/// 401 on the next call and triggers signOut via the 401 listener
/// wired into the screens.
library;

sealed class AuthState {
  const AuthState();
}

class SignedOut extends AuthState {
  const SignedOut();
}

class SignedIn extends AuthState {
  const SignedIn({
    required this.token,
    required this.tenantId,
    required this.roles,
    required this.expiresAt,
  });

  final String token;
  final String tenantId;
  final List<String> roles;
  final DateTime expiresAt;

  /// JSON form used by AuthStore for secure-storage persistence. Kept
  /// here next to the type so the two stay in sync.
  Map<String, dynamic> toJson() => {
        'token': token,
        'tenant_id': tenantId,
        'roles': roles,
        'expires_at': expiresAt.toIso8601String(),
      };

  factory SignedIn.fromJson(Map<String, dynamic> j) => SignedIn(
        token: j['token'] as String,
        tenantId: j['tenant_id'] as String,
        roles: (j['roles'] as List).cast<String>(),
        expiresAt: DateTime.parse(j['expires_at'] as String),
      );
}
