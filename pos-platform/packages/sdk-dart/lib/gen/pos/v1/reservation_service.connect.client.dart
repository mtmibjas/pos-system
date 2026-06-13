//
//  Generated code. Do not modify.
//  source: pos/v1/reservation_service.proto
//

import "package:connectrpc/connect.dart" as connect;
import "reservation_service.pb.dart" as posv1reservation_service;
import "reservation_service.connect.spec.dart" as specs;

/// ReservationService is the soft-inventory hold surface — Phase 4 slice
/// 4.3. Counters call Reserve when items hit the cart and Release if the
/// cart is abandoned. SaleService.Finalize finalizes reservations as part
/// of the sale's atomic commit (via FinalizeRequest.reservation_ids).
/// Holds are intra-store ONLY: never synced to the cloud, never produce
/// inventory_movements. They participate in InventoryService.ListOnHand
/// indirectly via the held-quantity subtracted from the on-hand sum.
extension type ReservationServiceClient (connect.Transport _transport) {
  /// Reserve creates a new active hold or fails with FailedPrecondition if
  /// available stock is insufficient (after lazily expiring stale holds).
  Future<posv1reservation_service.ReserveResponse> reserve(
    posv1reservation_service.ReserveRequest input, {
    connect.Headers? headers,
    connect.AbortSignal? signal,
    Function(connect.Headers)? onHeader,
    Function(connect.Headers)? onTrailer,
  }) {
    return connect.Client(_transport).unary(
      specs.ReservationService.reserve,
      input,
      signal: signal,
      headers: headers,
      onHeader: onHeader,
      onTrailer: onTrailer,
    );
  }

  /// Release cancels an active hold. Idempotent on already-released rows.
  Future<posv1reservation_service.ReleaseResponse> release(
    posv1reservation_service.ReleaseRequest input, {
    connect.Headers? headers,
    connect.AbortSignal? signal,
    Function(connect.Headers)? onHeader,
    Function(connect.Headers)? onTrailer,
  }) {
    return connect.Client(_transport).unary(
      specs.ReservationService.release,
      input,
      signal: signal,
      headers: headers,
      onHeader: onHeader,
      onTrailer: onTrailer,
    );
  }
}
