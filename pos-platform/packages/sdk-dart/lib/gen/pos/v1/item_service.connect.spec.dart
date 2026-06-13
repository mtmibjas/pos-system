//
//  Generated code. Do not modify.
//  source: pos/v1/item_service.proto
//

import "package:connectrpc/connect.dart" as connect;
import "item_service.pb.dart" as posv1item_service;

/// ItemService is the operator-facing catalog surface. The desktop
/// client browses/searches items to build a cart; the picked SKU and
/// denormalized price + tax_category_id then flow through
/// FinalizeSaleLine on SaleService.Finalize.
/// Like TaxAdminService, item writes are NOT events — they mutate the
/// local catalog directly. The cloud will eventually push a tenant
/// catalog down; until then, UpsertItem (and cmd/seed-demo) are the
/// only seed paths.
abstract final class ItemService {
  /// Fully-qualified name of the ItemService service.
  static const name = 'pos.v1.ItemService';

  static const upsertItem = connect.Spec(
    '/$name/UpsertItem',
    connect.StreamType.unary,
    posv1item_service.UpsertItemRequest.new,
    posv1item_service.UpsertItemResponse.new,
  );

  static const getItem = connect.Spec(
    '/$name/GetItem',
    connect.StreamType.unary,
    posv1item_service.GetItemRequest.new,
    posv1item_service.GetItemResponse.new,
  );

  static const listItems = connect.Spec(
    '/$name/ListItems',
    connect.StreamType.unary,
    posv1item_service.ListItemsRequest.new,
    posv1item_service.ListItemsResponse.new,
  );
}
