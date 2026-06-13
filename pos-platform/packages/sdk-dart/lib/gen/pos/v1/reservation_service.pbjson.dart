// This is a generated file - do not edit.
//
// Generated from pos/v1/reservation_service.proto.

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

@$core.Deprecated('Use reserveRequestDescriptor instead')
const ReserveRequest$json = {
  '1': 'ReserveRequest',
  '2': [
    {'1': 'reservation_id', '3': 1, '4': 1, '5': 9, '10': 'reservationId'},
    {'1': 'sku', '3': 2, '4': 1, '5': 9, '10': 'sku'},
    {
      '1': 'store_id',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.pos.v1.StoreId',
      '10': 'storeId'
    },
    {
      '1': 'counter_id',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.pos.v1.CounterId',
      '10': 'counterId'
    },
    {'1': 'quantity', '3': 5, '4': 1, '5': 3, '10': 'quantity'},
  ],
};

/// Descriptor for `ReserveRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List reserveRequestDescriptor = $convert.base64Decode(
    'Cg5SZXNlcnZlUmVxdWVzdBIlCg5yZXNlcnZhdGlvbl9pZBgBIAEoCVINcmVzZXJ2YXRpb25JZB'
    'IQCgNza3UYAiABKAlSA3NrdRIqCghzdG9yZV9pZBgDIAEoCzIPLnBvcy52MS5TdG9yZUlkUgdz'
    'dG9yZUlkEjAKCmNvdW50ZXJfaWQYBCABKAsyES5wb3MudjEuQ291bnRlcklkUgljb3VudGVySW'
    'QSGgoIcXVhbnRpdHkYBSABKANSCHF1YW50aXR5');

@$core.Deprecated('Use reserveResponseDescriptor instead')
const ReserveResponse$json = {
  '1': 'ReserveResponse',
  '2': [
    {
      '1': 'reservation',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.pos.v1.Reservation',
      '10': 'reservation'
    },
    {'1': 'available_qty', '3': 2, '4': 1, '5': 3, '10': 'availableQty'},
  ],
};

/// Descriptor for `ReserveResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List reserveResponseDescriptor = $convert.base64Decode(
    'Cg9SZXNlcnZlUmVzcG9uc2USNQoLcmVzZXJ2YXRpb24YASABKAsyEy5wb3MudjEuUmVzZXJ2YX'
    'Rpb25SC3Jlc2VydmF0aW9uEiMKDWF2YWlsYWJsZV9xdHkYAiABKANSDGF2YWlsYWJsZVF0eQ==');

@$core.Deprecated('Use releaseRequestDescriptor instead')
const ReleaseRequest$json = {
  '1': 'ReleaseRequest',
  '2': [
    {'1': 'reservation_id', '3': 1, '4': 1, '5': 9, '10': 'reservationId'},
  ],
};

/// Descriptor for `ReleaseRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List releaseRequestDescriptor = $convert.base64Decode(
    'Cg5SZWxlYXNlUmVxdWVzdBIlCg5yZXNlcnZhdGlvbl9pZBgBIAEoCVINcmVzZXJ2YXRpb25JZA'
    '==');

@$core.Deprecated('Use releaseResponseDescriptor instead')
const ReleaseResponse$json = {
  '1': 'ReleaseResponse',
  '2': [
    {
      '1': 'reservation',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.pos.v1.Reservation',
      '10': 'reservation'
    },
  ],
};

/// Descriptor for `ReleaseResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List releaseResponseDescriptor = $convert.base64Decode(
    'Cg9SZWxlYXNlUmVzcG9uc2USNQoLcmVzZXJ2YXRpb24YASABKAsyEy5wb3MudjEuUmVzZXJ2YX'
    'Rpb25SC3Jlc2VydmF0aW9u');

