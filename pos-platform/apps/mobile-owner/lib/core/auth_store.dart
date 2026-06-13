/// Secure-storage wrapper for the auth session.
///
/// Why secure_storage and not SharedPreferences: the JWT is a bearer
/// token — leaking it from a backup or world-readable prefs lets
/// anyone replay tenant-scoped owner calls until it expires.
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'auth_state.dart';

/// Storage key. Bump only on a breaking shape change.
const String kSecKeyAuth = 'auth_session_v1';

class AuthStore {
  AuthStore(this._secure);
  final FlutterSecureStorage _secure;

  /// Reads the session, returning [SignedOut] on missing-or-corrupt.
  /// We swallow JSON errors here because a corrupt blob is functionally
  /// equivalent to "logged out" — the user just signs in again.
  Future<AuthState> load() async {
    final raw = await _secure.read(key: kSecKeyAuth);
    if (raw == null || raw.isEmpty) return const SignedOut();
    try {
      return SignedIn.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const SignedOut();
    }
  }

  Future<void> save(SignedIn s) =>
      _secure.write(key: kSecKeyAuth, value: jsonEncode(s.toJson()));

  Future<void> clear() => _secure.delete(key: kSecKeyAuth);
}

/// Override in main() with a real [AuthStore]. Widget tests that don't
/// exercise persistence can override with an in-memory fake.
final authStoreProvider = Provider<AuthStore>((_) {
  throw UnimplementedError(
      'authStoreProvider must be overridden in main()');
});
