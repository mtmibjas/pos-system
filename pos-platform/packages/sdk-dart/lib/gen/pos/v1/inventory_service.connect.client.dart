//
//  Generated code. Do not modify.
//  source: pos/v1/inventory_service.proto
//

import "package:connectrpc/connect.dart" as connect;
import "inventory_service.pb.dart" as posv1inventory_service;
import "inventory_service.connect.spec.dart" as specs;

/// InventoryService is the read-side surface for stock-on-hand views.
/// Write operations land via SaleService.Finalize / RefundService.* —
/// inventory movements are an internal append-only ledger.
extension type InventoryServiceClient (connect.Transport _transport) {
  /// ListOnHand returns the live per-SKU on-hand quantity for one store.
  /// Empty / unseeded SKUs are omitted. Results are sorted by SKU.
  Future<posv1inventory_service.ListOnHandResponse> listOnHand(
    posv1inventory_service.ListOnHandRequest input, {
    connect.Headers? headers,
    connect.AbortSignal? signal,
    Function(connect.Headers)? onHeader,
    Function(connect.Headers)? onTrailer,
  }) {
    return connect.Client(_transport).unary(
      specs.InventoryService.listOnHand,
      input,
      signal: signal,
      headers: headers,
      onHeader: onHeader,
      onTrailer: onTrailer,
    );
  }
}
