import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:mobile_owner/core/auth_controller.dart';
import 'package:mobile_owner/core/auth_state.dart';
import 'package:mobile_owner/core/auth_store.dart';

/// In-memory AuthStore — avoids pulling FlutterSecureStorage into a
/// pure-Dart unit test (it requires platform channels).
class _FakeAuthStore implements AuthStore {
  AuthState _state = const SignedOut();
  int saves = 0;
  int clears = 0;

  @override
  Future<AuthState> load() async => _state;

  @override
  Future<void> save(SignedIn s) async {
    _state = s;
    saves++;
  }

  @override
  Future<void> clear() async {
    _state = const SignedOut();
    clears++;
  }
}

ProviderContainer _newContainer({
  required http.Client client,
  AuthState initial = const SignedOut(),
  required _FakeAuthStore store,
}) {
  return ProviderContainer(overrides: [
    loginHttpClientProvider.overrideWithValue(client),
    authStoreProvider.overrideWithValue(store),
    authControllerProvider.overrideWith(
      () => AuthController(initial: initial),
    ),
  ]);
}

void main() {
  test('signIn parses 200, persists session, flips state', () async {
    final body = {
      'token': 'jwt.test.token',
      'expires_at': '2026-06-02T12:00:00Z',
      'tenant_id': 'tenant-A',
      'roles': ['owner'],
    };
    final client = MockClient((req) async {
      expect(req.url.path, '/v1/auth/login');
      final decoded = jsonDecode(req.body) as Map<String, dynamic>;
      expect(decoded['username'], 'alice');
      expect(decoded['password'], 'hunter2');
      return http.Response(jsonEncode(body), 200,
          headers: {'content-type': 'application/json'});
    });
    final store = _FakeAuthStore();
    final c = _newContainer(client: client, store: store);
    addTearDown(c.dispose);

    await c.read(authControllerProvider.notifier).signIn('alice', 'hunter2');

    final state = c.read(authControllerProvider);
    expect(state, isA<SignedIn>());
    final s = state as SignedIn;
    expect(s.token, 'jwt.test.token');
    expect(s.tenantId, 'tenant-A');
    expect(s.roles, ['owner']);
    expect(store.saves, 1);
  });

  test('signIn maps 401 to LoginException with server message', () async {
    final client = MockClient((_) async => http.Response(
        jsonEncode({'error': 'invalid credentials'}), 401,
        headers: {'content-type': 'application/json'}));
    final store = _FakeAuthStore();
    final c = _newContainer(client: client, store: store);
    addTearDown(c.dispose);

    try {
      await c
          .read(authControllerProvider.notifier)
          .signIn('alice', 'WRONG');
      fail('expected LoginException');
    } on LoginException catch (e) {
      expect(e.statusCode, 401);
      expect(e.message, 'invalid credentials');
    }
    // State unchanged on failure; nothing persisted.
    expect(c.read(authControllerProvider), isA<SignedOut>());
    expect(store.saves, 0);
  });

  test('signOut clears persistence and resets state', () async {
    final client = MockClient((_) async => http.Response('unused', 500));
    final store = _FakeAuthStore();
    final initial = SignedIn(
      token: 't',
      tenantId: 'tenant-A',
      roles: const ['owner'],
      expiresAt: DateTime.utc(2026, 6, 2),
    );
    final c = _newContainer(client: client, store: store, initial: initial);
    addTearDown(c.dispose);

    expect(c.read(authControllerProvider), isA<SignedIn>());
    await c.read(authControllerProvider.notifier).signOut();
    expect(c.read(authControllerProvider), isA<SignedOut>());
    expect(store.clears, 1);
  });

  test('SignedIn.toJson round-trips through fromJson', () {
    final s = SignedIn(
      token: 't',
      tenantId: 'tenant-A',
      roles: const ['owner', 'cashier'],
      expiresAt: DateTime.utc(2026, 6, 2, 12, 0, 0),
    );
    final j = s.toJson();
    final back = SignedIn.fromJson(j);
    expect(back.token, s.token);
    expect(back.tenantId, s.tenantId);
    expect(back.roles, s.roles);
    expect(back.expiresAt, s.expiresAt);
  });
}
