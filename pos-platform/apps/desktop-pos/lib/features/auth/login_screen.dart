/// Cashier login (§4.2 / D3), on the Dostop design system. Shown by [AuthGate]
/// when the terminal is provisioned but there's no active session. On success
/// the gate advances to the app.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ui/auth_scaffold.dart';
import '../../ui/theme.dart';
import '../../ui/tokens.dart';
import 'session_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    await ref.read(sessionControllerProvider.notifier).login(
          username: _username.text.trim(),
          password: _password.text,
        );
    if (mounted) setState(() => _submitting = false);
    // On success the session lands → AuthGate swaps us out for the app.
  }

  @override
  Widget build(BuildContext context) {
    final error = ref.watch(sessionControllerProvider).error;
    final counter = ref.watch(deviceControllerProvider).valueOrNull?.counterId;

    return AuthScaffold(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Sign in', style: DostopText.h1),
            const SizedBox(height: 4),
            Text(
              (counter?.isNotEmpty ?? false)
                  ? 'Counter · $counter'
                  : 'Enter your cashier credentials',
              style: DostopText.label,
            ),
            const SizedBox(height: 22),
            AuthField(
              label: 'Username',
              controller: _username,
              hint: 'owner@a',
              autofocus: true,
              textInputAction: TextInputAction.next,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 14),
            AuthField(
              label: 'Password',
              controller: _password,
              hint: '••••••••',
              obscure: true,
              onSubmitted: (_) => _submit(),
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),
            if (error != null) AuthError(message: _message(error)),
            const SizedBox(height: 22),
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Sign in',
                        style: TextStyle(
                            fontFamily: DostopFonts.sans,
                            fontSize: 15,
                            fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _message(Object error) {
  if (error is NotProvisionedException) {
    return 'This terminal is not provisioned yet.';
  }
  final s = error.toString();
  if (s.contains('unauthenticated') || s.contains('invalid credentials')) {
    return 'Invalid username or password.';
  }
  return 'Could not sign in. Check the server connection.';
}
