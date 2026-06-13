/// Settings — edit cloud-api URL, sign out.
///
/// Saving a new URL clears the active session (different server =
/// different identity domain), which trips the gate back to login.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth_controller.dart';
import '../../core/server_url.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _urlCtrl;
  String? _saved;
  String? _error;

  @override
  void initState() {
    super.initState();
    _urlCtrl =
        TextEditingController(text: ref.read(serverUrlProvider).toString());
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveUrl() async {
    final raw = _urlCtrl.text.trim();
    final url = Uri.tryParse(raw);
    if (url == null || !url.hasScheme) {
      setState(() {
        _saved = null;
        _error = 'invalid URL';
      });
      return;
    }
    ref.read(serverUrlProvider.notifier).state = url;
    await ref.read(serverUrlStoreProvider).save(url);
    // URL change → drop the session; next reach will re-auth.
    await ref.read(authControllerProvider.notifier).signOut();
    if (!mounted) return;
    setState(() {
      _saved = 'saved — signing back in…';
      _error = null;
    });
  }

  Future<void> _signOut() async {
    await ref.read(authControllerProvider.notifier).signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Server', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          TextField(
            controller: _urlCtrl,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Cloud API URL',
              helperText: 'changing this signs you out',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!,
                style:
                    TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          if (_saved != null) ...[
            const SizedBox(height: 8),
            Text(_saved!,
                style: Theme.of(context).textTheme.bodySmall),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: _saveUrl,
              child: const Text('Save URL'),
            ),
          ),
          const Divider(height: 48),
          Text('Session', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _signOut,
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}
