/// Auth session + provisioning + role policy (docs/desktop-architecture.md
/// §4.2, D3).
///
///   - [DeviceController]   — manager-gated device registration; persists
///                            the device credential (provisioning, §4.1).
///   - [SessionController]  — cashier login/logout; restores a non-expired
///                            session from secure storage on boot.
///   - [RolePolicy]         — what the current session may do (feeds the
///                            role-aware nav shell, D4).
///   - [cashierIdProvider]  — the identity stamped on sales; session-derived
///                            (relocated here from the config seam).
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/auth_repository.dart';
import '../../data/credential_store.dart';

part 'session_controller.g.dart';

/// Thrown by [SessionController.login] when no device credential is stored —
/// the terminal must be provisioned first. The UI routes this to the
/// provisioning screen rather than showing a credential error.
class NotProvisionedException implements Exception {
  const NotProvisionedException();
  @override
  String toString() => 'terminal is not provisioned';
}

/// Holds the stored device credential and runs manager-gated registration.
/// Build resolves to the persisted credential (null = not provisioned).
@Riverpod(keepAlive: true)
class DeviceController extends _$DeviceController {
  @override
  Future<DeviceCredential?> build() =>
      ref.read(credentialStoreProvider).loadDevice();

  /// Registers THIS terminal. The manager authenticates inline (server
  /// requires the owner role). On success the credential is persisted and
  /// becomes the controller's state.
  Future<void> register({
    required String managerUsername,
    required String managerPassword,
    required String deviceName,
    String? replaceCounterId,
  }) async {
    final repo = ref.read(authRepositoryProvider);
    final store = ref.read(credentialStoreProvider);
    // No intermediate AsyncLoading: the provisioning screen owns its submit
    // spinner, and leaving the controller's value untouched keeps the boot
    // gate from flickering to a splash mid-call.
    state = await AsyncValue.guard(() async {
      final cred = await repo.registerDevice(
        managerUsername: managerUsername,
        managerPassword: managerPassword,
        deviceName: deviceName,
        replaceCounterId: replaceCounterId,
      );
      await store.saveDevice(cred);
      return cred;
    });
  }
}

/// The current cashier session. Build restores a non-expired session from
/// secure storage so a relaunch resumes without re-login.
@Riverpod(keepAlive: true)
class SessionController extends _$SessionController {
  @override
  Future<Session?> build() async {
    final stored = await ref.read(credentialStoreProvider).loadSession();
    return (stored != null && !stored.isExpired) ? stored : null;
  }

  /// Logs a cashier in on the provisioned device. Surfaces
  /// [NotProvisionedException] if the terminal has no device credential yet.
  Future<void> login({
    required String username,
    required String password,
  }) async {
    final store = ref.read(credentialStoreProvider);
    final device = await store.loadDevice();
    if (device == null) {
      state = AsyncValue.error(
          const NotProvisionedException(), StackTrace.current);
      return;
    }
    // No intermediate AsyncLoading — the login screen owns its submit
    // spinner; see the note in DeviceController.register.
    state = await AsyncValue.guard(() async {
      final session = await ref.read(authRepositoryProvider).login(
            deviceId: device.deviceId,
            deviceSecret: device.deviceSecret,
            username: username,
            password: password,
          );
      await store.saveSession(session);
      return session;
    });
  }

  /// Ends the session and clears the stored token (the device credential is
  /// kept — the terminal stays provisioned).
  Future<void> logout() async {
    await ref.read(credentialStoreProvider).clearSession();
    state = const AsyncValue.data(null);
  }
}

/// What the current session may do. Pure projection of the session's roles;
/// the nav shell and controllers consult it (no UI-only gating).
class RolePolicy {
  const RolePolicy(this.roles);
  final List<String> roles;

  static const empty = RolePolicy([]);

  bool get isAuthenticated => roles.isNotEmpty;
  bool get isOwner => roles.contains('owner');
  bool get isCashier => roles.contains('cashier');

  // Capability checks the nav shell (D4) and controllers gate on.
  bool get canSell => isOwner || isCashier;
  bool get canManageItems => isOwner;
  bool get canManageCashiers => isOwner;
  bool get canViewReports => isOwner;
}

/// The active role policy, derived from the current session (empty when
/// logged out).
@riverpod
RolePolicy rolePolicy(RolePolicyRef ref) {
  final session = ref.watch(sessionControllerProvider).valueOrNull;
  return RolePolicy(session?.roles ?? const []);
}

/// The cashier id stamped on sales/refunds/voids — the logged-in user's
/// username. Relocated here from the config seam now that a session exists.
/// Falls back to a placeholder until the login gate lands (D4), so the app
/// still functions pre-auth.
@riverpod
String cashierId(CashierIdRef ref) {
  final session = ref.watch(sessionControllerProvider).valueOrNull;
  return session?.username ?? 'cashier-1';
}
