/// RefundController tests using a FakeTransport.
///
/// Covers happy path (request mirrors cart + reuses original payment
/// IDs as original_payment_id, sale_line_id is plumbed from
/// FinalizeRecord.lineIdsBySku) and the already-refunded
/// FailedPrecondition surfacing as AsyncError.
library;

import 'package:connectrpc/connect.dart' as connect;
import 'package:connectrpc/test.dart' as ctest;
import 'package:desktop_pos/core/transport.dart';
import 'package:desktop_pos/features/cart/cart_controller.dart';
import 'package:desktop_pos/features/cart/finalize_controller.dart';
import 'package:desktop_pos/features/reversal/refund_controller.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_sdk/gen/pos/v1/common.pb.dart';
import 'package:pos_sdk/gen/pos/v1/item_service.pb.dart' as itempb;
import 'package:pos_sdk/gen/pos/v1/refund_service.connect.spec.dart';
import 'package:pos_sdk/gen/pos/v1/refund_service.pb.dart';
import 'package:pos_sdk/gen/pos/v1/sale_service.pb.dart';

itempb.Item _item(String sku, int units, {String tax = 'GST-18'}) =>
    itempb.Item(
      sku: sku,
      name: 'name-$sku',
      price: Money(currencyCode: 'INR', units: Int64(units), nanos: 0),
      taxCategoryId: tax,
    );

CartState _cartFrom(List<itempb.Item> items, ProviderContainer c) {
  final n = c.read(cartControllerProvider.notifier);
  for (final i in items) {
    n.addLine(i);
  }
  return c.read(cartControllerProvider);
}

FinalizeRecord _record({
  required String saleId,
  required Map<String, String> lineIds,
  required List<TenderRecord> tenders,
}) {
  return FinalizeRecord(
    response: FinalizeResponse(saleId: saleId),
    saleId: saleId,
    lineIdsBySku: lineIds,
    tenders: tenders,
  );
}

void main() {
  test('refundAll() mirrors cart lines + reuses original payment IDs',
      () async {
    RefundSaleRequest? captured;
    final fake = ctest.FakeTransportBuilder()
        .unary(RefundService.refundSale, (req, _) async {
      captured = req;
      return RefundSaleResponse(
        refundId: req.refundId,
        refund: Refund(
          refundId: req.refundId,
          saleId: req.saleId,
          creditNoteNumber: 'CN-2026-000001',
        ),
      );
    }).build();

    final c = ProviderContainer(overrides: [
      transportProvider.overrideWithValue(fake),
    ]);
    addTearDown(c.dispose);

    final cart = _cartFrom([_item('A', 10), _item('B', 20)], c);
    final record = _record(
      saleId: 'sale-1',
      lineIds: const {'A': 'line-A', 'B': 'line-B'},
      tenders: [
        TenderRecord(
          paymentId: 'pay-1',
          method: TenderMethod.cash,
          amount: Money(currencyCode: 'INR', units: Int64(30), nanos: 0),
        ),
      ],
    );

    await c.read(refundControllerProvider.notifier).refundAll(
          cart: cart,
          record: record,
          reason: 'customer changed mind',
        );

    final state = c.read(refundControllerProvider);
    expect(state.hasValue, isTrue);
    expect(state.value?.refund.creditNoteNumber, 'CN-2026-000001');

    expect(captured, isNotNull);
    expect(captured!.refundId, hasLength(36));
    expect(captured!.saleId, 'sale-1');
    expect(captured!.reason, 'customer changed mind');
    // Default TerminalConfig + cashierId provider values (the config seam).
    expect(captured!.storeId.value, 'store-1');
    expect(captured!.counterId.value, 'counter-1');
    expect(captured!.cashierId.value, 'cashier-1');
    expect(captured!.lines, hasLength(2));
    expect(captured!.lines[0].saleLineId, 'line-A');
    expect(captured!.lines[0].sku, 'A');
    expect(captured!.lines[0].quantity.toInt(), 1);
    expect(captured!.lines[0].restock, isTrue);
    expect(captured!.lines[1].saleLineId, 'line-B');
    expect(captured!.tenders, hasLength(1));
    expect(captured!.tenders.single.originalPaymentId, 'pay-1');
    expect(captured!.tenders.single.method, 'cash');
    expect(captured!.tenders.single.amount.units.toInt(), 30);
    expect(captured!.tenders.single.refundPaymentId, hasLength(36));
    expect(captured!.tenders.single.refundPaymentId,
        isNot(equals('pay-1'))); // freshly minted
  });

  test('refundAll() surfaces FailedPrecondition (already refunded) as AsyncError',
      () async {
    final fake = ctest.FakeTransportBuilder()
        .unary(RefundService.refundSale, (req, _) async {
      throw connect.ConnectException(
        connect.Code.failedPrecondition,
        'sale already refunded',
      );
    }).build();

    final c = ProviderContainer(overrides: [
      transportProvider.overrideWithValue(fake),
    ]);
    addTearDown(c.dispose);

    final cart = _cartFrom([_item('A', 10)], c);
    final record = _record(
      saleId: 'sale-1',
      lineIds: const {'A': 'line-A'},
      tenders: [
        TenderRecord(
          paymentId: 'pay-1',
          method: TenderMethod.cash,
          amount: Money(currencyCode: 'INR', units: Int64(10), nanos: 0),
        ),
      ],
    );

    await c.read(refundControllerProvider.notifier).refundAll(
          cart: cart,
          record: record,
          reason: 'oops',
        );

    final state = c.read(refundControllerProvider);
    expect(state.hasError, isTrue);
    expect(
      (state.error as connect.ConnectException).code,
      connect.Code.failedPrecondition,
    );
  });

  test('refundAll() on empty cart is a no-op', () async {
    var called = false;
    final fake = ctest.FakeTransportBuilder()
        .unary(RefundService.refundSale, (req, _) async {
      called = true;
      return RefundSaleResponse();
    }).build();

    final c = ProviderContainer(overrides: [
      transportProvider.overrideWithValue(fake),
    ]);
    addTearDown(c.dispose);

    await c.read(refundControllerProvider.notifier).refundAll(
          cart: const CartState(),
          record: _record(
            saleId: 's',
            lineIds: const {},
            tenders: const [],
          ),
          reason: 'r',
        );

    expect(called, isFalse);
    expect(c.read(refundControllerProvider).valueOrNull, isNull);
  });
}
