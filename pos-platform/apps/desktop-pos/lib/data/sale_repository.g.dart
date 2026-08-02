// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sale_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$saleRepositoryHash() => r'3599dc69dfacdf450f74857b3bf4cf0297409821';

/// The active sale repository. Built over the shared transport, so a test
/// that overrides [transportProvider] flows through here unchanged; tests
/// may also override this provider directly with a fake repository.
///
/// Copied from [saleRepository].
@ProviderFor(saleRepository)
final saleRepositoryProvider = Provider<SaleRepository>.internal(
  saleRepository,
  name: r'saleRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$saleRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef SaleRepositoryRef = ProviderRef<SaleRepository>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
