/// Reconciler for a pending (lost-reply) Finalize
/// (docs/desktop-local-persistence.md §5.3).
///
/// Owns the ambiguous-response recovery: it exposes whether a sale is pending
/// (for the nav-shell banner + manual "retry" button) and AUTO-replays the
/// moment the store server becomes reachable again. Replay is a safe
/// server-side idempotent replay because the persisted request carries the
/// draft's stable sale_id.
library;

import 'dart:async';

import 'package:connectrpc/connect.dart' as connect;
import 'package:flutter/foundation.dart' show immutable;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../config.dart';
import '../../core/connection_health_provider.dart';
import '../../core/rpc_policy.dart';
import '../../data/cart_draft_store.dart';
import '../../data/pending_finalize_store.dart';
import '../../data/sale_repository.dart';

part 'pending_finalize_controller.g.dart';

@immutable
class PendingFinalizeState {
  const PendingFinalizeState({this.saleId, this.retrying = false, this.lastError});

  /// The pending sale's id, or null when nothing is awaiting replay.
  final String? saleId;
  final bool retrying;
  final String? lastError;

  bool get hasPending => saleId != null;

  PendingFinalizeState copyWith({
    String? saleId,
    bool? retrying,
    String? lastError,
  }) =>
      PendingFinalizeState(
        saleId: saleId ?? this.saleId,
        retrying: retrying ?? this.retrying,
        lastError: lastError ?? this.lastError,
      );
}

@Riverpod(keepAlive: true)
class PendingFinalizeController extends _$PendingFinalizeController {
  @override
  PendingFinalizeState build() {
    // Auto-replay on the reachable edge (§5.3, decided: auto + manual).
    ref.listen(connectionHealthControllerProvider, (prev, next) {
      final becameReachable =
          next.isReachable && (prev == null || !prev.isReachable);
      if (becameReachable && state.hasPending) {
        unawaited(retryNow());
      }
    });
    unawaited(refresh());
    return const PendingFinalizeState();
  }

  /// Reload the pending status from the DB (called on launch + after writes).
  Future<void> refresh() async {
    try {
      final cfg = ref.read(terminalConfigProvider);
      final input = await ref.read(pendingFinalizeStoreProvider).load(
            storeId: cfg.storeId,
            counterId: cfg.counterId,
          );
      state = PendingFinalizeState(saleId: input?.saleId);
    } catch (_) {
      // Non-critical; leave state as-is.
    }
  }

  /// Replay the pending Finalize. Safe to call repeatedly — idempotent server
  /// replay. No-op if nothing is pending or a retry is already in flight.
  Future<void> retryNow() async {
    if (state.retrying) return;
    final cfg = ref.read(terminalConfigProvider);
    final store = ref.read(pendingFinalizeStoreProvider);

    FinalizeInput? input;
    try {
      input = await store.load(storeId: cfg.storeId, counterId: cfg.counterId);
    } catch (_) {
      return; // can't read; try again on the next reconnect.
    }
    if (input == null) {
      state = const PendingFinalizeState();
      return;
    }

    state = state.copyWith(retrying: true, lastError: null);
    try {
      await ref.read(saleRepositoryProvider).finalize(input);
      // Committed (or idempotently replayed) — clear pending + draft.
      await _clearAll(cfg, store);
      state = const PendingFinalizeState();
    } on connect.ConnectException catch (e) {
      if (classifyTransportFailure(e) == null) {
        // Definitive server rejection on replay → the sale can't complete;
        // stop retrying and clear it so we don't loop forever.
        await _clearAll(cfg, store);
        state = PendingFinalizeState(lastError: e.message);
      } else {
        // Still unreachable/ambiguous — keep the row; next reconnect retries.
        state = state.copyWith(retrying: false, lastError: e.message);
      }
    } catch (e) {
      state = state.copyWith(retrying: false, lastError: '$e');
    }
  }

  Future<void> _clearAll(TerminalConfig cfg, PendingFinalizeStore store) async {
    await store.clear(storeId: cfg.storeId, counterId: cfg.counterId);
    try {
      await ref.read(cartDraftStoreProvider).clear(
            storeId: cfg.storeId,
            counterId: cfg.counterId,
          );
    } catch (_) {
      // draft clear is best-effort.
    }
  }
}
