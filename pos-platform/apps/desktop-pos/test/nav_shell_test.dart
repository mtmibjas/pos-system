/// NavShell tests (D4): role-aware module filtering (pure) + a render with
/// injected lightweight modules (so we don't stand up the network-backed
/// real screens).
library;

import 'package:desktop_pos/data/auth_repository.dart';
import 'package:desktop_pos/data/credential_store.dart';
import 'package:desktop_pos/features/auth/session_controller.dart';
import 'package:desktop_pos/features/shell/feature_module.dart';
import 'package:desktop_pos/features/shell/modules.dart';
import 'package:desktop_pos/features/shell/nav_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('visibleModules (pure)', () {
    test('owner sees every registry module', () {
      final ids = visibleModules(kModules, const RolePolicy(['owner']))
          .map((m) => m.id)
          .toList();
      expect(
        ids,
        containsAll(<String>[
          'sell', 'sales', 'inventory', 'parties',
          'purchases', 'reports', 'cashiers', 'settings',
        ]),
      );
    });

    test('cashier sees only sell/invoice/sales/parties/settings', () {
      final ids = visibleModules(kModules, const RolePolicy(['cashier']))
          .map((m) => m.id)
          .toList();
      expect(ids, ['sell', 'invoice', 'sales', 'parties', 'settings']); // registry order
      expect(ids, isNot(contains('inventory')));
      expect(ids, isNot(contains('purchases')));
      expect(ids, isNot(contains('cashiers')));
    });
  });

  group('NavShell render', () {
    final testModules = [
      _mod('a', 'Alpha', (p) => true, 'ALPHA-BODY'),
      _mod('b', 'Beta', (p) => p.isOwner, 'BETA-BODY'),
      _mod('c', 'Gamma', (p) => true, 'GAMMA-BODY'),
    ];

    Widget shellFor(Session session) => ProviderScope(
          overrides: [
            credentialStoreProvider
                .overrideWithValue(InMemoryCredentialStore(session: session)),
          ],
          child: MaterialApp(home: NavShell(modules: testModules)),
        );

    testWidgets('owner sees the owner-only destination + first module body',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 832));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(shellFor(_session(['owner'])));
      await tester.pumpAndSettle();
      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Beta'), findsOneWidget); // owner-only, visible
      expect(find.text('Gamma'), findsOneWidget);
      expect(find.text('ALPHA-BODY'), findsOneWidget); // selected module body
    });

    testWidgets('cashier does not see the owner-only destination',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 832));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(shellFor(_session(['cashier'])));
      await tester.pumpAndSettle();
      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Gamma'), findsOneWidget);
      expect(find.text('Beta'), findsNothing); // gated out
    });

    testWidgets('sign out clears the session', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 832));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final store = InMemoryCredentialStore(session: _session(['owner']));
      await tester.pumpWidget(ProviderScope(
        overrides: [credentialStoreProvider.overrideWithValue(store)],
        child: MaterialApp(home: NavShell(modules: testModules)),
      ));
      await tester.pumpAndSettle();

      // The Dostop sidebar renders sign-out as an icon button (tooltip),
      // not a text label — tap by tooltip; the behaviour under test is
      // unchanged (session is cleared).
      await tester.tap(find.byTooltip('Sign out'));
      await tester.pumpAndSettle();
      expect(await store.loadSession(), isNull);
    });
  });
}

FeatureModule _mod(
        String id, String label, ModuleVisible visible, String body) =>
    FeatureModule(
      id: id,
      label: label,
      icon: Icons.circle,
      visible: visible,
      builder: (_) => Scaffold(body: Center(child: Text(body))),
    );

Session _session(List<String> roles) => Session(
      username: 'u@a',
      displayName: 'User',
      roles: roles,
      token: 'tok',
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
      tenantId: 'tenant-A',
      storeId: 'store-1',
      counterId: 'counter-1',
    );
