/// Auth controller — drives sign-in / sign-out + the persisted session.
///
/// The Notifier holds the live AuthState; signIn() POSTs to
/// /v1/auth/login on whatever [serverUrlProvider] currently points at,
/// persists the result via AuthStore, and flips state. signOut() does
/// the inverse.
///
/// The login HTTP client is pulled from [loginHttpClientProvider]
/// (separate from the authenticated httpClientProvider) so tests can
/// inject a MockClient without dragging Bearer plumbing into the
/// unauthenticated login round-trip.
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'auth_state.dart';
import 'auth_store.dart';
import 'server_url.dart';

/// Plain (non-Bearer) http.Client used for the login round-trip.
/// Default = a real client. Tests override with MockClient.
final loginHttpClientProvider = Provider<http.Client>((ref) {
  final c = http.Client();
  ref.onDispose(c.close);
  return c;
});

class LoginException implements Exception {
  LoginException(this.statusCode, this.message);
  final int statusCode;
  final String message;
  @override
  String toString() => 'login failed ($statusCode): $message';
}

class AuthController extends Notifier<AuthState> {
  /// Initial state is injected via override in main() (after AuthStore
  /// has been awaited). Default = SignedOut so widget tests that don't
  /// override still resolve cleanly.
  AuthController({AuthState initial = const SignedOut()}) : _initial = initial;
  final AuthState _initial;

  @override
  AuthState build() => _initial;

  Future<void> signIn(String username, String password) async {
    final base = ref.read(serverUrlProvider);
    final client = ref.read(loginHttpClientProvider);
    final uri = base.replace(path: '/v1/auth/login');

    final resp = await client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({'username': username, 'password': password}),
    );
    if (resp.statusCode != 200) {
      throw LoginException(resp.statusCode, _extractError(resp.body));
    }
    final j = jsonDecode(resp.body) as Map<String, dynamic>;
    final signed = SignedIn(
      token: j['token'] as String,
      tenantId: j['tenant_id'] as String,
      roles: ((j['roles'] as List?) ?? const []).cast<String>(),
      expiresAt: DateTime.parse(j['expires_at'] as String),
    );
    await ref.read(authStoreProvider).save(signed);
    state = signed;
  }

  Future<void> signOut() async {
    await ref.read(authStoreProvider).clear();
    state = const SignedOut();
  }

  /// Pulls a human message out of the error body. Tries cloud-api's
  /// `{"error": ...}` envelope, then a generic `{"message": ...}`
  /// (covers whatever non-POS server the URL might point at), then the
  /// raw body. Always truncated: the wrong server can answer with a
  /// multi-KB stack-trace JSON and the login screen must not render
  /// 6000px of it.
  String _extractError(String body) {
    String msg = body;
    try {
      final j = jsonDecode(body);
      if (j is Map && j['error'] is String) {
        msg = j['error'] as String;
      } else if (j is Map && j['message'] is String) {
        msg = j['message'] as String;
      }
    } catch (_) {}
    msg = msg.trim();
    if (msg.isEmpty) return 'login failed';
    return msg.length <= 200 ? msg : '${msg.substring(0, 200)}…';
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);
