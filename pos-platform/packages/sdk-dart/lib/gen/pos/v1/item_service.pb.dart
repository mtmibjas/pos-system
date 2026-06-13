// This is a generated file - do not edit.
//
// Generated from pos/v1/item_service.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names

import 'dart:async' as $async;
import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

import '../../google/protobuf/timestamp.pb.dart' as $1;
import 'common.pb.dart' as $0;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

/// Item is one row in the catalog. SKU is the primary key — matches
/// what FinalizeSaleLine.sku already wires. tenant_id is pinned from
/// server config on writes (ignored on the wire).
///
/// price is a Money; nil = unset (a write-time error). tax_category_id
/// MAY be empty, which the tax engine treats as EXEMPT. archived is a
/// soft-delete flag — archived items don't appear in default ListItems,
/// but GetItem still returns them so historical sale lines resolve.
class Item extends $pb.GeneratedMessage {
  factory Item({
    $core.String? sku,
    $core.String? tenantId,
    $core.String? name,
    $0.Money? price,
    $core.String? taxCategoryId,
    $core.bool? archived,
    $1.Timestamp? createdAt,
    $1.Timestamp? updatedAt,
  }) {
    final result = create();
    if (sku != null) result.sku = sku;
    if (tenantId != null) result.tenantId = tenantId;
    if (name != null) result.name = name;
    if (price != null) result.price = price;
    if (taxCategoryId != null) result.taxCategoryId = taxCategoryId;
    if (archived != null) result.archived = archived;
    if (createdAt != null) result.createdAt = createdAt;
    if (updatedAt != null) result.updatedAt = updatedAt;
    return result;
  }

  Item._();

