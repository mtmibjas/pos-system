/// Step 8c — the item picker consumes the BarcodeScanner PORT. A simulated
/// scan of a known SKU should reserve + add it to the cart, proving the
/// keystroke→port→cart wiring without any real hardware.
library;

import 'package:connectrpc/test.dart' as ctest;
import 'package:desktop_pos/core/transport.dart';
import 'package:desktop_pos/features/cart/cart_controller.dart';
import 'package:desktop_pos/features/items/item_picker_screen.dart';
import 'package:desktop_pos/hardware/hardware_providers.dart';
import 'package:desktop_pos/hardware/noop_adapters.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_sdk/gen/pos/v1/common.pb.dart';
import 'package:pos_sdk/gen/pos/v1/item_service.connect.spec.dart';
import 'package:pos_sdk/gen/pos/v1/item_service.pb.dart';
import 'package:pos_sdk/gen/pos/v1/reservation_service.connect.spec.dart';
import 'package:pos_sdk/gen/pos/v1/reservation_service.pb.dart';

void main() {
  testWidgets('a simulated scan adds the item to the cart', (tester) async {
    final scanner = SimulatedScanner();
    addTearDown(scanner.dispose);

    final fake = ctest.FakeTransportBuilder()
        .unary(ItemService.listItems, (req, _) async => ListItemsResponse(items: [
              Item(
                sku: 'RICE',
                name: 'Rice 1kg',
                price: Money(currencyCode: 'INR', units: Int64(575)),
                taxCategoryId: 'GST-18',
              ),
            ]))
        .unary(ReservationService.reserve, (req, _) async => ReserveResponse())
        .build();

    final c = ProviderContainer(overrides: [
      transportProvider.overrideWithValue(fake),
      barcodeScannerProvider.overrideWithValue(scanner),
    ]);
    addTearDown(c.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: const MaterialApp(home: ItemPickerScreen()),
    ));
    await tester.pumpAndSettle(); // load the catalog

    // Fire a scan through the port — as if the HID scanner had typed + Enter.
    scanner.emit('RICE');
    await tester.pump(); // deliver the stream event
    await tester.pump(const Duration(milliseconds: 100)); // reserve resolves

    expect(c.read(cartControllerProvider).lines.single.sku, 'RICE');

    // Drain the confirmation snackbar timer so no timers dangle at teardown.
    await tester.pump(const Duration(seconds: 3));
  });
}