@$core.Deprecated('Use reservationDescriptor instead')
const Reservation$json = {
  '1': 'Reservation',
  '2': [
    {'1': 'reservation_id', '3': 1, '4': 1, '5': 9, '10': 'reservationId'},
    {'1': 'sku', '3': 2, '4': 1, '5': 9, '10': 'sku'},
    {
      '1': 'store_id',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.pos.v1.StoreId',
      '10': 'storeId'
    },
    {
      '1': 'counter_id',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.pos.v1.CounterId',
      '10': 'counterId'
    },
    {'1': 'quantity', '3': 5, '4': 1, '5': 3, '10': 'quantity'},
    {
      '1': 'created_at',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'createdAt'
    },
    {
      '1': 'expires_at',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'expiresAt'
    },
    {'1': 'status', '3': 8, '4': 1, '5': 9, '10': 'status'},
  ],
};

/// Descriptor for `Reservation`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List reservationDescriptor = $convert.base64Decode(
    'CgtSZXNlcnZhdGlvbhIlCg5yZXNlcnZhdGlvbl9pZBgBIAEoCVINcmVzZXJ2YXRpb25JZBIQCg'
    'Nza3UYAiABKAlSA3NrdRIqCghzdG9yZV9pZBgDIAEoCzIPLnBvcy52MS5TdG9yZUlkUgdzdG9y'
    'ZUlkEjAKCmNvdW50ZXJfaWQYBCABKAsyES5wb3MudjEuQ291bnRlcklkUgljb3VudGVySWQSGg'
    'oIcXVhbnRpdHkYBSABKANSCHF1YW50aXR5EjkKCmNyZWF0ZWRfYXQYBiABKAsyGi5nb29nbGUu'
    'cHJvdG9idWYuVGltZXN0YW1wUgljcmVhdGVkQXQSOQoKZXhwaXJlc19hdBgHIAEoCzIaLmdvb2'
    'dsZS5wcm90b2J1Zi5UaW1lc3RhbXBSCWV4cGlyZXNBdBIWCgZzdGF0dXMYCCABKAlSBnN0YXR1'
    'cw==');

const $core.Map<$core.String, $core.dynamic> ReservationServiceBase$json = {
  '1': 'ReservationService',
  '2': [
    {
      '1': 'Reserve',
      '2': '.pos.v1.ReserveRequest',
      '3': '.pos.v1.ReserveResponse'
    },
    {
      '1': 'Release',
      '2': '.pos.v1.ReleaseRequest',
      '3': '.pos.v1.ReleaseResponse'
    },
  ],
};

@$core.Deprecated('Use reservationServiceDescriptor instead')
const $core.Map<$core.String, $core.Map<$core.String, $core.dynamic>>
    ReservationServiceBase$messageJson = {
  '.pos.v1.ReserveRequest': ReserveRequest$json,
  '.pos.v1.StoreId': $0.StoreId$json,
  '.pos.v1.CounterId': $0.CounterId$json,
  '.pos.v1.ReserveResponse': ReserveResponse$json,
  '.pos.v1.Reservation': Reservation$json,
  '.google.protobuf.Timestamp': $1.Timestamp$json,
  '.pos.v1.ReleaseRequest': ReleaseRequest$json,
  '.pos.v1.ReleaseResponse': ReleaseResponse$json,
};

/// Descriptor for `ReservationService`. Decode as a `google.protobuf.ServiceDescriptorProto`.
final $typed_data.Uint8List reservationServiceDescriptor = $convert.base64Decode(
    'ChJSZXNlcnZhdGlvblNlcnZpY2USOgoHUmVzZXJ2ZRIWLnBvcy52MS5SZXNlcnZlUmVxdWVzdB'
    'oXLnBvcy52MS5SZXNlcnZlUmVzcG9uc2USOgoHUmVsZWFzZRIWLnBvcy52MS5SZWxlYXNlUmVx'
    'dWVzdBoXLnBvcy52MS5SZWxlYXNlUmVzcG9uc2U=');
