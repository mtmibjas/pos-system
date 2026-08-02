/// Persistence tests for step 6a/6b — config store round-trip, cart-draft
/// checkpoint, and crash-recovery restore. Uses a shared in-memory SQLite DB
/// (sqflite_common_ffi) so there are no files and no plugins.
library;

import 'package:desktop_pos/config.dart';
import 'package:desktop_pos/data/cart_draft_store.dart';
import 'package:desktop_pos/data/local_db.dart';
import 'package:desktop_pos/data/terminal_config_store.dart';
import 'package:desktop_pos/features/cart/cart_controller.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_sdk/gen/pos/v1/common.pb.dart';
import 'package:pos_sdk/gen/pos/v1/item_service.pb.dart' as itempb;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

itempb.Item _item(String sku, int units) => itempb.Item(
      sku: sku,
      name: 'name-$sku',
      price: _money(units),
      taxCategoryId: 'GST-18',
    );

Money _money(int units) =>
    Money(currencyCode: 'INR', units: Int64(units), nanos: 0);

CartLine _line(String sku, int units, int qty) => CartLine(
      sku: sku,
      description: 'name-$sku',
      unitPrice: _money(units),
      taxCategoryId: 'GST-18',
      quantity: qty,
    );

/// Poll until [cond] holds or a short budget elapses (for async hydrate).
Future<void> _until(bool Function() cond) async {
  for (var i = 0; i < 100; i++) {
    if (cond()) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail('condition not met within budget');
}

void main() {
  late Database db;

  setUp(() async {
    db = await openInMemoryDatabase();
  });
  tearDown(() async {
    await db.close();
  });

  ProviderContainer containerWith(Database shared) {
    final c = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWith((ref) => shared),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  group('TerminalConfigStore (6a)', () {
    test('load returns null when unprovisioned', () async {
      final store = TerminalConfigStore(Future.value(db));
      expect(await store.load(), isNull);
    });

    test('save then load round-trips', () async {
      final store = TerminalConfigStore(Future.value(db));
      const cfg = TerminalConfig(
        serverUrl: 'http://10.0.0.5:8081',
        storeId: 'store-9',
        counterId: 'counter-3',
        terminalName: 'Front till',
      );
      await store.save(cfg);
      final got = await store.load();
      expect(got, isNotNull);
      expect(got!.serverUrl, 'http://10.0.0.5:8081');
      expect(got.storeId, 'store-9');
      expect(got.counterId, 'counter-3');
      expect(got.terminalName, 'Front till');
    });

    test('save is an upsert (single row)', () async {
      final store = TerminalConfigStore(Future.value(db));
      await store.save(const TerminalConfig(
          serverUrl: 'a', storeId: 's', counterId: 'c', terminalName: 't'));
      await store.save(const TerminalConfig(
          serverUrl: 'b', storeId: 's', counterId: 'c', terminalName: 't'));
      expect((await store.load())!.serverUrl, 'b');
      final rows = await db.query('terminal_config');
      expect(rows, hasLength(1));
    });
  });

  group('CartDraftStore (6b)', () {
    test('save then load round-trips lines + saleId', () async {
      final store = CartDraftStore(Future.value(db));
      final cart = CartState(lines: [_line('A', 10, 2), _line('B', 5, 1)],
          saleId: 'sale-abc');
      await store.save(cart,
          storeId: 'store-1', counterId: 'counter-1', nowIso: 'now');
      final got = await store.load(storeId: 'store-1', counterId: 'counter-1');
      expect(got, isNotNull);
      expect(got!.saleId, 'sale-abc');
      expect(got.lines.map((l) => l.sku), ['A', 'B']);
      expect(got.lines[0].quantity, 2);
      expect(got.lines[0].unitPrice.units.toInt(), 10);
    });

    test('saving an empty cart clears the draft', () async {
      final store = CartDraftStore(Future.value(db));
      await store.save(CartState(lines: [_line('A', 10, 1)], saleId: 's'),
          storeId: 'store-1', counterId: 'counter-1', nowIso: 'now');
      await store.save(const CartState(),
          storeId: 'store-1', counterId: 'counter-1', nowIso: 'now');
      expect(await store.load(storeId: 'store-1', counterId: 'counter-1'),
          isNull);
    });

    test('drafts are isolated per counter', () async {
      final store = CartDraftStore(Future.value(db));
      await store.save(CartState(lines: [_line('A', 10, 1)], saleId: 's1'),
          storeId: 'store-1', counterId: 'counter-1', nowIso: 'now');
      await store.save(CartState(lines: [_line('B', 20, 1)], saleId: 's2'),
          storeId: 'store-1', counterId: 'counter-2', nowIso: 'now');
      final c1 = await store.load(storeId: 'store-1', counterId: 'counter-1');
      final c2 = await store.load(storeId: 'store-1', counterId: 'counter-2');
      expect(c1!.lines.single.sku, 'A');
      expect(c2!.lines.single.sku, 'B');
    });
  });

  group('CartController crash recovery (6b)', () {
    test('hydrates a persisted draft on launch', () async {
      // Seed a draft for the default terminal identity (store-1 / counter-1).
      final store = CartDraftStore(Future.value(db));
      await store.save(
          CartState(lines: [_line('RICE', 575, 3)], saleId: 'sale-xyz'),
          storeId: 'store-1',
          counterId: 'counter-1',
          nowIso: 'now');

      // A fresh CartController over the same DB should restore it.
      final c = containerWith(db);
      c.read(cartControllerProvider.notifier); // triggers build + _hydrate
      await _until(() => c.read(cartControllerProvider).lines.isNotEmpty);

      final restored = c.read(cartControllerProvider);
      expect(restored.saleId, 'sale-xyz');
      expect(restored.lines.single.sku, 'RICE');
      expect(restored.lines.single.quantity, 3);
    });

    test('checkpoints mutations back to the DB', () async {
      final c = containerWith(db);
      final n = c.read(cartControllerProvider.notifier);
      n.addLine(_item('A', 12));

      // The persist is fire-and-forget; poll the DB (not in-memory state)
      // until the checkpoint lands, then confirm it's durable.
      final store = CartDraftStore(Future.value(db));
      CartState? persisted;
      for (var i = 0; i < 100; i++) {
        persisted = await store.load(storeId: 'store-1', counterId: 'counter-1');
        if (persisted != null) break;
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(persisted, isNotNull);
      expect(persisted!.lines.single.sku, 'A');
      expect(persisted.saleId, isNotNull); // stable id minted on first line
    });
  });
}
