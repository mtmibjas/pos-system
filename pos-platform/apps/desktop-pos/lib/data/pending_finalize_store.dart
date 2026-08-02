/// Persistence for the single in-flight Finalize
/// (docs/desktop-local-persistence.md §5.3).
///
/// Written BEFORE the Finalize RPC and cleared on a clean success. If the
/// reply is lost (ambiguous outcome) the row survives, and the reconciler
/// replays it on reconnect — a safe server-side replay because the request
/// carries the draft's STABLE sale_id. At most ONE row per (store, counter):
/// this is a bounded reconnect-retry, NOT an offline sales queue.
library;

import 'dart:convert';

import 'package:fixnum/fixnum.dart';
import 'package:pos_sdk/gen/pos/v1/common.pb.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'local_db.dart';
import 'sale_repository.dart';

part 'pending_finalize_store.g.dart';

class PendingFinalizeStore {
  PendingFinalizeStore(this._db);

  final Future<Database> _db;

  /// Persist the request about to be sent (overwrites any prior pending row
  /// for this terminal — there is only ever one).
  Future<void> put(
    FinalizeInput input, {
    required String storeId,
    required String counterId,
    required String nowIso,
  }) async {
    final db = await _db;
    await db.insert(
      'pending_finalize',
      {
        'store_id': storeId,
        'counter_id': counterId,
        'sale_id': input.saleId,
        'request_json': jsonEncode(finalizeInputToJson(input)),
        'created_at': nowIso,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// The pending request for this terminal, or null if none.
  Future<FinalizeInput?> load({
    required String storeId,
    required String counterId,
  }) async {
    final db = await _db;
    final rows = await db.query(
      'pending_finalize',
      where: 'store_id = ? AND counter_id = ?',
      whereArgs: [storeId, counterId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final json = jsonDecode(rows.first['request_json']! as String)
        as Map<String, dynamic>;
    return finalizeInputFromJson(json);
  }

  Future<void> clear({
    required String storeId,
    required String counterId,
  }) async {
    final db = await _db;
    await db.delete(
      'pending_finalize',
      where: 'store_id = ? AND counter_id = ?',
      whereArgs: [storeId, counterId],
    );
  }
}

// --- (de)serialization -----------------------------------------------------
//
// FinalizeInput ↔ plain JSON. Money is {c: currency, u: units, n: nanos}.

Map<String, dynamic> _moneyJson(Money m) =>
    {'c': m.currencyCode, 'u': m.units.toString(), 'n': m.nanos};

Money _moneyFrom(Map<String, dynamic> j) => Money(
      currencyCode: j['c'] as String,
      units: Int64.parseInt(j['u'] as String),
      nanos: j['n'] as int,
    );

Map<String, dynamic> finalizeInputToJson(FinalizeInput input) => {
      'saleId': input.saleId,
      'storeId': input.storeId,
      'counterId': input.counterId,
      'cashierId': input.cashierId,
      'occurredAt': input.occurredAt.toUtc().toIso8601String(),
      'reservationIds': input.reservationIds,
      'lines': [
        for (final l in input.lines)
          {
            'lineId': l.lineId,
            'sku': l.sku,
            'description': l.description,
            'quantity': l.quantity,
            'unitPrice': _moneyJson(l.unitPrice),
            'lineTotal': _moneyJson(l.lineTotal),
            'taxCategoryId': l.taxCategoryId,
          },
      ],
      'tenders': [
        for (final t in input.tenders)
          {
            'paymentId': t.paymentId,
            'method': t.method,
            'amount': _moneyJson(t.amount),
          },
      ],
    };

FinalizeInput finalizeInputFromJson(Map<String, dynamic> j) => FinalizeInput(
      saleId: j['saleId'] as String,
      storeId: j['storeId'] as String,
      counterId: j['counterId'] as String,
      cashierId: j['cashierId'] as String,
      occurredAt: DateTime.parse(j['occurredAt'] as String),
      reservationIds: [
        for (final r in (j['reservationIds'] as List)) r as String,
      ],
      lines: [
        for (final l in (j['lines'] as List).cast<Map<String, dynamic>>())
          SaleLineInput(
            lineId: l['lineId'] as String,
            sku: l['sku'] as String,
            description: l['description'] as String,
            quantity: l['quantity'] as int,
            unitPrice: _moneyFrom(l['unitPrice'] as Map<String, dynamic>),
            lineTotal: _moneyFrom(l['lineTotal'] as Map<String, dynamic>),
            taxCategoryId: l['taxCategoryId'] as String,
          ),
      ],
      tenders: [
        for (final t in (j['tenders'] as List).cast<Map<String, dynamic>>())
          SaleTenderInput(
            paymentId: t['paymentId'] as String,
            method: t['method'] as String,
            amount: _moneyFrom(t['amount'] as Map<String, dynamic>),
          ),
      ],
    );

@Riverpod(keepAlive: true)
PendingFinalizeStore pendingFinalizeStore(PendingFinalizeStoreRef ref) =>
    PendingFinalizeStore(ref.watch(appDatabaseProvider.future));
