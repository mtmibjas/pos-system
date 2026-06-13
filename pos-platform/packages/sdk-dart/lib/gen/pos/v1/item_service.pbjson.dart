// This is a generated file - do not edit.
//
// Generated from pos/v1/item_service.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

import '../../google/protobuf/timestamp.pbjson.dart' as $1;
import 'common.pbjson.dart' as $0;

@$core.Deprecated('Use itemDescriptor instead')
const Item$json = {
  '1': 'Item',
  '2': [
    {'1': 'sku', '3': 1, '4': 1, '5': 9, '10': 'sku'},
    {'1': 'tenant_id', '3': 2, '4': 1, '5': 9, '10': 'tenantId'},
    {'1': 'name', '3': 3, '4': 1, '5': 9, '10': 'name'},
    {
      '1': 'price',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.pos.v1.Money',
      '10': 'price'
    },
    {'1': 'tax_category_id', '3': 5, '4': 1, '5': 9, '10': 'taxCategoryId'},
    {'1': 'archived', '3': 6, '4': 1, '5': 8, '10': 'archived'},
    {
      '1': 'created_at',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'createdAt'
    },
    {
      '1': 'updated_at',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'updatedAt'
    },
  ],
};

/// Descriptor for `Item`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List itemDescriptor = $convert.base64Decode(
    'CgRJdGVtEhAKA3NrdRgBIAEoCVIDc2t1EhsKCXRlbmFudF9pZBgCIAEoCVIIdGVuYW50SWQSEg'
    'oEbmFtZRgDIAEoCVIEbmFtZRIjCgVwcmljZRgEIAEoCzINLnBvcy52MS5Nb25leVIFcHJpY2US'
    'JgoPdGF4X2NhdGVnb3J5X2lkGAUgASgJUg10YXhDYXRlZ29yeUlkEhoKCGFyY2hpdmVkGAYgAS'
    'gIUghhcmNoaXZlZBI5CgpjcmVhdGVkX2F0GAcgASgLMhouZ29vZ2xlLnByb3RvYnVmLlRpbWVz'
    'dGFtcFIJY3JlYXRlZEF0EjkKCnVwZGF0ZWRfYXQYCCABKAsyGi5nb29nbGUucHJvdG9idWYuVG'
    'ltZXN0YW1wUgl1cGRhdGVkQXQ=');

@$core.Deprecated('Use upsertItemRequestDescriptor instead')
const UpsertItemRequest$json = {
  '1': 'UpsertItemRequest',
  '2': [
    {'1': 'item', '3': 1, '4': 1, '5': 11, '6': '.pos.v1.Item', '10': 'item'},
  ],
};

/// Descriptor for `UpsertItemRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List upsertItemRequestDescriptor = $convert.base64Decode(
    'ChFVcHNlcnRJdGVtUmVxdWVzdBIgCgRpdGVtGAEgASgLMgwucG9zLnYxLkl0ZW1SBGl0ZW0=');

@$core.Deprecated('Use upsertItemResponseDescriptor instead')
const UpsertItemResponse$json = {
  '1': 'UpsertItemResponse',
  '2': [
    {'1': 'item', '3': 1, '4': 1, '5': 11, '6': '.pos.v1.Item', '10': 'item'},
  ],
};

/// Descriptor for `UpsertItemResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List upsertItemResponseDescriptor = $convert.base64Decode(
    'ChJVcHNlcnRJdGVtUmVzcG9uc2USIAoEaXRlbRgBIAEoCzIMLnBvcy52MS5JdGVtUgRpdGVt');

@$core.Deprecated('Use getItemRequestDescriptor instead')
const GetItemRequest$json = {
  '1': 'GetItemRequest',
  '2': [
    {'1': 'sku', '3': 1, '4': 1, '5': 9, '10': 'sku'},
  ],
};

/// Descriptor for `GetItemRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getItemRequestDescriptor =
    $convert.base64Decode('Cg5HZXRJdGVtUmVxdWVzdBIQCgNza3UYASABKAlSA3NrdQ==');

