/// Step 6d-2 — pending_finalize persist-before-call + ambiguous-response
/// replay (docs/desktop-local-persistence.md §5.3). Uses a shared in-memory
/// DB + a fake transport; health is driven honestly through the aggregator.
library;

import 'package:connectrpc/connect.dart' as connect;
import 'package:connectrpc/test.dart' as ctest;
import 'package:desktop_pos/core/connection_health_provider.dart';
import 'package:desktop_pos/core/realtime.dart';
import 'package:desktop_pos/core/transport.dart';
import 'package:desktop_pos/data/cart_draft_store.dart';
import 'package:desktop_pos/data/local_db.dart';
import 'package:desktop_pos/data/pending_finalize_store.dart';
import 'package:desktop_pos/data/sale_repository.dart';
import 'package:desktop_pos/domain/connection_health.dart';
import 'package:desktop_pos/features/cart/cart_controller.dart';
import 'package:desktop_pos/features/cart/finalize_controller.dart';
import 'package:desktop_pos/features/cart/pending_finalize_controller.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_sdk/gen/pos/v1/common.pb.dart';
import 'package:pos_sdk/gen/pos/v1/sale_service.connect.spec.dart';
import 'package:pos_sdk/gen/pos/v1/sale_service.pb.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'realtime_test.dart' show FakeRealtimeChannel;

Money _money(int u) => Money(currencyCode: 'INR', units: Int64(u), nanos: 0);

FinalizeInput _input(String saleId) => FinalizeInput(
      saleId: saleId,
      storeId: 'store-1',
      counterId: 'counter-1',
      cashierId: 'cashier-1',
      occurredAt: DateTime.utc(2026, 8, 2, 10, 30),
      reservationIds: const ['res-1', 'res-2'],
      lines: [
        SaleLineInput(
          lineId: 'line-1',
          sku: 'RICE',
          description: 'Rice 1kg',
          quantity: 3,
          unitPrice: _money(575),
          lineTotal: _money(1725),
          taxCategoryId: 'GST-18',
        ),
      ],
      tenders: [
        SaleTenderInput(paymentId: 'pay-1', method: 'cash', amount: _money(1725)),
      ],
    );

CartState _cart(String saleId) => CartState(
      saleId: saleId,
      lines: [
        CartLine(
          sku: 'RICE',
          description: 'Rice 1kg',
          unitPrice: _money(575),
          taxCategoryId: 'GST-18',
          quantity: 3,
        ),
      ],
    );

