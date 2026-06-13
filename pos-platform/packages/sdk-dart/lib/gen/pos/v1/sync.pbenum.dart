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

class SyncBatchAck_Status extends $pb.ProtobufEnum {
  static const SyncBatchAck_Status STATUS_UNSPECIFIED =
      SyncBatchAck_Status._(0, _omitEnumNames ? '' : 'STATUS_UNSPECIFIED');
  static const SyncBatchAck_Status STATUS_APPLIED =
      SyncBatchAck_Status._(1, _omitEnumNames ? '' : 'STATUS_APPLIED');
  static const SyncBatchAck_Status STATUS_DUPLICATE =
      SyncBatchAck_Status._(2, _omitEnumNames ? '' : 'STATUS_DUPLICATE');
  static const SyncBatchAck_Status STATUS_REJECTED =
      SyncBatchAck_Status._(3, _omitEnumNames ? '' : 'STATUS_REJECTED');
  static const SyncBatchAck_Status STATUS_RETRY_LATER =
      SyncBatchAck_Status._(4, _omitEnumNames ? '' : 'STATUS_RETRY_LATER');

  static const $core.List<SyncBatchAck_Status> values = <SyncBatchAck_Status>[
    STATUS_UNSPECIFIED,
    STATUS_APPLIED,
    STATUS_DUPLICATE,
    STATUS_REJECTED,
    STATUS_RETRY_LATER,
  ];

  static final $core.List<SyncBatchAck_Status?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 4);
  static SyncBatchAck_Status? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const SyncBatchAck_Status._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
