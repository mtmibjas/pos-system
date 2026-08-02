// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'credential_store.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$credentialStoreHash() => r'b552f084b651eb59decc615613251cf5faa990de';

/// Defaults to the real keystore; the [FlutterSecureStorage] handle is cheap
/// to construct (no I/O until read/write). Tests override this provider with
/// an [InMemoryCredentialStore].
///
/// Dev escape hatch: build with `--dart-define=POS_DEV_INSECURE_STORE=true` to
/// persist credentials to a plaintext file instead of the OS keystore. This
/// exists ONLY so local macOS builds without a signing identity can be tested
/// end-to-end; it is off by default and must never ship enabled.
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
