// This is a generated file - do not edit.
//
// Generated from pos/v1/tax_admin_service.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use taxCategoryDescriptor instead')
const TaxCategory$json = {
  '1': 'TaxCategory',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'tenant_id', '3': 3, '4': 1, '5': 9, '10': 'tenantId'},
    {
      '1': 'price_includes_tax',
      '3': 4,
      '4': 1,
      '5': 8,
      '10': 'priceIncludesTax'
    },
    {
      '1': 'components',
      '3': 5,
      '4': 3,
      '5': 11,
      '6': '.pos.v1.TaxComponent',
      '10': 'components'
    },
  ],
};

/// Descriptor for `TaxCategory`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List taxCategoryDescriptor = $convert.base64Decode(
    'CgtUYXhDYXRlZ29yeRIOCgJpZBgBIAEoCVICaWQSEgoEbmFtZRgCIAEoCVIEbmFtZRIbCgl0ZW'
    '5hbnRfaWQYAyABKAlSCHRlbmFudElkEiwKEnByaWNlX2luY2x1ZGVzX3RheBgEIAEoCFIQcHJp'
    'Y2VJbmNsdWRlc1RheBI0Cgpjb21wb25lbnRzGAUgAygLMhQucG9zLnYxLlRheENvbXBvbmVudF'
    'IKY29tcG9uZW50cw==');

@$core.Deprecated('Use taxComponentDescriptor instead')
const TaxComponent$json = {
  '1': 'TaxComponent',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'tax_category_id', '3': 2, '4': 1, '5': 9, '10': 'taxCategoryId'},
    {'1': 'name', '3': 3, '4': 1, '5': 9, '10': 'name'},
    {'1': 'rate_basis_points', '3': 4, '4': 1, '5': 5, '10': 'rateBasisPoints'},
    {'1': 'sort_order', '3': 5, '4': 1, '5': 5, '10': 'sortOrder'},
  ],
};

/// Descriptor for `TaxComponent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List taxComponentDescriptor = $convert.base64Decode(
    'CgxUYXhDb21wb25lbnQSDgoCaWQYASABKAlSAmlkEiYKD3RheF9jYXRlZ29yeV9pZBgCIAEoCV'
    'INdGF4Q2F0ZWdvcnlJZBISCgRuYW1lGAMgASgJUgRuYW1lEioKEXJhdGVfYmFzaXNfcG9pbnRz'
    'GAQgASgFUg9yYXRlQmFzaXNQb2ludHMSHQoKc29ydF9vcmRlchgFIAEoBVIJc29ydE9yZGVy');

@$core.Deprecated('Use upsertTaxCategoryRequestDescriptor instead')
const UpsertTaxCategoryRequest$json = {
  '1': 'UpsertTaxCategoryRequest',
  '2': [
    {
      '1': 'category',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.pos.v1.TaxCategory',
      '10': 'category'
    },
  ],
};

/// Descriptor for `UpsertTaxCategoryRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List upsertTaxCategoryRequestDescriptor =
    $convert.base64Decode(
        'ChhVcHNlcnRUYXhDYXRlZ29yeVJlcXVlc3QSLwoIY2F0ZWdvcnkYASABKAsyEy5wb3MudjEuVG'
        'F4Q2F0ZWdvcnlSCGNhdGVnb3J5');

@$core.Deprecated('Use upsertTaxCategoryResponseDescriptor instead')
const UpsertTaxCategoryResponse$json = {
  '1': 'UpsertTaxCategoryResponse',
  '2': [
    {
      '1': 'category',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.pos.v1.TaxCategory',
      '10': 'category'
    },
  ],
};

/// Descriptor for `UpsertTaxCategoryResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List upsertTaxCategoryResponseDescriptor =
    $convert.base64Decode(
        'ChlVcHNlcnRUYXhDYXRlZ29yeVJlc3BvbnNlEi8KCGNhdGVnb3J5GAEgASgLMhMucG9zLnYxLl'
        'RheENhdGVnb3J5UghjYXRlZ29yeQ==');

@$core.Deprecated('Use upsertTaxComponentRequestDescriptor instead')
const UpsertTaxComponentRequest$json = {
  '1': 'UpsertTaxComponentRequest',
  '2': [
    {
      '1': 'component',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.pos.v1.TaxComponent',
      '10': 'component'
    },
  ],
};

/// Descriptor for `UpsertTaxComponentRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List upsertTaxComponentRequestDescriptor =
    $convert.base64Decode(
        'ChlVcHNlcnRUYXhDb21wb25lbnRSZXF1ZXN0EjIKCWNvbXBvbmVudBgBIAEoCzIULnBvcy52MS'
        '5UYXhDb21wb25lbnRSCWNvbXBvbmVudA==');

