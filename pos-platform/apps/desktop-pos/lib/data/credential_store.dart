/// Data layer — secure persistence for the device credential + session
/// (docs/desktop-architecture.md §4.6 token storage; §4.2 auth).
///
/// The session token + device secret live in the OS keystore via
/// flutter_secure_storage (Windows Credential Manager / macOS Keychain),
/// NOT in the app SQLite cache — they're secrets, not cached read data.
///
/// The provider defaults to the real secure store; tests override it with
/// [InMemoryCredentialStore] so they never touch a platform channel.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'auth_repository.dart' show DeviceCredential, Session;

part 'credential_store.g.dart';

/// Persistence surface for auth credentials. Async because the real backend
/// (OS keystore) is async.
abstract class CredentialStore {
  Future<DeviceCredential?> loadDevice();
  Future<void> saveDevice(DeviceCredential device);
  Future<Session?> loadSession();
  Future<void> saveSession(Session session);
  Future<void> clearSession();
}

/// In-memory store for tests (and any environment without a keystore).
class InMemoryCredentialStore implements CredentialStore {
  InMemoryCredentialStore({DeviceCredential? device, Session? session})
      : _device = device,
        _session = session;

  DeviceCredential? _device;
  Session? _session;

  @override
  Future<DeviceCredential?> loadDevice() async => _device;
  @override
  Future<void> saveDevice(DeviceCredential device) async => _device = device;
  @override
  Future<Session?> loadSession() async => _session;
  @override
  Future<void> saveSession(Session session) async => _session = session;
  @override
  Future<void> clearSession() async => _session = null;
}

/// OS-keystore-backed store. Values are JSON blobs under stable keys.
class SecureCredentialStore implements CredentialStore {
  SecureCredentialStore(this._storage);

  final FlutterSecureStorage _storage;

  static const _kDevice = 'pos.device_credential';
  static const _kSession = 'pos.session';

  @override
  Future<DeviceCredential?> loadDevice() async {
    final raw = await _storage.read(key: _kDevice);
    if (raw == null) return null;
    return DeviceCredential.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  @override
  Future<void> saveDevice(DeviceCredential device) =>
      _storage.write(key: _kDevice, value: jsonEncode(device.toJson()));

  @override
  Future<Session?> loadSession() async {
    final raw = await _storage.read(key: _kSession);
    if (raw == null) return null;
    return Session.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  @override
  Future<void> saveSession(Session session) =>
      _storage.write(key: _kSession, value: jsonEncode(session.toJson()));

  @override
  Future<void> clearSession() => _storage.delete(key: _kSession);
}

/// DEV-ONLY plaintext file store. Used only on local builds that have no
/// code-signing identity, where the OS keystore is unavailable (macOS
/// flutter_secure_storage needs the keychain-access-groups entitlement, which
/// needs a real signing cert). Persists the same JSON blobs the keystore would
/// hold, to a file under the user's home, so a relaunch still resumes.
///
/// NEVER use in production — credentials are written in cleartext. Gated
/// behind the `POS_DEV_INSECURE_STORE` compile-time flag in [credentialStore].
class FileCredentialStore implements CredentialStore {
  FileCredentialStore(this._file);

  final File _file;

  /// `$HOME/.config/desktop_pos_dev/credentials.json` (or the OS temp dir if
  /// HOME is unset). The directory is created lazily on first write.
  factory FileCredentialStore.defaultLocation() {
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        Directory.systemTemp.path;
    final path = '$home/.config/desktop_pos_dev/credentials.json';
    return FileCredentialStore(File(path));
  }

  Future<Map<String, dynamic>> _readAll() async {
    if (!await _file.exists()) return {};
    final raw = await _file.readAsString();
    if (raw.trim().isEmpty) return {};
    return (jsonDecode(raw) as Map).cast<String, dynamic>();
  }

  Future<void> _writeAll(Map<String, dynamic> data) async {
    await _file.parent.create(recursive: true);
    await _file.writeAsString(jsonEncode(data), flush: true);
  }

  static const _kDevice = 'device';
  static const _kSession = 'session';

  @override
  Future<DeviceCredential?> loadDevice() async {
    final j = (await _readAll())[_kDevice];
    return j == null
        ? null
        : DeviceCredential.fromJson((j as Map).cast<String, dynamic>());
  }

  @override
  Future<void> saveDevice(DeviceCredential device) async {
    final all = await _readAll();
    all[_kDevice] = device.toJson();
    await _writeAll(all);
  }

  @override
  Future<Session?> loadSession() async {
    final j = (await _readAll())[_kSession];
    return j == null
        ? null
        : Session.fromJson((j as Map).cast<String, dynamic>());
  }

  @override
  Future<void> saveSession(Session session) async {
    final all = await _readAll();
    all[_kSession] = session.toJson();
    await _writeAll(all);
  }

  @override
  Future<void> clearSession() async {
    final all = await _readAll();
    all.remove(_kSession);
    await _writeAll(all);
  }
}

/// Defaults to the real keystore; the [FlutterSecureStorage] handle is cheap
/// to construct (no I/O until read/write). Tests override this provider with
/// an [InMemoryCredentialStore].
///
/// Dev escape hatch: build with `--dart-define=POS_DEV_INSECURE_STORE=true` to
/// persist credentials to a plaintext file instead of the OS keystore. This
/// exists ONLY so local macOS builds without a signing identity can be tested
/// end-to-end; it is off by default and must never ship enabled.
@Riverpod(keepAlive: true)
CredentialStore credentialStore(CredentialStoreRef ref) {
  const devInsecureStore =
      bool.fromEnvironment('POS_DEV_INSECURE_STORE');
  if (devInsecureStore) {
    return FileCredentialStore.defaultLocation();
  }
  return SecureCredentialStore(const FlutterSecureStorage());
}
