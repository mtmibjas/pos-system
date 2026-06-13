/// Unit tests for ItemsController using connectrpc FakeTransport.
///
/// Covers the three state transitions a UI consumer can observe:
///   - initial build → AsyncData(items) on success
///   - initial build → AsyncError on server error
///   - refresh()     → AsyncData after a prior error (recovery path)
///
/// Live-server smoke coverage of ItemService is exercised manually via
/// the Flutter app + cmd/seed-demo, plus the Go-side api_test.go
/// round-trip suite.
library;

import 'package:connectrpc/connect.dart' as connect;
import 'package:connectrpc/test.dart' as ctest;
import 'package:desktop_pos/core/transport.dart';
import 'package:desktop_pos/features/items/items_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_sdk/gen/pos/v1/item_service.connect.spec.dart';
import 'package:pos_sdk/gen/pos/v1/item_service.pb.dart';

void main() {
  test('build() returns the catalog on success', () async {
    final seeded = ListItemsResponse(items: [
      Item(sku: 'BREAD-WW', name: 'Whole wheat bread'),
      Item(sku: 'MILK-1L', name: 'Toned milk (1L)'),
    ]);
    final fake = ctest.FakeTransportBuilder()
        .unary(ItemService.listItems, (req, _) async => seeded)
        .build();

    final container = ProviderContainer(overrides: [
      transportProvider.overrideWithValue(fake),
    ]);
    addTearDown(container.dispose);

    final items =
        await container.read(itemsControllerProvider.future);

    expect(items.map((i) => i.sku), ['BREAD-WW', 'MILK-1L']);
  });

  test('build() exposes server errors as AsyncError', () async {
    final fake = ctest.FakeTransportBuilder()
        .unary(ItemService.listItems, (req, _) async {
      throw connect.ConnectException(connect.Code.unavailable, 'down');
    }).build();

    final container = ProviderContainer(overrides: [
      transportProvider.overrideWithValue(fake),
    ]);
    addTearDown(container.dispose);

    await expectLater(
      container.read(itemsControllerProvider.future),
      throwsA(isA<connect.ConnectException>()),
    );
    final state = container.read(itemsControllerProvider);
    expect(state.hasError, isTrue);
    expect(
      (state.error as connect.ConnectException).code,
      connect.Code.unavailable,
    );
  });

  test('refresh() can recover from a prior error', () async {
    var calls = 0;
    final fake = ctest.FakeTransportBuilder()
        .unary(ItemService.listItems, (req, _) async {
      calls++;
      if (calls == 1) {
        throw connect.ConnectException(connect.Code.unavailable, 'cold start');
      }
      return ListItemsResponse(items: [Item(sku: 'APPLE-1KG', name: 'Apples')]);
    }).build();

    final container = ProviderContainer(overrides: [
      transportProvider.overrideWithValue(fake),
    ]);
    addTearDown(container.dispose);

    // First read fails.
    await expectLater(
      container.read(itemsControllerProvider.future),
      throwsA(isA<connect.ConnectException>()),
    );
    expect(container.read(itemsControllerProvider).hasError, isTrue);

    // Refresh succeeds.
    await container.read(itemsControllerProvider.notifier).refresh();
    final state = container.read(itemsControllerProvider);
    expect(state.hasValue, isTrue);
    expect(state.value!.single.sku, 'APPLE-1KG');
    expect(calls, 2);
  });
}
