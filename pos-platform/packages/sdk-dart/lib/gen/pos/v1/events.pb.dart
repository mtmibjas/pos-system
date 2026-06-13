// This is a generated file - do not edit.
//
// Generated from pos/v1/events.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import '../../google/protobuf/timestamp.pb.dart' as $1;
import 'common.pb.dart' as $0;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

enum EventEnvelope_Payload {
  saleCreated,
  paymentAdded,
  paymentRefunded,
  inventoryAdjusted,
  stockTransferred,
  syncCompleted,
  syncFailed,
  userLoggedIn,
  saleVoided,
  saleRefunded,
  notSet
}

/// EventEnvelope — every domain event flows through this envelope.
/// The actual payload is one of the typed Event* messages declared below,
/// carried in the `payload` oneof. See docs/event-contracts.md.
///
/// Decision: oneof (not google.protobuf.Any) so the cloud + clients get
/// compile-time type safety, exhaustiveness checks on switches, and no
/// reflection at the hot path. New event types require a proto change +
/// regenerate (intentional friction — events are a contract).
class EventEnvelope extends $pb.GeneratedMessage {
  factory EventEnvelope({
    $0.OperationId? operationId,
    $core.String? eventType,
    $core.int? schemaVersion,
    $0.TenantId? tenantId,
    $0.OriginNode? origin,
    $0.LamportClock? clock,
    $1.Timestamp? occurredAt,
    SaleCreated? saleCreated,
    PaymentAdded? paymentAdded,
    PaymentRefunded? paymentRefunded,
    InventoryAdjusted? inventoryAdjusted,
    StockTransferred? stockTransferred,
    SyncCompleted? syncCompleted,
    SyncFailed? syncFailed,
    UserLoggedIn? userLoggedIn,
    SaleVoided? saleVoided,
    SaleRefunded? saleRefunded,
  }) {
    final result = create();
    if (operationId != null) result.operationId = operationId;
    if (eventType != null) result.eventType = eventType;
    if (schemaVersion != null) result.schemaVersion = schemaVersion;
    if (tenantId != null) result.tenantId = tenantId;
    if (origin != null) result.origin = origin;
    if (clock != null) result.clock = clock;
    if (occurredAt != null) result.occurredAt = occurredAt;
    if (saleCreated != null) result.saleCreated = saleCreated;
    if (paymentAdded != null) result.paymentAdded = paymentAdded;
    if (paymentRefunded != null) result.paymentRefunded = paymentRefunded;
    if (inventoryAdjusted != null) result.inventoryAdjusted = inventoryAdjusted;
    if (stockTransferred != null) result.stockTransferred = stockTransferred;
    if (syncCompleted != null) result.syncCompleted = syncCompleted;
    if (syncFailed != null) result.syncFailed = syncFailed;
    if (userLoggedIn != null) result.userLoggedIn = userLoggedIn;
    if (saleVoided != null) result.saleVoided = saleVoided;
    if (saleRefunded != null) result.saleRefunded = saleRefunded;
    return result;
  }

  EventEnvelope._();

