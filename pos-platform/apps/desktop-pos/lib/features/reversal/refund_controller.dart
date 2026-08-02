/// Drives RefundService.RefundSale — full-sale refund built from the
/// cached cart + FinalizeRecord (tender IDs).
///
/// Refund-all only this slice: every cart line is refunded in full
/// (restock=true), and each original tender becomes one refund tender
/// for the same amount and method. Per-line partial picker and split
/// adjustments are deferred to a later slice.
library;

import 'package:fixnum/fixnum.dart';
import 'package:pos_sdk/gen/google/protobuf/timestamp.pb.dart';
import 'package:pos_sdk/gen/pos/v1/common.pb.dart';
import 'package:pos_sdk/gen/pos/v1/refund_service.connect.client.dart';
import 'package:pos_sdk/gen/pos/v1/refund_service.pb.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

import '../../config.dart';
import '../../core/transport.dart';
import '../auth/session_controller.dart';
import '../cart/cart_controller.dart';
import '../cart/finalize_controller.dart';

part 'refund_controller.g.dart';

@riverpod
class RefundController extends _$RefundController {
  static const _uuid = Uuid();

  @override
  Future<RefundSaleResponse?> build() async => null;

  /// Full-refund the given sale. Pass the cart + FinalizeRecord from
  /// the receipt screen — we need cart for line shape (sku, qty,
  /// price, tax cat) and record for the original payment IDs that
  /// refund tenders must reference.
  Future<void> refundAll({
    required CartState cart,
    required FinalizeRecord record,
    required String reason,
  }) async {
    if (cart.isEmpty) return;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _submit(cart, record, reason));
  }

  Future<RefundSaleResponse> _submit(
    CartState cart,
    FinalizeRecord record,
    String reason,
  ) async {
    final client = RefundServiceClient(ref.read(transportProvider));

    // Walk back from cart → refund lines, reusing the line_ids we
    // minted on Finalize (carried in record.lineIdsBySku). Server
    // requires sale_line_id to be non-empty and matched against the
    // original sale's line set.
    final lines = cart.lines.map((l) {
      final lineId = record.lineIdsBySku[l.sku];
      if (lineId == null) {
        // Should not happen: the cart we're refunding is the same one
        // we charged. Defensive — surface a clear error rather than
        // sending an empty UUID and getting a confusing server reject.
        throw StateError('no line_id recorded for sku=${l.sku}');
      }
      return RefundSaleLine(
        saleLineId: lineId,
        sku: l.sku,
        quantity: Int64(l.quantity),
        restock: true,
        unitPrice: l.unitPrice,
        lineTotal: l.lineTotal,
        taxCategoryId: l.taxCategoryId,
      );
    }).toList(growable: false);

    // Mirror each original tender 1:1 as a refund tender.
    final tenders = record.tenders
        .map((t) => RefundSaleTender(
              refundPaymentId: _uuid.v4(),
              originalPaymentId: t.paymentId,
              method: t.method.wireName,
              amount: t.amount,
            ))
        .toList(growable: false);

    final cfg = ref.read(terminalConfigProvider);
    final req = RefundSaleRequest(
      refundId: _uuid.v4(),
      saleId: record.saleId,
      storeId: StoreId(value: cfg.storeId),
      counterId: CounterId(value: cfg.counterId),
      cashierId: UserId(value: ref.read(cashierIdProvider)),
      reason: reason,
      occurredAt: Timestamp.fromDateTime(DateTime.now().toUtc()),
      lines: lines,
      tenders: tenders,
    );
    return client.refundSale(req);
  }

  void reset() {
    state = const AsyncValue.data(null);
  }
}
