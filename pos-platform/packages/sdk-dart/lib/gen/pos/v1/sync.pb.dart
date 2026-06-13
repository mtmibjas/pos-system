// This is a generated file - do not edit.
//
// Generated from pos/v1/sync.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

import '../../google/protobuf/timestamp.pb.dart' as $2;
import 'common.pb.dart' as $0;
import 'events.pb.dart' as $1;
import 'sync.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'sync.pbenum.dart';

/// Operation is the on-disk shape of one row in operations_log
/// (Development Guide §9). It is also the wire shape sent to the cloud.
class Operation extends $pb.GeneratedMessage {
  factory Operation({
    $0.OperationId? operationId,
    $core.String? operationType,
    $core.String? entityType,
    $core.String? entityId,
    $1.EventEnvelope? envelope,
    $2.Timestamp? createdAt,
    $0.OriginNode? origin,
    $core.int? retryCount,
  }) {
    final result = create();
    if (operationId != null) result.operationId = operationId;
    if (operationType != null) result.operationType = operationType;
    if (entityType != null) result.entityType = entityType;
    if (entityId != null) result.entityId = entityId;
    if (envelope != null) result.envelope = envelope;
    if (createdAt != null) result.createdAt = createdAt;
    if (origin != null) result.origin = origin;
    if (retryCount != null) result.retryCount = retryCount;
    return result;
  }

  Operation._();

