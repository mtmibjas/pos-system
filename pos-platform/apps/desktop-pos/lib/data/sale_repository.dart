/// Data layer — SaleService repository (docs/desktop-architecture.md §3 /
/// §6 step 2, the first repository of the seam).
///
/// The RPC SERVICE SURFACE lives behind this repository: the generated
/// [SaleServiceClient], the transport, and `FinalizeRequest` construction.
/// Controllers pass a plain [FinalizeInput] and never import the connect
/// client or build proto requests — that's the decoupling that lets the
/// server contract churn without rippling into state/UI.
///
/// **Boundary policy (decided 2026-06-14):** stable generated message DTOs
/// — `Money`, `Invoice`, and the `FinalizeResponse` envelope — are ADOPTED
/// value types and may cross into state/UI as read-only view-models. Only
/// the RPC surface (client/transport/request building) is hidden here. This
/// is the pragmatic reading of §3: the intent is to decouple from the RPC
/// *client*, not to hand-rewrite every stable value DTO.
library;

import 'package:connectrpc/connect.dart' as connect;
import 'package:fixnum/fixnum.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:pos_sdk/gen/google/protobuf/timestamp.pb.dart';
import 'package:pos_sdk/gen/pos/v1/common.pb.dart';
import 'package:pos_sdk/gen/pos/v1/sale_service.connect.client.dart';
import 'package:pos_sdk/gen/pos/v1/sale_service.pb.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/transport.dart';

part 'sale_repository.g.dart';

/// One cart line as the domain hands it to the repository. Idempotency keys
/// (lineId) are minted by the caller — they're a domain concern, not the
/// transport's. `Money` is an adopted value type (see file header).
@immutable
class SaleLineInput {
  const SaleLineInput({
    required this.lineId,
    required this.sku,
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    required this.taxCategoryId,
  });

  final String lineId;
  final String sku;
  final String description;
  final int quantity;
  final Money unitPrice;
  final Money lineTotal;
  final String taxCategoryId;
}

/// One tender row. `method` is the wire string ("cash"/"card"/"upi").
@immutable
class SaleTenderInput {
  const SaleTenderInput({
    required this.paymentId,
    required this.method,
    required this.amount,
  });

  final String paymentId;
  final String method;
  final Money amount;
}

/// Everything the repository needs to finalize a sale. The caller mints
/// saleId / lineId / paymentId up-front so a retry is idempotent server-side.
/// subtotal/tax/grand are intentionally absent — the server's tax engine
/// fills them.
@immutable
class FinalizeInput {
  const FinalizeInput({
    required this.saleId,
    required this.storeId,
    required this.counterId,
    required this.cashierId,
    required this.lines,
    required this.tenders,
    required this.reservationIds,
    required this.occurredAt,
  });

  final String saleId;
  final String storeId;
  final String counterId;
  final String cashierId;
  final List<SaleLineInput> lines;
  final List<SaleTenderInput> tenders;
  final List<String> reservationIds;
  final DateTime occurredAt;
}

/// The sale data-access surface. Controllers depend on this, not on the
/// generated client — and override it in tests via [saleRepositoryProvider].
abstract class SaleRepository {
  Future<FinalizeResponse> finalize(FinalizeInput input);
}

/// Connect-backed implementation: builds the proto request and calls the
/// generated client over the shared transport.
class ConnectSaleRepository implements SaleRepository {
  ConnectSaleRepository(this._transport);

  final connect.Transport _transport;

  @override
  Future<FinalizeResponse> finalize(FinalizeInput input) {
    final client = SaleServiceClient(_transport);
    final req = FinalizeRequest(
      saleId: input.saleId,
      storeId: StoreId(value: input.storeId),
      counterId: CounterId(value: input.counterId),
      cashierId: UserId(value: input.cashierId),
      lines: input.lines
          .map((l) => FinalizeSaleLine(
                lineId: l.lineId,
                sku: l.sku,
                description: l.description,
                quantity: Int64(l.quantity),
                unitPrice: l.unitPrice,
                lineTotal: l.lineTotal,
                taxCategoryId: l.taxCategoryId,
              ))
          .toList(growable: false),
      tenders: input.tenders
          .map((t) => FinalizeSaleTender(
                paymentId: t.paymentId,
                method: t.method,
                amount: t.amount,
              ))
          .toList(growable: false),
      reservationIds: input.reservationIds,
      occurredAt: Timestamp.fromDateTime(input.occurredAt.toUtc()),
    );
    return client.finalize(req);
  }
}

/// The active sale repository. Built over the shared transport, so a test
/// that overrides [transportProvider] flows through here unchanged; tests
/// may also override this provider directly with a fake repository.
@Riverpod(keepAlive: true)
SaleRepository saleRepository(SaleRepositoryRef ref) =>
    ConnectSaleRepository(ref.watch(transportProvider));
