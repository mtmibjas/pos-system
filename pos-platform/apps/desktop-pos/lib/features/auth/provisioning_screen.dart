/// First-run provisioning: a manager registers THIS terminal (§4.1 / D3).
///
/// Shown by [AuthGate] when no device credential is stored. The manager
/// authenticates inline (server requires the owner role); on success the
/// device credential is persisted and the gate advances to the login
/// screen. Functional scaffolding — visual polish comes later.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'session_controller.dart';

class ProvisioningScreen extends ConsumerStatefulWidget {
  const ProvisioningScreen({super.key});

  @override
  ConsumerState<ProvisioningScreen> createState() => _ProvisioningScreenState();
}

class _ProvisioningScreenState extends ConsumerState<ProvisioningScreen> {
  final _formKey = GlobalKey<FormState>();
  final _managerUser = TextEditingController();
  final _managerPass = TextEditingController();
  final _deviceName = TextEditingController(text: 'Front till');
  bool _submitting = false;

  @override
  void dispose() {
    _managerUser.dispose();
    _managerPass.dispose();
    _deviceName.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    await ref.read(deviceControllerProvider.notifier).register(
          managerUsername: _managerUser.text.trim(),
          managerPassword: _managerPass.text,
          deviceName: _deviceName.text.trim(),
        );
    if (mounted) setState(() => _submitting = false);
    // On success the device credential lands → AuthGate swaps us out for the
    // login screen automatically; nothing to navigate here.
  }

  @override
  Widget build(BuildContext context) {
    final error = ref.watch(deviceControllerProvider).error;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Set up this terminal',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 4),
                Text('A manager registers this device once.',
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _managerUser,
                  decoration: const InputDecoration(
                      labelText: 'Manager username', border: OutlineInputBorder()),
                  textInputAction: TextInputAction.next,
                  validator: _required,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _managerPass,
                  decoration: const InputDecoration(
                      labelText: 'Manager password', border: OutlineInputBorder()),
                  obscureText: true,
                  validator: _required,
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _deviceName,
                  decoration: const InputDecoration(
                      labelText: 'Terminal name', border: OutlineInputBorder()),
                  validator: _required,
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
                      : const Text('Register terminal'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String? _required(String? v) =>
    (v == null || v.trim().isEmpty) ? 'Required' : null;

/// Friendly message for the common failures; falls back to a generic line.
String _message(Object error) {
  final s = error.toString();
  if (s.contains('permission_denied') || s.contains('owner role')) {
    return 'That account is not allowed to register a terminal (owner only).';
  }
  if (s.contains('unauthenticated') || s.contains('invalid credentials')) {
    return 'Invalid manager credentials.';
  }
  return 'Could not register this terminal. Check the server connection.';
}
