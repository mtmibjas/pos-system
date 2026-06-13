/// Per-cart soft inventory reservations (Slice 4.5).
///
/// Each cart line that the operator adds creates ONE reservation of
/// quantity 1 on the server. The stepper UI calls [reserveOne] /
/// [releaseOne] to keep the held quantity in sync with the cart line's
/// quantity. On Finalize the accumulated reservation_ids are sent in
/// FinalizeRequest.reservation_ids so the server consumes the holds as
/// part of the atomic sale commit.
///
/// We keep one reservation per +1 (rather than one reservation per SKU
/// with a growing quantity) because:
///
///   - Release-on-decrement is exact and idempotent: we just release the
///     most recent id; no need to PATCH a quantity.
///   - The server's Reserve RPC has no "update" verb, only Reserve and
///     Release. Building "update" on the client would mean Release+Reserve
///     which momentarily frees stock for another counter to grab — worse
///     UX than just holding N separate holds.
///   - The 5min TTL applies per-row; one-per-add gives natural lazy
///     expiry of abandoned carts row-by-row.
///
/// Failure semantics: if [reserveOne] fails (typically FailedPrecondition
/// → out-of-stock), the throw propagates to the caller. The cart UI then
/// must NOT bump its own counter so the on-screen quantity stays
/// truthful. The controller's internal map is unchanged on failure.
///
/// keepAlive so reservations survive screen navigation (picker ↔ cart ↔
/// tender). Cleared on a successful Finalize via [clearAll] (called by
/// FinalizeController).
library;

import 'package:fixnum/fixnum.dart';
import 'package:pos_sdk/gen/pos/v1/common.pb.dart';
import 'package:pos_sdk/gen/pos/v1/reservation_service.connect.client.dart';
import 'package:pos_sdk/gen/pos/v1/reservation_service.pb.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

import '../../config.dart';
import '../../core/transport.dart';

part 'reservations_controller.g.dart';

/// Maps SKU → ordered list of reservation_ids the cart currently holds
/// for that SKU. The order matters: [releaseOne] releases the MOST
/// RECENT id (LIFO), which is harmless but matches the natural "undo
/// the last +1" model.
typedef ReservationLedger = Map<String, List<String>>;

@Riverpod(keepAlive: true)
class ReservationsController extends _$ReservationsController {
  static const _uuid = Uuid();

  @override
  ReservationLedger build() => <String, List<String>>{};

  /// Returns all reservation_ids across every SKU in stable per-SKU
  /// order — what FinalizeRequest.reservation_ids wants.
  List<String> allReservationIds() {
    final out = <String>[];
    for (final ids in state.values) {
      out.addAll(ids);
    }
    return out;
  }

  /// Count of held units for a SKU. UI uses this when rebuilding the
  /// available-quantity row.
  int heldCountFor(String sku) => state[sku]?.length ?? 0;

  /// Reserves +1 on the given SKU. On success appends a new id; on
  /// failure rethrows and leaves state untouched. Caller (cart stepper)
  /// should not advance its own counter on failure.
  Future<void> reserveOne(String sku) async {
    final client = ReservationServiceClient(ref.read(transportProvider));
    final id = _uuid.v4();
    await client.reserve(ReserveRequest(
      reservationId: id,
      sku: sku,
      storeId: StoreId(value: kStoreId),
      counterId: CounterId(value: kCounterId),
      quantity: Int64(1),
    ));
    final cur = List<String>.from(state[sku] ?? const <String>[])..add(id);
    state = {...state, sku: cur};
  }

  /// Releases the most-recently-added reservation for the SKU. Errors
  /// from the server are swallowed (Release is idempotent server-side
  /// and the worst case is a TTL-expired row releasing itself in 5min).
  Future<void> releaseOne(String sku) async {
    final cur = state[sku];
    if (cur == null || cur.isEmpty) return;
    final id = cur.last;
    final next = List<String>.from(cur)..removeLast();
    // Optimistic local update — UX feels snappy even on slow LAN.
    if (next.isEmpty) {
      final m = {...state}..remove(sku);
      state = m;
    } else {
      state = {...state, sku: next};
    }
    try {
      final client = ReservationServiceClient(ref.read(transportProvider));
      await client.release(ReleaseRequest(reservationId: id));
    } catch (_) {
      // Server-side TTL will clean it up if needed. Local truth is what
      // the cart shows; we don't want a transient RPC blip to revert
      // the operator's UI.
    }
  }

  /// Releases every reservation for the SKU (e.g. user clicked "Remove
  /// line"). Best-effort per id; failures swallowed for the same reason
  /// as [releaseOne].
  Future<void> releaseAllFor(String sku) async {
    final cur = state[sku];
    if (cur == null || cur.isEmpty) return;
    final m = {...state}..remove(sku);
    state = m;
    final client = ReservationServiceClient(ref.read(transportProvider));
    for (final id in cur) {
      try {
        await client.release(ReleaseRequest(reservationId: id));
      } catch (_) {
        // ignore; TTL fallback.
      }
    }
  }

  /// Releases every reservation across every SKU. Used by cart-clear
  /// and by FinalizeController on a failed Finalize that needs to
  /// unwind holds (so another counter can pick up the stock).
  Future<void> releaseEverything() async {
    final snapshot = state;
    state = <String, List<String>>{};
    final client = ReservationServiceClient(ref.read(transportProvider));
    for (final ids in snapshot.values) {
      for (final id in ids) {
        try {
          await client.release(ReleaseRequest(reservationId: id));
        } catch (_) {
          // ignore; TTL fallback.
        }
      }
    }
  }

  /// Drops the local ledger WITHOUT calling Release. This is what
  /// FinalizeController calls after a successful sale: the server
  /// consumed every id as part of the Finalize commit, so a follow-up
  /// Release would 404 (or worse, race with the consumed-state row).
  void clearAfterFinalize() {
    state = <String, List<String>>{};
  }
}
