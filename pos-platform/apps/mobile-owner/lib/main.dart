/// Mobile-owner — Flutter entrypoint.
///
/// Boot sequence:
///   1. Await SharedPreferences + secure storage so the persisted
///      server URL and auth session are available before the first
///      provider read.
///   2. Override the four "platform" providers with concrete instances
///      and the loaded values, then runApp.
///   3. The _AuthGate widget watches authControllerProvider and routes
///      between LoginScreen (signed out) and TodayScreen (signed in).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/auth_controller.dart';
import 'core/auth_state.dart';
import 'core/auth_store.dart';
import 'core/server_url.dart';
import 'features/auth/login_screen.dart';
import 'features/today/today_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final urlStore = ServerUrlStore(prefs);
  final bootedUrl = urlStore.load();

  final authStore = AuthStore(const FlutterSecureStorage());
  final bootedAuth = await authStore.load();

  runApp(ProviderScope(
    overrides: [
      serverUrlProvider.overrideWith((_) => bootedUrl),
      serverUrlStoreProvider.overrideWithValue(urlStore),
      authStoreProvider.overrideWithValue(authStore),
      authControllerProvider.overrideWith(
        () => AuthController(initial: bootedAuth),
      ),
    ],
    child: const OwnerApp(),
  ));
}

class OwnerApp extends StatelessWidget {
  const OwnerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'pos-owner',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const _AuthGate(),
    );
  }
}

/// Routes between LoginScreen and TodayScreen based on auth state.
/// Sitting at the root means a signOut() anywhere in the app collapses
/// every pushed route automatically (the home widget rebuilds).
class _AuthGate extends ConsumerWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    return switch (auth) {
      SignedIn() => const TodayScreen(),
      SignedOut() => const LoginScreen(),
    };
  }
}
