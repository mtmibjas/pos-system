/// Desktop POS — Flutter client entrypoint (Windows + macOS).
///
/// Boots into the [AuthGate]: an unprovisioned terminal sees the
/// provisioning screen, a provisioned-but-logged-out terminal sees login,
/// and an authenticated terminal sees the role-aware [NavShell].
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/auth/auth_gate.dart';
import 'features/shell/nav_shell.dart';
import 'ui/theme.dart';

void main() {
  runApp(const ProviderScope(child: PosApp()));
}

class PosApp extends StatelessWidget {
  const PosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dostop POS',
      debugShowCheckedModeBanner: false,
      theme: buildDostopTheme(),
      home: AuthGate(child: NavShell()),
    );
  }
}
