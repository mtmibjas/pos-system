// This is a generated file - do not edit.
//
// Generated from pos/v1/refund_service.proto.

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

class VoidSaleRequest extends $pb.GeneratedMessage {
  factory VoidSaleRequest({
    $core.String? voidId,
    $core.String? saleId,
    $0.StoreId? storeId,
    $0.CounterId? counterId,
    $0.UserId? cashierId,
    $core.String? reason,
    $1.Timestamp? occurredAt,
  }) {
    final result = create();
    if (voidId != null) result.voidId = voidId;
    if (saleId != null) result.saleId = saleId;
    if (storeId != null) result.storeId = storeId;
    if (counterId != null) result.counterId = counterId;
    if (cashierId != null) result.cashierId = cashierId;
    if (reason != null) result.reason = reason;
    if (occurredAt != null) result.occurredAt = occurredAt;
    return result;
  }

  VoidSaleRequest._();

  factory VoidSaleRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory VoidSaleRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'VoidSaleRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pos.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'voidId')
    ..aOS(2, _omitFieldNames ? '' : 'saleId')
    ..aOM<$0.StoreId>(3, _omitFieldNames ? '' : 'storeId',
        subBuilder: $0.StoreId.create)
    ..aOM<$0.CounterId>(4, _omitFieldNames ? '' : 'counterId',
        subBuilder: $0.CounterId.create)
    ..aOM<$0.UserId>(5, _omitFieldNames ? '' : 'cashierId',
        subBuilder: $0.UserId.create)
    ..aOS(6, _omitFieldNames ? '' : 'reason')
    ..aOM<$1.Timestamp>(7, _omitFieldNames ? '' : 'occurredAt',
        subBuilder: $1.Timestamp.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  VoidSaleRequest clone() => VoidSaleRequest()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  VoidSaleRequest copyWith(void Function(VoidSaleRequest) updates) =>
      super.copyWith((message) => updates(message as VoidSaleRequest))
          as VoidSaleRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static VoidSaleRequest create() => VoidSaleRequest._();
  @$core.override
  VoidSaleRequest createEmptyInstance() => create();
  static $pb.PbList<VoidSaleRequest> createRepeated() =>
      $pb.PbList<VoidSaleRequest>();
  @$core.pragma('dart2js:noInline')
  static VoidSaleRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<VoidSaleRequest>(create);
  static VoidSaleRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get voidId => $_getSZ(0);
  @$pb.TagNumber(1)
  set voidId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasVoidId() => $_has(0);
  @$pb.TagNumber(1)
  void clearVoidId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get saleId => $_getSZ(1);
  @$pb.TagNumber(2)
  set saleId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSaleId() => $_has(1);
  @$pb.TagNumber(2)
  void clearSaleId() => $_clearField(2);

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
  $0.UserId get cashierId => $_getN(4);
  @$pb.TagNumber(5)
  set cashierId($0.UserId value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasCashierId() => $_has(4);
  @$pb.TagNumber(5)
  void clearCashierId() => $_clearField(5);
  @$pb.TagNumber(5)
  $0.UserId ensureCashierId() => $_ensure(4);

  @$pb.TagNumber(6)
  $core.String get reason => $_getSZ(5);
  @$pb.TagNumber(6)
  set reason($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasReason() => $_has(5);
  @$pb.TagNumber(6)
  void clearReason() => $_clearField(6);

  @$pb.TagNumber(7)
  $1.Timestamp get occurredAt => $_getN(6);
  @$pb.TagNumber(7)
  set occurredAt($1.Timestamp value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasOccurredAt() => $_has(6);
  @$pb.TagNumber(7)
  void clearOccurredAt() => $_clearField(7);
  @$pb.TagNumber(7)
  $1.Timestamp ensureOccurredAt() => $_ensure(6);
}

class VoidSaleResponse extends $pb.GeneratedMessage {
  factory VoidSaleResponse({
    $core.String? voidId,
    $core.String? batchId,
    $fixnum.Int64? lamport,
    Void? void_4,
    $core.bool? idempotent,
  }) {
    final result = create();
    if (voidId != null) result.voidId = voidId;
    if (batchId != null) result.batchId = batchId;
    if (lamport != null) result.lamport = lamport;
    if (void_4 != null) result.void_4 = void_4;
    if (idempotent != null) result.idempotent = idempotent;
    return result;
  }

  VoidSaleResponse._();

  factory VoidSaleResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory VoidSaleResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'VoidSaleResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pos.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'voidId')
    ..aOS(2, _omitFieldNames ? '' : 'batchId')
    ..a<$fixnum.Int64>(3, _omitFieldNames ? '' : 'lamport', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOM<Void>(4, _omitFieldNames ? '' : 'void', subBuilder: Void.create)
    ..aOB(5, _omitFieldNames ? '' : 'idempotent')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  VoidSaleResponse clone() => VoidSaleResponse()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  VoidSaleResponse copyWith(void Function(VoidSaleResponse) updates) =>
      super.copyWith((message) => updates(message as VoidSaleResponse))
          as VoidSaleResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static VoidSaleResponse create() => VoidSaleResponse._();
  @$core.override
  VoidSaleResponse createEmptyInstance() => create();
  static $pb.PbList<VoidSaleResponse> createRepeated() =>
      $pb.PbList<VoidSaleResponse>();
  @$core.pragma('dart2js:noInline')
  static VoidSaleResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<VoidSaleResponse>(create);
  static VoidSaleResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get voidId => $_getSZ(0);
  @$pb.TagNumber(1)
  set voidId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasVoidId() => $_has(0);
  @$pb.TagNumber(1)
  void clearVoidId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get batchId => $_getSZ(1);
  @$pb.TagNumber(2)
  set batchId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasBatchId() => $_has(1);
  @$pb.TagNumber(2)
  void clearBatchId() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get lamport => $_getI64(2);
  @$pb.TagNumber(3)
  set lamport($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasLamport() => $_has(2);
  @$pb.TagNumber(3)
  void clearLamport() => $_clearField(3);

  @$pb.TagNumber(4)
  Void get void_4 => $_getN(3);
  @$pb.TagNumber(4)
  set void_4(Void value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasVoid_4() => $_has(3);
  @$pb.TagNumber(4)
  void clearVoid_4() => $_clearField(4);
  @$pb.TagNumber(4)
  Void ensureVoid_4() => $_ensure(3);

  @$pb.TagNumber(5)
  $core.bool get idempotent => $_getBF(4);
  @$pb.TagNumber(5)
  set idempotent($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasIdempotent() => $_has(4);
  @$pb.TagNumber(5)
  void clearIdempotent() => $_clearField(5);
}

class Void extends $pb.GeneratedMessage {
  factory Void({
    $core.String? voidId,
    $core.String? saleId,
    $core.String? invoiceId,
    $0.StoreId? storeId,
    $0.CounterId? counterId,
    $0.UserId? cashierId,
    $core.String? reason,
    $core.List<$core.int>? snapshot,
    $1.Timestamp? voidedAt,
  }) {
    final result = create();
    if (voidId != null) result.voidId = voidId;
    if (saleId != null) result.saleId = saleId;
    if (invoiceId != null) result.invoiceId = invoiceId;
    if (storeId != null) result.storeId = storeId;
    if (counterId != null) result.counterId = counterId;
    if (cashierId != null) result.cashierId = cashierId;
    if (reason != null) result.reason = reason;
    if (snapshot != null) result.snapshot = snapshot;
    if (voidedAt != null) result.voidedAt = voidedAt;
    return result;
  }

  Void._();

  factory Void.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Void.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Void',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pos.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'voidId')
    ..aOS(2, _omitFieldNames ? '' : 'saleId')
    ..aOS(3, _omitFieldNames ? '' : 'invoiceId')
    ..aOM<$0.StoreId>(4, _omitFieldNames ? '' : 'storeId',
        subBuilder: $0.StoreId.create)
    ..aOM<$0.CounterId>(5, _omitFieldNames ? '' : 'counterId',
        subBuilder: $0.CounterId.create)
    ..aOM<$0.UserId>(6, _omitFieldNames ? '' : 'cashierId',
        subBuilder: $0.UserId.create)
    ..aOS(7, _omitFieldNames ? '' : 'reason')
    ..a<$core.List<$core.int>>(
        8, _omitFieldNames ? '' : 'snapshot', $pb.PbFieldType.OY)
    ..aOM<$1.Timestamp>(9, _omitFieldNames ? '' : 'voidedAt',
        subBuilder: $1.Timestamp.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Void clone() => Void()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Void copyWith(void Function(Void) updates) =>
      super.copyWith((message) => updates(message as Void)) as Void;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Void create() => Void._();
  @$core.override
  Void createEmptyInstance() => create();
  static $pb.PbList<Void> createRepeated() => $pb.PbList<Void>();
  @$core.pragma('dart2js:noInline')
  static Void getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Void>(create);
  static Void? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get voidId => $_getSZ(0);
  @$pb.TagNumber(1)
  set voidId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasVoidId() => $_has(0);
  @$pb.TagNumber(1)
  void clearVoidId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get saleId => $_getSZ(1);
  @$pb.TagNumber(2)
  set saleId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSaleId() => $_has(1);
  @$pb.TagNumber(2)
  void clearSaleId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get invoiceId => $_getSZ(2);
  @$pb.TagNumber(3)
  set invoiceId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasInvoiceId() => $_has(2);
  @$pb.TagNumber(3)
  void clearInvoiceId() => $_clearField(3);

  @$pb.TagNumber(4)
  $0.StoreId get storeId => $_getN(3);
  @$pb.TagNumber(4)
  set storeId($0.StoreId value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasStoreId() => $_has(3);
  @$pb.TagNumber(4)
  void clearStoreId() => $_clearField(4);
  @$pb.TagNumber(4)
  $0.StoreId ensureStoreId() => $_ensure(3);

  @$pb.TagNumber(5)
  $0.CounterId get counterId => $_getN(4);
  @$pb.TagNumber(5)
  set counterId($0.CounterId value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasCounterId() => $_has(4);
  @$pb.TagNumber(5)
  void clearCounterId() => $_clearField(5);
  @$pb.TagNumber(5)
  $0.CounterId ensureCounterId() => $_ensure(4);

  @$pb.TagNumber(6)
  $0.UserId get cashierId => $_getN(5);
  @$pb.TagNumber(6)
  set cashierId($0.UserId value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasCashierId() => $_has(5);
  @$pb.TagNumber(6)
  void clearCashierId() => $_clearField(6);
  @$pb.TagNumber(6)
  $0.UserId ensureCashierId() => $_ensure(5);

  @$pb.TagNumber(7)
  $core.String get reason => $_getSZ(6);
  @$pb.TagNumber(7)
  set reason($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasReason() => $_has(6);
  @$pb.TagNumber(7)
  void clearReason() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.List<$core.int> get snapshot => $_getN(7);
  @$pb.TagNumber(8)
  set snapshot($core.List<$core.int> value) => $_setBytes(7, value);
  @$pb.TagNumber(8)
  $core.bool hasSnapshot() => $_has(7);
  @$pb.TagNumber(8)
  void clearSnapshot() => $_clearField(8);

  @$pb.TagNumber(9)
  $1.Timestamp get voidedAt => $_getN(8);
  @$pb.TagNumber(9)
  set voidedAt($1.Timestamp value) => $_setField(9, value);
  @$pb.TagNumber(9)
  $core.bool hasVoidedAt() => $_has(8);
  @$pb.TagNumber(9)
  void clearVoidedAt() => $_clearField(9);
  @$pb.TagNumber(9)
  $1.Timestamp ensureVoidedAt() => $_ensure(8);
}

class RefundSaleRequest extends $pb.GeneratedMessage {
  factory RefundSaleRequest({
    $core.String? refundId,
    $core.String? saleId,
    $0.StoreId? storeId,
    $0.CounterId? counterId,
    $0.UserId? cashierId,
    $core.String? reason,
    $1.Timestamp? occurredAt,
    $core.Iterable<RefundSaleLine>? lines,
    $core.Iterable<RefundSaleTender>? tenders,
  }) {
    final result = create();
    if (refundId != null) result.refundId = refundId;
    if (saleId != null) result.saleId = saleId;
    if (storeId != null) result.storeId = storeId;
    if (counterId != null) result.counterId = counterId;
    if (cashierId != null) result.cashierId = cashierId;
    if (reason != null) result.reason = reason;
    if (occurredAt != null) result.occurredAt = occurredAt;
    if (lines != null) result.lines.addAll(lines);
    if (tenders != null) result.tenders.addAll(tenders);
    return result;
  }

  RefundSaleRequest._();

  factory RefundSaleRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RefundSaleRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RefundSaleRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pos.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'refundId')
    ..aOS(2, _omitFieldNames ? '' : 'saleId')
    ..aOM<$0.StoreId>(3, _omitFieldNames ? '' : 'storeId',
        subBuilder: $0.StoreId.create)
    ..aOM<$0.CounterId>(4, _omitFieldNames ? '' : 'counterId',
        subBuilder: $0.CounterId.create)
    ..aOM<$0.UserId>(5, _omitFieldNames ? '' : 'cashierId',
        subBuilder: $0.UserId.create)
    ..aOS(6, _omitFieldNames ? '' : 'reason')
    ..aOM<$1.Timestamp>(7, _omitFieldNames ? '' : 'occurredAt',
        subBuilder: $1.Timestamp.create)
    ..pc<RefundSaleLine>(8, _omitFieldNames ? '' : 'lines', $pb.PbFieldType.PM,
        subBuilder: RefundSaleLine.create)
    ..pc<RefundSaleTender>(
        9, _omitFieldNames ? '' : 'tenders', $pb.PbFieldType.PM,
        subBuilder: RefundSaleTender.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RefundSaleRequest clone() => RefundSaleRequest()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RefundSaleRequest copyWith(void Function(RefundSaleRequest) updates) =>
      super.copyWith((message) => updates(message as RefundSaleRequest))
          as RefundSaleRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RefundSaleRequest create() => RefundSaleRequest._();
  @$core.override
  RefundSaleRequest createEmptyInstance() => create();
  static $pb.PbList<RefundSaleRequest> createRepeated() =>
      $pb.PbList<RefundSaleRequest>();
  @$core.pragma('dart2js:noInline')
  static RefundSaleRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RefundSaleRequest>(create);
  static RefundSaleRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get refundId => $_getSZ(0);
  @$pb.TagNumber(1)
  set refundId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRefundId() => $_has(0);
  @$pb.TagNumber(1)
  void clearRefundId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get saleId => $_getSZ(1);
  @$pb.TagNumber(2)
  set saleId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSaleId() => $_has(1);
  @$pb.TagNumber(2)
  void clearSaleId() => $_clearField(2);

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
  $0.UserId get cashierId => $_getN(4);
  @$pb.TagNumber(5)
  set cashierId($0.UserId value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasCashierId() => $_has(4);
  @$pb.TagNumber(5)
  void clearCashierId() => $_clearField(5);
  @$pb.TagNumber(5)
  $0.UserId ensureCashierId() => $_ensure(4);

  @$pb.TagNumber(6)
  $core.String get reason => $_getSZ(5);
  @$pb.TagNumber(6)
  set reason($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasReason() => $_has(5);
  @$pb.TagNumber(6)
  void clearReason() => $_clearField(6);

  @$pb.TagNumber(7)
  $1.Timestamp get occurredAt => $_getN(6);
  @$pb.TagNumber(7)
  set occurredAt($1.Timestamp value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasOccurredAt() => $_has(6);
  @$pb.TagNumber(7)
  void clearOccurredAt() => $_clearField(7);
  @$pb.TagNumber(7)
  $1.Timestamp ensureOccurredAt() => $_ensure(6);

  @$pb.TagNumber(8)
  $pb.PbList<RefundSaleLine> get lines => $_getList(7);

  @$pb.TagNumber(9)
  $pb.PbList<RefundSaleTender> get tenders => $_getList(8);
}

class RefundSaleLine extends $pb.GeneratedMessage {
  factory RefundSaleLine({
    $core.String? saleLineId,
    $core.String? sku,
    $fixnum.Int64? quantity,
    $core.bool? restock,
    $0.Money? unitPrice,
    $0.Money? lineTotal,
    $core.String? taxCategoryId,
  }) {
    final result = create();
    if (saleLineId != null) result.saleLineId = saleLineId;
    if (sku != null) result.sku = sku;
    if (quantity != null) result.quantity = quantity;
    if (restock != null) result.restock = restock;
    if (unitPrice != null) result.unitPrice = unitPrice;
    if (lineTotal != null) result.lineTotal = lineTotal;
    if (taxCategoryId != null) result.taxCategoryId = taxCategoryId;
    return result;
  }

  RefundSaleLine._();

  factory RefundSaleLine.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RefundSaleLine.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RefundSaleLine',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pos.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'saleLineId')
    ..aOS(2, _omitFieldNames ? '' : 'sku')
    ..aInt64(3, _omitFieldNames ? '' : 'quantity')
    ..aOB(4, _omitFieldNames ? '' : 'restock')
    ..aOM<$0.Money>(5, _omitFieldNames ? '' : 'unitPrice',
        subBuilder: $0.Money.create)
    ..aOM<$0.Money>(6, _omitFieldNames ? '' : 'lineTotal',
        subBuilder: $0.Money.create)
    ..aOS(7, _omitFieldNames ? '' : 'taxCategoryId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RefundSaleLine clone() => RefundSaleLine()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RefundSaleLine copyWith(void Function(RefundSaleLine) updates) =>
      super.copyWith((message) => updates(message as RefundSaleLine))
          as RefundSaleLine;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RefundSaleLine create() => RefundSaleLine._();
  @$core.override
  RefundSaleLine createEmptyInstance() => create();
  static $pb.PbList<RefundSaleLine> createRepeated() =>
      $pb.PbList<RefundSaleLine>();
  @$core.pragma('dart2js:noInline')
  static RefundSaleLine getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RefundSaleLine>(create);
  static RefundSaleLine? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get saleLineId => $_getSZ(0);
  @$pb.TagNumber(1)
  set saleLineId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSaleLineId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSaleLineId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get sku => $_getSZ(1);
  @$pb.TagNumber(2)
  set sku($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSku() => $_has(1);
  @$pb.TagNumber(2)
  void clearSku() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get quantity => $_getI64(2);
  @$pb.TagNumber(3)
  set quantity($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasQuantity() => $_has(2);
  @$pb.TagNumber(3)
  void clearQuantity() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get restock => $_getBF(3);
  @$pb.TagNumber(4)
  set restock($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasRestock() => $_has(3);
  @$pb.TagNumber(4)
  void clearRestock() => $_clearField(4);

  @$pb.TagNumber(5)
  $0.Money get unitPrice => $_getN(4);
  @$pb.TagNumber(5)
  set unitPrice($0.Money value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasUnitPrice() => $_has(4);
  @$pb.TagNumber(5)
  void clearUnitPrice() => $_clearField(5);
  @$pb.TagNumber(5)
  $0.Money ensureUnitPrice() => $_ensure(4);

  @$pb.TagNumber(6)
  $0.Money get lineTotal => $_getN(5);
  @$pb.TagNumber(6)
  set lineTotal($0.Money value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasLineTotal() => $_has(5);
  @$pb.TagNumber(6)
  void clearLineTotal() => $_clearField(6);
  @$pb.TagNumber(6)
  $0.Money ensureLineTotal() => $_ensure(5);

  @$pb.TagNumber(7)
  $core.String get taxCategoryId => $_getSZ(6);
  @$pb.TagNumber(7)
  set taxCategoryId($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasTaxCategoryId() => $_has(6);
  @$pb.TagNumber(7)
  void clearTaxCategoryId() => $_clearField(7);
}

class RefundSaleTender extends $pb.GeneratedMessage {
  factory RefundSaleTender({
    $core.String? refundPaymentId,
    $core.String? originalPaymentId,
    $core.String? method,
    $0.Money? amount,
    $core.String? reference,
  }) {
    final result = create();
    if (refundPaymentId != null) result.refundPaymentId = refundPaymentId;
    if (originalPaymentId != null) result.originalPaymentId = originalPaymentId;
    if (method != null) result.method = method;
    if (amount != null) result.amount = amount;
    if (reference != null) result.reference = reference;
    return result;
  }

  RefundSaleTender._();

  factory RefundSaleTender.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RefundSaleTender.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RefundSaleTender',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pos.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'refundPaymentId')
    ..aOS(2, _omitFieldNames ? '' : 'originalPaymentId')
    ..aOS(3, _omitFieldNames ? '' : 'method')
    ..aOM<$0.Money>(4, _omitFieldNames ? '' : 'amount',
        subBuilder: $0.Money.create)
    ..aOS(5, _omitFieldNames ? '' : 'reference')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RefundSaleTender clone() => RefundSaleTender()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RefundSaleTender copyWith(void Function(RefundSaleTender) updates) =>
      super.copyWith((message) => updates(message as RefundSaleTender))
          as RefundSaleTender;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RefundSaleTender create() => RefundSaleTender._();
  @$core.override
  RefundSaleTender createEmptyInstance() => create();
  static $pb.PbList<RefundSaleTender> createRepeated() =>
      $pb.PbList<RefundSaleTender>();
  @$core.pragma('dart2js:noInline')
  static RefundSaleTender getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RefundSaleTender>(create);
  static RefundSaleTender? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get refundPaymentId => $_getSZ(0);
  @$pb.TagNumber(1)
  set refundPaymentId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRefundPaymentId() => $_has(0);
  @$pb.TagNumber(1)
  void clearRefundPaymentId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get originalPaymentId => $_getSZ(1);
  @$pb.TagNumber(2)
  set originalPaymentId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasOriginalPaymentId() => $_has(1);
  @$pb.TagNumber(2)
  void clearOriginalPaymentId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get method => $_getSZ(2);
  @$pb.TagNumber(3)
  set method($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasMethod() => $_has(2);
  @$pb.TagNumber(3)
  void clearMethod() => $_clearField(3);

  @$pb.TagNumber(4)
  $0.Money get amount => $_getN(3);
  @$pb.TagNumber(4)
  set amount($0.Money value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasAmount() => $_has(3);
  @$pb.TagNumber(4)
  void clearAmount() => $_clearField(4);
  @$pb.TagNumber(4)
  $0.Money ensureAmount() => $_ensure(3);

  @$pb.TagNumber(5)
  $core.String get reference => $_getSZ(4);
  @$pb.TagNumber(5)
  set reference($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasReference() => $_has(4);
  @$pb.TagNumber(5)
  void clearReference() => $_clearField(5);
}

class RefundSaleResponse extends $pb.GeneratedMessage {
  factory RefundSaleResponse({
    $core.String? refundId,
    $core.String? batchId,
    $fixnum.Int64? lamport,
    Refund? refund,
    $core.bool? idempotent,
  }) {
    final result = create();
    if (refundId != null) result.refundId = refundId;
    if (batchId != null) result.batchId = batchId;
    if (lamport != null) result.lamport = lamport;
    if (refund != null) result.refund = refund;
    if (idempotent != null) result.idempotent = idempotent;
    return result;
  }

  RefundSaleResponse._();

  factory RefundSaleResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RefundSaleResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RefundSaleResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pos.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'refundId')
    ..aOS(2, _omitFieldNames ? '' : 'batchId')
    ..a<$fixnum.Int64>(3, _omitFieldNames ? '' : 'lamport', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOM<Refund>(4, _omitFieldNames ? '' : 'refund', subBuilder: Refund.create)
    ..aOB(5, _omitFieldNames ? '' : 'idempotent')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RefundSaleResponse clone() => RefundSaleResponse()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RefundSaleResponse copyWith(void Function(RefundSaleResponse) updates) =>
      super.copyWith((message) => updates(message as RefundSaleResponse))
          as RefundSaleResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RefundSaleResponse create() => RefundSaleResponse._();
  @$core.override
  RefundSaleResponse createEmptyInstance() => create();
  static $pb.PbList<RefundSaleResponse> createRepeated() =>
      $pb.PbList<RefundSaleResponse>();
  @$core.pragma('dart2js:noInline')
  static RefundSaleResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RefundSaleResponse>(create);
  static RefundSaleResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get refundId => $_getSZ(0);
  @$pb.TagNumber(1)
  set refundId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRefundId() => $_has(0);
  @$pb.TagNumber(1)
  void clearRefundId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get batchId => $_getSZ(1);
  @$pb.TagNumber(2)
  set batchId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasBatchId() => $_has(1);
  @$pb.TagNumber(2)
  void clearBatchId() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get lamport => $_getI64(2);
  @$pb.TagNumber(3)
  set lamport($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasLamport() => $_has(2);
  @$pb.TagNumber(3)
  void clearLamport() => $_clearField(3);

  @$pb.TagNumber(4)
  Refund get refund => $_getN(3);
  @$pb.TagNumber(4)
  set refund(Refund value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasRefund() => $_has(3);
  @$pb.TagNumber(4)
  void clearRefund() => $_clearField(4);
  @$pb.TagNumber(4)
  Refund ensureRefund() => $_ensure(3);

  @$pb.TagNumber(5)
  $core.bool get idempotent => $_getBF(4);
  @$pb.TagNumber(5)
  set idempotent($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasIdempotent() => $_has(4);
  @$pb.TagNumber(5)
  void clearIdempotent() => $_clearField(5);
}

class Refund extends $pb.GeneratedMessage {
  factory Refund({
    $core.String? refundId,
    $core.String? saleId,
    $core.String? invoiceId,
    $core.String? creditNoteNumber,
    $0.StoreId? storeId,
    $0.CounterId? counterId,
    $0.UserId? cashierId,
    $core.String? reason,
    $0.Money? subtotal,
    $0.Money? taxTotal,
    $0.Money? grandTotal,
    $core.List<$core.int>? snapshot,
    $1.Timestamp? refundedAt,
  }) {
    final result = create();
    if (refundId != null) result.refundId = refundId;
    if (saleId != null) result.saleId = saleId;
    if (invoiceId != null) result.invoiceId = invoiceId;
    if (creditNoteNumber != null) result.creditNoteNumber = creditNoteNumber;
    if (storeId != null) result.storeId = storeId;
    if (counterId != null) result.counterId = counterId;
    if (cashierId != null) result.cashierId = cashierId;
    if (reason != null) result.reason = reason;
    if (subtotal != null) result.subtotal = subtotal;
    if (taxTotal != null) result.taxTotal = taxTotal;
    if (grandTotal != null) result.grandTotal = grandTotal;
    if (snapshot != null) result.snapshot = snapshot;
    if (refundedAt != null) result.refundedAt = refundedAt;
    return result;
  }

  Refund._();

  factory Refund.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Refund.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Refund',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pos.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'refundId')
    ..aOS(2, _omitFieldNames ? '' : 'saleId')
    ..aOS(3, _omitFieldNames ? '' : 'invoiceId')
    ..aOS(4, _omitFieldNames ? '' : 'creditNoteNumber')
    ..aOM<$0.StoreId>(5, _omitFieldNames ? '' : 'storeId',
        subBuilder: $0.StoreId.create)
    ..aOM<$0.CounterId>(6, _omitFieldNames ? '' : 'counterId',
        subBuilder: $0.CounterId.create)
    ..aOM<$0.UserId>(7, _omitFieldNames ? '' : 'cashierId',
        subBuilder: $0.UserId.create)
    ..aOS(8, _omitFieldNames ? '' : 'reason')
    ..aOM<$0.Money>(9, _omitFieldNames ? '' : 'subtotal',
        subBuilder: $0.Money.create)
    ..aOM<$0.Money>(10, _omitFieldNames ? '' : 'taxTotal',
        subBuilder: $0.Money.create)
    ..aOM<$0.Money>(11, _omitFieldNames ? '' : 'grandTotal',
        subBuilder: $0.Money.create)
    ..a<$core.List<$core.int>>(
        12, _omitFieldNames ? '' : 'snapshot', $pb.PbFieldType.OY)
    ..aOM<$1.Timestamp>(13, _omitFieldNames ? '' : 'refundedAt',
        subBuilder: $1.Timestamp.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Refund clone() => Refund()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Refund copyWith(void Function(Refund) updates) =>
      super.copyWith((message) => updates(message as Refund)) as Refund;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Refund create() => Refund._();
  @$core.override
  Refund createEmptyInstance() => create();
  static $pb.PbList<Refund> createRepeated() => $pb.PbList<Refund>();
  @$core.pragma('dart2js:noInline')
  static Refund getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Refund>(create);
  static Refund? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get refundId => $_getSZ(0);
  @$pb.TagNumber(1)
  set refundId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRefundId() => $_has(0);
  @$pb.TagNumber(1)
  void clearRefundId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get saleId => $_getSZ(1);
  @$pb.TagNumber(2)
  set saleId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSaleId() => $_has(1);
  @$pb.TagNumber(2)
  void clearSaleId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get invoiceId => $_getSZ(2);
  @$pb.TagNumber(3)
  set invoiceId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasInvoiceId() => $_has(2);
  @$pb.TagNumber(3)
  void clearInvoiceId() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get creditNoteNumber => $_getSZ(3);
  @$pb.TagNumber(4)
  set creditNoteNumber($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasCreditNoteNumber() => $_has(3);
  @$pb.TagNumber(4)
  void clearCreditNoteNumber() => $_clearField(4);

  @$pb.TagNumber(5)
  $0.StoreId get storeId => $_getN(4);
  @$pb.TagNumber(5)
  set storeId($0.StoreId value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasStoreId() => $_has(4);
  @$pb.TagNumber(5)
  void clearStoreId() => $_clearField(5);
  @$pb.TagNumber(5)
  $0.StoreId ensureStoreId() => $_ensure(4);

  @$pb.TagNumber(6)
  $0.CounterId get counterId => $_getN(5);
  @$pb.TagNumber(6)
  set counterId($0.CounterId value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasCounterId() => $_has(5);
  @$pb.TagNumber(6)
  void clearCounterId() => $_clearField(6);
  @$pb.TagNumber(6)
  $0.CounterId ensureCounterId() => $_ensure(5);

  @$pb.TagNumber(7)
  $0.UserId get cashierId => $_getN(6);
  @$pb.TagNumber(7)
  set cashierId($0.UserId value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasCashierId() => $_has(6);
  @$pb.TagNumber(7)
  void clearCashierId() => $_clearField(7);
  @$pb.TagNumber(7)
  $0.UserId ensureCashierId() => $_ensure(6);

  @$pb.TagNumber(8)
  $core.String get reason => $_getSZ(7);
  @$pb.TagNumber(8)
  set reason($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasReason() => $_has(7);
  @$pb.TagNumber(8)
  void clearReason() => $_clearField(8);

  @$pb.TagNumber(9)
  $0.Money get subtotal => $_getN(8);
  @$pb.TagNumber(9)
  set subtotal($0.Money value) => $_setField(9, value);
  @$pb.TagNumber(9)
  $core.bool hasSubtotal() => $_has(8);
  @$pb.TagNumber(9)
  void clearSubtotal() => $_clearField(9);
  @$pb.TagNumber(9)
  $0.Money ensureSubtotal() => $_ensure(8);

  @$pb.TagNumber(10)
  $0.Money get taxTotal => $_getN(9);
  @$pb.TagNumber(10)
  set taxTotal($0.Money value) => $_setField(10, value);
  @$pb.TagNumber(10)
  $core.bool hasTaxTotal() => $_has(9);
  @$pb.TagNumber(10)
  void clearTaxTotal() => $_clearField(10);
  @$pb.TagNumber(10)
  $0.Money ensureTaxTotal() => $_ensure(9);

  @$pb.TagNumber(11)
  $0.Money get grandTotal => $_getN(10);
  @$pb.TagNumber(11)
  set grandTotal($0.Money value) => $_setField(11, value);
  @$pb.TagNumber(11)
  $core.bool hasGrandTotal() => $_has(10);
  @$pb.TagNumber(11)
  void clearGrandTotal() => $_clearField(11);
  @$pb.TagNumber(11)
  $0.Money ensureGrandTotal() => $_ensure(10);

  @$pb.TagNumber(12)
  $core.List<$core.int> get snapshot => $_getN(11);
  @$pb.TagNumber(12)
  set snapshot($core.List<$core.int> value) => $_setBytes(11, value);
  @$pb.TagNumber(12)
  $core.bool hasSnapshot() => $_has(11);
  @$pb.TagNumber(12)
  void clearSnapshot() => $_clearField(12);

  @$pb.TagNumber(13)
  $1.Timestamp get refundedAt => $_getN(12);
  @$pb.TagNumber(13)
  set refundedAt($1.Timestamp value) => $_setField(13, value);
  @$pb.TagNumber(13)
  $core.bool hasRefundedAt() => $_has(12);
  @$pb.TagNumber(13)
  void clearRefundedAt() => $_clearField(13);
  @$pb.TagNumber(13)
  $1.Timestamp ensureRefundedAt() => $_ensure(12);
}

/// RefundService exposes void + refund flows. See refunds/service.go for
/// the canonical contract — this proto is a thin adapter on top.
///
/// Idempotency: identical void_id / refund_id replay returns the prior
/// response with idempotent=true.
class RefundServiceApi {
  final $pb.RpcClient _client;

  RefundServiceApi(this._client);

  $async.Future<VoidSaleResponse> voidSale(
          $pb.ClientContext? ctx, VoidSaleRequest request) =>
      _client.invoke<VoidSaleResponse>(
          ctx, 'RefundService', 'VoidSale', request, VoidSaleResponse());
  $async.Future<RefundSaleResponse> refundSale(
          $pb.ClientContext? ctx, RefundSaleRequest request) =>
      _client.invoke<RefundSaleResponse>(
          ctx, 'RefundService', 'RefundSale', request, RefundSaleResponse());
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
