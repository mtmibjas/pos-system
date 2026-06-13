// This is a generated file - do not edit.
//
// Generated from pos/v1/inventory_service.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

import 'common.pbjson.dart' as $0;

@$core.Deprecated('Use listOnHandRequestDescriptor instead')
const ListOnHandRequest$json = {
  '1': 'ListOnHandRequest',
  '2': [
    {
      '1': 'store_id',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.pos.v1.StoreId',
      '10': 'storeId'
    },
  ],
};

/// Descriptor for `ListOnHandRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listOnHandRequestDescriptor = $convert.base64Decode(
    'ChFMaXN0T25IYW5kUmVxdWVzdBIqCghzdG9yZV9pZBgBIAEoCzIPLnBvcy52MS5TdG9yZUlkUg'
    'dzdG9yZUlk');

@$core.Deprecated('Use listOnHandResponseDescriptor instead')
const ListOnHandResponse$json = {
  '1': 'ListOnHandResponse',
  '2': [
    {
      '1': 'rows',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.pos.v1.OnHandRow',
      '10': 'rows'
    },
  ],
};

/// Descriptor for `ListOnHandResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listOnHandResponseDescriptor = $convert.base64Decode(
    'ChJMaXN0T25IYW5kUmVzcG9uc2USJQoEcm93cxgBIAMoCzIRLnBvcy52MS5PbkhhbmRSb3dSBH'
    'Jvd3M=');

@$core.Deprecated('Use onHandRowDescriptor instead')
const OnHandRow$json = {
  '1': 'OnHandRow',
  '2': [
    {'1': 'sku', '3': 1, '4': 1, '5': 9, '10': 'sku'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {
      '1': 'price',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.pos.v1.Money',
      '10': 'price'
    },
    {'1': 'on_hand', '3': 4, '4': 1, '5': 3, '10': 'onHand'},
  ],
};

/// Descriptor for `OnHandRow`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List onHandRowDescriptor = $convert.base64Decode(
    'CglPbkhhbmRSb3cSEAoDc2t1GAEgASgJUgNza3USEgoEbmFtZRgCIAEoCVIEbmFtZRIjCgVwcm'
    'ljZRgDIAEoCzINLnBvcy52MS5Nb25leVIFcHJpY2USFwoHb25faGFuZBgEIAEoA1IGb25IYW5k');

const $core.Map<$core.String, $core.dynamic> InventoryServiceBase$json = {
  '1': 'InventoryService',
  '2': [
    {
      '1': 'ListOnHand',
      '2': '.pos.v1.ListOnHandRequest',
      '3': '.pos.v1.ListOnHandResponse'
    },
  ],
};

@$core.Deprecated('Use inventoryServiceDescriptor instead')
const $core.Map<$core.String, $core.Map<$core.String, $core.dynamic>>
    InventoryServiceBase$messageJson = {
  '.pos.v1.ListOnHandRequest': ListOnHandRequest$json,
  '.pos.v1.StoreId': $0.StoreId$json,
  '.pos.v1.ListOnHandResponse': ListOnHandResponse$json,
  '.pos.v1.OnHandRow': OnHandRow$json,
  '.pos.v1.Money': $0.Money$json,
};

/// Descriptor for `InventoryService`. Decode as a `google.protobuf.ServiceDescriptorProto`.
final $typed_data.Uint8List inventoryServiceDescriptor = $convert.base64Decode(
    'ChBJbnZlbnRvcnlTZXJ2aWNlEkMKCkxpc3RPbkhhbmQSGS5wb3MudjEuTGlzdE9uSGFuZFJlcX'
    'Vlc3QaGi5wb3MudjEuTGlzdE9uSGFuZFJlc3BvbnNl');
