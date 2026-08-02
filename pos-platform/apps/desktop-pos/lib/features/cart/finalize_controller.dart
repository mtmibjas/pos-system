/// Drives SaleService.Finalize from the tender screen.
///
/// Mints all idempotency keys (sale_id, per-line line_id, payment_id)
/// client-side via uuid v4 so a retry of the same Finalize call hits
/// the server's idempotent replay path. Sends subtotal/tax/grand as
/// zero Money so the tax engine fills them — the cart only knows the
/// untaxed line totals.
///
/// State is AsyncValue<FinalizeRecord?> — the record bundles the
/// server's FinalizeResponse with the IDs we minted, because the
/// reversal flow (Slice 2.10) needs the original payment IDs to
/// construct a RefundSale request (per-tender original_payment_id refs).
library;

import 'dart:async';

import 'package:connectrpc/connect.dart' as connect;
import 'package:flutter/foundation.dart' show immutable;
import 'package:pos_sdk/gen/pos/v1/common.pb.dart';
import 'package:pos_sdk/gen/pos/v1/sale_service.pb.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

import '../../config.dart';
import '../../core/connection_health_provider.dart';
import '../../core/rpc_policy.dart';
import '../../data/cart_draft_store.dart';
import '../../data/pending_finalize_store.dart';
import '../../data/sale_repository.dart';
import '../auth/session_controller.dart';
import '../reservations/reservations_controller.dart';
import 'cart_controller.dart';
import 'pending_finalize_controller.dart';

part 'finalize_controller.g.dart';

/// Raised when Finalize is attempted while the store server is unreachable
/// (docs/desktop-local-persistence.md §5.1 / architecture §4.7). NOT a system
/// failure — a precondition the UI surfaces as a calm, actionable message.
/// The cart draft is safe in SQLite; finalize re-enables on reconnect.
class FinalizeBlockedException implements Exception {
  const FinalizeBlockedException();
  @override
  String toString() =>
      'Cannot finalize — store server unreachable. Your cart is saved.';
}

/// Tender method the user picks on the tender screen.
enum TenderMethod {
  cash('cash'),
  card('card'),
  upi('upi');

  const TenderMethod(this.wireName);
  final String wireName;
}

/// One tender row as we sent it. Holds the client-minted payment_id so
/// a follow-up RefundSale can reference it as original_payment_id.
@immutable
class TenderRecord {
  const TenderRecord({
    required this.paymentId,
    required this.method,
    required this.amount,
  });

  final String paymentId;
  final TenderMethod method;
  final Money amount;
}

/// What we know about a just-finalized sale: the server's response
/// plus the IDs we minted on the way in. The reversal flow needs:
///   - saleId to address the sale
///   - lineIds (sku → line_id) so RefundSale lines carry SaleLineID
///   - tenders so refund tenders can reference original_payment_id
@immutable
class FinalizeRecord {
  const FinalizeRecord({
    required this.response,
    required this.saleId,
    required this.lineIdsBySku,
    required this.tenders,
  });

  final FinalizeResponse response;
  final String saleId;
  final Map<String, String> lineIdsBySku;
  final List<TenderRecord> tenders;
}

@riverpod
class FinalizeController extends _$FinalizeController {
  static const _uuid = Uuid();

  @override
  Future<FinalizeRecord?> build() async => null;

