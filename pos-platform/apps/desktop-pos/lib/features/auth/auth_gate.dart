/// The boot gate (§4.1/§4.2, D3). Routes on provisioning + session state:
///
///   no device credential  → ProvisioningScreen
///   provisioned, no session → LoginScreen
///   authenticated          → [child] (today the app; D4 swaps in the shell)
///
/// A splash shows only during the initial restore of the stored credential +
/// session; login/registration don't toggle a blanket loading state (the
/// screens own their submit spinners), so the gate never flickers mid-call.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'login_screen.dart';
import 'provisioning_screen.dart';
import 'session_controller.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deviceAsync = ref.watch(deviceControllerProvider);
    final sessionAsync = ref.watch(sessionControllerProvider);

    // Initial restore from secure storage.
    if (deviceAsync.isLoading || sessionAsync.isLoading) {
      return const _Splash();
    }

    if (deviceAsync.valueOrNull == null) {
      return const ProvisioningScreen();
    }
    if (sessionAsync.valueOrNull == null) {
      return const LoginScreen();
    }
    return child;
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}