Future<void> _until(bool Function() cond) async {
  for (var i = 0; i < 200; i++) {
    if (cond()) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail('condition not met within budget');
}

void main() {
  test('FinalizeInput JSON round-trips', () {
    final input = _input('sale-json');
    final back = finalizeInputFromJson(finalizeInputToJson(input));
    expect(back.saleId, 'sale-json');
    expect(back.storeId, 'store-1');
    expect(back.cashierId, 'cashier-1');
    expect(back.occurredAt.toUtc(), input.occurredAt.toUtc());
    expect(back.reservationIds, ['res-1', 'res-2']);
    expect(back.lines.single.sku, 'RICE');
    expect(back.lines.single.quantity, 3);
    expect(back.lines.single.unitPrice.units.toInt(), 575);
    expect(back.lines.single.lineTotal.units.toInt(), 1725);
    expect(back.tenders.single.paymentId, 'pay-1');
    expect(back.tenders.single.amount.units.toInt(), 1725);
  });

  group('with a shared in-memory DB', () {
    late Database db;
    setUp(() async => db = await openInMemoryDatabase());
    tearDown(() async => db.close());

    List<Override> baseOverrides(connect.Transport t) => [
          appDatabaseProvider.overrideWith((ref) => db),
          transportProvider.overrideWithValue(t),
          realtimeChannelProvider.overrideWithValue(FakeRealtimeChannel()),
          healthProbeProvider.overrideWithValue((_) async => false),
          clockProvider.overrideWithValue(() => DateTime.utc(2026, 8, 2)),
        ];

    test('PendingFinalizeStore put/load/clear', () async {
      final store = PendingFinalizeStore(Future.value(db));
      expect(
          await store.load(storeId: 'store-1', counterId: 'counter-1'), isNull);
      await store.put(_input('sale-1'),
          storeId: 'store-1', counterId: 'counter-1', nowIso: 'now');
      final got = await store.load(storeId: 'store-1', counterId: 'counter-1');
      expect(got!.saleId, 'sale-1');
      await store.clear(storeId: 'store-1', counterId: 'counter-1');
      expect(
          await store.load(storeId: 'store-1', counterId: 'counter-1'), isNull);
    });

    test('ambiguous (transport) failure KEEPS the pending row', () async {
      final fake = ctest.FakeTransportBuilder()
          .unary(SaleService.finalize, (req, _) async {
        throw connect.ConnectException(connect.Code.unavailable, 'lost reply');
      }).build();
      final c = ProviderContainer(overrides: baseOverrides(fake));
      addTearDown(c.dispose);

      await c.read(finalizeControllerProvider.notifier).charge(
          cart: _cart('sale-keep'),
          method: TenderMethod.cash,
          amount: _money(1725));

      final store = PendingFinalizeStore(Future.value(db));
      final pending =
          await store.load(storeId: 'store-1', counterId: 'counter-1');
      expect(pending?.saleId, 'sale-keep',
          reason: 'a lost reply must be replayable');
    });

    test('definitive server error CLEARS the pending row', () async {
      final fake = ctest.FakeTransportBuilder()
          .unary(SaleService.finalize, (req, _) async {
        throw connect.ConnectException(
            connect.Code.failedPrecondition, 'totals mismatch');
      }).build();
      final c = ProviderContainer(overrides: baseOverrides(fake));
      addTearDown(c.dispose);

      await c.read(finalizeControllerProvider.notifier).charge(
          cart: _cart('sale-reject'),
          method: TenderMethod.cash,
          amount: _money(1725));

      final store = PendingFinalizeStore(Future.value(db));
      expect(await store.load(storeId: 'store-1', counterId: 'counter-1'),
          isNull);
    });

    test('clean success clears pending + draft', () async {
      final fake = ctest.FakeTransportBuilder()
          .unary(SaleService.finalize, (req, _) async {
        return FinalizeResponse(
            saleId: req.saleId, invoice: Invoice(invoiceNumber: 'INV-1'));
      }).build();
      final c = ProviderContainer(overrides: baseOverrides(fake));
      addTearDown(c.dispose);

      await c.read(finalizeControllerProvider.notifier).charge(
          cart: _cart('sale-ok'),
          method: TenderMethod.cash,
          amount: _money(1725));

      final pStore = PendingFinalizeStore(Future.value(db));
      final dStore = CartDraftStore(Future.value(db));
      expect(await pStore.load(storeId: 'store-1', counterId: 'counter-1'),
          isNull);
      expect(await dStore.load(storeId: 'store-1', counterId: 'counter-1'),
          isNull);
    });

    test('reconciler retryNow replays and clears', () async {
      final store = PendingFinalizeStore(Future.value(db));
      await store.put(_input('sale-retry'),
          storeId: 'store-1', counterId: 'counter-1', nowIso: 'now');

      var hit = false;
      final fake = ctest.FakeTransportBuilder()
          .unary(SaleService.finalize, (req, _) async {
        hit = true;
        return FinalizeResponse(saleId: req.saleId);
      }).build();
      final c = ProviderContainer(overrides: baseOverrides(fake));
      addTearDown(c.dispose);

      final ctrl = c.read(pendingFinalizeControllerProvider.notifier);
      await _until(() => c.read(pendingFinalizeControllerProvider).hasPending);
      await ctrl.retryNow();

      expect(hit, isTrue);
      expect(c.read(pendingFinalizeControllerProvider).hasPending, isFalse);
      expect(await store.load(storeId: 'store-1', counterId: 'counter-1'),
          isNull);
    });

    test('reconciler auto-replays on the reachable edge', () async {
      final store = PendingFinalizeStore(Future.value(db));
      await store.put(_input('sale-auto'),
          storeId: 'store-1', counterId: 'counter-1', nowIso: 'now');

      var hit = false;
      final fake = ctest.FakeTransportBuilder()
          .unary(SaleService.finalize, (req, _) async {
        hit = true;
        return FinalizeResponse(saleId: req.saleId);
      }).build();
      final c = ProviderContainer(overrides: baseOverrides(fake));
      addTearDown(c.dispose);

      // Build the reconciler (registers the health listener + loads pending).
      c.read(pendingFinalizeControllerProvider.notifier);
      await _until(() => c.read(pendingFinalizeControllerProvider).hasPending);

      // Drive an unreachable → reachable edge.
      final health = c.read(connectionHealthControllerProvider.notifier);
      health.recordFailure(FailureKind.refused, 'down');
      health.recordSuccess();

      await _until(
          () => !c.read(pendingFinalizeControllerProvider).hasPending);
      expect(hit, isTrue);
    });
  });
}
