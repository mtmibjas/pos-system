/// SaleLookupController tests via FakeTransport.
///
/// Covers happy path (request shape + state.data populated), NotFound
/// surfacing as AsyncError, and empty-input no-op.
library;

import 'package:connectrpc/connect.dart' as connect;
import 'package:connectrpc/test.dart' as ctest;
import 'package:desktop_pos/core/transport.dart';
import 'package:desktop_pos/features/lookup/sale_lookup_controller.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_sdk/gen/pos/v1/common.pb.dart';
import 'package:pos_sdk/gen/pos/v1/sale_service.connect.spec.dart';
import 'package:pos_sdk/gen/pos/v1/sale_service.pb.dart';

void main() {
  test('bySaleId() captures sale_id key and surfaces the response',
      () async {
    GetSaleRequest? captured;
    final fake = ctest.FakeTransportBuilder()
        .unary(SaleService.getSale, (req, _) async {
      captured = req;
      return GetSaleResponse(
        invoice: Invoice(saleId: req.saleId, invoiceNumber: 'INV-2026-000007'),
        lines: [
          GetSaleLine(
            lineId: 'line-A',
            sku: 'A',
            description: 'name-A',
            quantity: Int64(1),
            unitPrice: Money(currencyCode: 'INR', units: Int64(10)),
            lineTotal: Money(currencyCode: 'INR', units: Int64(10)),
          ),
        ],
        payments: [
          GetSalePayment(
            paymentId: 'pay-1',
            method: 'cash',
            amount: Money(currencyCode: 'INR', units: Int64(10)),
          ),
        ],
      );
    }).build();

    final c = ProviderContainer(overrides: [
      transportProvider.overrideWithValue(fake),
    ]);
    addTearDown(c.dispose);

    await c
        .read(saleLookupControllerProvider.notifier)
        .bySaleId('sale-uuid-xyz');

    final state = c.read(saleLookupControllerProvider);
    expect(state.hasValue, isTrue);
    expect(state.value?.invoice.invoiceNumber, 'INV-2026-000007');
    expect(state.value?.lines.single.lineId, 'line-A');
    expect(state.value?.payments.single.paymentId, 'pay-1');

    expect(captured, isNotNull);
    expect(captured!.hasSaleId(), isTrue);
    expect(captured!.saleId, 'sale-uuid-xyz');
    expect(captured!.hasInvoiceNumber(), isFalse);
  });

  test('byInvoiceNumber() captures invoice_number key', () async {
    GetSaleRequest? captured;
    final fake = ctest.FakeTransportBuilder()
        .unary(SaleService.getSale, (req, _) async {
      captured = req;
      return GetSaleResponse(
        invoice: Invoice(saleId: 's', invoiceNumber: req.invoiceNumber),
      );
    }).build();

    final c = ProviderContainer(overrides: [
      transportProvider.overrideWithValue(fake),
    ]);
    addTearDown(c.dispose);

    await c
        .read(saleLookupControllerProvider.notifier)
        .byInvoiceNumber('INV-2026-000001');

    expect(captured!.hasInvoiceNumber(), isTrue);
    expect(captured!.invoiceNumber, 'INV-2026-000001');
    expect(captured!.hasSaleId(), isFalse);
  });

  test('surfaces NotFound as AsyncError', () async {
    final fake = ctest.FakeTransportBuilder()
        .unary(SaleService.getSale, (req, _) async {
      throw connect.ConnectException(
        connect.Code.notFound,
        'sale not found',
      );
    }).build();

    final c = ProviderContainer(overrides: [
      transportProvider.overrideWithValue(fake),
    ]);
    addTearDown(c.dispose);

    await c
        .read(saleLookupControllerProvider.notifier)
        .byInvoiceNumber('INV-1999-000001');

    final state = c.read(saleLookupControllerProvider);
    expect(state.hasError, isTrue);
    expect(
      (state.error as connect.ConnectException).code,
      connect.Code.notFound,
    );
  });

  test('empty input is a no-op', () async {
    var called = false;
    final fake = ctest.FakeTransportBuilder()
        .unary(SaleService.getSale, (req, _) async {
      called = true;
      return GetSaleResponse();
    }).build();

    final c = ProviderContainer(overrides: [
      transportProvider.overrideWithValue(fake),
    ]);
    addTearDown(c.dispose);

    await c.read(saleLookupControllerProvider.notifier).bySaleId('');
    await c.read(saleLookupControllerProvider.notifier).byInvoiceNumber('');

    expect(called, isFalse);
    expect(c.read(saleLookupControllerProvider).valueOrNull, isNull);
  });
}
