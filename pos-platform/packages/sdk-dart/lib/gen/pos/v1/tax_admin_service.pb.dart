// This is a generated file - do not edit.
//
// Generated from pos/v1/tax_admin_service.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names

import 'dart:async' as $async;
import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

class TaxCategory extends $pb.GeneratedMessage {
  factory TaxCategory({
    $core.String? id,
    $core.String? name,
    $core.String? tenantId,
    $core.bool? priceIncludesTax,
    $core.Iterable<TaxComponent>? components,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (name != null) result.name = name;
    if (tenantId != null) result.tenantId = tenantId;
    if (priceIncludesTax != null) result.priceIncludesTax = priceIncludesTax;
    if (components != null) result.components.addAll(components);
    return result;
  }

  TaxCategory._();

  factory TaxCategory.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory TaxCategory.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TaxCategory',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pos.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aOS(3, _omitFieldNames ? '' : 'tenantId')
    ..aOB(4, _omitFieldNames ? '' : 'priceIncludesTax')
    ..pc<TaxComponent>(
        5, _omitFieldNames ? '' : 'components', $pb.PbFieldType.PM,
        subBuilder: TaxComponent.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TaxCategory clone() => TaxCategory()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TaxCategory copyWith(void Function(TaxCategory) updates) =>
      super.copyWith((message) => updates(message as TaxCategory))
          as TaxCategory;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TaxCategory create() => TaxCategory._();
  @$core.override
  TaxCategory createEmptyInstance() => create();
  static $pb.PbList<TaxCategory> createRepeated() => $pb.PbList<TaxCategory>();
  @$core.pragma('dart2js:noInline')
  static TaxCategory getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TaxCategory>(create);
  static TaxCategory? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get tenantId => $_getSZ(2);
  @$pb.TagNumber(3)
  set tenantId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTenantId() => $_has(2);
  @$pb.TagNumber(3)
  void clearTenantId() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get priceIncludesTax => $_getBF(3);
  @$pb.TagNumber(4)
  set priceIncludesTax($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasPriceIncludesTax() => $_has(3);
  @$pb.TagNumber(4)
  void clearPriceIncludesTax() => $_clearField(4);

  @$pb.TagNumber(5)
  $pb.PbList<TaxComponent> get components => $_getList(4);
}

class TaxComponent extends $pb.GeneratedMessage {
  factory TaxComponent({
    $core.String? id,
    $core.String? taxCategoryId,
    $core.String? name,
    $core.int? rateBasisPoints,
    $core.int? sortOrder,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (taxCategoryId != null) result.taxCategoryId = taxCategoryId;
    if (name != null) result.name = name;
    if (rateBasisPoints != null) result.rateBasisPoints = rateBasisPoints;
    if (sortOrder != null) result.sortOrder = sortOrder;
    return result;
  }

  TaxComponent._();

  factory TaxComponent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory TaxComponent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TaxComponent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pos.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'taxCategoryId')
    ..aOS(3, _omitFieldNames ? '' : 'name')
    ..a<$core.int>(
        4, _omitFieldNames ? '' : 'rateBasisPoints', $pb.PbFieldType.O3)
    ..a<$core.int>(5, _omitFieldNames ? '' : 'sortOrder', $pb.PbFieldType.O3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TaxComponent clone() => TaxComponent()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TaxComponent copyWith(void Function(TaxComponent) updates) =>
      super.copyWith((message) => updates(message as TaxComponent))
          as TaxComponent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TaxComponent create() => TaxComponent._();
  @$core.override
  TaxComponent createEmptyInstance() => create();
  static $pb.PbList<TaxComponent> createRepeated() =>
      $pb.PbList<TaxComponent>();
  @$core.pragma('dart2js:noInline')
  static TaxComponent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TaxComponent>(create);
  static TaxComponent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get taxCategoryId => $_getSZ(1);
  @$pb.TagNumber(2)
  set taxCategoryId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTaxCategoryId() => $_has(1);
  @$pb.TagNumber(2)
  void clearTaxCategoryId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get name => $_getSZ(2);
  @$pb.TagNumber(3)
  set name($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasName() => $_has(2);
  @$pb.TagNumber(3)
  void clearName() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get rateBasisPoints => $_getIZ(3);
  @$pb.TagNumber(4)
  set rateBasisPoints($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasRateBasisPoints() => $_has(3);
  @$pb.TagNumber(4)
  void clearRateBasisPoints() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get sortOrder => $_getIZ(4);
  @$pb.TagNumber(5)
  set sortOrder($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasSortOrder() => $_has(4);
  @$pb.TagNumber(5)
  void clearSortOrder() => $_clearField(5);
}

class UpsertTaxCategoryRequest extends $pb.GeneratedMessage {
  factory UpsertTaxCategoryRequest({
    TaxCategory? category,
  }) {
    final result = create();
    if (category != null) result.category = category;
    return result;
  }

  UpsertTaxCategoryRequest._();

  factory UpsertTaxCategoryRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UpsertTaxCategoryRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpsertTaxCategoryRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pos.v1'),
      createEmptyInstance: create)
    ..aOM<TaxCategory>(1, _omitFieldNames ? '' : 'category',
        subBuilder: TaxCategory.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpsertTaxCategoryRequest clone() =>
      UpsertTaxCategoryRequest()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpsertTaxCategoryRequest copyWith(
          void Function(UpsertTaxCategoryRequest) updates) =>
      super.copyWith((message) => updates(message as UpsertTaxCategoryRequest))
          as UpsertTaxCategoryRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpsertTaxCategoryRequest create() => UpsertTaxCategoryRequest._();
  @$core.override
  UpsertTaxCategoryRequest createEmptyInstance() => create();
  static $pb.PbList<UpsertTaxCategoryRequest> createRepeated() =>
      $pb.PbList<UpsertTaxCategoryRequest>();
  @$core.pragma('dart2js:noInline')
  static UpsertTaxCategoryRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpsertTaxCategoryRequest>(create);
  static UpsertTaxCategoryRequest? _defaultInstance;

  @$pb.TagNumber(1)
  TaxCategory get category => $_getN(0);
  @$pb.TagNumber(1)
  set category(TaxCategory value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasCategory() => $_has(0);
  @$pb.TagNumber(1)
  void clearCategory() => $_clearField(1);
  @$pb.TagNumber(1)
  TaxCategory ensureCategory() => $_ensure(0);
}

class UpsertTaxCategoryResponse extends $pb.GeneratedMessage {
  factory UpsertTaxCategoryResponse({
    TaxCategory? category,
  }) {
    final result = create();
    if (category != null) result.category = category;
    return result;
  }

  UpsertTaxCategoryResponse._();

  factory UpsertTaxCategoryResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UpsertTaxCategoryResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpsertTaxCategoryResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pos.v1'),
      createEmptyInstance: create)
    ..aOM<TaxCategory>(1, _omitFieldNames ? '' : 'category',
        subBuilder: TaxCategory.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpsertTaxCategoryResponse clone() =>
      UpsertTaxCategoryResponse()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpsertTaxCategoryResponse copyWith(
          void Function(UpsertTaxCategoryResponse) updates) =>
      super.copyWith((message) => updates(message as UpsertTaxCategoryResponse))
          as UpsertTaxCategoryResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpsertTaxCategoryResponse create() => UpsertTaxCategoryResponse._();
  @$core.override
  UpsertTaxCategoryResponse createEmptyInstance() => create();
  static $pb.PbList<UpsertTaxCategoryResponse> createRepeated() =>
      $pb.PbList<UpsertTaxCategoryResponse>();
  @$core.pragma('dart2js:noInline')
  static UpsertTaxCategoryResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpsertTaxCategoryResponse>(create);
  static UpsertTaxCategoryResponse? _defaultInstance;

  @$pb.TagNumber(1)
  TaxCategory get category => $_getN(0);
  @$pb.TagNumber(1)
  set category(TaxCategory value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasCategory() => $_has(0);
  @$pb.TagNumber(1)
  void clearCategory() => $_clearField(1);
  @$pb.TagNumber(1)
  TaxCategory ensureCategory() => $_ensure(0);
}

class UpsertTaxComponentRequest extends $pb.GeneratedMessage {
  factory UpsertTaxComponentRequest({
    TaxComponent? component,
  }) {
    final result = create();
    if (component != null) result.component = component;
    return result;
  }

  UpsertTaxComponentRequest._();

  factory UpsertTaxComponentRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UpsertTaxComponentRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpsertTaxComponentRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pos.v1'),
      createEmptyInstance: create)
    ..aOM<TaxComponent>(1, _omitFieldNames ? '' : 'component',
        subBuilder: TaxComponent.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpsertTaxComponentRequest clone() =>
      UpsertTaxComponentRequest()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpsertTaxComponentRequest copyWith(
          void Function(UpsertTaxComponentRequest) updates) =>
      super.copyWith((message) => updates(message as UpsertTaxComponentRequest))
          as UpsertTaxComponentRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpsertTaxComponentRequest create() => UpsertTaxComponentRequest._();
  @$core.override
  UpsertTaxComponentRequest createEmptyInstance() => create();
  static $pb.PbList<UpsertTaxComponentRequest> createRepeated() =>
      $pb.PbList<UpsertTaxComponentRequest>();
  @$core.pragma('dart2js:noInline')
  static UpsertTaxComponentRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpsertTaxComponentRequest>(create);
  static UpsertTaxComponentRequest? _defaultInstance;

  @$pb.TagNumber(1)
  TaxComponent get component => $_getN(0);
  @$pb.TagNumber(1)
  set component(TaxComponent value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasComponent() => $_has(0);
  @$pb.TagNumber(1)
  void clearComponent() => $_clearField(1);
  @$pb.TagNumber(1)
  TaxComponent ensureComponent() => $_ensure(0);
}

class UpsertTaxComponentResponse extends $pb.GeneratedMessage {
  factory UpsertTaxComponentResponse({
    TaxComponent? component,
  }) {
    final result = create();
    if (component != null) result.component = component;
    return result;
  }

  UpsertTaxComponentResponse._();

  factory UpsertTaxComponentResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UpsertTaxComponentResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpsertTaxComponentResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pos.v1'),
      createEmptyInstance: create)
    ..aOM<TaxComponent>(1, _omitFieldNames ? '' : 'component',
        subBuilder: TaxComponent.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpsertTaxComponentResponse clone() =>
      UpsertTaxComponentResponse()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpsertTaxComponentResponse copyWith(
          void Function(UpsertTaxComponentResponse) updates) =>
      super.copyWith(
              (message) => updates(message as UpsertTaxComponentResponse))
          as UpsertTaxComponentResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpsertTaxComponentResponse create() => UpsertTaxComponentResponse._();
  @$core.override
  UpsertTaxComponentResponse createEmptyInstance() => create();
  static $pb.PbList<UpsertTaxComponentResponse> createRepeated() =>
      $pb.PbList<UpsertTaxComponentResponse>();
  @$core.pragma('dart2js:noInline')
  static UpsertTaxComponentResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpsertTaxComponentResponse>(create);
  static UpsertTaxComponentResponse? _defaultInstance;

  @$pb.TagNumber(1)
  TaxComponent get component => $_getN(0);
  @$pb.TagNumber(1)
  set component(TaxComponent value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasComponent() => $_has(0);
  @$pb.TagNumber(1)
  void clearComponent() => $_clearField(1);
  @$pb.TagNumber(1)
  TaxComponent ensureComponent() => $_ensure(0);
}

class GetTaxCategoryRequest extends $pb.GeneratedMessage {
  factory GetTaxCategoryRequest({
    $core.String? id,
  }) {
    final result = create();
    if (id != null) result.id = id;
    return result;
  }

  GetTaxCategoryRequest._();

  factory GetTaxCategoryRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetTaxCategoryRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetTaxCategoryRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pos.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetTaxCategoryRequest clone() =>
      GetTaxCategoryRequest()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetTaxCategoryRequest copyWith(
          void Function(GetTaxCategoryRequest) updates) =>
      super.copyWith((message) => updates(message as GetTaxCategoryRequest))
          as GetTaxCategoryRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetTaxCategoryRequest create() => GetTaxCategoryRequest._();
  @$core.override
  GetTaxCategoryRequest createEmptyInstance() => create();
  static $pb.PbList<GetTaxCategoryRequest> createRepeated() =>
      $pb.PbList<GetTaxCategoryRequest>();
  @$core.pragma('dart2js:noInline')
  static GetTaxCategoryRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetTaxCategoryRequest>(create);
  static GetTaxCategoryRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);
}

class GetTaxCategoryResponse extends $pb.GeneratedMessage {
  factory GetTaxCategoryResponse({
    TaxCategory? category,
  }) {
    final result = create();
    if (category != null) result.category = category;
    return result;
  }

  GetTaxCategoryResponse._();

  factory GetTaxCategoryResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetTaxCategoryResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetTaxCategoryResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pos.v1'),
      createEmptyInstance: create)
    ..aOM<TaxCategory>(1, _omitFieldNames ? '' : 'category',
        subBuilder: TaxCategory.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetTaxCategoryResponse clone() =>
      GetTaxCategoryResponse()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetTaxCategoryResponse copyWith(
          void Function(GetTaxCategoryResponse) updates) =>
      super.copyWith((message) => updates(message as GetTaxCategoryResponse))
          as GetTaxCategoryResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetTaxCategoryResponse create() => GetTaxCategoryResponse._();
  @$core.override
  GetTaxCategoryResponse createEmptyInstance() => create();
  static $pb.PbList<GetTaxCategoryResponse> createRepeated() =>
      $pb.PbList<GetTaxCategoryResponse>();
  @$core.pragma('dart2js:noInline')
  static GetTaxCategoryResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetTaxCategoryResponse>(create);
  static GetTaxCategoryResponse? _defaultInstance;

  @$pb.TagNumber(1)
  TaxCategory get category => $_getN(0);
  @$pb.TagNumber(1)
  set category(TaxCategory value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasCategory() => $_has(0);
  @$pb.TagNumber(1)
  void clearCategory() => $_clearField(1);
  @$pb.TagNumber(1)
  TaxCategory ensureCategory() => $_ensure(0);
}

/// TaxAdminService is the operator-facing surface for tax category +
/// component management. Used by the desktop client's settings UI so the
/// operator doesn't have to write raw SQL to define rates.
///
/// Note: TaxAdminService writes are NOT events — they mutate the local
/// catalog directly. The cloud will eventually source tax catalogs from
/// a tenant-config push instead. Until then, this surface is the only
/// way to seed rates after Phase 2.
class TaxAdminServiceApi {
  final $pb.RpcClient _client;

  TaxAdminServiceApi(this._client);

  $async.Future<UpsertTaxCategoryResponse> upsertTaxCategory(
          $pb.ClientContext? ctx, UpsertTaxCategoryRequest request) =>
      _client.invoke<UpsertTaxCategoryResponse>(ctx, 'TaxAdminService',
          'UpsertTaxCategory', request, UpsertTaxCategoryResponse());
  $async.Future<UpsertTaxComponentResponse> upsertTaxComponent(
          $pb.ClientContext? ctx, UpsertTaxComponentRequest request) =>
      _client.invoke<UpsertTaxComponentResponse>(ctx, 'TaxAdminService',
          'UpsertTaxComponent', request, UpsertTaxComponentResponse());
  $async.Future<GetTaxCategoryResponse> getTaxCategory(
          $pb.ClientContext? ctx, GetTaxCategoryRequest request) =>
      _client.invoke<GetTaxCategoryResponse>(ctx, 'TaxAdminService',
          'GetTaxCategory', request, GetTaxCategoryResponse());
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
