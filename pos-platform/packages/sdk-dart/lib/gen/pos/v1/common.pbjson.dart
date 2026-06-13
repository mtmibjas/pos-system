// This is a generated file - do not edit.
//
// Generated from pos/v1/common.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use moneyDescriptor instead')
const Money$json = {
  '1': 'Money',
  '2': [
    {'1': 'currency_code', '3': 1, '4': 1, '5': 9, '10': 'currencyCode'},
    {'1': 'units', '3': 2, '4': 1, '5': 3, '10': 'units'},
    {'1': 'nanos', '3': 3, '4': 1, '5': 5, '10': 'nanos'},
  ],
};

/// Descriptor for `Money`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List moneyDescriptor = $convert.base64Decode(
    'CgVNb25leRIjCg1jdXJyZW5jeV9jb2RlGAEgASgJUgxjdXJyZW5jeUNvZGUSFAoFdW5pdHMYAi'
    'ABKANSBXVuaXRzEhQKBW5hbm9zGAMgASgFUgVuYW5vcw==');

@$core.Deprecated('Use tenantIdDescriptor instead')
const TenantId$json = {
  '1': 'TenantId',
  '2': [
    {'1': 'value', '3': 1, '4': 1, '5': 9, '10': 'value'},
  ],
};

/// Descriptor for `TenantId`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List tenantIdDescriptor =
    $convert.base64Decode('CghUZW5hbnRJZBIUCgV2YWx1ZRgBIAEoCVIFdmFsdWU=');

@$core.Deprecated('Use storeIdDescriptor instead')
const StoreId$json = {
  '1': 'StoreId',
  '2': [
    {'1': 'value', '3': 1, '4': 1, '5': 9, '10': 'value'},
  ],
};

/// Descriptor for `StoreId`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List storeIdDescriptor =
    $convert.base64Decode('CgdTdG9yZUlkEhQKBXZhbHVlGAEgASgJUgV2YWx1ZQ==');

@$core.Deprecated('Use counterIdDescriptor instead')
const CounterId$json = {
  '1': 'CounterId',
  '2': [
    {'1': 'value', '3': 1, '4': 1, '5': 9, '10': 'value'},
  ],
};

/// Descriptor for `CounterId`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List counterIdDescriptor =
    $convert.base64Decode('CglDb3VudGVySWQSFAoFdmFsdWUYASABKAlSBXZhbHVl');

@$core.Deprecated('Use userIdDescriptor instead')
const UserId$json = {
  '1': 'UserId',
  '2': [
    {'1': 'value', '3': 1, '4': 1, '5': 9, '10': 'value'},
  ],
};

/// Descriptor for `UserId`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List userIdDescriptor =
    $convert.base64Decode('CgZVc2VySWQSFAoFdmFsdWUYASABKAlSBXZhbHVl');

@$core.Deprecated('Use operationIdDescriptor instead')
const OperationId$json = {
  '1': 'OperationId',
  '2': [
    {'1': 'value', '3': 1, '4': 1, '5': 9, '10': 'value'},
  ],
};

/// Descriptor for `OperationId`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List operationIdDescriptor =
    $convert.base64Decode('CgtPcGVyYXRpb25JZBIUCgV2YWx1ZRgBIAEoCVIFdmFsdWU=');

@$core.Deprecated('Use originNodeDescriptor instead')
const OriginNode$json = {
  '1': 'OriginNode',
  '2': [
    {'1': 'node_id', '3': 1, '4': 1, '5': 9, '10': 'nodeId'},
    {
      '1': 'store_id',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.pos.v1.StoreId',
      '10': 'storeId'
    },
    {
      '1': 'counter_id',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.pos.v1.CounterId',
      '10': 'counterId'
    },
  ],
};

/// Descriptor for `OriginNode`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List originNodeDescriptor = $convert.base64Decode(
    'CgpPcmlnaW5Ob2RlEhcKB25vZGVfaWQYASABKAlSBm5vZGVJZBIqCghzdG9yZV9pZBgCIAEoCz'
    'IPLnBvcy52MS5TdG9yZUlkUgdzdG9yZUlkEjAKCmNvdW50ZXJfaWQYAyABKAsyES5wb3MudjEu'
    'Q291bnRlcklkUgljb3VudGVySWQ=');

@$core.Deprecated('Use lamportClockDescriptor instead')
const LamportClock$json = {
  '1': 'LamportClock',
  '2': [
    {'1': 'counter', '3': 1, '4': 1, '5': 4, '10': 'counter'},
    {'1': 'node_id', '3': 2, '4': 1, '5': 9, '10': 'nodeId'},
  ],
};

/// Descriptor for `LamportClock`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List lamportClockDescriptor = $convert.base64Decode(
    'CgxMYW1wb3J0Q2xvY2sSGAoHY291bnRlchgBIAEoBFIHY291bnRlchIXCgdub2RlX2lkGAIgAS'
    'gJUgZub2RlSWQ=');

@$core.Deprecated('Use signedEnvelopeDescriptor instead')
const SignedEnvelope$json = {
  '1': 'SignedEnvelope',
  '2': [
    {'1': 'payload', '3': 1, '4': 1, '5': 12, '10': 'payload'},
    {'1': 'algorithm', '3': 2, '4': 1, '5': 9, '10': 'algorithm'},
    {'1': 'signature', '3': 3, '4': 1, '5': 12, '10': 'signature'},
    {'1': 'key_id', '3': 4, '4': 1, '5': 9, '10': 'keyId'},
  ],
};

/// Descriptor for `SignedEnvelope`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List signedEnvelopeDescriptor = $convert.base64Decode(
    'Cg5TaWduZWRFbnZlbG9wZRIYCgdwYXlsb2FkGAEgASgMUgdwYXlsb2FkEhwKCWFsZ29yaXRobR'
    'gCIAEoCVIJYWxnb3JpdGhtEhwKCXNpZ25hdHVyZRgDIAEoDFIJc2lnbmF0dXJlEhUKBmtleV9p'
    'ZBgEIAEoCVIFa2V5SWQ=');
