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

import 'package:fixnum/fixnum.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:pos_sdk/gen/google/protobuf/timestamp.pb.dart';
import 'package:pos_sdk/gen/pos/v1/common.pb.dart';
import 'package:pos_sdk/gen/pos/v1/sale_service.connect.client.dart';
import 'package:pos_sdk/gen/pos/v1/sale_service.pb.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

import '../../config.dart';
import '../../core/transport.dart';
import '../reservations/reservations_controller.dart';
import 'cart_controller.dart';

part 'finalize_controller.g.dart';

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
    state = await AsyncValue.guard(() => _submit(cart, method, amount));
  }

  Future<FinalizeRecord> _submit(
    CartState cart,
    TenderMethod method,
    Money amount,
  ) async {
    final client = SaleServiceClient(ref.read(transportProvider));
    final reservations =
        ref.read(reservationsControllerProvider.notifier);
    final saleId = _uuid.v4();
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
    final reservationIds = reservations.allReservationIds();
    final req = FinalizeRequest(
      saleId: saleId,
      storeId: StoreId(value: kStoreId),
      counterId: CounterId(value: kCounterId),
      cashierId: UserId(value: kCashierId),
      lines: cart.lines
          .map((l) => FinalizeSaleLine(
                lineId: lineIds[l.sku],
                sku: l.sku,
                description: l.description,
                quantity: Int64(l.quantity),
                unitPrice: l.unitPrice,
                lineTotal: l.lineTotal,
                taxCategoryId: l.taxCategoryId,
              ))
          .toList(growable: false),
      tenders: [
        FinalizeSaleTender(
          paymentId: tender.paymentId,
          method: tender.method.wireName,
          amount: tender.amount,
        ),
      ],
      reservationIds: reservationIds,
      // subtotal/taxTotal/grandTotal omitted → zero Money → engine fills.
      occurredAt: Timestamp.fromDateTime(DateTime.now().toUtc()),
    );
    final resp = await client.finalize(req);
    // Server consumed the reservations as part of the commit; drop the
    // local ledger without calling Release (those rows are gone).
    reservations.clearAfterFinalize();
    return FinalizeRecord(
      response: resp,
      saleId: saleId,
      lineIdsBySku: lineIds,
      tenders: [tender],
    );
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
