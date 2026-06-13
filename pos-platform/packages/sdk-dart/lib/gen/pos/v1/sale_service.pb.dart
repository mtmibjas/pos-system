// This is a generated file - do not edit.
//
// Generated from pos/v1/sale_service.proto.

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

/// FinalizeRequest mirrors sales.FinalizeRequest. tenant_id is
/// pinned from server config and ignored if set on the wire — the API
/// is single-tenant per instance.
class FinalizeRequest extends $pb.GeneratedMessage {
  factory FinalizeRequest({
    $core.String? saleId,
    $0.StoreId? storeId,
    $0.CounterId? counterId,
    $0.UserId? cashierId,
    $core.Iterable<FinalizeSaleLine>? lines,
    $core.Iterable<FinalizeSaleTender>? tenders,
    $0.Money? subtotal,
    $0.Money? taxTotal,
    $0.Money? grandTotal,
    $1.Timestamp? occurredAt,
    $core.Iterable<$core.String>? reservationIds,
  }) {
    final result = create();
    if (saleId != null) result.saleId = saleId;
    if (storeId != null) result.storeId = storeId;
    if (counterId != null) result.counterId = counterId;
    if (cashierId != null) result.cashierId = cashierId;
    if (lines != null) result.lines.addAll(lines);
    if (tenders != null) result.tenders.addAll(tenders);
    if (subtotal != null) result.subtotal = subtotal;
    if (taxTotal != null) result.taxTotal = taxTotal;
    if (grandTotal != null) result.grandTotal = grandTotal;
    if (occurredAt != null) result.occurredAt = occurredAt;
    if (reservationIds != null) result.reservationIds.addAll(reservationIds);
    return result;
  }

  FinalizeRequest._();

