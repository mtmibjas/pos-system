/// Controller for the item picker screen.
///
/// Wraps ItemService.ListItems in a Riverpod AsyncNotifier. `build()`
/// kicks off the initial fetch so the UI sees a loading spinner
/// immediately on mount; `refresh()` re-runs the call (used by pull-to-
/// refresh and the manual reload button on the app bar).
///
/// `includeArchived` is fixed to false — the picker is for live
/// catalog browsing only. Admin/management surfaces (Slice 3+) will
/// use a separate controller if they need archived rows.
library;

import 'package:pos_sdk/gen/pos/v1/item_service.connect.client.dart';
import 'package:pos_sdk/gen/pos/v1/item_service.pb.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/transport.dart';

part 'items_controller.g.dart';

@riverpod
class ItemsController extends _$ItemsController {
  @override
  Future<List<Item>> build() async {
    return _fetch();
  }

  /// Re-fetch the catalog. UI transitions to loading then either
  /// data or error — same shape as `build()`.
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<List<Item>> _fetch() async {
    final client = ItemServiceClient(ref.read(transportProvider));
    final resp = await client.listItems(
      ListItemsRequest(includeArchived: false),
    );
    return resp.items;
  }
}
