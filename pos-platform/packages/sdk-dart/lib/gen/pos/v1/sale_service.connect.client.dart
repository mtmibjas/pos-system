//
//  Generated code. Do not modify.
//  source: pos/v1/sale_service.proto
//

import "package:connectrpc/connect.dart" as connect;
import "sale_service.pb.dart" as posv1sale_service;
import "sale_service.connect.spec.dart" as specs;

/// SaleService is the customer-facing transactional surface of the
/// local-store-server. The desktop client calls Finalize when the operator
/// hits "Pay" on a fully-tendered cart. Server is authoritative on tax;
/// caller-supplied totals (if non-zero) must match the engine's output.
/// Idempotency: identical sale_id replay returns the prior FinalizeResponse
/// with idempotent=true rather than creating a duplicate sale.
extension type SaleServiceClient (connect.Transport _transport) {
  Future<posv1sale_service.FinalizeResponse> finalize(
    posv1sale_service.FinalizeRequest input, {
    connect.Headers? headers,
    connect.AbortSignal? signal,
    Function(connect.Headers)? onHeader,
    Function(connect.Headers)? onTrailer,
  }) {
    return connect.Client(_transport).unary(
      specs.SaleService.finalize,
      input,
      signal: signal,
      headers: headers,
      onHeader: onHeader,
      onTrailer: onTrailer,
    );
  }

  /// GetSale is the read-side lookup for a finalized sale. Returns
  /// NotFound if neither key resolves. The caller picks the key — UI
  /// typically uses invoice_number (operator-facing); reversal flows
  /// already hold sale_id and use that.
  Future<posv1sale_service.GetSaleResponse> getSale(
    posv1sale_service.GetSaleRequest input, {
    connect.Headers? headers,
    connect.AbortSignal? signal,
    Function(connect.Headers)? onHeader,
    Function(connect.Headers)? onTrailer,
  }) {
    return connect.Client(_transport).unary(
      specs.SaleService.getSale,
      input,
      signal: signal,
      headers: headers,
      onHeader: onHeader,
      onTrailer: onTrailer,
    );
  }
}
