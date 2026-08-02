/// AuthGate routing tests (D3): unprovisioned → provisioning, provisioned →
/// login, authenticated → app. Uses an in-memory credential store; the
/// auth repository isn't exercised (routing only reads stored state).
library;

import 'package:desktop_pos/data/auth_repository.dart';
import 'package:desktop_pos/data/credential_store.dart';
import 'package:desktop_pos/features/auth/auth_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _device = DeviceCredential(
    deviceId: 'dev-1', deviceSecret: 'sec', storeId: 'store-1', counterId: 'counter-1');

Session _liveSession() => Session(
      username: 'cash@a',
      displayName: 'Cashier',
      roles: const ['cashier'],
      token: 'tok',
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
      tenantId: 'tenant-A',
      storeId: 'store-1',
      counterId: 'counter-1',
    );

Widget _app(CredentialStore store) => ProviderScope(
      overrides: [credentialStoreProvider.overrideWithValue(store)],
      child: const MaterialApp(home: AuthGate(child: Text('APP'))),
    );

void main() {
  testWidgets('unprovisioned terminal → provisioning screen', (tester) async {
    await tester.pumpWidget(_app(InMemoryCredentialStore()));
    await tester.pumpAndSettle();
    expect(find.text('Set up this terminal'), findsOneWidget);
  });

  testWidgets('provisioned, no session → login screen', (tester) async {
    await tester.pumpWidget(_app(InMemoryCredentialStore(device: _device)));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, 'Username'), findsOneWidget);
  });

  testWidgets('authenticated → app', (tester) async {
    await tester.pumpWidget(
        _app(InMemoryCredentialStore(device: _device, session: _liveSession())));
    await tester.pumpAndSettle();
    expect(find.text('APP'), findsOneWidget);
  });
}