  factory EventEnvelope.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory EventEnvelope.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, EventEnvelope_Payload>
      _EventEnvelope_PayloadByTag = {
    10: EventEnvelope_Payload.saleCreated,
    11: EventEnvelope_Payload.paymentAdded,
    12: EventEnvelope_Payload.paymentRefunded,
    13: EventEnvelope_Payload.inventoryAdjusted,
    14: EventEnvelope_Payload.stockTransferred,
    15: EventEnvelope_Payload.syncCompleted,
    16: EventEnvelope_Payload.syncFailed,
    17: EventEnvelope_Payload.userLoggedIn,
    18: EventEnvelope_Payload.saleVoided,
    19: EventEnvelope_Payload.saleRefunded,
    0: EventEnvelope_Payload.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'EventEnvelope',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pos.v1'),
      createEmptyInstance: create)
    ..oo(0, [10, 11, 12, 13, 14, 15, 16, 17, 18, 19])
    ..aOM<$0.OperationId>(1, _omitFieldNames ? '' : 'operationId',
        subBuilder: $0.OperationId.create)
    ..aOS(2, _omitFieldNames ? '' : 'eventType')
    ..a<$core.int>(
        3, _omitFieldNames ? '' : 'schemaVersion', $pb.PbFieldType.OU3)
    ..aOM<$0.TenantId>(4, _omitFieldNames ? '' : 'tenantId',
        subBuilder: $0.TenantId.create)
    ..aOM<$0.OriginNode>(5, _omitFieldNames ? '' : 'origin',
        subBuilder: $0.OriginNode.create)
    ..aOM<$0.LamportClock>(6, _omitFieldNames ? '' : 'clock',
        subBuilder: $0.LamportClock.create)
    ..aOM<$1.Timestamp>(7, _omitFieldNames ? '' : 'occurredAt',
        subBuilder: $1.Timestamp.create)
    ..aOM<SaleCreated>(10, _omitFieldNames ? '' : 'saleCreated',
        subBuilder: SaleCreated.create)
    ..aOM<PaymentAdded>(11, _omitFieldNames ? '' : 'paymentAdded',
        subBuilder: PaymentAdded.create)
    ..aOM<PaymentRefunded>(12, _omitFieldNames ? '' : 'paymentRefunded',
        subBuilder: PaymentRefunded.create)
    ..aOM<InventoryAdjusted>(13, _omitFieldNames ? '' : 'inventoryAdjusted',
        subBuilder: InventoryAdjusted.create)
    ..aOM<StockTransferred>(14, _omitFieldNames ? '' : 'stockTransferred',
        subBuilder: StockTransferred.create)
    ..aOM<SyncCompleted>(15, _omitFieldNames ? '' : 'syncCompleted',
        subBuilder: SyncCompleted.create)
    ..aOM<SyncFailed>(16, _omitFieldNames ? '' : 'syncFailed',
        subBuilder: SyncFailed.create)
    ..aOM<UserLoggedIn>(17, _omitFieldNames ? '' : 'userLoggedIn',
        subBuilder: UserLoggedIn.create)
    ..aOM<SaleVoided>(18, _omitFieldNames ? '' : 'saleVoided',
        subBuilder: SaleVoided.create)
    ..aOM<SaleRefunded>(19, _omitFieldNames ? '' : 'saleRefunded',
        subBuilder: SaleRefunded.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EventEnvelope clone() => EventEnvelope()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EventEnvelope copyWith(void Function(EventEnvelope) updates) =>
      super.copyWith((message) => updates(message as EventEnvelope))
          as EventEnvelope;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static EventEnvelope create() => EventEnvelope._();
  @$core.override
  EventEnvelope createEmptyInstance() => create();
  static $pb.PbList<EventEnvelope> createRepeated() =>
      $pb.PbList<EventEnvelope>();
  @$core.pragma('dart2js:noInline')
  static EventEnvelope getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<EventEnvelope>(create);
  static EventEnvelope? _defaultInstance;

  EventEnvelope_Payload whichPayload() =>
      _EventEnvelope_PayloadByTag[$_whichOneof(0)]!;
  void clearPayload() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  $0.OperationId get operationId => $_getN(0);
  @$pb.TagNumber(1)
  set operationId($0.OperationId value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasOperationId() => $_has(0);
  @$pb.TagNumber(1)
  void clearOperationId() => $_clearField(1);
  @$pb.TagNumber(1)
  $0.OperationId ensureOperationId() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.String get eventType => $_getSZ(1);
  @$pb.TagNumber(2)
  set eventType($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasEventType() => $_has(1);
  @$pb.TagNumber(2)
  void clearEventType() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get schemaVersion => $_getIZ(2);
  @$pb.TagNumber(3)
  set schemaVersion($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSchemaVersion() => $_has(2);
  @$pb.TagNumber(3)
  void clearSchemaVersion() => $_clearField(3);

  @$pb.TagNumber(4)
  $0.TenantId get tenantId => $_getN(3);
  @$pb.TagNumber(4)
  set tenantId($0.TenantId value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasTenantId() => $_has(3);
  @$pb.TagNumber(4)
  void clearTenantId() => $_clearField(4);
  @$pb.TagNumber(4)
  $0.TenantId ensureTenantId() => $_ensure(3);

  @$pb.TagNumber(5)
  $0.OriginNode get origin => $_getN(4);
  @$pb.TagNumber(5)
  set origin($0.OriginNode value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasOrigin() => $_has(4);
  @$pb.TagNumber(5)
  void clearOrigin() => $_clearField(5);
  @$pb.TagNumber(5)
  $0.OriginNode ensureOrigin() => $_ensure(4);

  @$pb.TagNumber(6)
  $0.LamportClock get clock => $_getN(5);
  @$pb.TagNumber(6)
  set clock($0.LamportClock value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasClock() => $_has(5);
  @$pb.TagNumber(6)
  void clearClock() => $_clearField(6);
  @$pb.TagNumber(6)
  $0.LamportClock ensureClock() => $_ensure(5);

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

  @$pb.TagNumber(10)
  SaleCreated get saleCreated => $_getN(7);
  @$pb.TagNumber(10)
  set saleCreated(SaleCreated value) => $_setField(10, value);
  @$pb.TagNumber(10)
  $core.bool hasSaleCreated() => $_has(7);
  @$pb.TagNumber(10)
  void clearSaleCreated() => $_clearField(10);
  @$pb.TagNumber(10)
  SaleCreated ensureSaleCreated() => $_ensure(7);

  @$pb.TagNumber(11)
  PaymentAdded get paymentAdded => $_getN(8);
  @$pb.TagNumber(11)
  set paymentAdded(PaymentAdded value) => $_setField(11, value);
  @$pb.TagNumber(11)
  $core.bool hasPaymentAdded() => $_has(8);
  @$pb.TagNumber(11)
  void clearPaymentAdded() => $_clearField(11);
  @$pb.TagNumber(11)
  PaymentAdded ensurePaymentAdded() => $_ensure(8);

  @$pb.TagNumber(12)
  PaymentRefunded get paymentRefunded => $_getN(9);
  @$pb.TagNumber(12)
  set paymentRefunded(PaymentRefunded value) => $_setField(12, value);
  @$pb.TagNumber(12)
  $core.bool hasPaymentRefunded() => $_has(9);
  @$pb.TagNumber(12)
  void clearPaymentRefunded() => $_clearField(12);
  @$pb.TagNumber(12)
  PaymentRefunded ensurePaymentRefunded() => $_ensure(9);

  @$pb.TagNumber(13)
  InventoryAdjusted get inventoryAdjusted => $_getN(10);
  @$pb.TagNumber(13)
  set inventoryAdjusted(InventoryAdjusted value) => $_setField(13, value);
  @$pb.TagNumber(13)
  $core.bool hasInventoryAdjusted() => $_has(10);
  @$pb.TagNumber(13)
  void clearInventoryAdjusted() => $_clearField(13);
  @$pb.TagNumber(13)
  InventoryAdjusted ensureInventoryAdjusted() => $_ensure(10);

  @$pb.TagNumber(14)
  StockTransferred get stockTransferred => $_getN(11);
  @$pb.TagNumber(14)
  set stockTransferred(StockTransferred value) => $_setField(14, value);
  @$pb.TagNumber(14)
  $core.bool hasStockTransferred() => $_has(11);
  @$pb.TagNumber(14)
  void clearStockTransferred() => $_clearField(14);
  @$pb.TagNumber(14)
  StockTransferred ensureStockTransferred() => $_ensure(11);

  @$pb.TagNumber(15)
  SyncCompleted get syncCompleted => $_getN(12);
  @$pb.TagNumber(15)
  set syncCompleted(SyncCompleted value) => $_setField(15, value);
  @$pb.TagNumber(15)
  $core.bool hasSyncCompleted() => $_has(12);
  @$pb.TagNumber(15)
  void clearSyncCompleted() => $_clearField(15);
  @$pb.TagNumber(15)
  SyncCompleted ensureSyncCompleted() => $_ensure(12);

  @$pb.TagNumber(16)
  SyncFailed get syncFailed => $_getN(13);
  @$pb.TagNumber(16)
  set syncFailed(SyncFailed value) => $_setField(16, value);
  @$pb.TagNumber(16)
  $core.bool hasSyncFailed() => $_has(13);
  @$pb.TagNumber(16)
  void clearSyncFailed() => $_clearField(16);
  @$pb.TagNumber(16)
  SyncFailed ensureSyncFailed() => $_ensure(13);

  @$pb.TagNumber(17)
  UserLoggedIn get userLoggedIn => $_getN(14);
  @$pb.TagNumber(17)
  set userLoggedIn(UserLoggedIn value) => $_setField(17, value);
  @$pb.TagNumber(17)
  $core.bool hasUserLoggedIn() => $_has(14);
  @$pb.TagNumber(17)
  void clearUserLoggedIn() => $_clearField(17);
  @$pb.TagNumber(17)
  UserLoggedIn ensureUserLoggedIn() => $_ensure(14);

  @$pb.TagNumber(18)
  SaleVoided get saleVoided => $_getN(15);
  @$pb.TagNumber(18)
  set saleVoided(SaleVoided value) => $_setField(18, value);
  @$pb.TagNumber(18)
  $core.bool hasSaleVoided() => $_has(15);
  @$pb.TagNumber(18)
  void clearSaleVoided() => $_clearField(18);
  @$pb.TagNumber(18)
  SaleVoided ensureSaleVoided() => $_ensure(15);

  @$pb.TagNumber(19)
  SaleRefunded get saleRefunded => $_getN(16);
  @$pb.TagNumber(19)
  set saleRefunded(SaleRefunded value) => $_setField(19, value);
  @$pb.TagNumber(19)
  $core.bool hasSaleRefunded() => $_has(16);
  @$pb.TagNumber(19)
  void clearSaleRefunded() => $_clearField(19);
  @$pb.TagNumber(19)
  SaleRefunded ensureSaleRefunded() => $_ensure(16);
}

class SaleCreated extends $pb.GeneratedMessage {
  factory SaleCreated({
    $core.String? saleId,
    $0.StoreId? storeId,
    $0.CounterId? counterId,
    $0.UserId? cashierId,
    $core.Iterable<SaleLine>? lines,
    $0.Money? subtotal,
    $0.Money? taxTotal,
    $0.Money? grandTotal,
  }) {
    final result = create();
    if (saleId != null) result.saleId = saleId;
    if (storeId != null) result.storeId = storeId;
    if (counterId != null) result.counterId = counterId;
    if (cashierId != null) result.cashierId = cashierId;
    if (lines != null) result.lines.addAll(lines);
    if (subtotal != null) result.subtotal = subtotal;
    if (taxTotal != null) result.taxTotal = taxTotal;
    if (grandTotal != null) result.grandTotal = grandTotal;
    return result;
  }

  SaleCreated._();

  factory SaleCreated.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SaleCreated.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SaleCreated',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pos.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'saleId')
    ..aOM<$0.StoreId>(2, _omitFieldNames ? '' : 'storeId',
        subBuilder: $0.StoreId.create)
    ..aOM<$0.CounterId>(3, _omitFieldNames ? '' : 'counterId',
        subBuilder: $0.CounterId.create)
    ..aOM<$0.UserId>(4, _omitFieldNames ? '' : 'cashierId',
        subBuilder: $0.UserId.create)
    ..pc<SaleLine>(5, _omitFieldNames ? '' : 'lines', $pb.PbFieldType.PM,
        subBuilder: SaleLine.create)
    ..aOM<$0.Money>(6, _omitFieldNames ? '' : 'subtotal',
        subBuilder: $0.Money.create)
    ..aOM<$0.Money>(7, _omitFieldNames ? '' : 'taxTotal',
        subBuilder: $0.Money.create)
    ..aOM<$0.Money>(8, _omitFieldNames ? '' : 'grandTotal',
        subBuilder: $0.Money.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SaleCreated clone() => SaleCreated()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SaleCreated copyWith(void Function(SaleCreated) updates) =>
      super.copyWith((message) => updates(message as SaleCreated))
          as SaleCreated;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SaleCreated create() => SaleCreated._();
  @$core.override
  SaleCreated createEmptyInstance() => create();
  static $pb.PbList<SaleCreated> createRepeated() => $pb.PbList<SaleCreated>();
  @$core.pragma('dart2js:noInline')
  static SaleCreated getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SaleCreated>(create);
  static SaleCreated? _defaultInstance;

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
  $pb.PbList<SaleLine> get lines => $_getList(4);

  @$pb.TagNumber(6)
  $0.Money get subtotal => $_getN(5);
  @$pb.TagNumber(6)
  set subtotal($0.Money value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasSubtotal() => $_has(5);
  @$pb.TagNumber(6)
  void clearSubtotal() => $_clearField(6);
  @$pb.TagNumber(6)
  $0.Money ensureSubtotal() => $_ensure(5);

  @$pb.TagNumber(7)
  $0.Money get taxTotal => $_getN(6);
  @$pb.TagNumber(7)
  set taxTotal($0.Money value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasTaxTotal() => $_has(6);
  @$pb.TagNumber(7)
  void clearTaxTotal() => $_clearField(7);
  @$pb.TagNumber(7)
  $0.Money ensureTaxTotal() => $_ensure(6);

  @$pb.TagNumber(8)
  $0.Money get grandTotal => $_getN(7);
  @$pb.TagNumber(8)
  set grandTotal($0.Money value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasGrandTotal() => $_has(7);
  @$pb.TagNumber(8)
  void clearGrandTotal() => $_clearField(8);
  @$pb.TagNumber(8)
  $0.Money ensureGrandTotal() => $_ensure(7);
}

class SaleLine extends $pb.GeneratedMessage {
  factory SaleLine({
    $core.String? sku,
    $core.String? description,
    $fixnum.Int64? quantity,
    $0.Money? unitPrice,
    $0.Money? lineTotal,
    $core.String? lineId,
    $core.String? taxCategoryId,
    $0.Money? lineTax,
  }) {
    final result = create();
    if (sku != null) result.sku = sku;
    if (description != null) result.description = description;
    if (quantity != null) result.quantity = quantity;
    if (unitPrice != null) result.unitPrice = unitPrice;
    if (lineTotal != null) result.lineTotal = lineTotal;
    if (lineId != null) result.lineId = lineId;
    if (taxCategoryId != null) result.taxCategoryId = taxCategoryId;
    if (lineTax != null) result.lineTax = lineTax;
    return result;
  }

  SaleLine._();

  factory SaleLine.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SaleLine.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SaleLine',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pos.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'sku')
    ..aOS(2, _omitFieldNames ? '' : 'description')
    ..aInt64(3, _omitFieldNames ? '' : 'quantity')
    ..aOM<$0.Money>(4, _omitFieldNames ? '' : 'unitPrice',
        subBuilder: $0.Money.create)
    ..aOM<$0.Money>(5, _omitFieldNames ? '' : 'lineTotal',
        subBuilder: $0.Money.create)
    ..aOS(6, _omitFieldNames ? '' : 'lineId')
    ..aOS(7, _omitFieldNames ? '' : 'taxCategoryId')
    ..aOM<$0.Money>(8, _omitFieldNames ? '' : 'lineTax',
        subBuilder: $0.Money.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SaleLine clone() => SaleLine()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SaleLine copyWith(void Function(SaleLine) updates) =>
      super.copyWith((message) => updates(message as SaleLine)) as SaleLine;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SaleLine create() => SaleLine._();
  @$core.override
  SaleLine createEmptyInstance() => create();
  static $pb.PbList<SaleLine> createRepeated() => $pb.PbList<SaleLine>();
  @$core.pragma('dart2js:noInline')
  static SaleLine getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SaleLine>(create);
  static SaleLine? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sku => $_getSZ(0);
  @$pb.TagNumber(1)
  set sku($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSku() => $_has(0);
  @$pb.TagNumber(1)
  void clearSku() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get description => $_getSZ(1);
  @$pb.TagNumber(2)
  set description($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDescription() => $_has(1);
  @$pb.TagNumber(2)
  void clearDescription() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get quantity => $_getI64(2);
  @$pb.TagNumber(3)
  set quantity($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasQuantity() => $_has(2);
  @$pb.TagNumber(3)
  void clearQuantity() => $_clearField(3);

  @$pb.TagNumber(4)
  $0.Money get unitPrice => $_getN(3);
  @$pb.TagNumber(4)
  set unitPrice($0.Money value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasUnitPrice() => $_has(3);
  @$pb.TagNumber(4)
  void clearUnitPrice() => $_clearField(4);
  @$pb.TagNumber(4)
  $0.Money ensureUnitPrice() => $_ensure(3);

  @$pb.TagNumber(5)
  $0.Money get lineTotal => $_getN(4);
  @$pb.TagNumber(5)
  set lineTotal($0.Money value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasLineTotal() => $_has(4);
  @$pb.TagNumber(5)
  void clearLineTotal() => $_clearField(5);
  @$pb.TagNumber(5)
  $0.Money ensureLineTotal() => $_ensure(4);

  @$pb.TagNumber(6)
  $core.String get lineId => $_getSZ(5);
  @$pb.TagNumber(6)
  set lineId($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasLineId() => $_has(5);
  @$pb.TagNumber(6)
  void clearLineId() => $_clearField(6);

  /// Added in Phase 5 (slice 5.2). Lets the cloud GL projection split
  /// Tax Payable per tax_category_id. Empty = unclassified (posts to
  /// 2100.unclassified). Older binaries leave this blank — handled.
  @$pb.TagNumber(7)
  $core.String get taxCategoryId => $_getSZ(6);
  @$pb.TagNumber(7)
  set taxCategoryId($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasTaxCategoryId() => $_has(6);
  @$pb.TagNumber(7)
  void clearTaxCategoryId() => $_clearField(7);

  /// Per-line tax magnitude. Sum across lines == SaleCreated.tax_total.
  /// Older binaries leave this nil — cloud falls back to spreading
  /// tax_total proportionally if missing.
  @$pb.TagNumber(8)
  $0.Money get lineTax => $_getN(7);
  @$pb.TagNumber(8)
  set lineTax($0.Money value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasLineTax() => $_has(7);
  @$pb.TagNumber(8)
  void clearLineTax() => $_clearField(8);
  @$pb.TagNumber(8)
  $0.Money ensureLineTax() => $_ensure(7);
}

class PaymentAdded extends $pb.GeneratedMessage {
  factory PaymentAdded({
    $core.String? paymentId,
    $core.String? saleId,
    $core.String? method,
    $0.Money? amount,
    $core.String? reference,
  }) {
    final result = create();
    if (paymentId != null) result.paymentId = paymentId;
    if (saleId != null) result.saleId = saleId;
    if (method != null) result.method = method;
    if (amount != null) result.amount = amount;
    if (reference != null) result.reference = reference;
    return result;
  }

  PaymentAdded._();

  factory PaymentAdded.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PaymentAdded.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PaymentAdded',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pos.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'paymentId')
    ..aOS(2, _omitFieldNames ? '' : 'saleId')
    ..aOS(3, _omitFieldNames ? '' : 'method')
    ..aOM<$0.Money>(4, _omitFieldNames ? '' : 'amount',
        subBuilder: $0.Money.create)
    ..aOS(5, _omitFieldNames ? '' : 'reference')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PaymentAdded clone() => PaymentAdded()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PaymentAdded copyWith(void Function(PaymentAdded) updates) =>
      super.copyWith((message) => updates(message as PaymentAdded))
          as PaymentAdded;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PaymentAdded create() => PaymentAdded._();
  @$core.override
  PaymentAdded createEmptyInstance() => create();
  static $pb.PbList<PaymentAdded> createRepeated() =>
      $pb.PbList<PaymentAdded>();
  @$core.pragma('dart2js:noInline')
  static PaymentAdded getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PaymentAdded>(create);
  static PaymentAdded? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get paymentId => $_getSZ(0);
  @$pb.TagNumber(1)
  set paymentId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPaymentId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPaymentId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get saleId => $_getSZ(1);
  @$pb.TagNumber(2)
  set saleId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSaleId() => $_has(1);
  @$pb.TagNumber(2)
  void clearSaleId() => $_clearField(2);

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

class PaymentRefunded extends $pb.GeneratedMessage {
  factory PaymentRefunded({
    $core.String? refundId,
    $core.String? originalPaymentId,
    $0.Money? amount,
    $core.String? reason,
  }) {
    final result = create();
    if (refundId != null) result.refundId = refundId;
    if (originalPaymentId != null) result.originalPaymentId = originalPaymentId;
    if (amount != null) result.amount = amount;
    if (reason != null) result.reason = reason;
    return result;
  }

  PaymentRefunded._();

  factory PaymentRefunded.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PaymentRefunded.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PaymentRefunded',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pos.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'refundId')
    ..aOS(2, _omitFieldNames ? '' : 'originalPaymentId')
    ..aOM<$0.Money>(3, _omitFieldNames ? '' : 'amount',
        subBuilder: $0.Money.create)
    ..aOS(4, _omitFieldNames ? '' : 'reason')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PaymentRefunded clone() => PaymentRefunded()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PaymentRefunded copyWith(void Function(PaymentRefunded) updates) =>
      super.copyWith((message) => updates(message as PaymentRefunded))
          as PaymentRefunded;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PaymentRefunded create() => PaymentRefunded._();
  @$core.override
  PaymentRefunded createEmptyInstance() => create();
  static $pb.PbList<PaymentRefunded> createRepeated() =>
      $pb.PbList<PaymentRefunded>();
  @$core.pragma('dart2js:noInline')
  static PaymentRefunded getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PaymentRefunded>(create);
  static PaymentRefunded? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get refundId => $_getSZ(0);
  @$pb.TagNumber(1)
  set refundId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRefundId() => $_has(0);
  @$pb.TagNumber(1)
  void clearRefundId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get originalPaymentId => $_getSZ(1);
  @$pb.TagNumber(2)
  set originalPaymentId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasOriginalPaymentId() => $_has(1);
  @$pb.TagNumber(2)
  void clearOriginalPaymentId() => $_clearField(2);

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
  $core.String get reason => $_getSZ(3);
  @$pb.TagNumber(4)
  set reason($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasReason() => $_has(3);
  @$pb.TagNumber(4)
  void clearReason() => $_clearField(4);
}

class InventoryAdjusted extends $pb.GeneratedMessage {
  factory InventoryAdjusted({
    $core.String? sku,
    $fixnum.Int64? delta,
    $core.String? reason,
    $core.String? refId,
  }) {
    final result = create();
    if (sku != null) result.sku = sku;
    if (delta != null) result.delta = delta;
    if (reason != null) result.reason = reason;
    if (refId != null) result.refId = refId;
    return result;
  }

  InventoryAdjusted._();

  factory InventoryAdjusted.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory InventoryAdjusted.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'InventoryAdjusted',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pos.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'sku')
    ..aInt64(2, _omitFieldNames ? '' : 'delta')
    ..aOS(3, _omitFieldNames ? '' : 'reason')
    ..aOS(4, _omitFieldNames ? '' : 'refId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  InventoryAdjusted clone() => InventoryAdjusted()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  InventoryAdjusted copyWith(void Function(InventoryAdjusted) updates) =>
      super.copyWith((message) => updates(message as InventoryAdjusted))
          as InventoryAdjusted;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static InventoryAdjusted create() => InventoryAdjusted._();
  @$core.override
  InventoryAdjusted createEmptyInstance() => create();
  static $pb.PbList<InventoryAdjusted> createRepeated() =>
      $pb.PbList<InventoryAdjusted>();
  @$core.pragma('dart2js:noInline')
  static InventoryAdjusted getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<InventoryAdjusted>(create);
  static InventoryAdjusted? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sku => $_getSZ(0);
  @$pb.TagNumber(1)
  set sku($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSku() => $_has(0);
  @$pb.TagNumber(1)
  void clearSku() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get delta => $_getI64(1);
  @$pb.TagNumber(2)
  set delta($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDelta() => $_has(1);
  @$pb.TagNumber(2)
  void clearDelta() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get reason => $_getSZ(2);
  @$pb.TagNumber(3)
  set reason($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasReason() => $_has(2);
  @$pb.TagNumber(3)
  void clearReason() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get refId => $_getSZ(3);
  @$pb.TagNumber(4)
  set refId($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasRefId() => $_has(3);
  @$pb.TagNumber(4)
  void clearRefId() => $_clearField(4);
}

class StockTransferred extends $pb.GeneratedMessage {
  factory StockTransferred({
    $core.String? transferId,
    $core.String? sku,
    $fixnum.Int64? quantity,
    $0.StoreId? fromStore,
    $0.StoreId? toStore,
  }) {
    final result = create();
    if (transferId != null) result.transferId = transferId;
    if (sku != null) result.sku = sku;
    if (quantity != null) result.quantity = quantity;
    if (fromStore != null) result.fromStore = fromStore;
    if (toStore != null) result.toStore = toStore;
    return result;
  }

  StockTransferred._();

  factory StockTransferred.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory StockTransferred.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StockTransferred',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pos.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'transferId')
    ..aOS(2, _omitFieldNames ? '' : 'sku')
    ..aInt64(3, _omitFieldNames ? '' : 'quantity')
    ..aOM<$0.StoreId>(4, _omitFieldNames ? '' : 'fromStore',
        subBuilder: $0.StoreId.create)
    ..aOM<$0.StoreId>(5, _omitFieldNames ? '' : 'toStore',
        subBuilder: $0.StoreId.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StockTransferred clone() => StockTransferred()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StockTransferred copyWith(void Function(StockTransferred) updates) =>
      super.copyWith((message) => updates(message as StockTransferred))
          as StockTransferred;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static StockTransferred create() => StockTransferred._();
  @$core.override
  StockTransferred createEmptyInstance() => create();
  static $pb.PbList<StockTransferred> createRepeated() =>
      $pb.PbList<StockTransferred>();
  @$core.pragma('dart2js:noInline')
  static StockTransferred getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<StockTransferred>(create);
  static StockTransferred? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get transferId => $_getSZ(0);
  @$pb.TagNumber(1)
  set transferId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTransferId() => $_has(0);
  @$pb.TagNumber(1)
  void clearTransferId() => $_clearField(1);

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
  $0.StoreId get fromStore => $_getN(3);
  @$pb.TagNumber(4)
  set fromStore($0.StoreId value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasFromStore() => $_has(3);
  @$pb.TagNumber(4)
  void clearFromStore() => $_clearField(4);
  @$pb.TagNumber(4)
  $0.StoreId ensureFromStore() => $_ensure(3);

  @$pb.TagNumber(5)
  $0.StoreId get toStore => $_getN(4);
  @$pb.TagNumber(5)
  set toStore($0.StoreId value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasToStore() => $_has(4);
  @$pb.TagNumber(5)
  void clearToStore() => $_clearField(5);
  @$pb.TagNumber(5)
  $0.StoreId ensureToStore() => $_ensure(4);
}

class SyncCompleted extends $pb.GeneratedMessage {
  factory SyncCompleted({
    $core.String? batchId,
    $core.int? operationsCount,
  }) {
    final result = create();
    if (batchId != null) result.batchId = batchId;
    if (operationsCount != null) result.operationsCount = operationsCount;
    return result;
  }

  SyncCompleted._();

  factory SyncCompleted.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SyncCompleted.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SyncCompleted',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pos.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'batchId')
    ..a<$core.int>(
        2, _omitFieldNames ? '' : 'operationsCount', $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SyncCompleted clone() => SyncCompleted()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SyncCompleted copyWith(void Function(SyncCompleted) updates) =>
      super.copyWith((message) => updates(message as SyncCompleted))
          as SyncCompleted;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SyncCompleted create() => SyncCompleted._();
  @$core.override
  SyncCompleted createEmptyInstance() => create();
  static $pb.PbList<SyncCompleted> createRepeated() =>
      $pb.PbList<SyncCompleted>();
  @$core.pragma('dart2js:noInline')
  static SyncCompleted getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SyncCompleted>(create);
  static SyncCompleted? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get batchId => $_getSZ(0);
  @$pb.TagNumber(1)
  set batchId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasBatchId() => $_has(0);
  @$pb.TagNumber(1)
  void clearBatchId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get operationsCount => $_getIZ(1);
  @$pb.TagNumber(2)
  set operationsCount($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasOperationsCount() => $_has(1);
  @$pb.TagNumber(2)
  void clearOperationsCount() => $_clearField(2);
}

class SyncFailed extends $pb.GeneratedMessage {
  factory SyncFailed({
    $core.String? batchId,
    $core.String? reason,
    $core.int? retryCount,
  }) {
    final result = create();
    if (batchId != null) result.batchId = batchId;
    if (reason != null) result.reason = reason;
    if (retryCount != null) result.retryCount = retryCount;
    return result;
  }

  SyncFailed._();

  factory SyncFailed.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SyncFailed.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SyncFailed',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pos.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'batchId')
    ..aOS(2, _omitFieldNames ? '' : 'reason')
    ..a<$core.int>(3, _omitFieldNames ? '' : 'retryCount', $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SyncFailed clone() => SyncFailed()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SyncFailed copyWith(void Function(SyncFailed) updates) =>
      super.copyWith((message) => updates(message as SyncFailed)) as SyncFailed;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SyncFailed create() => SyncFailed._();
  @$core.override
  SyncFailed createEmptyInstance() => create();
  static $pb.PbList<SyncFailed> createRepeated() => $pb.PbList<SyncFailed>();
  @$core.pragma('dart2js:noInline')
  static SyncFailed getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SyncFailed>(create);
  static SyncFailed? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get batchId => $_getSZ(0);
  @$pb.TagNumber(1)
  set batchId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasBatchId() => $_has(0);
  @$pb.TagNumber(1)
  void clearBatchId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get reason => $_getSZ(1);
  @$pb.TagNumber(2)
  set reason($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasReason() => $_has(1);
  @$pb.TagNumber(2)
  void clearReason() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get retryCount => $_getIZ(2);
  @$pb.TagNumber(3)
  set retryCount($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasRetryCount() => $_has(2);
  @$pb.TagNumber(3)
  void clearRetryCount() => $_clearField(3);
}

class UserLoggedIn extends $pb.GeneratedMessage {
  factory UserLoggedIn({
    $0.UserId? userId,
    $core.String? deviceId,
  }) {
    final result = create();
    if (userId != null) result.userId = userId;
    if (deviceId != null) result.deviceId = deviceId;
    return result;
  }

  UserLoggedIn._();

  factory UserLoggedIn.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UserLoggedIn.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UserLoggedIn',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pos.v1'),
      createEmptyInstance: create)
    ..aOM<$0.UserId>(1, _omitFieldNames ? '' : 'userId',
        subBuilder: $0.UserId.create)
    ..aOS(2, _omitFieldNames ? '' : 'deviceId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UserLoggedIn clone() => UserLoggedIn()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UserLoggedIn copyWith(void Function(UserLoggedIn) updates) =>
      super.copyWith((message) => updates(message as UserLoggedIn))
          as UserLoggedIn;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UserLoggedIn create() => UserLoggedIn._();
  @$core.override
  UserLoggedIn createEmptyInstance() => create();
  static $pb.PbList<UserLoggedIn> createRepeated() =>
      $pb.PbList<UserLoggedIn>();
  @$core.pragma('dart2js:noInline')
  static UserLoggedIn getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UserLoggedIn>(create);
  static UserLoggedIn? _defaultInstance;

  @$pb.TagNumber(1)
  $0.UserId get userId => $_getN(0);
  @$pb.TagNumber(1)
  set userId($0.UserId value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => $_clearField(1);
  @$pb.TagNumber(1)
  $0.UserId ensureUserId() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.String get deviceId => $_getSZ(1);
  @$pb.TagNumber(2)
  set deviceId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDeviceId() => $_has(1);
  @$pb.TagNumber(2)
  void clearDeviceId() => $_clearField(2);
}

/// SaleVoided fully reverses a sale issued in the same shift. Conceptually
/// "this sale never happened" — restores inventory, reverses payments. The
/// originating SaleCreated stays in the log (events are append-only); this
/// is the compensating event.
class SaleVoided extends $pb.GeneratedMessage {
  factory SaleVoided({
    $core.String? voidId,
    $core.String? saleId,
    $core.String? invoiceNumber,
    $0.StoreId? storeId,
    $0.CounterId? counterId,
    $0.UserId? cashierId,
    $core.String? reason,
  }) {
    final result = create();
    if (voidId != null) result.voidId = voidId;
    if (saleId != null) result.saleId = saleId;
    if (invoiceNumber != null) result.invoiceNumber = invoiceNumber;
    if (storeId != null) result.storeId = storeId;
    if (counterId != null) result.counterId = counterId;
    if (cashierId != null) result.cashierId = cashierId;
    if (reason != null) result.reason = reason;
    return result;
  }

  SaleVoided._();

  factory SaleVoided.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SaleVoided.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SaleVoided',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pos.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'voidId')
    ..aOS(2, _omitFieldNames ? '' : 'saleId')
    ..aOS(3, _omitFieldNames ? '' : 'invoiceNumber')
    ..aOM<$0.StoreId>(4, _omitFieldNames ? '' : 'storeId',
        subBuilder: $0.StoreId.create)
    ..aOM<$0.CounterId>(5, _omitFieldNames ? '' : 'counterId',
        subBuilder: $0.CounterId.create)
    ..aOM<$0.UserId>(6, _omitFieldNames ? '' : 'cashierId',
        subBuilder: $0.UserId.create)
    ..aOS(7, _omitFieldNames ? '' : 'reason')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SaleVoided clone() => SaleVoided()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SaleVoided copyWith(void Function(SaleVoided) updates) =>
      super.copyWith((message) => updates(message as SaleVoided)) as SaleVoided;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SaleVoided create() => SaleVoided._();
  @$core.override
  SaleVoided createEmptyInstance() => create();
  static $pb.PbList<SaleVoided> createRepeated() => $pb.PbList<SaleVoided>();
  @$core.pragma('dart2js:noInline')
  static SaleVoided getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SaleVoided>(create);
  static SaleVoided? _defaultInstance;

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
  $core.String get reason => $_getSZ(6);
  @$pb.TagNumber(7)
  set reason($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasReason() => $_has(6);
  @$pb.TagNumber(7)
  void clearReason() => $_clearField(7);
}

/// SaleRefunded refunds zero-or-more lines of an earlier sale, in whole or
/// in part. The cloud rebuilds line-balance from the original SaleCreated
/// minus the sum of RefundLine.quantity across all SaleRefunded events for
/// that sale. Issued tenders are paired with refund tenders by Method
/// (card-line refunds settle back to card, cash to cash) — see slice 2.4
/// design notes.
class SaleRefunded extends $pb.GeneratedMessage {
  factory SaleRefunded({
    $core.String? refundId,
    $core.String? saleId,
    $core.String? creditNoteNumber,
    $0.StoreId? storeId,
    $0.CounterId? counterId,
    $0.UserId? cashierId,
    $core.String? reason,
    $core.Iterable<RefundLine>? lines,
    $0.Money? subtotal,
    $0.Money? taxTotal,
    $0.Money? grandTotal,
    $core.Iterable<RefundTender>? tenders,
  }) {
    final result = create();
    if (refundId != null) result.refundId = refundId;
    if (saleId != null) result.saleId = saleId;
    if (creditNoteNumber != null) result.creditNoteNumber = creditNoteNumber;
    if (storeId != null) result.storeId = storeId;
    if (counterId != null) result.counterId = counterId;
    if (cashierId != null) result.cashierId = cashierId;
    if (reason != null) result.reason = reason;
    if (lines != null) result.lines.addAll(lines);
    if (subtotal != null) result.subtotal = subtotal;
    if (taxTotal != null) result.taxTotal = taxTotal;
    if (grandTotal != null) result.grandTotal = grandTotal;
    if (tenders != null) result.tenders.addAll(tenders);
    return result;
  }

  SaleRefunded._();

  factory SaleRefunded.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SaleRefunded.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SaleRefunded',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pos.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'refundId')
    ..aOS(2, _omitFieldNames ? '' : 'saleId')
    ..aOS(3, _omitFieldNames ? '' : 'creditNoteNumber')
    ..aOM<$0.StoreId>(4, _omitFieldNames ? '' : 'storeId',
        subBuilder: $0.StoreId.create)
    ..aOM<$0.CounterId>(5, _omitFieldNames ? '' : 'counterId',
        subBuilder: $0.CounterId.create)
    ..aOM<$0.UserId>(6, _omitFieldNames ? '' : 'cashierId',
        subBuilder: $0.UserId.create)
    ..aOS(7, _omitFieldNames ? '' : 'reason')
    ..pc<RefundLine>(8, _omitFieldNames ? '' : 'lines', $pb.PbFieldType.PM,
        subBuilder: RefundLine.create)
    ..aOM<$0.Money>(9, _omitFieldNames ? '' : 'subtotal',
        subBuilder: $0.Money.create)
    ..aOM<$0.Money>(10, _omitFieldNames ? '' : 'taxTotal',
        subBuilder: $0.Money.create)
    ..aOM<$0.Money>(11, _omitFieldNames ? '' : 'grandTotal',
        subBuilder: $0.Money.create)
    ..pc<RefundTender>(12, _omitFieldNames ? '' : 'tenders', $pb.PbFieldType.PM,
        subBuilder: RefundTender.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SaleRefunded clone() => SaleRefunded()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SaleRefunded copyWith(void Function(SaleRefunded) updates) =>
      super.copyWith((message) => updates(message as SaleRefunded))
          as SaleRefunded;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SaleRefunded create() => SaleRefunded._();
  @$core.override
  SaleRefunded createEmptyInstance() => create();
  static $pb.PbList<SaleRefunded> createRepeated() =>
      $pb.PbList<SaleRefunded>();
  @$core.pragma('dart2js:noInline')
  static SaleRefunded getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SaleRefunded>(create);
  static SaleRefunded? _defaultInstance;

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
  $core.String get creditNoteNumber => $_getSZ(2);
  @$pb.TagNumber(3)
  set creditNoteNumber($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCreditNoteNumber() => $_has(2);
  @$pb.TagNumber(3)
  void clearCreditNoteNumber() => $_clearField(3);

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
  $pb.PbList<RefundLine> get lines => $_getList(7);

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
  $pb.PbList<RefundTender> get tenders => $_getList(11);
}

/// RefundLine is one line of a refund. Quantity is positive (magnitude);
/// the implicit sign is "returned to customer". sale_line_id references the
/// LineID of the SaleLine being (partially) refunded.
class RefundLine extends $pb.GeneratedMessage {
  factory RefundLine({
    $core.String? saleLineId,
    $core.String? sku,
    $fixnum.Int64? quantity,
    $core.bool? restock,
    $0.Money? unitPrice,
    $0.Money? lineTotal,
    $core.String? taxCategoryId,
    $0.Money? lineTax,
  }) {
    final result = create();
    if (saleLineId != null) result.saleLineId = saleLineId;
    if (sku != null) result.sku = sku;
    if (quantity != null) result.quantity = quantity;
    if (restock != null) result.restock = restock;
    if (unitPrice != null) result.unitPrice = unitPrice;
    if (lineTotal != null) result.lineTotal = lineTotal;
    if (taxCategoryId != null) result.taxCategoryId = taxCategoryId;
    if (lineTax != null) result.lineTax = lineTax;
    return result;
  }

  RefundLine._();

  factory RefundLine.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RefundLine.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RefundLine',
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
    ..aOM<$0.Money>(8, _omitFieldNames ? '' : 'lineTax',
        subBuilder: $0.Money.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RefundLine clone() => RefundLine()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RefundLine copyWith(void Function(RefundLine) updates) =>
      super.copyWith((message) => updates(message as RefundLine)) as RefundLine;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RefundLine create() => RefundLine._();
  @$core.override
  RefundLine createEmptyInstance() => create();
  static $pb.PbList<RefundLine> createRepeated() => $pb.PbList<RefundLine>();
  @$core.pragma('dart2js:noInline')
  static RefundLine getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RefundLine>(create);
  static RefundLine? _defaultInstance;

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

  /// Added in Phase 5 (slice 5.2). Copied forward from the original
  /// SaleLine.tax_category_id so the cloud can reverse the right Tax
  /// Payable sub-account.
  @$pb.TagNumber(7)
  $core.String get taxCategoryId => $_getSZ(6);
  @$pb.TagNumber(7)
  set taxCategoryId($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasTaxCategoryId() => $_has(6);
  @$pb.TagNumber(7)
  void clearTaxCategoryId() => $_clearField(7);

  /// Per-line refund tax magnitude. Sum across lines == SaleRefunded.tax_total.
  @$pb.TagNumber(8)
  $0.Money get lineTax => $_getN(7);
  @$pb.TagNumber(8)
  set lineTax($0.Money value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasLineTax() => $_has(7);
  @$pb.TagNumber(8)
  void clearLineTax() => $_clearField(8);
  @$pb.TagNumber(8)
  $0.Money ensureLineTax() => $_ensure(7);
}

/// RefundTender is one tender returned to the customer.
/// original_payment_id ties this refund tender back to a specific original
/// PaymentAdded so the cloud can pair them.
class RefundTender extends $pb.GeneratedMessage {
  factory RefundTender({
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

  RefundTender._();

  factory RefundTender.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RefundTender.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RefundTender',
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
  RefundTender clone() => RefundTender()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RefundTender copyWith(void Function(RefundTender) updates) =>
      super.copyWith((message) => updates(message as RefundTender))
          as RefundTender;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RefundTender create() => RefundTender._();
  @$core.override
  RefundTender createEmptyInstance() => create();
  static $pb.PbList<RefundTender> createRepeated() =>
      $pb.PbList<RefundTender>();
  @$core.pragma('dart2js:noInline')
  static RefundTender getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RefundTender>(create);
  static RefundTender? _defaultInstance;

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

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