  factory Operation.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Operation.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Operation',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pos.v1'),
      createEmptyInstance: create)
    ..aOM<$0.OperationId>(1, _omitFieldNames ? '' : 'operationId',
        subBuilder: $0.OperationId.create)
    ..aOS(2, _omitFieldNames ? '' : 'operationType')
    ..aOS(3, _omitFieldNames ? '' : 'entityType')
    ..aOS(4, _omitFieldNames ? '' : 'entityId')
    ..aOM<$1.EventEnvelope>(5, _omitFieldNames ? '' : 'envelope',
        subBuilder: $1.EventEnvelope.create)
    ..aOM<$2.Timestamp>(6, _omitFieldNames ? '' : 'createdAt',
        subBuilder: $2.Timestamp.create)
    ..aOM<$0.OriginNode>(7, _omitFieldNames ? '' : 'origin',
        subBuilder: $0.OriginNode.create)
    ..a<$core.int>(8, _omitFieldNames ? '' : 'retryCount', $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Operation clone() => Operation()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Operation copyWith(void Function(Operation) updates) =>
      super.copyWith((message) => updates(message as Operation)) as Operation;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Operation create() => Operation._();
  @$core.override
  Operation createEmptyInstance() => create();
  static $pb.PbList<Operation> createRepeated() => $pb.PbList<Operation>();
  @$core.pragma('dart2js:noInline')
  static Operation getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Operation>(create);
  static Operation? _defaultInstance;

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
  $core.String get operationType => $_getSZ(1);
  @$pb.TagNumber(2)
  set operationType($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasOperationType() => $_has(1);
  @$pb.TagNumber(2)
  void clearOperationType() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get entityType => $_getSZ(2);
  @$pb.TagNumber(3)
  set entityType($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasEntityType() => $_has(2);
  @$pb.TagNumber(3)
  void clearEntityType() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get entityId => $_getSZ(3);
  @$pb.TagNumber(4)
  set entityId($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasEntityId() => $_has(3);
  @$pb.TagNumber(4)
  void clearEntityId() => $_clearField(4);

  @$pb.TagNumber(5)
  $1.EventEnvelope get envelope => $_getN(4);
  @$pb.TagNumber(5)
  set envelope($1.EventEnvelope value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasEnvelope() => $_has(4);
  @$pb.TagNumber(5)
  void clearEnvelope() => $_clearField(5);
  @$pb.TagNumber(5)
  $1.EventEnvelope ensureEnvelope() => $_ensure(4);

  @$pb.TagNumber(6)
  $2.Timestamp get createdAt => $_getN(5);
  @$pb.TagNumber(6)
  set createdAt($2.Timestamp value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasCreatedAt() => $_has(5);
  @$pb.TagNumber(6)
  void clearCreatedAt() => $_clearField(6);
  @$pb.TagNumber(6)
  $2.Timestamp ensureCreatedAt() => $_ensure(5);

  @$pb.TagNumber(7)
  $0.OriginNode get origin => $_getN(6);
  @$pb.TagNumber(7)
  set origin($0.OriginNode value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasOrigin() => $_has(6);
  @$pb.TagNumber(7)
  void clearOrigin() => $_clearField(7);
  @$pb.TagNumber(7)
  $0.OriginNode ensureOrigin() => $_ensure(6);

  @$pb.TagNumber(8)
  $core.int get retryCount => $_getIZ(7);
  @$pb.TagNumber(8)
  set retryCount($core.int value) => $_setUnsignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasRetryCount() => $_has(7);
  @$pb.TagNumber(8)
  void clearRetryCount() => $_clearField(8);
}

/// SyncBatch — operations that MUST be applied atomically (Development Guide §12).
/// Example: invoice + payment + stock movement go in one batch.
class SyncBatch extends $pb.GeneratedMessage {
  factory SyncBatch({
    $core.String? batchId,
    $0.TenantId? tenantId,
    $core.Iterable<Operation>? operations,
    $2.Timestamp? clientSentAt,
  }) {
    final result = create();
    if (batchId != null) result.batchId = batchId;
    if (tenantId != null) result.tenantId = tenantId;
    if (operations != null) result.operations.addAll(operations);
    if (clientSentAt != null) result.clientSentAt = clientSentAt;
    return result;
  }

  SyncBatch._();

  factory SyncBatch.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SyncBatch.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SyncBatch',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pos.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'batchId')
    ..aOM<$0.TenantId>(2, _omitFieldNames ? '' : 'tenantId',
        subBuilder: $0.TenantId.create)
    ..pc<Operation>(3, _omitFieldNames ? '' : 'operations', $pb.PbFieldType.PM,
        subBuilder: Operation.create)
    ..aOM<$2.Timestamp>(4, _omitFieldNames ? '' : 'clientSentAt',
        subBuilder: $2.Timestamp.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SyncBatch clone() => SyncBatch()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SyncBatch copyWith(void Function(SyncBatch) updates) =>
      super.copyWith((message) => updates(message as SyncBatch)) as SyncBatch;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SyncBatch create() => SyncBatch._();
  @$core.override
  SyncBatch createEmptyInstance() => create();
  static $pb.PbList<SyncBatch> createRepeated() => $pb.PbList<SyncBatch>();
  @$core.pragma('dart2js:noInline')
  static SyncBatch getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SyncBatch>(create);
  static SyncBatch? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get batchId => $_getSZ(0);
  @$pb.TagNumber(1)
  set batchId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasBatchId() => $_has(0);
  @$pb.TagNumber(1)
  void clearBatchId() => $_clearField(1);

  @$pb.TagNumber(2)
  $0.TenantId get tenantId => $_getN(1);
  @$pb.TagNumber(2)
  set tenantId($0.TenantId value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasTenantId() => $_has(1);
  @$pb.TagNumber(2)
  void clearTenantId() => $_clearField(2);
  @$pb.TagNumber(2)
  $0.TenantId ensureTenantId() => $_ensure(1);

  @$pb.TagNumber(3)
  $pb.PbList<Operation> get operations => $_getList(2);

  @$pb.TagNumber(4)
  $2.Timestamp get clientSentAt => $_getN(3);
  @$pb.TagNumber(4)
  set clientSentAt($2.Timestamp value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasClientSentAt() => $_has(3);
  @$pb.TagNumber(4)
  void clearClientSentAt() => $_clearField(4);
  @$pb.TagNumber(4)
  $2.Timestamp ensureClientSentAt() => $_ensure(3);
}

class SyncBatchAck extends $pb.GeneratedMessage {
  factory SyncBatchAck({
    $core.String? batchId,
    SyncBatchAck_Status? status,
    $core.String? message,
    $core.Iterable<OperationAck>? operationAcks,
  }) {
    final result = create();
    if (batchId != null) result.batchId = batchId;
    if (status != null) result.status = status;
    if (message != null) result.message = message;
    if (operationAcks != null) result.operationAcks.addAll(operationAcks);
    return result;
  }

  SyncBatchAck._();

  factory SyncBatchAck.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SyncBatchAck.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SyncBatchAck',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pos.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'batchId')
    ..e<SyncBatchAck_Status>(
        2, _omitFieldNames ? '' : 'status', $pb.PbFieldType.OE,
        defaultOrMaker: SyncBatchAck_Status.STATUS_UNSPECIFIED,
        valueOf: SyncBatchAck_Status.valueOf,
        enumValues: SyncBatchAck_Status.values)
    ..aOS(3, _omitFieldNames ? '' : 'message')
    ..pc<OperationAck>(
        4, _omitFieldNames ? '' : 'operationAcks', $pb.PbFieldType.PM,
        subBuilder: OperationAck.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SyncBatchAck clone() => SyncBatchAck()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SyncBatchAck copyWith(void Function(SyncBatchAck) updates) =>
      super.copyWith((message) => updates(message as SyncBatchAck))
          as SyncBatchAck;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SyncBatchAck create() => SyncBatchAck._();
  @$core.override
  SyncBatchAck createEmptyInstance() => create();
  static $pb.PbList<SyncBatchAck> createRepeated() =>
      $pb.PbList<SyncBatchAck>();
  @$core.pragma('dart2js:noInline')
  static SyncBatchAck getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SyncBatchAck>(create);
  static SyncBatchAck? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get batchId => $_getSZ(0);
  @$pb.TagNumber(1)
  set batchId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasBatchId() => $_has(0);
  @$pb.TagNumber(1)
  void clearBatchId() => $_clearField(1);

  @$pb.TagNumber(2)
  SyncBatchAck_Status get status => $_getN(1);
  @$pb.TagNumber(2)
  set status(SyncBatchAck_Status value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasStatus() => $_has(1);
  @$pb.TagNumber(2)
  void clearStatus() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get message => $_getSZ(2);
  @$pb.TagNumber(3)
  set message($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasMessage() => $_has(2);
  @$pb.TagNumber(3)
  void clearMessage() => $_clearField(3);

  @$pb.TagNumber(4)
  $pb.PbList<OperationAck> get operationAcks => $_getList(3);
}

class OperationAck extends $pb.GeneratedMessage {
  factory OperationAck({
    $0.OperationId? operationId,
    SyncBatchAck_Status? status,
    $core.String? error,
  }) {
    final result = create();
    if (operationId != null) result.operationId = operationId;
    if (status != null) result.status = status;
    if (error != null) result.error = error;
    return result;
  }

  OperationAck._();

  factory OperationAck.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory OperationAck.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'OperationAck',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pos.v1'),
      createEmptyInstance: create)
    ..aOM<$0.OperationId>(1, _omitFieldNames ? '' : 'operationId',
        subBuilder: $0.OperationId.create)
    ..e<SyncBatchAck_Status>(
        2, _omitFieldNames ? '' : 'status', $pb.PbFieldType.OE,
        defaultOrMaker: SyncBatchAck_Status.STATUS_UNSPECIFIED,
        valueOf: SyncBatchAck_Status.valueOf,
        enumValues: SyncBatchAck_Status.values)
    ..aOS(3, _omitFieldNames ? '' : 'error')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OperationAck clone() => OperationAck()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OperationAck copyWith(void Function(OperationAck) updates) =>
      super.copyWith((message) => updates(message as OperationAck))
          as OperationAck;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static OperationAck create() => OperationAck._();
  @$core.override
  OperationAck createEmptyInstance() => create();
  static $pb.PbList<OperationAck> createRepeated() =>
      $pb.PbList<OperationAck>();
  @$core.pragma('dart2js:noInline')
  static OperationAck getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<OperationAck>(create);
  static OperationAck? _defaultInstance;

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
  SyncBatchAck_Status get status => $_getN(1);
  @$pb.TagNumber(2)
  set status(SyncBatchAck_Status value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasStatus() => $_has(1);
  @$pb.TagNumber(2)
  void clearStatus() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get error => $_getSZ(2);
  @$pb.TagNumber(3)
  set error($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasError() => $_has(2);
  @$pb.TagNumber(3)
  void clearError() => $_clearField(3);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
