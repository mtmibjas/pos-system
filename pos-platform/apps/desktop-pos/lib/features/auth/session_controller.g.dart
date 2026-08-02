// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$rolePolicyHash() => r'4df1c3b62ff0101ca6e65bba5c51056526c6c2a2';

/// The active role policy, derived from the current session (empty when
/// logged out).
///
/// Copied from [rolePolicy].
@ProviderFor(rolePolicy)
final rolePolicyProvider = AutoDisposeProvider<RolePolicy>.internal(
  rolePolicy,
  name: r'rolePolicyProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$rolePolicyHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef RolePolicyRef = AutoDisposeProviderRef<RolePolicy>;
String _$cashierIdHash() => r'9a8fb3d0667d133621aaa59b278e14a6cacc9a10';

/// The cashier id stamped on sales/refunds/voids — the logged-in user's
/// username. Relocated here from the config seam now that a session exists.
/// Falls back to a placeholder until the login gate lands (D4), so the app
/// still functions pre-auth.
///
/// Copied from [cashierId].
@ProviderFor(cashierId)
final cashierIdProvider = AutoDisposeProvider<String>.internal(
  cashierId,
  name: r'cashierIdProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$cashierIdHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef CashierIdRef = AutoDisposeProviderRef<String>;
String _$deviceControllerHash() => r'29efcc624fb0e8accd3581ca89c4aa85391d6a3a';

/// Holds the stored device credential and runs manager-gated registration.
/// Build resolves to the persisted credential (null = not provisioned).
///
/// Copied from [DeviceController].
@ProviderFor(DeviceController)
final deviceControllerProvider =
    AsyncNotifierProvider<DeviceController, DeviceCredential?>.internal(
  DeviceController.new,
  name: r'deviceControllerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$deviceControllerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$DeviceController = AsyncNotifier<DeviceCredential?>;
String _$sessionControllerHash() => r'c631d6330d99c2ce22627f7f4c1c24db303cbed8';

/// The current cashier session. Build restores a non-expired session from
/// secure storage so a relaunch resumes without re-login.
///
/// Copied from [SessionController].
@ProviderFor(SessionController)
final sessionControllerProvider =
    AsyncNotifierProvider<SessionController, Session?>.internal(
  SessionController.new,
  name: r'sessionControllerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$sessionControllerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$SessionController = AsyncNotifier<Session?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
