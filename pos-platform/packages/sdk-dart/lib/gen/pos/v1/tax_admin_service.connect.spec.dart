//
//  Generated code. Do not modify.
//  source: pos/v1/tax_admin_service.proto
//

import "package:connectrpc/connect.dart" as connect;
import "tax_admin_service.pb.dart" as posv1tax_admin_service;

/// TaxAdminService is the operator-facing surface for tax category +
/// component management. Used by the desktop client's settings UI so the
/// operator doesn't have to write raw SQL to define rates.
/// Note: TaxAdminService writes are NOT events — they mutate the local
/// catalog directly. The cloud will eventually source tax catalogs from
/// a tenant-config push instead. Until then, this surface is the only
/// way to seed rates after Phase 2.
abstract final class TaxAdminService {
  /// Fully-qualified name of the TaxAdminService service.
  static const name = 'pos.v1.TaxAdminService';

  static const upsertTaxCategory = connect.Spec(
    '/$name/UpsertTaxCategory',
    connect.StreamType.unary,
    posv1tax_admin_service.UpsertTaxCategoryRequest.new,
    posv1tax_admin_service.UpsertTaxCategoryResponse.new,
  );

  static const upsertTaxComponent = connect.Spec(
    '/$name/UpsertTaxComponent',
    connect.StreamType.unary,
    posv1tax_admin_service.UpsertTaxComponentRequest.new,
    posv1tax_admin_service.UpsertTaxComponentResponse.new,
  );

  static const getTaxCategory = connect.Spec(
    '/$name/GetTaxCategory',
    connect.StreamType.unary,
    posv1tax_admin_service.GetTaxCategoryRequest.new,
    posv1tax_admin_service.GetTaxCategoryResponse.new,
  );
}