  /// Submits the current cart as a sale. `amount` is the tender total
  /// (single tender for Slice 2.9). On success, the cart is NOT
  /// cleared here — the receipt screen does that after the operator
  /// confirms, so the receipt can still read the cart for a summary.
  Future<void> charge({
    required CartState cart,
    required TenderMethod method,
    required Money amount,
  }) async {
    if (cart.isEmpty) return;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      // Write-gate (§4.7): never finalize while the store server is
      // unreachable — no coordinator means we can't guard against
      // cross-counter oversell. The draft is already checkpointed, so
      // blocking loses nothing. Thrown inside guard so it surfaces as a
      // clean AsyncError (and isn't clobbered by build()'s async completion).
      if (ref.read(connectionHealthControllerProvider).isUnreachable) {
        throw const FinalizeBlockedException();
      }
      return _submit(cart, method, amount);
    });
  }

  Future<FinalizeRecord> _submit(
    CartState cart,
    TenderMethod method,
    Money amount,
  ) async {
    final repo = ref.read(saleRepositoryProvider);
    final cfg = ref.read(terminalConfigProvider);
    final reservations =
        ref.read(reservationsControllerProvider.notifier);
    // Use the draft's STABLE sale_id (§5.2) so a lost-reply retry replays the
    // same sale server-side. Fall back to a fresh id only if the cart was
    // seeded without a draft (e.g. a lookup-loaded sale).
    final saleId = cart.saleId ?? _uuid.v4();
    final tender = TenderRecord(
      paymentId: _uuid.v4(),
      method: method,
      amount: amount,
    );
    // Mint line_ids up-front so we can remember them by SKU for the
    // reversal flow. The cart enforces unique SKUs, so (sku → line_id)
    // is well-defined.
    final lineIds = <String, String>{
      for (final l in cart.lines) l.sku: _uuid.v4(),
    };
    // Collect every active reservation_id so the server consumes the
    // holds atomically as part of the sale commit (slice 4.3). Sale-
    // lookup flows that re-load a finalized record into Finalize won't
    // have any active reservations; allReservationIds() returns [] then.
    final input = FinalizeInput(
      saleId: saleId,
      storeId: cfg.storeId,
      counterId: cfg.counterId,
      cashierId: ref.read(cashierIdProvider),
      lines: cart.lines
          .map((l) => SaleLineInput(
                lineId: lineIds[l.sku]!,
                sku: l.sku,
                description: l.description,
                quantity: l.quantity,
                unitPrice: l.unitPrice,
                lineTotal: l.lineTotal,
                taxCategoryId: l.taxCategoryId,
              ))
          .toList(growable: false),
      tenders: [
        SaleTenderInput(
          paymentId: tender.paymentId,
          method: tender.method.wireName,
          amount: tender.amount,
        ),
      ],
      reservationIds: reservations.allReservationIds(),
      // subtotal/taxTotal/grandTotal omitted → server tax engine fills them.
      occurredAt: DateTime.now(),
    );

    // Persist-before-call (§5.3): record the exact request so a lost reply
    // can be safely replayed (same sale_id → server idempotent replay).
    final pending = ref.read(pendingFinalizeStoreProvider);
    await _tryPending(() => pending.put(
          input,
          storeId: cfg.storeId,
          counterId: cfg.counterId,
          nowIso: DateTime.now().toUtc().toIso8601String(),
        ));

    final FinalizeResponse resp;
    try {
      resp = await repo.finalize(input);
    } on connect.ConnectException catch (e) {
      // Transport failure (ambiguous) → KEEP the pending row for reconnect
      // replay. A definitive server error (business/auth) → the sale was not
      // committed; clear it so we never replay a rejected sale.
      if (classifyTransportFailure(e) == null) {
        await _tryPending(() =>
            pending.clear(storeId: cfg.storeId, counterId: cfg.counterId));
      }
      _nudgePending(); // surface/clear the pending banner promptly
      rethrow;
    }

    // Clean success → the sale is committed; drop the pending row and the
    // checkpointed draft (best-effort; a lingering draft stays idempotent
    // via its stable sale_id).
    reservations.clearAfterFinalize();
    await _tryPending(
        () => pending.clear(storeId: cfg.storeId, counterId: cfg.counterId));
    _nudgePending();
    unawaited(_clearDraft(cfg));
    return FinalizeRecord(
      response: resp,
      saleId: saleId,
      lineIdsBySku: lineIds,
      tenders: [tender],
    );
  }

  /// Ask the reconciler to re-read pending status so the banner updates
  /// without waiting for the next reconnect. Best-effort.
  void _nudgePending() {
    try {
      unawaited(ref.read(pendingFinalizeControllerProvider.notifier).refresh());
    } catch (_) {}
  }

  /// Best-effort pending-row op: persistence must never crash a sale.
  Future<void> _tryPending(Future<void> Function() op) async {
    try {
      await op();
    } catch (_) {
      // Replay safety is a bonus; a DB failure here still lets the sale run.
    }
  }

  Future<void> _clearDraft(TerminalConfig cfg) async {
    try {
      await ref.read(cartDraftStoreProvider).clear(
            storeId: cfg.storeId,
            counterId: cfg.counterId,
          );
    } catch (_) {
      // Non-critical; the stable sale_id keeps a stray draft idempotent.
    }
  }

  /// Resets state to idle (used by the receipt screen when starting
  /// a new sale so the next Finalize call doesn't render the previous
  /// invoice while loading).
  void reset() {
    state = const AsyncValue.data(null);
  }

  /// Seeds state from a previously finalized sale fetched via
  /// SaleService.GetSale (slice 2.11). The receipt screen reads this
  /// to render the same Void/Refund affordances it shows after a
  /// just-completed sale.
  void loadFromLookup(FinalizeRecord record) {
    state = AsyncValue.data(record);
  }
}