  factory FinalizeRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory FinalizeRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FinalizeRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pos.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'saleId')
    ..aOM<$0.StoreId>(2, _omitFieldNames ? '' : 'storeId',
        subBuilder: $0.StoreId.create)
    ..aOM<$0.CounterId>(3, _omitFieldNames ? '' : 'counterId',
        subBuilder: $0.CounterId.create)
    ..aOM<$0.UserId>(4, _omitFieldNames ? '' : 'cashierId',
        subBuilder: $0.UserId.create)
    ..pc<FinalizeSaleLine>(
        5, _omitFieldNames ? '' : 'lines', $pb.PbFieldType.PM,
        subBuilder: FinalizeSaleLine.create)
    ..pc<FinalizeSaleTender>(
        6, _omitFieldNames ? '' : 'tenders', $pb.PbFieldType.PM,
        subBuilder: FinalizeSaleTender.create)
    ..aOM<$0.Money>(7, _omitFieldNames ? '' : 'subtotal',
        subBuilder: $0.Money.create)
    ..aOM<$0.Money>(8, _omitFieldNames ? '' : 'taxTotal',
        subBuilder: $0.Money.create)
    ..aOM<$0.Money>(9, _omitFieldNames ? '' : 'grandTotal',
        subBuilder: $0.Money.create)
    ..aOM<$1.Timestamp>(10, _omitFieldNames ? '' : 'occurredAt',
        subBuilder: $1.Timestamp.create)
    ..pPS(11, _omitFieldNames ? '' : 'reservationIds')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FinalizeRequest clone() => FinalizeRequest()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FinalizeRequest copyWith(void Function(FinalizeRequest) updates) =>
      super.copyWith((message) => updates(message as FinalizeRequest))
          as FinalizeRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static FinalizeRequest create() => FinalizeRequest._();
  @$core.override
  FinalizeRequest createEmptyInstance() => create();
  static $pb.PbList<FinalizeRequest> createRepeated() =>
      $pb.PbList<FinalizeRequest>();
  @$core.pragma('dart2js:noInline')
  static FinalizeRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<FinalizeRequest>(create);
  static FinalizeRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get saleId => $_getSZ(0);
  @$pb.TagNumber(1)
  set saleId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSaleId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSaleId() => $_clearField(1);

  @$pb.TagNumber(2)
  $0.StoreId get storeId => $_getN(1);
  @$pb.TagNumber(2)
  set storeId($0.StoreId value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasStoreId() => $_has(1);
  @$pb.TagNumber(2)
  void clearStoreId() => $_clearField(2);
  @$pb.TagNumber(2)
  $0.StoreId ensureStoreId() => $_ensure(1);

  @$pb.TagNumber(3)
  $0.CounterId get counterId => $_getN(2);
  @$pb.TagNumber(3)
  set counterId($0.CounterId value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasCounterId() => $_has(2);
  @$pb.TagNumber(3)
  void clearCounterId() => $_clearField(3);
  @$pb.TagNumber(3)
  $0.CounterId ensureCounterId() => $_ensure(2);

  @$pb.TagNumber(4)
  $0.UserId get cashierId => $_getN(3);
  @$pb.TagNumber(4)
  set cashierId($0.UserId value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasCashierId() => $_has(3);
  @$pb.TagNumber(4)
  void clearCashierId() => $_clearField(4);
  @$pb.TagNumber(4)
  $0.UserId ensureCashierId() => $_ensure(3);

  @$pb.TagNumber(5)
  $pb.PbList<FinalizeSaleLine> get lines => $_getList(4);

  @$pb.TagNumber(6)
  $pb.PbList<FinalizeSaleTender> get tenders => $_getList(5);

  @$pb.TagNumber(7)
  $0.Money get subtotal => $_getN(6);
  @$pb.TagNumber(7)
  set subtotal($0.Money value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasSubtotal() => $_has(6);
  @$pb.TagNumber(7)
  void clearSubtotal() => $_clearField(7);
  @$pb.TagNumber(7)
  $0.Money ensureSubtotal() => $_ensure(6);

  @$pb.TagNumber(8)
  $0.Money get taxTotal => $_getN(7);
  @$pb.TagNumber(8)
  set taxTotal($0.Money value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasTaxTotal() => $_has(7);
  @$pb.TagNumber(8)
  void clearTaxTotal() => $_clearField(8);
  @$pb.TagNumber(8)
  $0.Money ensureTaxTotal() => $_ensure(7);

  @$pb.TagNumber(9)
  $0.Money get grandTotal => $_getN(8);
  @$pb.TagNumber(9)
  set grandTotal($0.Money value) => $_setField(9, value);
  @$pb.TagNumber(9)
  $core.bool hasGrandTotal() => $_has(8);
  @$pb.TagNumber(9)
  void clearGrandTotal() => $_clearField(9);
  @$pb.TagNumber(9)
  $0.Money ensureGrandTotal() => $_ensure(8);

  @$pb.TagNumber(10)
  $1.Timestamp get occurredAt => $_getN(9);
  @$pb.TagNumber(10)
  set occurredAt($1.Timestamp value) => $_setField(10, value);
  @$pb.TagNumber(10)
  $core.bool hasOccurredAt() => $_has(9);
  @$pb.TagNumber(10)
  void clearOccurredAt() => $_clearField(10);
  @$pb.TagNumber(10)
  $1.Timestamp ensureOccurredAt() => $_ensure(9);

  /// Slice 4.3: reservation_ids the cart is consuming. Server finalizes
  /// them in the same transaction as the sale so the held quantity drops
  /// from inventory.Available instantly (no 5-min false-depletion window).
  /// Unknown / non-active ids cause the Finalize to fail FailedPrecondition
  /// BEFORE any movements are written — the cart is stale and needs reload.
  @$pb.TagNumber(11)
  $pb.PbList<$core.String> get reservationIds => $_getList(10);
}

class FinalizeSaleLine extends $pb.GeneratedMessage {
  factory FinalizeSaleLine({
    $core.String? lineId,
    $core.String? sku,
    $core.String? description,
    $fixnum.Int64? quantity,
    $0.Money? unitPrice,
    $0.Money? lineTotal,
    $core.String? taxCategoryId,
  }) {
    final result = create();
    if (lineId != null) result.lineId = lineId;
    if (sku != null) result.sku = sku;
    if (description != null) result.description = description;
    if (quantity != null) result.quantity = quantity;
    if (unitPrice != null) result.unitPrice = unitPrice;
    if (lineTotal != null) result.lineTotal = lineTotal;
    if (taxCategoryId != null) result.taxCategoryId = taxCategoryId;
    return result;
  }

  FinalizeSaleLine._();

  factory FinalizeSaleLine.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory FinalizeSaleLine.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FinalizeSaleLine',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pos.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'lineId')
    ..aOS(2, _omitFieldNames ? '' : 'sku')
    ..aOS(3, _omitFieldNames ? '' : 'description')
    ..aInt64(4, _omitFieldNames ? '' : 'quantity')
    ..aOM<$0.Money>(5, _omitFieldNames ? '' : 'unitPrice',
        subBuilder: $0.Money.create)
    ..aOM<$0.Money>(6, _omitFieldNames ? '' : 'lineTotal',
        subBuilder: $0.Money.create)
    ..aOS(7, _omitFieldNames ? '' : 'taxCategoryId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FinalizeSaleLine clone() => FinalizeSaleLine()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FinalizeSaleLine copyWith(void Function(FinalizeSaleLine) updates) =>
      super.copyWith((message) => updates(message as FinalizeSaleLine))
          as FinalizeSaleLine;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static FinalizeSaleLine create() => FinalizeSaleLine._();
  @$core.override
  FinalizeSaleLine createEmptyInstance() => create();
  static $pb.PbList<FinalizeSaleLine> createRepeated() =>
      $pb.PbList<FinalizeSaleLine>();
  @$core.pragma('dart2js:noInline')
  static FinalizeSaleLine getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<FinalizeSaleLine>(create);
  static FinalizeSaleLine? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get lineId => $_getSZ(0);
  @$pb.TagNumber(1)
  set lineId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasLineId() => $_has(0);
  @$pb.TagNumber(1)
  void clearLineId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get sku => $_getSZ(1);
  @$pb.TagNumber(2)
  set sku($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSku() => $_has(1);
  @$pb.TagNumber(2)
  void clearSku() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get description => $_getSZ(2);
  @$pb.TagNumber(3)
  set description($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasDescription() => $_has(2);
  @$pb.TagNumber(3)
  void clearDescription() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get quantity => $_getI64(3);
  @$pb.TagNumber(4)
  set quantity($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasQuantity() => $_has(3);
  @$pb.TagNumber(4)
  void clearQuantity() => $_clearField(4);

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

class FinalizeSaleTender extends $pb.GeneratedMessage {
  factory FinalizeSaleTender({
    $core.String? paymentId,
    $core.String? method,
    $0.Money? amount,
    $core.String? reference,
  }) {
    final result = create();
    if (paymentId != null) result.paymentId = paymentId;
    if (method != null) result.method = method;
    if (amount != null) result.amount = amount;
    if (reference != null) result.reference = reference;
    return result;
  }

  FinalizeSaleTender._();

  factory FinalizeSaleTender.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory FinalizeSaleTender.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FinalizeSaleTender',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pos.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'paymentId')
    ..aOS(2, _omitFieldNames ? '' : 'method')
    ..aOM<$0.Money>(3, _omitFieldNames ? '' : 'amount',
        subBuilder: $0.Money.create)
    ..aOS(4, _omitFieldNames ? '' : 'reference')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FinalizeSaleTender clone() => FinalizeSaleTender()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FinalizeSaleTender copyWith(void Function(FinalizeSaleTender) updates) =>
      super.copyWith((message) => updates(message as FinalizeSaleTender))
          as FinalizeSaleTender;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static FinalizeSaleTender create() => FinalizeSaleTender._();
  @$core.override
  FinalizeSaleTender createEmptyInstance() => create();
  static $pb.PbList<FinalizeSaleTender> createRepeated() =>
      $pb.PbList<FinalizeSaleTender>();
  @$core.pragma('dart2js:noInline')
  static FinalizeSaleTender getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<FinalizeSaleTender>(create);
  static FinalizeSaleTender? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get paymentId => $_getSZ(0);
  @$pb.TagNumber(1)
  set paymentId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPaymentId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPaymentId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get method => $_getSZ(1);
  @$pb.TagNumber(2)
  set method($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMethod() => $_has(1);
  @$pb.TagNumber(2)
  void clearMethod() => $_clearField(2);

  @$pb.TagNumber(3)
  $0.Money get amount => $_getN(2);
  @$pb.TagNumber(3)
  set amount($0.Money value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasAmount() => $_has(2);
  @$pb.TagNumber(3)
  void clearAmount() => $_clearField(3);
  @$pb.TagNumber(3)
  $0.Money ensureAmount() => $_ensure(2);

  @$pb.TagNumber(4)
  $core.String get reference => $_getSZ(3);
  @$pb.TagNumber(4)
  set reference($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasReference() => $_has(3);
  @$pb.TagNumber(4)
  void clearReference() => $_clearField(4);
}

class FinalizeResponse extends $pb.GeneratedMessage {
  factory FinalizeResponse({
    $core.String? saleId,
    $core.String? batchId,
    $fixnum.Int64? lamport,
    Invoice? invoice,
    $core.bool? idempotent,
  }) {
    final result = create();
    if (saleId != null) result.saleId = saleId;
    if (batchId != null) result.batchId = batchId;
    if (lamport != null) result.lamport = lamport;
    if (invoice != null) result.invoice = invoice;
    if (idempotent != null) result.idempotent = idempotent;
    return result;
  }

  FinalizeResponse._();

  factory FinalizeResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory FinalizeResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FinalizeResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pos.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'saleId')
    ..aOS(2, _omitFieldNames ? '' : 'batchId')
    ..a<$fixnum.Int64>(3, _omitFieldNames ? '' : 'lamport', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOM<Invoice>(4, _omitFieldNames ? '' : 'invoice',
        subBuilder: Invoice.create)
    ..aOB(5, _omitFieldNames ? '' : 'idempotent')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FinalizeResponse clone() => FinalizeResponse()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FinalizeResponse copyWith(void Function(FinalizeResponse) updates) =>
      super.copyWith((message) => updates(message as FinalizeResponse))
          as FinalizeResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static FinalizeResponse create() => FinalizeResponse._();
  @$core.override
  FinalizeResponse createEmptyInstance() => create();
  static $pb.PbList<FinalizeResponse> createRepeated() =>
      $pb.PbList<FinalizeResponse>();
  @$core.pragma('dart2js:noInline')
  static FinalizeResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<FinalizeResponse>(create);
  static FinalizeResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get saleId => $_getSZ(0);
  @$pb.TagNumber(1)
  set saleId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSaleId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSaleId() => $_clearField(1);

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
  Invoice get invoice => $_getN(3);
  @$pb.TagNumber(4)
  set invoice(Invoice value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasInvoice() => $_has(3);
  @$pb.TagNumber(4)
  void clearInvoice() => $_clearField(4);
  @$pb.TagNumber(4)
  Invoice ensureInvoice() => $_ensure(3);

  @$pb.TagNumber(5)
  $core.bool get idempotent => $_getBF(4);
  @$pb.TagNumber(5)
  set idempotent($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasIdempotent() => $_has(4);
  @$pb.TagNumber(5)
  void clearIdempotent() => $_clearField(5);
}

enum GetSaleRequest_Key { saleId, invoiceNumber, notSet }

/// GetSaleRequest selects a sale by exactly one of the two keys. Empty
/// key is InvalidArgument.
class GetSaleRequest extends $pb.GeneratedMessage {
  factory GetSaleRequest({
    $core.String? saleId,
    $core.String? invoiceNumber,
  }) {
    final result = create();
    if (saleId != null) result.saleId = saleId;
    if (invoiceNumber != null) result.invoiceNumber = invoiceNumber;
    return result;
  }

  GetSaleRequest._();

  factory GetSaleRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetSaleRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, GetSaleRequest_Key>
      _GetSaleRequest_KeyByTag = {
    1: GetSaleRequest_Key.saleId,
    2: GetSaleRequest_Key.invoiceNumber,
    0: GetSaleRequest_Key.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetSaleRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pos.v1'),
      createEmptyInstance: create)
    ..oo(0, [1, 2])
    ..aOS(1, _omitFieldNames ? '' : 'saleId')
    ..aOS(2, _omitFieldNames ? '' : 'invoiceNumber')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetSaleRequest clone() => GetSaleRequest()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetSaleRequest copyWith(void Function(GetSaleRequest) updates) =>
      super.copyWith((message) => updates(message as GetSaleRequest))
          as GetSaleRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetSaleRequest create() => GetSaleRequest._();
  @$core.override
  GetSaleRequest createEmptyInstance() => create();
  static $pb.PbList<GetSaleRequest> createRepeated() =>
      $pb.PbList<GetSaleRequest>();
  @$core.pragma('dart2js:noInline')
  static GetSaleRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetSaleRequest>(create);
  static GetSaleRequest? _defaultInstance;

  GetSaleRequest_Key whichKey() => _GetSaleRequest_KeyByTag[$_whichOneof(0)]!;
  void clearKey() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  $core.String get saleId => $_getSZ(0);
  @$pb.TagNumber(1)
  set saleId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSaleId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSaleId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get invoiceNumber => $_getSZ(1);
  @$pb.TagNumber(2)
  set invoiceNumber($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasInvoiceNumber() => $_has(1);
  @$pb.TagNumber(2)
  void clearInvoiceNumber() => $_clearField(2);
}

/// GetSaleResponse mirrors Invoice plus the per-line and per-tender
/// detail. Lines are sourced from the canonical SaleCreated snapshot;
/// payments come from the local payments projection.
class GetSaleResponse extends $pb.GeneratedMessage {
  factory GetSaleResponse({
    Invoice? invoice,
    $core.Iterable<GetSaleLine>? lines,
    $core.Iterable<GetSalePayment>? payments,
  }) {
    final result = create();
    if (invoice != null) result.invoice = invoice;
    if (lines != null) result.lines.addAll(lines);
    if (payments != null) result.payments.addAll(payments);
    return result;
  }

  GetSaleResponse._();

  factory GetSaleResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetSaleResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetSaleResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pos.v1'),
      createEmptyInstance: create)
    ..aOM<Invoice>(1, _omitFieldNames ? '' : 'invoice',
        subBuilder: Invoice.create)
    ..pc<GetSaleLine>(2, _omitFieldNames ? '' : 'lines', $pb.PbFieldType.PM,
        subBuilder: GetSaleLine.create)
    ..pc<GetSalePayment>(
        3, _omitFieldNames ? '' : 'payments', $pb.PbFieldType.PM,
        subBuilder: GetSalePayment.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetSaleResponse clone() => GetSaleResponse()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetSaleResponse copyWith(void Function(GetSaleResponse) updates) =>
      super.copyWith((message) => updates(message as GetSaleResponse))
          as GetSaleResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetSaleResponse create() => GetSaleResponse._();
  @$core.override
  GetSaleResponse createEmptyInstance() => create();
  static $pb.PbList<GetSaleResponse> createRepeated() =>
      $pb.PbList<GetSaleResponse>();
  @$core.pragma('dart2js:noInline')
  static GetSaleResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetSaleResponse>(create);
  static GetSaleResponse? _defaultInstance;

  @$pb.TagNumber(1)
  Invoice get invoice => $_getN(0);
  @$pb.TagNumber(1)
  set invoice(Invoice value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasInvoice() => $_has(0);
  @$pb.TagNumber(1)
  void clearInvoice() => $_clearField(1);
  @$pb.TagNumber(1)
  Invoice ensureInvoice() => $_ensure(0);

  @$pb.TagNumber(2)
  $pb.PbList<GetSaleLine> get lines => $_getList(1);

  @$pb.TagNumber(3)
  $pb.PbList<GetSalePayment> get payments => $_getList(2);
}

class GetSaleLine extends $pb.GeneratedMessage {
  factory GetSaleLine({
    $core.String? lineId,
    $core.String? sku,
    $core.String? description,
    $fixnum.Int64? quantity,
    $0.Money? unitPrice,
    $0.Money? lineTotal,
  }) {
    final result = create();
    if (lineId != null) result.lineId = lineId;
    if (sku != null) result.sku = sku;
    if (description != null) result.description = description;
    if (quantity != null) result.quantity = quantity;
    if (unitPrice != null) result.unitPrice = unitPrice;
    if (lineTotal != null) result.lineTotal = lineTotal;
    return result;
  }

  GetSaleLine._();

  factory GetSaleLine.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetSaleLine.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetSaleLine',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pos.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'lineId')
    ..aOS(2, _omitFieldNames ? '' : 'sku')
    ..aOS(3, _omitFieldNames ? '' : 'description')
    ..aInt64(4, _omitFieldNames ? '' : 'quantity')
    ..aOM<$0.Money>(5, _omitFieldNames ? '' : 'unitPrice',
        subBuilder: $0.Money.create)
    ..aOM<$0.Money>(6, _omitFieldNames ? '' : 'lineTotal',
        subBuilder: $0.Money.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetSaleLine clone() => GetSaleLine()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetSaleLine copyWith(void Function(GetSaleLine) updates) =>
      super.copyWith((message) => updates(message as GetSaleLine))
          as GetSaleLine;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetSaleLine create() => GetSaleLine._();
  @$core.override
  GetSaleLine createEmptyInstance() => create();
  static $pb.PbList<GetSaleLine> createRepeated() => $pb.PbList<GetSaleLine>();
  @$core.pragma('dart2js:noInline')
  static GetSaleLine getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetSaleLine>(create);
  static GetSaleLine? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get lineId => $_getSZ(0);
  @$pb.TagNumber(1)
  set lineId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasLineId() => $_has(0);
  @$pb.TagNumber(1)
  void clearLineId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get sku => $_getSZ(1);
  @$pb.TagNumber(2)
  set sku($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSku() => $_has(1);
  @$pb.TagNumber(2)
  void clearSku() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get description => $_getSZ(2);
  @$pb.TagNumber(3)
  set description($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasDescription() => $_has(2);
  @$pb.TagNumber(3)
  void clearDescription() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get quantity => $_getI64(3);
  @$pb.TagNumber(4)
  set quantity($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasQuantity() => $_has(3);
  @$pb.TagNumber(4)
  void clearQuantity() => $_clearField(4);

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
}

class GetSalePayment extends $pb.GeneratedMessage {
  factory GetSalePayment({
    $core.String? paymentId,
    $core.String? method,
    $0.Money? amount,
    $core.String? reference,
  }) {
    final result = create();
    if (paymentId != null) result.paymentId = paymentId;
    if (method != null) result.method = method;
    if (amount != null) result.amount = amount;
    if (reference != null) result.reference = reference;
    return result;
  }

  GetSalePayment._();

  factory GetSalePayment.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetSalePayment.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetSalePayment',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pos.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'paymentId')
    ..aOS(2, _omitFieldNames ? '' : 'method')
    ..aOM<$0.Money>(3, _omitFieldNames ? '' : 'amount',
        subBuilder: $0.Money.create)
    ..aOS(4, _omitFieldNames ? '' : 'reference')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetSalePayment clone() => GetSalePayment()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetSalePayment copyWith(void Function(GetSalePayment) updates) =>
      super.copyWith((message) => updates(message as GetSalePayment))
          as GetSalePayment;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetSalePayment create() => GetSalePayment._();
  @$core.override
  GetSalePayment createEmptyInstance() => create();
  static $pb.PbList<GetSalePayment> createRepeated() =>
      $pb.PbList<GetSalePayment>();
  @$core.pragma('dart2js:noInline')
  static GetSalePayment getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetSalePayment>(create);
  static GetSalePayment? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get paymentId => $_getSZ(0);
  @$pb.TagNumber(1)
  set paymentId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPaymentId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPaymentId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get method => $_getSZ(1);
  @$pb.TagNumber(2)
  set method($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMethod() => $_has(1);
  @$pb.TagNumber(2)
  void clearMethod() => $_clearField(2);

  @$pb.TagNumber(3)
  $0.Money get amount => $_getN(2);
  @$pb.TagNumber(3)
  set amount($0.Money value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasAmount() => $_has(2);
  @$pb.TagNumber(3)
  void clearAmount() => $_clearField(3);
  @$pb.TagNumber(3)
  $0.Money ensureAmount() => $_ensure(2);

  @$pb.TagNumber(4)
  $core.String get reference => $_getSZ(3);
  @$pb.TagNumber(4)
  set reference($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasReference() => $_has(3);
  @$pb.TagNumber(4)
  void clearReference() => $_clearField(4);
}

/// Invoice is the local read projection of a finalized sale. Snapshot is
/// the canonical serialized SaleCreated bytes for clients that want the
/// full per-line detail.
class Invoice extends $pb.GeneratedMessage {
  factory Invoice({
    $core.String? invoiceId,
    $core.String? saleId,
    $core.String? invoiceNumber,
    $0.StoreId? storeId,
    $0.CounterId? counterId,
    $0.UserId? cashierId,
    $0.Money? subtotal,
    $0.Money? taxTotal,
    $0.Money? grandTotal,
    $core.List<$core.int>? snapshot,
    $1.Timestamp? finalizedAt,
  }) {
    final result = create();
    if (invoiceId != null) result.invoiceId = invoiceId;
    if (saleId != null) result.saleId = saleId;
    if (invoiceNumber != null) result.invoiceNumber = invoiceNumber;
    if (storeId != null) result.storeId = storeId;
    if (counterId != null) result.counterId = counterId;
    if (cashierId != null) result.cashierId = cashierId;
    if (subtotal != null) result.subtotal = subtotal;
    if (taxTotal != null) result.taxTotal = taxTotal;
    if (grandTotal != null) result.grandTotal = grandTotal;
    if (snapshot != null) result.snapshot = snapshot;
    if (finalizedAt != null) result.finalizedAt = finalizedAt;
    return result;
  }

  Invoice._();

  factory Invoice.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Invoice.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Invoice',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pos.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'invoiceId')
    ..aOS(2, _omitFieldNames ? '' : 'saleId')
    ..aOS(3, _omitFieldNames ? '' : 'invoiceNumber')
    ..aOM<$0.StoreId>(4, _omitFieldNames ? '' : 'storeId',
        subBuilder: $0.StoreId.create)
    ..aOM<$0.CounterId>(5, _omitFieldNames ? '' : 'counterId',
        subBuilder: $0.CounterId.create)
    ..aOM<$0.UserId>(6, _omitFieldNames ? '' : 'cashierId',
        subBuilder: $0.UserId.create)
    ..aOM<$0.Money>(7, _omitFieldNames ? '' : 'subtotal',
        subBuilder: $0.Money.create)
    ..aOM<$0.Money>(8, _omitFieldNames ? '' : 'taxTotal',
        subBuilder: $0.Money.create)
    ..aOM<$0.Money>(9, _omitFieldNames ? '' : 'grandTotal',
        subBuilder: $0.Money.create)
    ..a<$core.List<$core.int>>(
        10, _omitFieldNames ? '' : 'snapshot', $pb.PbFieldType.OY)
    ..aOM<$1.Timestamp>(11, _omitFieldNames ? '' : 'finalizedAt',
        subBuilder: $1.Timestamp.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Invoice clone() => Invoice()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Invoice copyWith(void Function(Invoice) updates) =>
      super.copyWith((message) => updates(message as Invoice)) as Invoice;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Invoice create() => Invoice._();
  @$core.override
  Invoice createEmptyInstance() => create();
  static $pb.PbList<Invoice> createRepeated() => $pb.PbList<Invoice>();
  @$core.pragma('dart2js:noInline')
  static Invoice getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Invoice>(create);
  static Invoice? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get invoiceId => $_getSZ(0);
  @$pb.TagNumber(1)
  set invoiceId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasInvoiceId() => $_has(0);
  @$pb.TagNumber(1)
  void clearInvoiceId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get saleId => $_getSZ(1);
  @$pb.TagNumber(2)
  set saleId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSaleId() => $_has(1);
  @$pb.TagNumber(2)
  void clearSaleId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get invoiceNumber => $_getSZ(2);
  @$pb.TagNumber(3)
  set invoiceNumber($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasInvoiceNumber() => $_has(2);
  @$pb.TagNumber(3)
  void clearInvoiceNumber() => $_clearField(3);

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
  $0.Money get subtotal => $_getN(6);
  @$pb.TagNumber(7)
  set subtotal($0.Money value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasSubtotal() => $_has(6);
  @$pb.TagNumber(7)
  void clearSubtotal() => $_clearField(7);
  @$pb.TagNumber(7)
  $0.Money ensureSubtotal() => $_ensure(6);

  @$pb.TagNumber(8)
  $0.Money get taxTotal => $_getN(7);
  @$pb.TagNumber(8)
  set taxTotal($0.Money value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasTaxTotal() => $_has(7);
  @$pb.TagNumber(8)
  void clearTaxTotal() => $_clearField(8);
  @$pb.TagNumber(8)
  $0.Money ensureTaxTotal() => $_ensure(7);

  @$pb.TagNumber(9)
  $0.Money get grandTotal => $_getN(8);
  @$pb.TagNumber(9)
  set grandTotal($0.Money value) => $_setField(9, value);
  @$pb.TagNumber(9)
  $core.bool hasGrandTotal() => $_has(8);
  @$pb.TagNumber(9)
  void clearGrandTotal() => $_clearField(9);
  @$pb.TagNumber(9)
  $0.Money ensureGrandTotal() => $_ensure(8);

  @$pb.TagNumber(10)
  $core.List<$core.int> get snapshot => $_getN(9);
  @$pb.TagNumber(10)
  set snapshot($core.List<$core.int> value) => $_setBytes(9, value);
  @$pb.TagNumber(10)
  $core.bool hasSnapshot() => $_has(9);
  @$pb.TagNumber(10)
  void clearSnapshot() => $_clearField(10);

  @$pb.TagNumber(11)
  $1.Timestamp get finalizedAt => $_getN(10);
  @$pb.TagNumber(11)
  set finalizedAt($1.Timestamp value) => $_setField(11, value);
  @$pb.TagNumber(11)
  $core.bool hasFinalizedAt() => $_has(10);
  @$pb.TagNumber(11)
  void clearFinalizedAt() => $_clearField(11);
  @$pb.TagNumber(11)
  $1.Timestamp ensureFinalizedAt() => $_ensure(10);
}

/// SaleService is the customer-facing transactional surface of the
/// local-store-server. The desktop client calls Finalize when the operator
/// hits "Pay" on a fully-tendered cart. Server is authoritative on tax;
/// caller-supplied totals (if non-zero) must match the engine's output.
///
/// Idempotency: identical sale_id replay returns the prior FinalizeResponse
/// with idempotent=true rather than creating a duplicate sale.
class SaleServiceApi {
  final $pb.RpcClient _client;

  SaleServiceApi(this._client);

  $async.Future<FinalizeResponse> finalize(
          $pb.ClientContext? ctx, FinalizeRequest request) =>
      _client.invoke<FinalizeResponse>(
          ctx, 'SaleService', 'Finalize', request, FinalizeResponse());

  /// GetSale is the read-side lookup for a finalized sale. Returns
  /// NotFound if neither key resolves. The caller picks the key — UI
  /// typically uses invoice_number (operator-facing); reversal flows
  /// already hold sale_id and use that.
  $async.Future<GetSaleResponse> getSale(
          $pb.ClientContext? ctx, GetSaleRequest request) =>
      _client.invoke<GetSaleResponse>(
          ctx, 'SaleService', 'GetSale', request, GetSaleResponse());
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
