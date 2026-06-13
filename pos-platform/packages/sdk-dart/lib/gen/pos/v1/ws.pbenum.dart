// This is a generated file - do not edit.
//
// Generated from pos/v1/ws.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class CartUpdate_State extends $pb.ProtobufEnum {
  static const CartUpdate_State STATE_UNSPECIFIED =
      CartUpdate_State._(0, _omitEnumNames ? '' : 'STATE_UNSPECIFIED');
  static const CartUpdate_State STATE_OPEN =
      CartUpdate_State._(1, _omitEnumNames ? '' : 'STATE_OPEN');
  static const CartUpdate_State STATE_PARKED =
      CartUpdate_State._(2, _omitEnumNames ? '' : 'STATE_PARKED');
  static const CartUpdate_State STATE_CLOSED =
      CartUpdate_State._(3, _omitEnumNames ? '' : 'STATE_CLOSED');

  static const $core.List<CartUpdate_State> values = <CartUpdate_State>[
    STATE_UNSPECIFIED,
    STATE_OPEN,
    STATE_PARKED,
    STATE_CLOSED,
  ];

  static final $core.List<CartUpdate_State?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static CartUpdate_State? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const CartUpdate_State._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
