/// Inventory on-hand controller — wraps InventoryService.ListOnHand and
/// merges live updates from the realtime channel (Phase 4 Slice 4.5).
///
/// State is [InventoryView] (rows + last-seen-available map). Two event
/// streams update it:
///
///   - `inventory_adjusted` (typed envelope): a stock movement landed.
///     We just bump `refresh()` — a re-fetch is the simplest way to get
///     the new on_hand sum from the read-side projection.
///   - `inventory_available_changed` (raw frame): another counter
///     reserved or released stock. We patch available_qty in-place on
///     the matching row; no RPC round-trip needed.
library;

import 'dart:async';

import 'package:flutter/foundation.dart' show immutable;
import 'package:pos_sdk/gen/pos/v1/common.pb.dart';
import 'package:pos_sdk/gen/pos/v1/inventory_service.connect.client.dart';
import 'package:pos_sdk/gen/pos/v1/inventory_service.pb.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../config.dart';
import '../../core/realtime.dart';
import '../../core/transport.dart';

part 'inventory_controller.g.dart';

/// One inventory tile row. Wraps OnHandRow (which carries SKU/name/
/// on_hand/price) with an optional [available] populated from realtime
/// inventory_available_changed frames.
@immutable
class InventoryRow {
  const InventoryRow({required this.row, this.available});

  final OnHandRow row;

  /// Live "what's NOT held by another counter". Null when we haven't
  /// observed an availability update yet — UI then shows only on_hand.
  final int? available;

  InventoryRow withAvailable(int v) => InventoryRow(row: row, available: v);
}

@immutable
class InventoryView {
  const InventoryView({required this.rows});
  final List<InventoryRow> rows;
}

@riverpod
class InventoryController extends _$InventoryController {
  @override
  Future<InventoryView> build() async {
    // Subscribe to realtime once per controller lifetime. ref.onDispose
    // cancels the subscription so we don't leak when the AsyncNotifier
    // is rebuilt (e.g. on refresh).
    final ch = ref.read(realtimeChannelProvider);
    final sub = ch.stream.listen(_onFrame);
    ref.onDispose(sub.cancel);
    return _fetch();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<InventoryView> _fetch() async {
    final client = InventoryServiceClient(ref.read(transportProvider));
    final resp = await client.listOnHand(
      ListOnHandRequest(
          storeId: StoreId(value: ref.read(terminalConfigProvider).storeId)),
    );
    return InventoryView(
      rows: resp.rows.map((r) => InventoryRow(row: r)).toList(growable: false),
    );
  }

  void _onFrame(RealtimeFrame frame) {
    switch (frame) {
      case RealtimeEnvelopeFrame(:final eventType):
        if (eventType == 'inventory_adjusted') {
          // Stock moved: re-fetch on-hand totals. Cheap — single SELECT.
          // We don't block on it; the controller transitions through
          // loading naturally inside refresh().
          unawaited(refresh());
        }
      case RealtimeRawFrame(:final type, :final json):
        if (type == 'inventory_available_changed') {
          _patchAvailable(
            sku: (json['sku'] as String?) ?? '',
            available: (json['available_qty'] as num?)?.toInt() ?? 0,
          );
        }
      case RealtimeControlFrame(:final type):
        // Snapshot fallback if the backlog was too large to replay.
        if (type == 'catchup_overflow') {
          unawaited(refresh());
        }
    }
  }

  void _patchAvailable({required String sku, required int available}) {
    final cur = state.valueOrNull;
    if (cur == null || sku.isEmpty) return;
    final idx = cur.rows.indexWhere((r) => r.row.sku == sku);
    if (idx < 0) return;
    final next = List<InventoryRow>.from(cur.rows);
    next[idx] = next[idx].withAvailable(available);
    state = AsyncValue.data(InventoryView(rows: next));
  }
}

