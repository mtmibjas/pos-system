// This is a generated file - do not edit.
//
// Generated from pos/v1/common.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

/// Money is a fixed-precision monetary amount.
///
/// We avoid floats. `units` is the whole units (e.g. 12 for $12.34) and
/// `nanos` is the fractional part in nanos (10^-9) — matches Google's
/// google.type.Money convention.
///
/// currency_code is ISO-4217 (e.g. "USD", "INR").
class Money extends $pb.GeneratedMessage {
  factory Money({
    $core.String? currencyCode,
    $fixnum.Int64? units,
    $core.int? nanos,
  }) {
    final result = create();
    if (currencyCode != null) result.currencyCode = currencyCode;
    if (units != null) result.units = units;
    if (nanos != null) result.nanos = nanos;
    return result;
  }

  Money._();

  factory Money.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Money.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Money',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pos.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'currencyCode')
    ..aInt64(2, _omitFieldNames ? '' : 'units')
    ..a<$core.int>(3, _omitFieldNames ? '' : 'nanos', $pb.PbFieldType.O3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Money clone() => Money()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Money copyWith(void Function(Money) updates) =>
      super.copyWith((message) => updates(message as Money)) as Money;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Money create() => Money._();
  @$core.override
  Money createEmptyInstance() => create();
  static $pb.PbList<Money> createRepeated() => $pb.PbList<Money>();
  @$core.pragma('dart2js:noInline')
  static Money getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Money>(create);
  static Money? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get currencyCode => $_getSZ(0);
  @$pb.TagNumber(1)
  set currencyCode($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCurrencyCode() => $_has(0);
  @$pb.TagNumber(1)
  void clearCurrencyCode() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get units => $_getI64(1);
  @$pb.TagNumber(2)
  set units($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasUnits() => $_has(1);
  @$pb.TagNumber(2)
  void clearUnits() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get nanos => $_getIZ(2);
  @$pb.TagNumber(3)
  set nanos($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasNanos() => $_has(2);
  @$pb.TagNumber(3)
  void clearNanos() => $_clearField(3);
}

/// Identifiers — all UUIDs are serialized as RFC-4122 strings.
class TenantId extends $pb.GeneratedMessage {
  factory TenantId({
    $core.String? value,
  }) {
    final result = create();
    if (value != null) result.value = value;
    return result;
  }

  TenantId._();

  factory TenantId.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory TenantId.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TenantId',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pos.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'value')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TenantId clone() => TenantId()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TenantId copyWith(void Function(TenantId) updates) =>
      super.copyWith((message) => updates(message as TenantId)) as TenantId;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TenantId create() => TenantId._();
  @$core.override
  TenantId createEmptyInstance() => create();
  static $pb.PbList<TenantId> createRepeated() => $pb.PbList<TenantId>();
  @$core.pragma('dart2js:noInline')
  static TenantId getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<TenantId>(create);
  static TenantId? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get value => $_getSZ(0);
  @$pb.TagNumber(1)
  set value($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasValue() => $_has(0);
  @$pb.TagNumber(1)
  void clearValue() => $_clearField(1);
}

class StoreId extends $pb.GeneratedMessage {
  factory StoreId({
    $core.String? value,
  }) {
    final result = create();
    if (value != null) result.value = value;
    return result;
  }

  StoreId._();

  factory StoreId.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory StoreId.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StoreId',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pos.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'value')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StoreId clone() => StoreId()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StoreId copyWith(void Function(StoreId) updates) =>
      super.copyWith((message) => updates(message as StoreId)) as StoreId;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static StoreId create() => StoreId._();
  @$core.override
  StoreId createEmptyInstance() => create();
  static $pb.PbList<StoreId> createRepeated() => $pb.PbList<StoreId>();
  @$core.pragma('dart2js:noInline')
  static StoreId getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<StoreId>(create);
  static StoreId? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get value => $_getSZ(0);
  @$pb.TagNumber(1)
  set value($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasValue() => $_has(0);
  @$pb.TagNumber(1)
  void clearValue() => $_clearField(1);
}

class CounterId extends $pb.GeneratedMessage {
  factory CounterId({
    $core.String? value,
  }) {
    final result = create();
    if (value != null) result.value = value;
    return result;
  }

  CounterId._();

  factory CounterId.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CounterId.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CounterId',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pos.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'value')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CounterId clone() => CounterId()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CounterId copyWith(void Function(CounterId) updates) =>
      super.copyWith((message) => updates(message as CounterId)) as CounterId;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CounterId create() => CounterId._();
  @$core.override
  CounterId createEmptyInstance() => create();
  static $pb.PbList<CounterId> createRepeated() => $pb.PbList<CounterId>();
  @$core.pragma('dart2js:noInline')
  static CounterId getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CounterId>(create);
  static CounterId? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get value => $_getSZ(0);
  @$pb.TagNumber(1)
  set value($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasValue() => $_has(0);
  @$pb.TagNumber(1)
  void clearValue() => $_clearField(1);
}

class UserId extends $pb.GeneratedMessage {
  factory UserId({
    $core.String? value,
  }) {
    final result = create();
    if (value != null) result.value = value;
    return result;
  }

  UserId._();

  factory UserId.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UserId.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UserId',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pos.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'value')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UserId clone() => UserId()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UserId copyWith(void Function(UserId) updates) =>
      super.copyWith((message) => updates(message as UserId)) as UserId;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UserId create() => UserId._();
  @$core.override
  UserId createEmptyInstance() => create();
  static $pb.PbList<UserId> createRepeated() => $pb.PbList<UserId>();
  @$core.pragma('dart2js:noInline')
  static UserId getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<UserId>(create);
  static UserId? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get value => $_getSZ(0);
  @$pb.TagNumber(1)
  set value($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasValue() => $_has(0);
  @$pb.TagNumber(1)
  void clearValue() => $_clearField(1);
}

class OperationId extends $pb.GeneratedMessage {
  factory OperationId({
    $core.String? value,
  }) {
    final result = create();
    if (value != null) result.value = value;
    return result;
  }

  OperationId._();

  factory OperationId.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory OperationId.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'OperationId',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pos.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'value')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OperationId clone() => OperationId()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OperationId copyWith(void Function(OperationId) updates) =>
      super.copyWith((message) => updates(message as OperationId))
          as OperationId;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static OperationId create() => OperationId._();
  @$core.override
  OperationId createEmptyInstance() => create();
  static $pb.PbList<OperationId> createRepeated() => $pb.PbList<OperationId>();
  @$core.pragma('dart2js:noInline')
  static OperationId getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<OperationId>(create);
  static OperationId? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get value => $_getSZ(0);
  @$pb.TagNumber(1)
  set value($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasValue() => $_has(0);
  @$pb.TagNumber(1)
  void clearValue() => $_clearField(1);
}

/// OriginNode identifies where an operation was first created.
/// Required for conflict diagnosis and replay-attack defence.
class OriginNode extends $pb.GeneratedMessage {
  factory OriginNode({
    $core.String? nodeId,
    StoreId? storeId,
    CounterId? counterId,
  }) {
    final result = create();
    if (nodeId != null) result.nodeId = nodeId;
    if (storeId != null) result.storeId = storeId;
    if (counterId != null) result.counterId = counterId;
    return result;
  }

  OriginNode._();

  factory OriginNode.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory OriginNode.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'OriginNode',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pos.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'nodeId')
    ..aOM<StoreId>(2, _omitFieldNames ? '' : 'storeId',
        subBuilder: StoreId.create)
    ..aOM<CounterId>(3, _omitFieldNames ? '' : 'counterId',
        subBuilder: CounterId.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OriginNode clone() => OriginNode()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OriginNode copyWith(void Function(OriginNode) updates) =>
      super.copyWith((message) => updates(message as OriginNode)) as OriginNode;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static OriginNode create() => OriginNode._();
  @$core.override
  OriginNode createEmptyInstance() => create();
  static $pb.PbList<OriginNode> createRepeated() => $pb.PbList<OriginNode>();
  @$core.pragma('dart2js:noInline')
  static OriginNode getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<OriginNode>(create);
  static OriginNode? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get nodeId => $_getSZ(0);
  @$pb.TagNumber(1)
  set nodeId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasNodeId() => $_has(0);
  @$pb.TagNumber(1)
  void clearNodeId() => $_clearField(1);

  @$pb.TagNumber(2)
  StoreId get storeId => $_getN(1);
  @$pb.TagNumber(2)
  set storeId(StoreId value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasStoreId() => $_has(1);
  @$pb.TagNumber(2)
  void clearStoreId() => $_clearField(2);
  @$pb.TagNumber(2)
  StoreId ensureStoreId() => $_ensure(1);

  @$pb.TagNumber(3)
  CounterId get counterId => $_getN(2);
  @$pb.TagNumber(3)
  set counterId(CounterId value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasCounterId() => $_has(2);
  @$pb.TagNumber(3)
  void clearCounterId() => $_clearField(3);
  @$pb.TagNumber(3)
  CounterId ensureCounterId() => $_ensure(2);
}

/// LamportClock pairs a logical counter with a node id so that the cloud
/// can order operations across stores without trusting wall-clock time.
/// (Clock-drift handling — see docs/sync-rules.md.)
class LamportClock extends $pb.GeneratedMessage {
  factory LamportClock({
    $fixnum.Int64? counter,
    $core.String? nodeId,
  }) {
    final result = create();
    if (counter != null) result.counter = counter;
    if (nodeId != null) result.nodeId = nodeId;
    return result;
  }

  LamportClock._();

  factory LamportClock.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory LamportClock.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'LamportClock',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pos.v1'),
      createEmptyInstance: create)
    ..a<$fixnum.Int64>(1, _omitFieldNames ? '' : 'counter', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOS(2, _omitFieldNames ? '' : 'nodeId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LamportClock clone() => LamportClock()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LamportClock copyWith(void Function(LamportClock) updates) =>
      super.copyWith((message) => updates(message as LamportClock))
          as LamportClock;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static LamportClock create() => LamportClock._();
  @$core.override
  LamportClock createEmptyInstance() => create();
  static $pb.PbList<LamportClock> createRepeated() =>
      $pb.PbList<LamportClock>();
  @$core.pragma('dart2js:noInline')
  static LamportClock getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<LamportClock>(create);
  static LamportClock? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get counter => $_getI64(0);
  @$pb.TagNumber(1)
  set counter($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCounter() => $_has(0);
  @$pb.TagNumber(1)
  void clearCounter() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get nodeId => $_getSZ(1);
  @$pb.TagNumber(2)
  set nodeId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasNodeId() => $_has(1);
  @$pb.TagNumber(2)
  void clearNodeId() => $_clearField(2);
}

/// SignedEnvelope wraps any operation payload with a detached signature.
/// Required for sync transport — see docs/security-rules.md (signed operations).
class SignedEnvelope extends $pb.GeneratedMessage {
  factory SignedEnvelope({
    $core.List<$core.int>? payload,
    $core.String? algorithm,
    $core.List<$core.int>? signature,
    $core.String? keyId,
  }) {
    final result = create();
    if (payload != null) result.payload = payload;
    if (algorithm != null) result.algorithm = algorithm;
    if (signature != null) result.signature = signature;
    if (keyId != null) result.keyId = keyId;
    return result;
  }

  SignedEnvelope._();

  factory SignedEnvelope.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SignedEnvelope.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SignedEnvelope',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pos.v1'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'payload', $pb.PbFieldType.OY)
    ..aOS(2, _omitFieldNames ? '' : 'algorithm')
    ..a<$core.List<$core.int>>(
        3, _omitFieldNames ? '' : 'signature', $pb.PbFieldType.OY)
    ..aOS(4, _omitFieldNames ? '' : 'keyId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SignedEnvelope clone() => SignedEnvelope()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SignedEnvelope copyWith(void Function(SignedEnvelope) updates) =>
      super.copyWith((message) => updates(message as SignedEnvelope))
          as SignedEnvelope;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SignedEnvelope create() => SignedEnvelope._();
  @$core.override
  SignedEnvelope createEmptyInstance() => create();
  static $pb.PbList<SignedEnvelope> createRepeated() =>
      $pb.PbList<SignedEnvelope>();
  @$core.pragma('dart2js:noInline')
  static SignedEnvelope getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SignedEnvelope>(create);
  static SignedEnvelope? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get payload => $_getN(0);
  @$pb.TagNumber(1)
  set payload($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPayload() => $_has(0);
  @$pb.TagNumber(1)
  void clearPayload() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get algorithm => $_getSZ(1);
  @$pb.TagNumber(2)
  set algorithm($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasAlgorithm() => $_has(1);
  @$pb.TagNumber(2)
  void clearAlgorithm() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.List<$core.int> get signature => $_getN(2);
  @$pb.TagNumber(3)
  set signature($core.List<$core.int> value) => $_setBytes(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSignature() => $_has(2);
  @$pb.TagNumber(3)
  void clearSignature() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get keyId => $_getSZ(3);
  @$pb.TagNumber(4)
  set keyId($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasKeyId() => $_has(3);
  @$pb.TagNumber(4)
  void clearKeyId() => $_clearField(4);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
