/// ReservationsController tests via FakeTransport.
///
/// Covers:
///   - reserveOne → server gets one Reserve per call, ledger appends id
///   - releaseOne LIFO + optimistic local update
///   - allReservationIds returns the full accumulated set
///   - reserveOne failure leaves state untouched and rethrows
///   - clearAfterFinalize empties without calling Release
library;

import 'package:connectrpc/connect.dart' as connect;
import 'package:connectrpc/test.dart' as ctest;
import 'package:desktop_pos/core/transport.dart';
import 'package:desktop_pos/features/reservations/reservations_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_sdk/gen/pos/v1/reservation_service.connect.spec.dart';
import 'package:pos_sdk/gen/pos/v1/reservation_service.pb.dart';

void main() {
  test('reserveOne appends an id; allReservationIds aggregates', () async {
    final reserved = <ReserveRequest>[];
    final fake = ctest.FakeTransportBuilder()
        .unary(ReservationService.reserve, (req, _) async {
      reserved.add(req);
      return ReserveResponse(reservation: Reservation(
        reservationId: req.reservationId,
        sku: req.sku,
      ));
    }).build();

    final c = ProviderContainer(overrides: [
      transportProvider.overrideWithValue(fake),
    ]);
    addTearDown(c.dispose);

    final ctl = c.read(reservationsControllerProvider.notifier);
    await ctl.reserveOne('A');
    await ctl.reserveOne('A');
    await ctl.reserveOne('B');

    expect(reserved, hasLength(3));
    expect(reserved.map((r) => r.sku).toList(), ['A', 'A', 'B']);
    expect(ctl.heldCountFor('A'), 2);
    expect(ctl.heldCountFor('B'), 1);
    expect(ctl.allReservationIds(), hasLength(3));

    // Every reservation_id minted client-side is non-empty and unique.
    final ids = ctl.allReservationIds().toSet();
    expect(ids, hasLength(3));
    for (final id in ids) {
      expect(id, isNotEmpty);
    }
  });

  test('releaseOne is LIFO and applies optimistically before RPC',
      () async {
    final released = <ReleaseRequest>[];
    final reserveIds = <String>[];
    final fake = ctest.FakeTransportBuilder()
        .unary(ReservationService.reserve, (req, _) async {
      reserveIds.add(req.reservationId);
      return ReserveResponse(
          reservation: Reservation(reservationId: req.reservationId));
    }).unary(ReservationService.release, (req, _) async {
      released.add(req);
      return ReleaseResponse();
    }).build();

    final c = ProviderContainer(overrides: [
      transportProvider.overrideWithValue(fake),
    ]);
    addTearDown(c.dispose);

    final ctl = c.read(reservationsControllerProvider.notifier);
    await ctl.reserveOne('A');
    await ctl.reserveOne('A');
    final mostRecent = reserveIds.last;

    await ctl.releaseOne('A');
    expect(released.single.reservationId, mostRecent);
    expect(ctl.heldCountFor('A'), 1);

    // Release the last one — entry should drop from the map entirely.
    await ctl.releaseOne('A');
    expect(ctl.heldCountFor('A'), 0);
    expect(ctl.allReservationIds(), isEmpty);
  });

  test('reserveOne failure rethrows and leaves state untouched',
      () async {
    final fake = ctest.FakeTransportBuilder()
        .unary(ReservationService.reserve, (req, _) async {
      throw connect.ConnectException(
          connect.Code.failedPrecondition, 'out of stock');
    }).build();

    final c = ProviderContainer(overrides: [
      transportProvider.overrideWithValue(fake),
    ]);
    addTearDown(c.dispose);

    final ctl = c.read(reservationsControllerProvider.notifier);
    await expectLater(
      ctl.reserveOne('A'),
      throwsA(isA<connect.ConnectException>()),
    );
    expect(ctl.heldCountFor('A'), 0);
    expect(ctl.allReservationIds(), isEmpty);
  });

  test('releaseOne swallows server errors (TTL fallback)', () async {
    var reserveCount = 0;
    final fake = ctest.FakeTransportBuilder()
        .unary(ReservationService.reserve, (req, _) async {
      reserveCount++;
      return ReserveResponse(
          reservation: Reservation(reservationId: req.reservationId));
    }).unary(ReservationService.release, (req, _) async {
      throw connect.ConnectException(connect.Code.unavailable, 'boom');
    }).build();

    final c = ProviderContainer(overrides: [
      transportProvider.overrideWithValue(fake),
    ]);
    addTearDown(c.dispose);

    final ctl = c.read(reservationsControllerProvider.notifier);
    await ctl.reserveOne('A');
    expect(reserveCount, 1);

    // Should NOT throw — local state is optimistic truth.
    await ctl.releaseOne('A');
    expect(ctl.heldCountFor('A'), 0);
  });

  test('releaseAllFor drops every id for the SKU', () async {
    final released = <ReleaseRequest>[];
    final fake = ctest.FakeTransportBuilder()
        .unary(ReservationService.reserve, (req, _) async {
      return ReserveResponse(
          reservation: Reservation(reservationId: req.reservationId));
    }).unary(ReservationService.release, (req, _) async {
      released.add(req);
      return ReleaseResponse();
    }).build();

    final c = ProviderContainer(overrides: [
      transportProvider.overrideWithValue(fake),
    ]);
    addTearDown(c.dispose);

    final ctl = c.read(reservationsControllerProvider.notifier);
    await ctl.reserveOne('A');
    await ctl.reserveOne('A');
    await ctl.reserveOne('A');
    await ctl.reserveOne('B');

    await ctl.releaseAllFor('A');
    expect(ctl.heldCountFor('A'), 0);
    expect(ctl.heldCountFor('B'), 1);
    expect(released.map((r) => r.reservationId).toSet(), hasLength(3));
  });

  test('clearAfterFinalize drops state without calling Release', () async {
    final released = <ReleaseRequest>[];
    final fake = ctest.FakeTransportBuilder()
        .unary(ReservationService.reserve, (req, _) async {
      return ReserveResponse(
          reservation: Reservation(reservationId: req.reservationId));
    }).unary(ReservationService.release, (req, _) async {
      released.add(req);
      return ReleaseResponse();
    }).build();

    final c = ProviderContainer(overrides: [
      transportProvider.overrideWithValue(fake),
    ]);
    addTearDown(c.dispose);

    final ctl = c.read(reservationsControllerProvider.notifier);
    await ctl.reserveOne('A');
    await ctl.reserveOne('B');

    ctl.clearAfterFinalize();
    expect(ctl.allReservationIds(), isEmpty);
    expect(released, isEmpty);
  });
}