@$core.Deprecated('Use getItemResponseDescriptor instead')
const GetItemResponse$json = {
  '1': 'GetItemResponse',
  '2': [
    {'1': 'item', '3': 1, '4': 1, '5': 11, '6': '.pos.v1.Item', '10': 'item'},
  ],
};

/// Descriptor for `GetItemResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getItemResponseDescriptor = $convert.base64Decode(
    'Cg9HZXRJdGVtUmVzcG9uc2USIAoEaXRlbRgBIAEoCzIMLnBvcy52MS5JdGVtUgRpdGVt');

@$core.Deprecated('Use listItemsRequestDescriptor instead')
const ListItemsRequest$json = {
  '1': 'ListItemsRequest',
  '2': [
    {'1': 'include_archived', '3': 1, '4': 1, '5': 8, '10': 'includeArchived'},
  ],
};

/// Descriptor for `ListItemsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listItemsRequestDescriptor = $convert.base64Decode(
    'ChBMaXN0SXRlbXNSZXF1ZXN0EikKEGluY2x1ZGVfYXJjaGl2ZWQYASABKAhSD2luY2x1ZGVBcm'
    'NoaXZlZA==');

@$core.Deprecated('Use listItemsResponseDescriptor instead')
const ListItemsResponse$json = {
  '1': 'ListItemsResponse',
  '2': [
    {'1': 'items', '3': 1, '4': 3, '5': 11, '6': '.pos.v1.Item', '10': 'items'},
  ],
};

/// Descriptor for `ListItemsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listItemsResponseDescriptor = $convert.base64Decode(
    'ChFMaXN0SXRlbXNSZXNwb25zZRIiCgVpdGVtcxgBIAMoCzIMLnBvcy52MS5JdGVtUgVpdGVtcw'
    '==');

const $core.Map<$core.String, $core.dynamic> ItemServiceBase$json = {
  '1': 'ItemService',
  '2': [
    {
      '1': 'UpsertItem',
      '2': '.pos.v1.UpsertItemRequest',
      '3': '.pos.v1.UpsertItemResponse'
    },
    {
      '1': 'GetItem',
      '2': '.pos.v1.GetItemRequest',
      '3': '.pos.v1.GetItemResponse'
    },
    {
      '1': 'ListItems',
      '2': '.pos.v1.ListItemsRequest',
      '3': '.pos.v1.ListItemsResponse'
    },
  ],
};

@$core.Deprecated('Use itemServiceDescriptor instead')
const $core.Map<$core.String, $core.Map<$core.String, $core.dynamic>>
    ItemServiceBase$messageJson = {
  '.pos.v1.UpsertItemRequest': UpsertItemRequest$json,
  '.pos.v1.Item': Item$json,
  '.pos.v1.Money': $0.Money$json,
  '.google.protobuf.Timestamp': $1.Timestamp$json,
  '.pos.v1.UpsertItemResponse': UpsertItemResponse$json,
  '.pos.v1.GetItemRequest': GetItemRequest$json,
  '.pos.v1.GetItemResponse': GetItemResponse$json,
  '.pos.v1.ListItemsRequest': ListItemsRequest$json,
  '.pos.v1.ListItemsResponse': ListItemsResponse$json,
};

/// Descriptor for `ItemService`. Decode as a `google.protobuf.ServiceDescriptorProto`.
final $typed_data.Uint8List itemServiceDescriptor = $convert.base64Decode(
    'CgtJdGVtU2VydmljZRJDCgpVcHNlcnRJdGVtEhkucG9zLnYxLlVwc2VydEl0ZW1SZXF1ZXN0Gh'
    'oucG9zLnYxLlVwc2VydEl0ZW1SZXNwb25zZRI6CgdHZXRJdGVtEhYucG9zLnYxLkdldEl0ZW1S'
    'ZXF1ZXN0GhcucG9zLnYxLkdldEl0ZW1SZXNwb25zZRJACglMaXN0SXRlbXMSGC5wb3MudjEuTG'
    'lzdEl0ZW1zUmVxdWVzdBoZLnBvcy52MS5MaXN0SXRlbXNSZXNwb25zZQ==');