@$core.Deprecated('Use upsertTaxComponentResponseDescriptor instead')
const UpsertTaxComponentResponse$json = {
  '1': 'UpsertTaxComponentResponse',
  '2': [
    {
      '1': 'component',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.pos.v1.TaxComponent',
      '10': 'component'
    },
  ],
};

/// Descriptor for `UpsertTaxComponentResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List upsertTaxComponentResponseDescriptor =
    $convert.base64Decode(
        'ChpVcHNlcnRUYXhDb21wb25lbnRSZXNwb25zZRIyCgljb21wb25lbnQYASABKAsyFC5wb3Mudj'
        'EuVGF4Q29tcG9uZW50Ugljb21wb25lbnQ=');

@$core.Deprecated('Use getTaxCategoryRequestDescriptor instead')
const GetTaxCategoryRequest$json = {
  '1': 'GetTaxCategoryRequest',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
  ],
};

/// Descriptor for `GetTaxCategoryRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getTaxCategoryRequestDescriptor = $convert
    .base64Decode('ChVHZXRUYXhDYXRlZ29yeVJlcXVlc3QSDgoCaWQYASABKAlSAmlk');

@$core.Deprecated('Use getTaxCategoryResponseDescriptor instead')
const GetTaxCategoryResponse$json = {
  '1': 'GetTaxCategoryResponse',
  '2': [
    {
      '1': 'category',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.pos.v1.TaxCategory',
      '10': 'category'
    },
  ],
};

/// Descriptor for `GetTaxCategoryResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getTaxCategoryResponseDescriptor =
    $convert.base64Decode(
        'ChZHZXRUYXhDYXRlZ29yeVJlc3BvbnNlEi8KCGNhdGVnb3J5GAEgASgLMhMucG9zLnYxLlRheE'
        'NhdGVnb3J5UghjYXRlZ29yeQ==');

const $core.Map<$core.String, $core.dynamic> TaxAdminServiceBase$json = {
  '1': 'TaxAdminService',
  '2': [
    {
      '1': 'UpsertTaxCategory',
      '2': '.pos.v1.UpsertTaxCategoryRequest',
      '3': '.pos.v1.UpsertTaxCategoryResponse'
    },
    {
      '1': 'UpsertTaxComponent',
      '2': '.pos.v1.UpsertTaxComponentRequest',
      '3': '.pos.v1.UpsertTaxComponentResponse'
    },
    {
      '1': 'GetTaxCategory',
      '2': '.pos.v1.GetTaxCategoryRequest',
      '3': '.pos.v1.GetTaxCategoryResponse'
    },
  ],
};

@$core.Deprecated('Use taxAdminServiceDescriptor instead')
const $core.Map<$core.String, $core.Map<$core.String, $core.dynamic>>
    TaxAdminServiceBase$messageJson = {
  '.pos.v1.UpsertTaxCategoryRequest': UpsertTaxCategoryRequest$json,
  '.pos.v1.TaxCategory': TaxCategory$json,
  '.pos.v1.TaxComponent': TaxComponent$json,
  '.pos.v1.UpsertTaxCategoryResponse': UpsertTaxCategoryResponse$json,
  '.pos.v1.UpsertTaxComponentRequest': UpsertTaxComponentRequest$json,
  '.pos.v1.UpsertTaxComponentResponse': UpsertTaxComponentResponse$json,
  '.pos.v1.GetTaxCategoryRequest': GetTaxCategoryRequest$json,
  '.pos.v1.GetTaxCategoryResponse': GetTaxCategoryResponse$json,
};

/// Descriptor for `TaxAdminService`. Decode as a `google.protobuf.ServiceDescriptorProto`.
final $typed_data.Uint8List taxAdminServiceDescriptor = $convert.base64Decode(
    'Cg9UYXhBZG1pblNlcnZpY2USWAoRVXBzZXJ0VGF4Q2F0ZWdvcnkSIC5wb3MudjEuVXBzZXJ0VG'
    'F4Q2F0ZWdvcnlSZXF1ZXN0GiEucG9zLnYxLlVwc2VydFRheENhdGVnb3J5UmVzcG9uc2USWwoS'
    'VXBzZXJ0VGF4Q29tcG9uZW50EiEucG9zLnYxLlVwc2VydFRheENvbXBvbmVudFJlcXVlc3QaIi'
    '5wb3MudjEuVXBzZXJ0VGF4Q29tcG9uZW50UmVzcG9uc2USTwoOR2V0VGF4Q2F0ZWdvcnkSHS5w'
    'b3MudjEuR2V0VGF4Q2F0ZWdvcnlSZXF1ZXN0Gh4ucG9zLnYxLkdldFRheENhdGVnb3J5UmVzcG'
    '9uc2U=');
