/// First-run provisioning: a manager registers THIS terminal (§4.1 / D3), on
/// the Dostop design system. Shown by [AuthGate] when no device credential is
/// stored. The manager authenticates inline (server requires the owner role);
/// on success the device credential is persisted and the gate advances to the
/// login screen.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ui/auth_scaffold.dart';
import '../../ui/theme.dart';
import '../../ui/tokens.dart';
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
    // login screen automatically.
  }

  @override
  Widget build(BuildContext context) {
    final error = ref.watch(deviceControllerProvider).error;
    return AuthScaffold(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Set up this terminal', style: DostopText.h1),
            const SizedBox(height: 4),
            const Text('A manager registers this device once.',
                style: DostopText.label),
            const SizedBox(height: 22),
            AuthField(
              label: 'Manager username',
              controller: _managerUser,
              hint: 'owner@a',
              autofocus: true,
              textInputAction: TextInputAction.next,
              validator: _required,
            ),
            const SizedBox(height: 14),
            AuthField(
              label: 'Manager password',
              controller: _managerPass,
              hint: '••••••••',
              obscure: true,
              textInputAction: TextInputAction.next,
              validator: _required,
            ),
            const SizedBox(height: 14),
            AuthField(
              label: 'Terminal name',
              controller: _deviceName,
              hint: 'Front till',
              onSubmitted: (_) => _submit(),
              validator: _required,
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
                    : const Text('Register terminal',
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
