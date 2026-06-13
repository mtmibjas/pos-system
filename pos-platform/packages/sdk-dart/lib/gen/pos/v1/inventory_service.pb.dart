// This is a generated file - do not edit.
//
// Generated from pos/v1/inventory_service.proto.

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

import 'common.pb.dart' as $0;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

class ListOnHandRequest extends $pb.GeneratedMessage {
  factory ListOnHandRequest({
    $0.StoreId? storeId,
  }) {
    final result = create();
    if (storeId != null) result.storeId = storeId;
    return result;
  }

  ListOnHandRequest._();

  factory ListOnHandRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ListOnHandRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListOnHandRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pos.v1'),
      createEmptyInstance: create)
    ..aOM<$0.StoreId>(1, _omitFieldNames ? '' : 'storeId',
        subBuilder: $0.StoreId.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListOnHandRequest clone() => ListOnHandRequest()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListOnHandRequest copyWith(void Function(ListOnHandRequest) updates) =>
      super.copyWith((message) => updates(message as ListOnHandRequest))
          as ListOnHandRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListOnHandRequest create() => ListOnHandRequest._();
  @$core.override
  ListOnHandRequest createEmptyInstance() => create();
  static $pb.PbList<ListOnHandRequest> createRepeated() =>
      $pb.PbList<ListOnHandRequest>();
  @$core.pragma('dart2js:noInline')
  static ListOnHandRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListOnHandRequest>(create);
  static ListOnHandRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $0.StoreId get storeId => $_getN(0);
  @$pb.TagNumber(1)
  set storeId($0.StoreId value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasStoreId() => $_has(0);
  @$pb.TagNumber(1)
  void clearStoreId() => $_clearField(1);
  @$pb.TagNumber(1)
  $0.StoreId ensureStoreId() => $_ensure(0);
}

class ListOnHandResponse extends $pb.GeneratedMessage {
  factory ListOnHandResponse({
    $core.Iterable<OnHandRow>? rows,
  }) {
    final result = create();
    if (rows != null) result.rows.addAll(rows);
    return result;
  }

  ListOnHandResponse._();

  factory ListOnHandResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ListOnHandResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListOnHandResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pos.v1'),
      createEmptyInstance: create)
    ..pc<OnHandRow>(1, _omitFieldNames ? '' : 'rows', $pb.PbFieldType.PM,
        subBuilder: OnHandRow.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListOnHandResponse clone() => ListOnHandResponse()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListOnHandResponse copyWith(void Function(ListOnHandResponse) updates) =>
      super.copyWith((message) => updates(message as ListOnHandResponse))
          as ListOnHandResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListOnHandResponse create() => ListOnHandResponse._();
  @$core.override
  ListOnHandResponse createEmptyInstance() => create();
  static $pb.PbList<ListOnHandResponse> createRepeated() =>
      $pb.PbList<ListOnHandResponse>();
  @$core.pragma('dart2js:noInline')
  static ListOnHandResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListOnHandResponse>(create);
  static ListOnHandResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<OnHandRow> get rows => $_getList(0);
}

/// OnHandRow joins inventory_movements (summed) with the item catalog.
/// name + price come from the items table; on_hand is the derived
/// COALESCE(SUM(delta),0) over non-voided movements. SKUs present in
/// either source render — unmatched items show 0, unmatched movements
/// show empty name.
class OnHandRow extends $pb.GeneratedMessage {
  factory OnHandRow({
    $core.String? sku,
    $core.String? name,
    $0.Money? price,
    $fixnum.Int64? onHand,
  }) {
    final result = create();
    if (sku != null) result.sku = sku;
    if (name != null) result.name = name;
    if (price != null) result.price = price;
    if (onHand != null) result.onHand = onHand;
    return result;
  }

  OnHandRow._();

  factory OnHandRow.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory OnHandRow.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'OnHandRow',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pos.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'sku')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aOM<$0.Money>(3, _omitFieldNames ? '' : 'price',
        subBuilder: $0.Money.create)
    ..aInt64(4, _omitFieldNames ? '' : 'onHand')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OnHandRow clone() => OnHandRow()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OnHandRow copyWith(void Function(OnHandRow) updates) =>
      super.copyWith((message) => updates(message as OnHandRow)) as OnHandRow;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static OnHandRow create() => OnHandRow._();
  @$core.override
  OnHandRow createEmptyInstance() => create();
  static $pb.PbList<OnHandRow> createRepeated() => $pb.PbList<OnHandRow>();
  @$core.pragma('dart2js:noInline')
  static OnHandRow getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<OnHandRow>(create);
  static OnHandRow? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sku => $_getSZ(0);
  @$pb.TagNumber(1)
  set sku($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSku() => $_has(0);
  @$pb.TagNumber(1)
  void clearSku() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);

  @$pb.TagNumber(3)
  $0.Money get price => $_getN(2);
  @$pb.TagNumber(3)
  set price($0.Money value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasPrice() => $_has(2);
  @$pb.TagNumber(3)
  void clearPrice() => $_clearField(3);
  @$pb.TagNumber(3)
  $0.Money ensurePrice() => $_ensure(2);

  @$pb.TagNumber(4)
  $fixnum.Int64 get onHand => $_getI64(3);
  @$pb.TagNumber(4)
  set onHand($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasOnHand() => $_has(3);
  @$pb.TagNumber(4)
  void clearOnHand() => $_clearField(4);
}

/// InventoryService is the read-side surface for stock-on-hand views.
/// Write operations land via SaleService.Finalize / RefundService.* —
/// inventory movements are an internal append-only ledger.
class InventoryServiceApi {
  final $pb.RpcClient _client;

  InventoryServiceApi(this._client);

  /// ListOnHand returns the live per-SKU on-hand quantity for one store.
  /// Empty / unseeded SKUs are omitted. Results are sorted by SKU.
  $async.Future<ListOnHandResponse> listOnHand(
          $pb.ClientContext? ctx, ListOnHandRequest request) =>
      _client.invoke<ListOnHandResponse>(
          ctx, 'InventoryService', 'ListOnHand', request, ListOnHandResponse());
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
