// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'credential_store.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$credentialStoreHash() => r'6552e07da57b9fa160cd84d7a75b3173b0d3495a';

/// Defaults to the real keystore; the [FlutterSecureStorage] handle is cheap
/// to construct (no I/O until read/write). Tests override this provider with
/// an [InMemoryCredentialStore].
///
/// Copied from [credentialStore].
@ProviderFor(credentialStore)
final credentialStoreProvider = Provider<CredentialStore>.internal(
  credentialStore,
  name: r'credentialStoreProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$credentialStoreHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef CredentialStoreRef = ProviderRef<CredentialStore>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
