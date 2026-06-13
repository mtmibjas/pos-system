//
//  Generated code. Do not modify.
//  source: pos/v1/reservation_service.proto
//

import "package:connectrpc/connect.dart" as connect;
import "reservation_service.pb.dart" as posv1reservation_service;

/// ReservationService is the soft-inventory hold surface — Phase 4 slice
/// 4.3. Counters call Reserve when items hit the cart and Release if the
/// cart is abandoned. SaleService.Finalize finalizes reservations as part
/// of the sale's atomic commit (via FinalizeRequest.reservation_ids).
/// Holds are intra-store ONLY: never synced to the cloud, never produce
/// inventory_movements. They participate in InventoryService.ListOnHand
/// indirectly via the held-quantity subtracted from the on-hand sum.
abstract final class ReservationService {
  /// Fully-qualified name of the ReservationService service.
  static const name = 'pos.v1.ReservationService';

  /// Reserve creates a new active hold or fails with FailedPrecondition if
  /// available stock is insufficient (after lazily expiring stale holds).
  static const reserve = connect.Spec(
    '/$name/Reserve',
    connect.StreamType.unary,
    posv1reservation_service.ReserveRequest.new,
    posv1reservation_service.ReserveResponse.new,
  );

  /// Release cancels an active hold. Idempotent on already-released rows.
  static const release = connect.Spec(
    '/$name/Release',
    connect.StreamType.unary,
    posv1reservation_service.ReleaseRequest.new,
    posv1reservation_service.ReleaseResponse.new,
  );
}
