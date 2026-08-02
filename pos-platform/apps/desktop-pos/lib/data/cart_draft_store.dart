/// Persistence for the in-progress cart draft
/// (docs/desktop-local-persistence.md §3).
///
/// Checkpoints the open, *unfinalized* sale so a crash or power blip mid-sale
/// doesn't lose the operator's work. Keyed by (store, counter) so a relaunch
/// restores THIS terminal's draft. Carries the draft's stable `sale_id` (the
/// idempotency key, §5.2) alongside the lines.
library;

import 'package:fixnum/fixnum.dart';
import 'package:pos_sdk/gen/pos/v1/common.pb.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../features/cart/cart_controller.dart';
import 'local_db.dart';

part 'cart_draft_store.g.dart';

class CartDraftStore {
  CartDraftStore(this._db);

  final Future<Database> _db;

  /// The persisted draft for this terminal, or null if none is open.
  Future<CartState?> load({
    required String storeId,
    required String counterId,
  }) async {
    final db = await _db;
    final head = await db.query(
      'cart_draft',
      where: 'store_id = ? AND counter_id = ?',
      whereArgs: [storeId, counterId],
      limit: 1,
    );
    if (head.isEmpty) return null;

    final lineRows = await db.query(
      'cart_draft_line',
      where: 'store_id = ? AND counter_id = ?',
      whereArgs: [storeId, counterId],
      orderBy: 'position ASC',
    );
    final lines = [
      for (final r in lineRows)
        CartLine(
          sku: r['sku']! as String,
          description: r['description']! as String,
          unitPrice: Money(
            currencyCode: r['currency_code']! as String,
            units: Int64(r['units']! as int),
            nanos: r['nanos']! as int,
          ),
          taxCategoryId: r['tax_category_id']! as String,
          quantity: r['quantity']! as int,
        ),
    ];
    return CartState(lines: lines, saleId: head.first['sale_id'] as String?);
  }

  /// Checkpoint the draft. An empty cart clears the draft instead of writing
  /// an empty one. Replaces the prior snapshot wholesale inside one txn.
  Future<void> save(
    CartState cart, {
    required String storeId,
    required String counterId,
    required String nowIso,
  }) async {
    if (cart.isEmpty) {
      await clear(storeId: storeId, counterId: counterId);
      return;
    }
    final db = await _db;
    await db.transaction((txn) async {
      await _deleteWithin(txn, storeId, counterId);
      await txn.insert('cart_draft', {
        'store_id': storeId,
        'counter_id': counterId,
        'sale_id': cart.saleId,
        'updated_at': nowIso,
      });
      var position = 0;
      for (final l in cart.lines) {
        await txn.insert('cart_draft_line', {
          'store_id': storeId,
          'counter_id': counterId,
          'position': position++,
          'sku': l.sku,
          'description': l.description,
          'currency_code': l.unitPrice.currencyCode,
          'units': l.unitPrice.units.toInt(),
          'nanos': l.unitPrice.nanos,
          'tax_category_id': l.taxCategoryId,
          'quantity': l.quantity,
        });
      }
    });
  }

  /// Drop the draft (called after a sale finalizes).
  Future<void> clear({
    required String storeId,
    required String counterId,
  }) async {
    final db = await _db;
    await db.transaction((txn) => _deleteWithin(txn, storeId, counterId));
  }

  Future<void> _deleteWithin(
    DatabaseExecutor txn,
    String storeId,
    String counterId,
  ) async {
    final args = [storeId, counterId];
    await txn.delete('cart_draft_line',
        where: 'store_id = ? AND counter_id = ?', whereArgs: args);
    await txn.delete('cart_draft',
        where: 'store_id = ? AND counter_id = ?', whereArgs: args);
  }
}

@Riverpod(keepAlive: true)
CartDraftStore cartDraftStore(CartDraftStoreRef ref) =>
    CartDraftStore(ref.watch(appDatabaseProvider.future));
