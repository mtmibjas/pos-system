/// Session / provisioning / role-policy tests (D3) using a fake
/// AuthRepository + in-memory CredentialStore — no transport, no keystore.
library;

import 'package:desktop_pos/data/auth_repository.dart';
import 'package:desktop_pos/data/credential_store.dart';
import 'package:desktop_pos/features/auth/session_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.failLogin = false});

  bool failLogin;
  int loginCalls = 0;
  String? lastUsername;

  @override
  Future<DeviceCredential> registerDevice({
    required String managerUsername,
    required String managerPassword,
    required String deviceName,
    String? replaceCounterId,
  }) async =>
      const DeviceCredential(
          deviceId: 'dev-1',
          deviceSecret: 'sec',
          storeId: 'store-1',
          counterId: 'counter-1');

  @override
  Future<Session> login({
    required String deviceId,
    required String deviceSecret,
    required String username,
    required String password,
  }) async {
    loginCalls++;
    lastUsername = username;
    if (failLogin) throw Exception('invalid credentials');
    return Session(
      username: username,
      displayName: 'Cashier',
      roles: const ['cashier'],
      token: 'tok',
      expiresAt: DateTime.now().add(const Duration(hours: 16)),
      tenantId: 'tenant-A',
      storeId: 'store-1',
      counterId: 'counter-1',
    );
  }
}

ProviderContainer _container({
  AuthRepository? repo,
  CredentialStore? store,
}) {
  final c = ProviderContainer(overrides: [
    authRepositoryProvider.overrideWithValue(repo ?? FakeAuthRepository()),
    credentialStoreProvider.overrideWithValue(store ?? InMemoryCredentialStore()),
  ]);
  return c;
}

const _device = DeviceCredential(
    deviceId: 'dev-1', deviceSecret: 'sec', storeId: 'store-1', counterId: 'counter-1');

void main() {
  test('login on a provisioned device sets the session + derived identity',
      () async {
    final c = _container(store: InMemoryCredentialStore(device: _device));
    addTearDown(c.dispose);
    await c.read(sessionControllerProvider.future); // resolve initial null

    await c.read(sessionControllerProvider.notifier)
        .login(username: 'cash@a', password: 'pw');

    final session = c.read(sessionControllerProvider).valueOrNull;
    expect(session, isNotNull);
    expect(session!.username, 'cash@a');
    expect(c.read(cashierIdProvider), 'cash@a', reason: 'sales stamp the user');
    expect(c.read(rolePolicyProvider).canSell, isTrue);
    expect(c.read(rolePolicyProvider).isOwner, isFalse);
    // Persisted so a relaunch resumes.
    expect(await c.read(credentialStoreProvider).loadSession(), isNotNull);
  });

  test('login without a provisioned device surfaces NotProvisionedException',
      () async {
    final c = _container(); // empty store, no device
    addTearDown(c.dispose);
    await c.read(sessionControllerProvider.future);

    await c.read(sessionControllerProvider.notifier)
        .login(username: 'cash@a', password: 'pw');

    final state = c.read(sessionControllerProvider);
    expect(state.hasError, isTrue);
    expect(state.error, isA<NotProvisionedException>());
  });

  test('a non-expired stored session is restored on build', () async {
    final stored = Session(
      username: 'owner@a',
      displayName: 'Owner',
      roles: const ['owner'],
      token: 'tok',
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
      tenantId: 'tenant-A',
      storeId: 'store-1',
      counterId: 'counter-1',
    );
    final c = _container(store: InMemoryCredentialStore(session: stored));
    addTearDown(c.dispose);

    final restored = await c.read(sessionControllerProvider.future);
    expect(restored?.username, 'owner@a');
    expect(c.read(rolePolicyProvider).isOwner, isTrue);
  });

  test('an expired stored session is ignored', () async {
    final expired = Session(
      username: 'owner@a',
      displayName: 'Owner',
      roles: const ['owner'],
      token: 'tok',
      expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
      tenantId: 'tenant-A',
      storeId: 'store-1',
      counterId: 'counter-1',
    );
    final c = _container(store: InMemoryCredentialStore(session: expired));
    addTearDown(c.dispose);

    expect(await c.read(sessionControllerProvider.future), isNull);
  });

  test('logout clears the session and stored token', () async {
    final store = InMemoryCredentialStore(device: _device);
    final c = _container(store: store);
    addTearDown(c.dispose);
    await c.read(sessionControllerProvider.future);
    await c.read(sessionControllerProvider.notifier)
        .login(username: 'cash@a', password: 'pw');
    expect(await store.loadSession(), isNotNull);

    await c.read(sessionControllerProvider.notifier).logout();
    expect(c.read(sessionControllerProvider).valueOrNull, isNull);
    expect(await store.loadSession(), isNull);
    expect(c.read(cashierIdProvider), 'cashier-1', reason: 'falls back when logged out');
  });

  test('device registration persists the credential', () async {
    final store = InMemoryCredentialStore();
    final c = _container(store: store);
    addTearDown(c.dispose);
    await c.read(deviceControllerProvider.future); // null initially

    await c.read(deviceControllerProvider.notifier).register(
          managerUsername: 'owner@a',
          managerPassword: 'ownerpw',
          deviceName: 'Front till',
        );

    expect(c.read(deviceControllerProvider).valueOrNull?.counterId, 'counter-1');
    expect(await store.loadDevice(), isNotNull);
  });
}
