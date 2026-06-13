// This is a generated file - do not edit.
//
// Generated from pos/v1/reservation_service.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names

import 'dart:async' as $async;
import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import '../../google/protobuf/timestamp.pb.dart' as $1;
import 'common.pb.dart' as $0;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

class ReserveRequest extends $pb.GeneratedMessage {
  factory ReserveRequest({
    $core.String? reservationId,
    $core.String? sku,
    $0.StoreId? storeId,
    $0.CounterId? counterId,
    $fixnum.Int64? quantity,
  }) {
    final result = create();
    if (reservationId != null) result.reservationId = reservationId;
    if (sku != null) result.sku = sku;
    if (storeId != null) result.storeId = storeId;
    if (counterId != null) result.counterId = counterId;
    if (quantity != null) result.quantity = quantity;
    return result;
  }

  ReserveRequest._();

  factory ReserveRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ReserveRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ReserveRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pos.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'reservationId')
    ..aOS(2, _omitFieldNames ? '' : 'sku')
    ..aOM<$0.StoreId>(3, _omitFieldNames ? '' : 'storeId',
        subBuilder: $0.StoreId.create)
    ..aOM<$0.CounterId>(4, _omitFieldNames ? '' : 'counterId',
        subBuilder: $0.CounterId.create)
    ..aInt64(5, _omitFieldNames ? '' : 'quantity')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReserveRequest clone() => ReserveRequest()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReserveRequest copyWith(void Function(ReserveRequest) updates) =>
      super.copyWith((message) => updates(message as ReserveRequest))
          as ReserveRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ReserveRequest create() => ReserveRequest._();
  @$core.override
  ReserveRequest createEmptyInstance() => create();
  static $pb.PbList<ReserveRequest> createRepeated() =>
      $pb.PbList<ReserveRequest>();
  @$core.pragma('dart2js:noInline')
  static ReserveRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ReserveRequest>(create);
  static ReserveRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get reservationId => $_getSZ(0);
  @$pb.TagNumber(1)
  set reservationId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasReservationId() => $_has(0);
  @$pb.TagNumber(1)
  void clearReservationId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get sku => $_getSZ(1);
  @$pb.TagNumber(2)
  set sku($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSku() => $_has(1);
  @$pb.TagNumber(2)
  void clearSku() => $_clearField(2);

  @$pb.TagNumber(3)
  $0.StoreId get storeId => $_getN(2);
  @$pb.TagNumber(3)
  set storeId($0.StoreId value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasStoreId() => $_has(2);
  @$pb.TagNumber(3)
  void clearStoreId() => $_clearField(3);
  @$pb.TagNumber(3)
  $0.StoreId ensureStoreId() => $_ensure(2);

  @$pb.TagNumber(4)
  $0.CounterId get counterId => $_getN(3);
  @$pb.TagNumber(4)
  set counterId($0.CounterId value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasCounterId() => $_has(3);
  @$pb.TagNumber(4)
  void clearCounterId() => $_clearField(4);
  @$pb.TagNumber(4)
  $0.CounterId ensureCounterId() => $_ensure(3);

  @$pb.TagNumber(5)
  $fixnum.Int64 get quantity => $_getI64(4);
  @$pb.TagNumber(5)
  set quantity($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasQuantity() => $_has(4);
  @$pb.TagNumber(5)
  void clearQuantity() => $_clearField(5);
}

class ReserveResponse extends $pb.GeneratedMessage {
  factory ReserveResponse({
    Reservation? reservation,
    $fixnum.Int64? availableQty,
  }) {
    final result = create();
    if (reservation != null) result.reservation = reservation;
    if (availableQty != null) result.availableQty = availableQty;
    return result;
  }

  ReserveResponse._();

  factory ReserveResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ReserveResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ReserveResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pos.v1'),
      createEmptyInstance: create)
    ..aOM<Reservation>(1, _omitFieldNames ? '' : 'reservation',
        subBuilder: Reservation.create)
    ..aInt64(2, _omitFieldNames ? '' : 'availableQty')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReserveResponse clone() => ReserveResponse()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReserveResponse copyWith(void Function(ReserveResponse) updates) =>
      super.copyWith((message) => updates(message as ReserveResponse))
          as ReserveResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ReserveResponse create() => ReserveResponse._();
  @$core.override
  ReserveResponse createEmptyInstance() => create();
  static $pb.PbList<ReserveResponse> createRepeated() =>
      $pb.PbList<ReserveResponse>();
  @$core.pragma('dart2js:noInline')
  static ReserveResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ReserveResponse>(create);
  static ReserveResponse? _defaultInstance;

  @$pb.TagNumber(1)
  Reservation get reservation => $_getN(0);
  @$pb.TagNumber(1)
  set reservation(Reservation value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasReservation() => $_has(0);
  @$pb.TagNumber(1)
  void clearReservation() => $_clearField(1);
  @$pb.TagNumber(1)
  Reservation ensureReservation() => $_ensure(0);

  @$pb.TagNumber(2)
  $fixnum.Int64 get availableQty => $_getI64(1);
  @$pb.TagNumber(2)
  set availableQty($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasAvailableQty() => $_has(1);
  @$pb.TagNumber(2)
  void clearAvailableQty() => $_clearField(2);
}

class ReleaseRequest extends $pb.GeneratedMessage {
  factory ReleaseRequest({
    $core.String? reservationId,
  }) {
    final result = create();
    if (reservationId != null) result.reservationId = reservationId;
    return result;
  }

  ReleaseRequest._();

  factory ReleaseRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ReleaseRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ReleaseRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pos.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'reservationId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReleaseRequest clone() => ReleaseRequest()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReleaseRequest copyWith(void Function(ReleaseRequest) updates) =>
      super.copyWith((message) => updates(message as ReleaseRequest))
          as ReleaseRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ReleaseRequest create() => ReleaseRequest._();
  @$core.override
  ReleaseRequest createEmptyInstance() => create();
  static $pb.PbList<ReleaseRequest> createRepeated() =>
      $pb.PbList<ReleaseRequest>();
  @$core.pragma('dart2js:noInline')
  static ReleaseRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ReleaseRequest>(create);
  static ReleaseRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get reservationId => $_getSZ(0);
  @$pb.TagNumber(1)
  set reservationId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasReservationId() => $_has(0);
  @$pb.TagNumber(1)
  void clearReservationId() => $_clearField(1);
}

class ReleaseResponse extends $pb.GeneratedMessage {
  factory ReleaseResponse({
    Reservation? reservation,
  }) {
    final result = create();
    if (reservation != null) result.reservation = reservation;
    return result;
  }

  ReleaseResponse._();

  factory ReleaseResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ReleaseResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ReleaseResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pos.v1'),
      createEmptyInstance: create)
    ..aOM<Reservation>(1, _omitFieldNames ? '' : 'reservation',
        subBuilder: Reservation.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReleaseResponse clone() => ReleaseResponse()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReleaseResponse copyWith(void Function(ReleaseResponse) updates) =>
      super.copyWith((message) => updates(message as ReleaseResponse))
          as ReleaseResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ReleaseResponse create() => ReleaseResponse._();
  @$core.override
  ReleaseResponse createEmptyInstance() => create();
  static $pb.PbList<ReleaseResponse> createRepeated() =>
      $pb.PbList<ReleaseResponse>();
  @$core.pragma('dart2js:noInline')
  static ReleaseResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ReleaseResponse>(create);
  static ReleaseResponse? _defaultInstance;

  @$pb.TagNumber(1)
  Reservation get reservation => $_getN(0);
  @$pb.TagNumber(1)
  set reservation(Reservation value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasReservation() => $_has(0);
  @$pb.TagNumber(1)
  void clearReservation() => $_clearField(1);
  @$pb.TagNumber(1)
  Reservation ensureReservation() => $_ensure(0);
}

class Reservation extends $pb.GeneratedMessage {
  factory Reservation({
    $core.String? reservationId,
    $core.String? sku,
    $0.StoreId? storeId,
    $0.CounterId? counterId,
    $fixnum.Int64? quantity,
    $1.Timestamp? createdAt,
    $1.Timestamp? expiresAt,
    $core.String? status,
  }) {
    final result = create();
    if (reservationId != null) result.reservationId = reservationId;
    if (sku != null) result.sku = sku;
    if (storeId != null) result.storeId = storeId;
    if (counterId != null) result.counterId = counterId;
    if (quantity != null) result.quantity = quantity;
    if (createdAt != null) result.createdAt = createdAt;
    if (expiresAt != null) result.expiresAt = expiresAt;
    if (status != null) result.status = status;
    return result;
  }

  Reservation._();

  factory Reservation.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Reservation.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Reservation',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pos.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'reservationId')
    ..aOS(2, _omitFieldNames ? '' : 'sku')
    ..aOM<$0.StoreId>(3, _omitFieldNames ? '' : 'storeId',
        subBuilder: $0.StoreId.create)
    ..aOM<$0.CounterId>(4, _omitFieldNames ? '' : 'counterId',
        subBuilder: $0.CounterId.create)
    ..aInt64(5, _omitFieldNames ? '' : 'quantity')
    ..aOM<$1.Timestamp>(6, _omitFieldNames ? '' : 'createdAt',
        subBuilder: $1.Timestamp.create)
    ..aOM<$1.Timestamp>(7, _omitFieldNames ? '' : 'expiresAt',
        subBuilder: $1.Timestamp.create)
    ..aOS(8, _omitFieldNames ? '' : 'status')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Reservation clone() => Reservation()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Reservation copyWith(void Function(Reservation) updates) =>
      super.copyWith((message) => updates(message as Reservation))
          as Reservation;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Reservation create() => Reservation._();
  @$core.override
  Reservation createEmptyInstance() => create();
  static $pb.PbList<Reservation> createRepeated() => $pb.PbList<Reservation>();
  @$core.pragma('dart2js:noInline')
  static Reservation getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Reservation>(create);
  static Reservation? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get reservationId => $_getSZ(0);
  @$pb.TagNumber(1)
  set reservationId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasReservationId() => $_has(0);
  @$pb.TagNumber(1)
  void clearReservationId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get sku => $_getSZ(1);
  @$pb.TagNumber(2)
  set sku($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSku() => $_has(1);
  @$pb.TagNumber(2)
  void clearSku() => $_clearField(2);

  @$pb.TagNumber(3)
  $0.StoreId get storeId => $_getN(2);
  @$pb.TagNumber(3)
  set storeId($0.StoreId value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasStoreId() => $_has(2);
  @$pb.TagNumber(3)
  void clearStoreId() => $_clearField(3);
  @$pb.TagNumber(3)
  $0.StoreId ensureStoreId() => $_ensure(2);

  @$pb.TagNumber(4)
  $0.CounterId get counterId => $_getN(3);
  @$pb.TagNumber(4)
  set counterId($0.CounterId value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasCounterId() => $_has(3);
  @$pb.TagNumber(4)
  void clearCounterId() => $_clearField(4);
  @$pb.TagNumber(4)
  $0.CounterId ensureCounterId() => $_ensure(3);

  @$pb.TagNumber(5)
  $fixnum.Int64 get quantity => $_getI64(4);
  @$pb.TagNumber(5)
  set quantity($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasQuantity() => $_has(4);
  @$pb.TagNumber(5)
  void clearQuantity() => $_clearField(5);

  @$pb.TagNumber(6)
  $1.Timestamp get createdAt => $_getN(5);
  @$pb.TagNumber(6)
  set createdAt($1.Timestamp value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasCreatedAt() => $_has(5);
  @$pb.TagNumber(6)
  void clearCreatedAt() => $_clearField(6);
  @$pb.TagNumber(6)
  $1.Timestamp ensureCreatedAt() => $_ensure(5);

  @$pb.TagNumber(7)
  $1.Timestamp get expiresAt => $_getN(6);
  @$pb.TagNumber(7)
  set expiresAt($1.Timestamp value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasExpiresAt() => $_has(6);
  @$pb.TagNumber(7)
  void clearExpiresAt() => $_clearField(7);
  @$pb.TagNumber(7)
  $1.Timestamp ensureExpiresAt() => $_ensure(6);

  @$pb.TagNumber(8)
  $core.String get status => $_getSZ(7);
  @$pb.TagNumber(8)
  set status($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasStatus() => $_has(7);
  @$pb.TagNumber(8)
  void clearStatus() => $_clearField(8);
}

/// ReservationService is the soft-inventory hold surface — Phase 4 slice
/// 4.3. Counters call Reserve when items hit the cart and Release if the
/// cart is abandoned. SaleService.Finalize finalizes reservations as part
/// of the sale's atomic commit (via FinalizeRequest.reservation_ids).
///
/// Holds are intra-store ONLY: never synced to the cloud, never produce
/// inventory_movements. They participate in InventoryService.ListOnHand
/// indirectly via the held-quantity subtracted from the on-hand sum.
class ReservationServiceApi {
  final $pb.RpcClient _client;

  ReservationServiceApi(this._client);

  /// Reserve creates a new active hold or fails with FailedPrecondition if
  /// available stock is insufficient (after lazily expiring stale holds).
  $async.Future<ReserveResponse> reserve(
          $pb.ClientContext? ctx, ReserveRequest request) =>
      _client.invoke<ReserveResponse>(
          ctx, 'ReservationService', 'Reserve', request, ReserveResponse());

  /// Release cancels an active hold. Idempotent on already-released rows.
  $async.Future<ReleaseResponse> release(
          $pb.ClientContext? ctx, ReleaseRequest request) =>
      _client.invoke<ReleaseResponse>(
          ctx, 'ReservationService', 'Release', request, ReleaseResponse());
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
