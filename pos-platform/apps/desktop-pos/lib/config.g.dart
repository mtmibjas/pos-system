// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'config.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$terminalConfigHash() => r'01a90eb1ad9817eadf4a69d8ecdf1eb59759e96a';

/// The active terminal config. Defaults to the Phase-2 values; overridden in
/// tests via `ProviderScope`, and (later) replaced by a provider that reads
/// persisted provisioning.
///
/// Copied from [terminalConfig].
@ProviderFor(terminalConfig)
final terminalConfigProvider = Provider<TerminalConfig>.internal(
  terminalConfig,
  name: r'terminalConfigProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$terminalConfigHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef TerminalConfigRef = ProviderRef<TerminalConfig>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
