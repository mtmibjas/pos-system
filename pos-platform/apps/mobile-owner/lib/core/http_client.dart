/// Authenticated HTTP client for cloud-api calls.
///
/// Exposes a [http.Client] Provider so repositories never construct
/// their own client (and tests can inject a MockClient by overriding
/// [httpClientProvider] at the ProviderScope boundary).
///
/// The client wraps every outbound request with `Authorization: Bearer`
/// using the live JWT from [authControllerProvider]. When the user
/// signs in/out, this provider rebuilds and dependents (repositories)
/// pick up a fresh client automatically.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'auth_controller.dart';
import 'auth_state.dart';

/// Riverpod-managed authenticated client. Rebuilds when auth changes
/// so a stale token is never reused across a sign-out.
final httpClientProvider = Provider<http.Client>((ref) {
  final auth = ref.watch(authControllerProvider);
  final token = switch (auth) {
    SignedIn(:final token) => token,
    SignedOut() => '',
  };
  final client = _BearerClient(http.Client(), token);
  ref.onDispose(client.close);
  return client;
});

/// Tiny decorator that injects `Authorization: Bearer <jwt>` on every
/// request. Lives here (not in repositories) so swapping in a MockClient
/// for tests gives them a vanilla http.Client without auth plumbing.
class _BearerClient extends http.BaseClient {
  _BearerClient(this._inner, this._token);

  final http.Client _inner;
  final String _token;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (_token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $_token';
    }
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}
