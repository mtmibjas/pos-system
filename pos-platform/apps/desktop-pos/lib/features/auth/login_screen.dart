/// Cashier login (§4.2 / D3). Shown by [AuthGate] when the terminal is
/// provisioned but there's no active session. On success the gate advances
/// to the app. Functional scaffolding — polish later.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Sign in', style: Theme.of(context).textTheme.headlineSmall),
                if (counter != null) ...[
                  const SizedBox(height: 4),
                  Text(counter, style: Theme.of(context).textTheme.bodyMedium),
                ],
                const SizedBox(height: 24),
                TextFormField(
                  controller: _username,
                  decoration: const InputDecoration(
                      labelText: 'Username', border: OutlineInputBorder()),
                  textInputAction: TextInputAction.next,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _password,
                  decoration: const InputDecoration(
                      labelText: 'Password', border: OutlineInputBorder()),
                  obscureText: true,
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Required' : null,
                  onFieldSubmitted: (_) => _submit(),
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(_message(error),
                      style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Sign in'),
                ),
              ],
            ),
          ),
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
