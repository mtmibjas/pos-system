// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'connection_health_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$clockHash() => r'a26b013105e788969b25b5c8d5587776aab593d3';

/// Injectable clock so `lastOkAt` is deterministic in tests.
///
/// Copied from [clock].
@ProviderFor(clock)
final clockProvider = Provider<DateTime Function()>.internal(
  clock,
  name: r'clockProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$clockHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef ClockRef = ProviderRef<DateTime Function()>;
String _$healthProbeHash() => r'dd75b9bfd3ef36dc6be8a8c411bfe04c01cca1ae';

/// See also [healthProbe].
@ProviderFor(healthProbe)
final healthProbeProvider = Provider<HealthProbe>.internal(
  healthProbe,
  name: r'healthProbeProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$healthProbeHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef HealthProbeRef = ProviderRef<HealthProbe>;
String _$connectionHealthControllerHash() =>
    r'68ff99db319bdd87cc6b2f0c659241cb523c5a7f';

/// The aggregator. Public [recordSuccess]/[recordFailure] are the RPC hooks;
/// the realtime listener and probe are wired internally.
///
/// Copied from [ConnectionHealthController].
@ProviderFor(ConnectionHealthController)
final connectionHealthControllerProvider =
    NotifierProvider<ConnectionHealthController, ConnectionHealth>.internal(
  ConnectionHealthController.new,
  name: r'connectionHealthControllerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$connectionHealthControllerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$ConnectionHealthController = Notifier<ConnectionHealth>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
