//
//  Generated code. Do not modify.
//  source: pos/v1/item_service.proto
//

import "package:connectrpc/connect.dart" as connect;
import "item_service.pb.dart" as posv1item_service;
import "item_service.connect.spec.dart" as specs;

/// ItemService is the operator-facing catalog surface. The desktop
/// client browses/searches items to build a cart; the picked SKU and
/// denormalized price + tax_category_id then flow through
/// FinalizeSaleLine on SaleService.Finalize.
/// Like TaxAdminService, item writes are NOT events — they mutate the
/// local catalog directly. The cloud will eventually push a tenant
/// catalog down; until then, UpsertItem (and cmd/seed-demo) are the
/// only seed paths.
extension type ItemServiceClient (connect.Transport _transport) {
  Future<posv1item_service.UpsertItemResponse> upsertItem(
    posv1item_service.UpsertItemRequest input, {
    connect.Headers? headers,
    connect.AbortSignal? signal,
    Function(connect.Headers)? onHeader,
    Function(connect.Headers)? onTrailer,
  }) {
    return connect.Client(_transport).unary(
      specs.ItemService.upsertItem,
      input,
      signal: signal,
      headers: headers,
      onHeader: onHeader,
      onTrailer: onTrailer,
    );
  }

  Future<posv1item_service.GetItemResponse> getItem(
    posv1item_service.GetItemRequest input, {
    connect.Headers? headers,
    connect.AbortSignal? signal,
    Function(connect.Headers)? onHeader,
    Function(connect.Headers)? onTrailer,
  }) {
    return connect.Client(_transport).unary(
      specs.ItemService.getItem,
      input,
      signal: signal,
      headers: headers,
      onHeader: onHeader,
      onTrailer: onTrailer,
    );
  }

  Future<posv1item_service.ListItemsResponse> listItems(
    posv1item_service.ListItemsRequest input, {
    connect.Headers? headers,
    connect.AbortSignal? signal,
    Function(connect.Headers)? onHeader,
    Function(connect.Headers)? onTrailer,
  }) {
    return connect.Client(_transport).unary(
      specs.ItemService.listItems,
      input,
      signal: signal,
      headers: headers,
      onHeader: onHeader,
      onTrailer: onTrailer,
    );
  }
}
