/// Login screen — username + password against cloud-api /v1/auth/login.
///
/// The server URL field is editable here too (mirrors what settings
/// shows after login) so an operator can fix a wrong URL without
/// signing in first.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth_controller.dart';
import '../../core/server_url.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _urlCtrl;
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _busy = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _urlCtrl =
        TextEditingController(text: ref.read(serverUrlProvider).toString());
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _errorText = null;
    });
    try {
      // Apply URL first so signIn() POSTs to the right host. Persist
      // it too — operator confirmed it works.
      final url = Uri.parse(_urlCtrl.text.trim());
      ref.read(serverUrlProvider.notifier).state = url;
      await ref.read(serverUrlStoreProvider).save(url);

      await ref
          .read(authControllerProvider.notifier)
          .signIn(_userCtrl.text.trim(), _passCtrl.text);
      // No navigation — the gate widget in main.dart reacts to auth state.
    } on LoginException catch (e) {
      setState(() => _errorText = e.message);
    } catch (e) {
      setState(() => _errorText = 'connection failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')),
      body: Center(
        // Scrollable so the form survives small screens / open keyboard /
        // long error text without overflowing the viewport.
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _urlCtrl,
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Cloud API URL',
                        helperText: 'e.g. http://127.0.0.1:18080',
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'required';
                        final u = Uri.tryParse(v.trim());
                        if (u == null || !u.hasScheme) return 'invalid URL';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _userCtrl,
                      autocorrect: false,
                      decoration: const InputDecoration(labelText: 'Username'),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Password'),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'required' : null,
                    ),
                    if (_errorText != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _errorText!,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Sign in'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
