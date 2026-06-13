//
//  Generated code. Do not modify.
//  source: pos/v1/inventory_service.proto
//

import "package:connectrpc/connect.dart" as connect;
import "inventory_service.pb.dart" as posv1inventory_service;

/// InventoryService is the read-side surface for stock-on-hand views.
/// Write operations land via SaleService.Finalize / RefundService.* —
/// inventory movements are an internal append-only ledger.
abstract final class InventoryService {
  /// Fully-qualified name of the InventoryService service.
  static const name = 'pos.v1.InventoryService';

  /// ListOnHand returns the live per-SKU on-hand quantity for one store.
  /// Empty / unseeded SKUs are omitted. Results are sorted by SKU.
  static const listOnHand = connect.Spec(
    '/$name/ListOnHand',
    connect.StreamType.unary,
    posv1inventory_service.ListOnHandRequest.new,
    posv1inventory_service.ListOnHandResponse.new,
  );
}
