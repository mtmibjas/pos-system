/// InventoryController tests via FakeTransport.
///
/// Covers happy path (request shape + state populated), error
/// surfacing, and recovery via refresh.
library;

import 'package:connectrpc/connect.dart' as connect;
import 'package:connectrpc/test.dart' as ctest;
import 'package:desktop_pos/config.dart';
import 'package:desktop_pos/core/transport.dart';
import 'package:desktop_pos/features/inventory/inventory_controller.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_sdk/gen/pos/v1/common.pb.dart';
import 'package:pos_sdk/gen/pos/v1/inventory_service.connect.spec.dart';
import 'package:pos_sdk/gen/pos/v1/inventory_service.pb.dart';

void main() {
  test('build() loads rows and passes store_id from config', () async {
    ListOnHandRequest? captured;
    final fake = ctest.FakeTransportBuilder()
        .unary(InventoryService.listOnHand, (req, _) async {
      captured = req;
      return ListOnHandResponse(rows: [
        OnHandRow(
          sku: 'A',
          name: 'Apples',
          price: Money(currencyCode: 'INR', units: Int64(10)),
          onHand: Int64(7),
        ),
      ]);
    }).build();

    final c = ProviderContainer(overrides: [
      transportProvider.overrideWithValue(fake),
    ]);
    addTearDown(c.dispose);

    final view = await c.read(inventoryControllerProvider.future);
    expect(view.rows, hasLength(1));
    expect(view.rows.first.row.sku, 'A');
    expect(view.rows.first.row.onHand.toInt(), 7);
    expect(view.rows.first.available, isNull);
    expect(captured!.storeId.value, kStoreId);
  });

  test('error surfaces as AsyncError and refresh recovers', () async {
    var call = 0;
    final fake = ctest.FakeTransportBuilder()
        .unary(InventoryService.listOnHand, (req, _) async {
      call++;
      if (call == 1) {
        throw connect.ConnectException(connect.Code.unavailable, 'boom');
      }
      return ListOnHandResponse(rows: [
        OnHandRow(sku: 'B', onHand: Int64(1)),
      ]);
    }).build();

    final c = ProviderContainer(overrides: [
      transportProvider.overrideWithValue(fake),
    ]);
    addTearDown(c.dispose);

    // Initial build hits the failing arm.
    await expectLater(
      c.read(inventoryControllerProvider.future),
      throwsA(isA<connect.ConnectException>()),
    );
    expect(c.read(inventoryControllerProvider).hasError, isTrue);

    // Refresh re-fetches and gets the second-call success.
    await c.read(inventoryControllerProvider.notifier).refresh();
    final view = c.read(inventoryControllerProvider).value!;
    expect(view.rows.single.row.sku, 'B');
  });
}
