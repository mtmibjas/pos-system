/// FinalizeController tests — covers the request-shape and error
/// surfacing without standing up a real server.
///
/// We inspect the captured FinalizeRequest to confirm:
///   - sale_id is a UUID v4
///   - cart lines become FinalizeSaleLines with the right qty / price
///   - tender row carries the picked method + amount
///   - store/counter/cashier come from config constants
/// And on failure, the totals-mismatch FailedPrecondition surfaces as
/// AsyncError(ConnectException).
library;

import 'package:connectrpc/connect.dart' as connect;
import 'package:connectrpc/test.dart' as ctest;
import 'package:desktop_pos/config.dart';
import 'package:desktop_pos/core/transport.dart';
import 'package:desktop_pos/features/cart/cart_controller.dart';
import 'package:desktop_pos/features/cart/finalize_controller.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_sdk/gen/pos/v1/common.pb.dart';
import 'package:pos_sdk/gen/pos/v1/item_service.pb.dart' as itempb;
import 'package:pos_sdk/gen/pos/v1/sale_service.connect.spec.dart';
import 'package:pos_sdk/gen/pos/v1/sale_service.pb.dart';

itempb.Item _item(String sku, int units) => itempb.Item(
      sku: sku,
      name: 'name-$sku',
      price: Money(currencyCode: 'INR', units: Int64(units), nanos: 0),
      taxCategoryId: 'GST-18',
    );

CartState _cartFrom(List<itempb.Item> items, ProviderContainer c) {
  final n = c.read(cartControllerProvider.notifier);
  for (final i in items) {
    n.addLine(i);
  }
  return c.read(cartControllerProvider);
}

void main() {
  test('charge() sends a well-formed FinalizeRequest', () async {
    FinalizeRequest? captured;
    final fake = ctest.FakeTransportBuilder()
        .unary(SaleService.finalize, (req, _) async {
      captured = req;
      return FinalizeResponse(
        saleId: req.saleId,
        invoice: Invoice(invoiceNumber: 'INV-2026-000001'),
      );
    }).build();

    final c = ProviderContainer(overrides: [
      transportProvider.overrideWithValue(fake),
    ]);
    addTearDown(c.dispose);

    final cart = _cartFrom([_item('A', 10), _item('B', 20)], c);
    final amount = Money(currencyCode: 'INR', units: Int64(30), nanos: 0);

    await c.read(finalizeControllerProvider.notifier).charge(
          cart: cart,
          method: TenderMethod.cash,
          amount: amount,
        );

    final state = c.read(finalizeControllerProvider);
    expect(state.hasValue, isTrue);
    expect(state.value?.response.invoice.invoiceNumber, 'INV-2026-000001');
    // FinalizeRecord plumbs the minted saleId + per-SKU line_ids + tender ID
    // through so the reversal flow can build a refund request.
    expect(state.value?.saleId, hasLength(36));
    expect(state.value?.lineIdsBySku.keys, containsAll(['A', 'B']));
    expect(state.value?.tenders.single.method, TenderMethod.cash);

    expect(captured, isNotNull);
    expect(captured!.saleId, hasLength(36)); // uuid v4 canonical
    expect(captured!.storeId.value, kStoreId);
    expect(captured!.counterId.value, kCounterId);
    expect(captured!.cashierId.value, kCashierId);
    expect(captured!.lines, hasLength(2));
    expect(captured!.lines[0].sku, 'A');
    expect(captured!.lines[0].quantity.toInt(), 1);
    expect(captured!.lines[0].unitPrice.units.toInt(), 10);
    expect(captured!.lines[0].taxCategoryId, 'GST-18');
    expect(captured!.tenders, hasLength(1));
    expect(captured!.tenders.single.method, 'cash');
    expect(captured!.tenders.single.amount.units.toInt(), 30);
    // Engine fills totals — client sends zero.
    expect(captured!.subtotal.units.toInt(), 0);
    expect(captured!.taxTotal.units.toInt(), 0);
    expect(captured!.grandTotal.units.toInt(), 0);
  });

  test('charge() exposes FailedPrecondition as AsyncError', () async {
    final fake = ctest.FakeTransportBuilder()
        .unary(SaleService.finalize, (req, _) async {
      throw connect.ConnectException(
        connect.Code.failedPrecondition,
        'totals mismatch',
      );
    }).build();

    final c = ProviderContainer(overrides: [
      transportProvider.overrideWithValue(fake),
    ]);
    addTearDown(c.dispose);

    final cart = _cartFrom([_item('A', 10)], c);
    final amount = Money(currencyCode: 'INR', units: Int64(10), nanos: 0);

    await c.read(finalizeControllerProvider.notifier).charge(
          cart: cart,
          method: TenderMethod.cash,
          amount: amount,
        );

    final state = c.read(finalizeControllerProvider);
    expect(state.hasError, isTrue);
    expect(state.error, isA<connect.ConnectException>());
    expect(
      (state.error as connect.ConnectException).code,
      connect.Code.failedPrecondition,
    );
  });

  test('charge() on empty cart is a no-op', () async {
    var called = false;
    final fake = ctest.FakeTransportBuilder()
        .unary(SaleService.finalize, (req, _) async {
      called = true;
      return FinalizeResponse();
    }).build();

    final c = ProviderContainer(overrides: [
      transportProvider.overrideWithValue(fake),
    ]);
    addTearDown(c.dispose);

    await c.read(finalizeControllerProvider.notifier).charge(
          cart: const CartState(),
          method: TenderMethod.cash,
          amount: Money(currencyCode: 'INR', units: Int64(0), nanos: 0),
        );

    expect(called, isFalse);
    final state = c.read(finalizeControllerProvider);
    // build() returns null; an empty-cart charge leaves it untouched.
    expect(state.valueOrNull, isNull);
  });
}
