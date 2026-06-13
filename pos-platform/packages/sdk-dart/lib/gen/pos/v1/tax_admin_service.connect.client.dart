//
//  Generated code. Do not modify.
//  source: pos/v1/tax_admin_service.proto
//

import "package:connectrpc/connect.dart" as connect;
import "tax_admin_service.pb.dart" as posv1tax_admin_service;
import "tax_admin_service.connect.spec.dart" as specs;

/// TaxAdminService is the operator-facing surface for tax category +
/// component management. Used by the desktop client's settings UI so the
/// operator doesn't have to write raw SQL to define rates.
/// Note: TaxAdminService writes are NOT events — they mutate the local
/// catalog directly. The cloud will eventually source tax catalogs from
/// a tenant-config push instead. Until then, this surface is the only
/// way to seed rates after Phase 2.
extension type TaxAdminServiceClient (connect.Transport _transport) {
  Future<posv1tax_admin_service.UpsertTaxCategoryResponse> upsertTaxCategory(
    posv1tax_admin_service.UpsertTaxCategoryRequest input, {
    connect.Headers? headers,
    connect.AbortSignal? signal,
    Function(connect.Headers)? onHeader,
    Function(connect.Headers)? onTrailer,
  }) {
    return connect.Client(_transport).unary(
      specs.TaxAdminService.upsertTaxCategory,
      input,
      signal: signal,
      headers: headers,
      onHeader: onHeader,
      onTrailer: onTrailer,
    );
  }

  Future<posv1tax_admin_service.UpsertTaxComponentResponse> upsertTaxComponent(
    posv1tax_admin_service.UpsertTaxComponentRequest input, {
    connect.Headers? headers,
    connect.AbortSignal? signal,
    Function(connect.Headers)? onHeader,
    Function(connect.Headers)? onTrailer,
  }) {
    return connect.Client(_transport).unary(
      specs.TaxAdminService.upsertTaxComponent,
      input,
      signal: signal,
      headers: headers,
      onHeader: onHeader,
      onTrailer: onTrailer,
    );
  }

  Future<posv1tax_admin_service.GetTaxCategoryResponse> getTaxCategory(
    posv1tax_admin_service.GetTaxCategoryRequest input, {
    connect.Headers? headers,
    connect.AbortSignal? signal,
    Function(connect.Headers)? onHeader,
    Function(connect.Headers)? onTrailer,
  }) {
    return connect.Client(_transport).unary(
      specs.TaxAdminService.getTaxCategory,
      input,
      signal: signal,
      headers: headers,
      onHeader: onHeader,
      onTrailer: onTrailer,
    );
  }
}
