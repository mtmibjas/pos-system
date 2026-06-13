//
//  Generated code. Do not modify.
//  source: pos/v1/sale_service.proto
//

import "package:connectrpc/connect.dart" as connect;
import "sale_service.pb.dart" as posv1sale_service;

/// SaleService is the customer-facing transactional surface of the
/// local-store-server. The desktop client calls Finalize when the operator
/// hits "Pay" on a fully-tendered cart. Server is authoritative on tax;
/// caller-supplied totals (if non-zero) must match the engine's output.
/// Idempotency: identical sale_id replay returns the prior FinalizeResponse
/// with idempotent=true rather than creating a duplicate sale.
abstract final class SaleService {
  /// Fully-qualified name of the SaleService service.
  static const name = 'pos.v1.SaleService';

  static const finalize = connect.Spec(
    '/$name/Finalize',
    connect.StreamType.unary,
    posv1sale_service.FinalizeRequest.new,
    posv1sale_service.FinalizeResponse.new,
  );

  /// GetSale is the read-side lookup for a finalized sale. Returns
  /// NotFound if neither key resolves. The caller picks the key — UI
  /// typically uses invoice_number (operator-facing); reversal flows
  /// already hold sale_id and use that.
  static const getSale = connect.Spec(
    '/$name/GetSale',
    connect.StreamType.unary,
    posv1sale_service.GetSaleRequest.new,
    posv1sale_service.GetSaleResponse.new,
  );
}