  factory Item.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Item.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Item',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pos.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'sku')
    ..aOS(2, _omitFieldNames ? '' : 'tenantId')
    ..aOS(3, _omitFieldNames ? '' : 'name')
    ..aOM<$0.Money>(4, _omitFieldNames ? '' : 'price',
        subBuilder: $0.Money.create)
    ..aOS(5, _omitFieldNames ? '' : 'taxCategoryId')
    ..aOB(6, _omitFieldNames ? '' : 'archived')
    ..aOM<$1.Timestamp>(7, _omitFieldNames ? '' : 'createdAt',
        subBuilder: $1.Timestamp.create)
    ..aOM<$1.Timestamp>(8, _omitFieldNames ? '' : 'updatedAt',
        subBuilder: $1.Timestamp.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Item clone() => Item()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Item copyWith(void Function(Item) updates) =>
      super.copyWith((message) => updates(message as Item)) as Item;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Item create() => Item._();
  @$core.override
  Item createEmptyInstance() => create();
  static $pb.PbList<Item> createRepeated() => $pb.PbList<Item>();
  @$core.pragma('dart2js:noInline')
  static Item getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Item>(create);
  static Item? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sku => $_getSZ(0);
  @$pb.TagNumber(1)
  set sku($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSku() => $_has(0);
  @$pb.TagNumber(1)
  void clearSku() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get tenantId => $_getSZ(1);
  @$pb.TagNumber(2)
  set tenantId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTenantId() => $_has(1);
  @$pb.TagNumber(2)
  void clearTenantId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get name => $_getSZ(2);
  @$pb.TagNumber(3)
  set name($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasName() => $_has(2);
  @$pb.TagNumber(3)
  void clearName() => $_clearField(3);

  @$pb.TagNumber(4)
  $0.Money get price => $_getN(3);
  @$pb.TagNumber(4)
  set price($0.Money value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasPrice() => $_has(3);
  @$pb.TagNumber(4)
  void clearPrice() => $_clearField(4);
  @$pb.TagNumber(4)
  $0.Money ensurePrice() => $_ensure(3);

  @$pb.TagNumber(5)
  $core.String get taxCategoryId => $_getSZ(4);
  @$pb.TagNumber(5)
  set taxCategoryId($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasTaxCategoryId() => $_has(4);
  @$pb.TagNumber(5)
  void clearTaxCategoryId() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.bool get archived => $_getBF(5);
  @$pb.TagNumber(6)
  set archived($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasArchived() => $_has(5);
  @$pb.TagNumber(6)
  void clearArchived() => $_clearField(6);

  @$pb.TagNumber(7)
  $1.Timestamp get createdAt => $_getN(6);
  @$pb.TagNumber(7)
  set createdAt($1.Timestamp value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasCreatedAt() => $_has(6);
  @$pb.TagNumber(7)
  void clearCreatedAt() => $_clearField(7);
  @$pb.TagNumber(7)
  $1.Timestamp ensureCreatedAt() => $_ensure(6);

  @$pb.TagNumber(8)
  $1.Timestamp get updatedAt => $_getN(7);
  @$pb.TagNumber(8)
  set updatedAt($1.Timestamp value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasUpdatedAt() => $_has(7);
  @$pb.TagNumber(8)
  void clearUpdatedAt() => $_clearField(8);
  @$pb.TagNumber(8)
  $1.Timestamp ensureUpdatedAt() => $_ensure(7);
}

class UpsertItemRequest extends $pb.GeneratedMessage {
  factory UpsertItemRequest({
    Item? item,
  }) {
    final result = create();
    if (item != null) result.item = item;
    return result;
  }

  UpsertItemRequest._();

  factory UpsertItemRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UpsertItemRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpsertItemRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pos.v1'),
      createEmptyInstance: create)
    ..aOM<Item>(1, _omitFieldNames ? '' : 'item', subBuilder: Item.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpsertItemRequest clone() => UpsertItemRequest()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpsertItemRequest copyWith(void Function(UpsertItemRequest) updates) =>
      super.copyWith((message) => updates(message as UpsertItemRequest))
          as UpsertItemRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpsertItemRequest create() => UpsertItemRequest._();
  @$core.override
  UpsertItemRequest createEmptyInstance() => create();
  static $pb.PbList<UpsertItemRequest> createRepeated() =>
      $pb.PbList<UpsertItemRequest>();
  @$core.pragma('dart2js:noInline')
  static UpsertItemRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpsertItemRequest>(create);
  static UpsertItemRequest? _defaultInstance;

  @$pb.TagNumber(1)
  Item get item => $_getN(0);
  @$pb.TagNumber(1)
  set item(Item value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasItem() => $_has(0);
  @$pb.TagNumber(1)
  void clearItem() => $_clearField(1);
  @$pb.TagNumber(1)
  Item ensureItem() => $_ensure(0);
}

class UpsertItemResponse extends $pb.GeneratedMessage {
  factory UpsertItemResponse({
    Item? item,
  }) {
    final result = create();
    if (item != null) result.item = item;
    return result;
  }

  UpsertItemResponse._();

  factory UpsertItemResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UpsertItemResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpsertItemResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pos.v1'),
      createEmptyInstance: create)
    ..aOM<Item>(1, _omitFieldNames ? '' : 'item', subBuilder: Item.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpsertItemResponse clone() => UpsertItemResponse()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpsertItemResponse copyWith(void Function(UpsertItemResponse) updates) =>
      super.copyWith((message) => updates(message as UpsertItemResponse))
          as UpsertItemResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpsertItemResponse create() => UpsertItemResponse._();
  @$core.override
  UpsertItemResponse createEmptyInstance() => create();
  static $pb.PbList<UpsertItemResponse> createRepeated() =>
      $pb.PbList<UpsertItemResponse>();
  @$core.pragma('dart2js:noInline')
  static UpsertItemResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpsertItemResponse>(create);
  static UpsertItemResponse? _defaultInstance;

  @$pb.TagNumber(1)
  Item get item => $_getN(0);
  @$pb.TagNumber(1)
  set item(Item value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasItem() => $_has(0);
  @$pb.TagNumber(1)
  void clearItem() => $_clearField(1);
  @$pb.TagNumber(1)
  Item ensureItem() => $_ensure(0);
}

class GetItemRequest extends $pb.GeneratedMessage {
  factory GetItemRequest({
    $core.String? sku,
  }) {
    final result = create();
    if (sku != null) result.sku = sku;
    return result;
  }

  GetItemRequest._();

  factory GetItemRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetItemRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetItemRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pos.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'sku')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetItemRequest clone() => GetItemRequest()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetItemRequest copyWith(void Function(GetItemRequest) updates) =>
      super.copyWith((message) => updates(message as GetItemRequest))
          as GetItemRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetItemRequest create() => GetItemRequest._();
  @$core.override
  GetItemRequest createEmptyInstance() => create();
  static $pb.PbList<GetItemRequest> createRepeated() =>
      $pb.PbList<GetItemRequest>();
  @$core.pragma('dart2js:noInline')
  static GetItemRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetItemRequest>(create);
  static GetItemRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sku => $_getSZ(0);
  @$pb.TagNumber(1)
  set sku($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSku() => $_has(0);
  @$pb.TagNumber(1)
  void clearSku() => $_clearField(1);
}

class GetItemResponse extends $pb.GeneratedMessage {
  factory GetItemResponse({
    Item? item,
  }) {
    final result = create();
    if (item != null) result.item = item;
    return result;
  }

  GetItemResponse._();

  factory GetItemResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetItemResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetItemResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pos.v1'),
      createEmptyInstance: create)
    ..aOM<Item>(1, _omitFieldNames ? '' : 'item', subBuilder: Item.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetItemResponse clone() => GetItemResponse()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetItemResponse copyWith(void Function(GetItemResponse) updates) =>
      super.copyWith((message) => updates(message as GetItemResponse))
          as GetItemResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetItemResponse create() => GetItemResponse._();
  @$core.override
  GetItemResponse createEmptyInstance() => create();
  static $pb.PbList<GetItemResponse> createRepeated() =>
      $pb.PbList<GetItemResponse>();
  @$core.pragma('dart2js:noInline')
  static GetItemResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetItemResponse>(create);
  static GetItemResponse? _defaultInstance;

  @$pb.TagNumber(1)
  Item get item => $_getN(0);
  @$pb.TagNumber(1)
  set item(Item value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasItem() => $_has(0);
  @$pb.TagNumber(1)
  void clearItem() => $_clearField(1);
  @$pb.TagNumber(1)
  Item ensureItem() => $_ensure(0);
}

/// ListItemsRequest has no pagination — a single shop's catalog stays
/// small enough to fetch in one shot. Add a page_token field if/when
/// that stops being true.
class ListItemsRequest extends $pb.GeneratedMessage {
  factory ListItemsRequest({
    $core.bool? includeArchived,
  }) {
    final result = create();
    if (includeArchived != null) result.includeArchived = includeArchived;
    return result;
  }

  ListItemsRequest._();

  factory ListItemsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ListItemsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListItemsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pos.v1'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'includeArchived')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListItemsRequest clone() => ListItemsRequest()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListItemsRequest copyWith(void Function(ListItemsRequest) updates) =>
      super.copyWith((message) => updates(message as ListItemsRequest))
          as ListItemsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListItemsRequest create() => ListItemsRequest._();
  @$core.override
  ListItemsRequest createEmptyInstance() => create();
  static $pb.PbList<ListItemsRequest> createRepeated() =>
      $pb.PbList<ListItemsRequest>();
  @$core.pragma('dart2js:noInline')
  static ListItemsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListItemsRequest>(create);
  static ListItemsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get includeArchived => $_getBF(0);
  @$pb.TagNumber(1)
  set includeArchived($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasIncludeArchived() => $_has(0);
  @$pb.TagNumber(1)
  void clearIncludeArchived() => $_clearField(1);
}

class ListItemsResponse extends $pb.GeneratedMessage {
  factory ListItemsResponse({
    $core.Iterable<Item>? items,
  }) {
    final result = create();
    if (items != null) result.items.addAll(items);
    return result;
  }

  ListItemsResponse._();

  factory ListItemsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ListItemsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListItemsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pos.v1'),
      createEmptyInstance: create)
    ..pc<Item>(1, _omitFieldNames ? '' : 'items', $pb.PbFieldType.PM,
        subBuilder: Item.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListItemsResponse clone() => ListItemsResponse()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListItemsResponse copyWith(void Function(ListItemsResponse) updates) =>
      super.copyWith((message) => updates(message as ListItemsResponse))
          as ListItemsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListItemsResponse create() => ListItemsResponse._();
  @$core.override
  ListItemsResponse createEmptyInstance() => create();
  static $pb.PbList<ListItemsResponse> createRepeated() =>
      $pb.PbList<ListItemsResponse>();
  @$core.pragma('dart2js:noInline')
  static ListItemsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListItemsResponse>(create);
  static ListItemsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<Item> get items => $_getList(0);
}

/// ItemService is the operator-facing catalog surface. The desktop
/// client browses/searches items to build a cart; the picked SKU and
/// denormalized price + tax_category_id then flow through
/// FinalizeSaleLine on SaleService.Finalize.
///
/// Like TaxAdminService, item writes are NOT events — they mutate the
/// local catalog directly. The cloud will eventually push a tenant
/// catalog down; until then, UpsertItem (and cmd/seed-demo) are the
/// only seed paths.
class ItemServiceApi {
  final $pb.RpcClient _client;

  ItemServiceApi(this._client);

  $async.Future<UpsertItemResponse> upsertItem(
          $pb.ClientContext? ctx, UpsertItemRequest request) =>
      _client.invoke<UpsertItemResponse>(
          ctx, 'ItemService', 'UpsertItem', request, UpsertItemResponse());
  $async.Future<GetItemResponse> getItem(
          $pb.ClientContext? ctx, GetItemRequest request) =>
      _client.invoke<GetItemResponse>(
          ctx, 'ItemService', 'GetItem', request, GetItemResponse());
  $async.Future<ListItemsResponse> listItems(
          $pb.ClientContext? ctx, ListItemsRequest request) =>
      _client.invoke<ListItemsResponse>(
          ctx, 'ItemService', 'ListItems', request, ListItemsResponse());
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
