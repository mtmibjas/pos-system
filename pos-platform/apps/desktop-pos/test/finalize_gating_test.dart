/// Step 6d — Finalize write-gating (docs/desktop-local-persistence.md §5.1).
///
/// When the store server is unreachable, charge() must NOT hit the wire: it
/// surfaces a FinalizeBlockedException and the cart is left intact. Health is
/// driven honestly through the aggregator (recordFailure), not stubbed.
library;

import 'package:connectrpc/test.dart' as ctest;
import 'package:desktop_pos/core/connection_health_provider.dart';
import 'package:desktop_pos/core/realtime.dart';
import 'package:desktop_pos/core/transport.dart';
import 'package:desktop_pos/domain/connection_health.dart';
import 'package:desktop_pos/features/cart/cart_controller.dart';
import 'package:desktop_pos/features/cart/finalize_controller.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_sdk/gen/pos/v1/common.pb.dart';
import 'package:pos_sdk/gen/pos/v1/item_service.pb.dart' as itempb;
import 'package:pos_sdk/gen/pos/v1/sale_service.connect.spec.dart';
import 'package:pos_sdk/gen/pos/v1/sale_service.pb.dart';

import 'realtime_test.dart' show FakeRealtimeChannel;

itempb.Item _item(String sku, int units) => itempb.Item(
      sku: sku,
      name: 'name-$sku',
      price: Money(currencyCode: 'INR', units: Int64(units), nanos: 0),
      taxCategoryId: 'GST-18',
    );

void main() {
  test('charge() is blocked when the store server is unreachable', () async {
    var wireHit = false;
    final fake = ctest.FakeTransportBuilder()
        .unary(SaleService.finalize, (req, _) async {
      wireHit = true;
      return FinalizeResponse(saleId: req.saleId);
    }).build();

    final c = ProviderContainer(overrides: [
      transportProvider.overrideWithValue(fake),
      realtimeChannelProvider.overrideWithValue(FakeRealtimeChannel()),
      healthProbeProvider.overrideWithValue((_) async => false),
      clockProvider.overrideWithValue(() => DateTime.utc(2026, 8, 2)),
    ]);
    addTearDown(c.dispose);

    // Drive health to confirmed-unreachable (connection refused).
    c
        .read(connectionHealthControllerProvider.notifier)
        .recordFailure(FailureKind.refused, 'ECONNREFUSED');
    expect(c.read(connectionHealthControllerProvider).isUnreachable, isTrue);

    final n = c.read(cartControllerProvider.notifier);
    n.addLine(_item('A', 10));
    final cart = c.read(cartControllerProvider);

    await c.read(finalizeControllerProvider.notifier).charge(
          cart: cart,
          method: TenderMethod.cash,
          amount: Money(currencyCode: 'INR', units: Int64(10), nanos: 0),
        );

    final state = c.read(finalizeControllerProvider);
    expect(state.hasError, isTrue);
    expect(state.error, isA<FinalizeBlockedException>());
    expect(wireHit, isFalse, reason: 'must not finalize while blind');
    // Cart is preserved — nothing was lost.
    expect(c.read(cartControllerProvider).lines, isNotEmpty);
  });

  test('charge() proceeds once the server is reachable again', () async {
    var wireHit = false;
    final fake = ctest.FakeTransportBuilder()
        .unary(SaleService.finalize, (req, _) async {
      wireHit = true;
      return FinalizeResponse(
          saleId: req.saleId, invoice: Invoice(invoiceNumber: 'INV-1'));
    }).build();

    final c = ProviderContainer(overrides: [
      transportProvider.overrideWithValue(fake),
      realtimeChannelProvider.overrideWithValue(FakeRealtimeChannel()),
      healthProbeProvider.overrideWithValue((_) async => false),
      clockProvider.overrideWithValue(() => DateTime.utc(2026, 8, 2)),
    ]);
    addTearDown(c.dispose);

    final health = c.read(connectionHealthControllerProvider.notifier);
    health.recordFailure(FailureKind.refused, 'down');
    health.recordSuccess(); // server came back
    expect(c.read(connectionHealthControllerProvider).isReachable, isTrue);

    final n = c.read(cartControllerProvider.notifier);
    n.addLine(_item('A', 10));

    await c.read(finalizeControllerProvider.notifier).charge(
          cart: c.read(cartControllerProvider),
          method: TenderMethod.cash,
          amount: Money(currencyCode: 'INR', units: Int64(10), nanos: 0),
        );

    expect(wireHit, isTrue);
    expect(c.read(finalizeControllerProvider).value?.response.invoice
        .invoiceNumber, 'INV-1');
  });
}
