// This is a generated file - do not edit.
//
// Generated from pos/v1/ws.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use wsMessageDescriptor instead')
const WsMessage$json = {
  '1': 'WsMessage',
  '2': [
    {'1': 'message_id', '3': 1, '4': 1, '5': 9, '10': 'messageId'},
    {
      '1': 'sent_at',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'sentAt'
    },
    {
      '1': 'hello',
      '3': 10,
      '4': 1,
      '5': 11,
      '6': '.pos.v1.Hello',
      '9': 0,
      '10': 'hello'
    },
    {
      '1': 'subscribe',
      '3': 11,
      '4': 1,
      '5': 11,
      '6': '.pos.v1.Subscribe',
      '9': 0,
      '10': 'subscribe'
    },
    {
      '1': 'event',
      '3': 12,
      '4': 1,
      '5': 11,
      '6': '.pos.v1.EventEnvelope',
      '9': 0,
      '10': 'event'
    },
    {
      '1': 'inventory',
      '3': 13,
      '4': 1,
      '5': 11,
      '6': '.pos.v1.InventoryUpdate',
      '9': 0,
      '10': 'inventory'
    },
    {
      '1': 'cart',
      '3': 14,
      '4': 1,
      '5': 11,
      '6': '.pos.v1.CartUpdate',
      '9': 0,
      '10': 'cart'
    },
    {
      '1': 'heartbeat',
      '3': 15,
      '4': 1,
      '5': 11,
      '6': '.pos.v1.Heartbeat',
      '9': 0,
      '10': 'heartbeat'
    },
    {
      '1': 'goodbye',
      '3': 16,
      '4': 1,
      '5': 11,
      '6': '.pos.v1.Goodbye',
      '9': 0,
      '10': 'goodbye'
    },
  ],
  '8': [
    {'1': 'body'},
  ],
};

/// Descriptor for `WsMessage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List wsMessageDescriptor = $convert.base64Decode(
    'CglXc01lc3NhZ2USHQoKbWVzc2FnZV9pZBgBIAEoCVIJbWVzc2FnZUlkEjMKB3NlbnRfYXQYAi'
    'ABKAsyGi5nb29nbGUucHJvdG9idWYuVGltZXN0YW1wUgZzZW50QXQSJQoFaGVsbG8YCiABKAsy'
    'DS5wb3MudjEuSGVsbG9IAFIFaGVsbG8SMQoJc3Vic2NyaWJlGAsgASgLMhEucG9zLnYxLlN1Yn'
    'NjcmliZUgAUglzdWJzY3JpYmUSLQoFZXZlbnQYDCABKAsyFS5wb3MudjEuRXZlbnRFbnZlbG9w'
    'ZUgAUgVldmVudBI3CglpbnZlbnRvcnkYDSABKAsyFy5wb3MudjEuSW52ZW50b3J5VXBkYXRlSA'
    'BSCWludmVudG9yeRIoCgRjYXJ0GA4gASgLMhIucG9zLnYxLkNhcnRVcGRhdGVIAFIEY2FydBIx'
    'CgloZWFydGJlYXQYDyABKAsyES5wb3MudjEuSGVhcnRiZWF0SABSCWhlYXJ0YmVhdBIrCgdnb2'
    '9kYnllGBAgASgLMg8ucG9zLnYxLkdvb2RieWVIAFIHZ29vZGJ5ZUIGCgRib2R5');

@$core.Deprecated('Use helloDescriptor instead')
const Hello$json = {
  '1': 'Hello',
  '2': [
    {
      '1': 'counter_id',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.pos.v1.CounterId',
      '10': 'counterId'
    },
    {
      '1': 'user_id',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.pos.v1.UserId',
      '10': 'userId'
    },
    {
      '1': 'last_seen_message_id',
      '3': 3,
      '4': 1,
      '5': 9,
      '10': 'lastSeenMessageId'
    },
  ],
};

/// Descriptor for `Hello`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List helloDescriptor = $convert.base64Decode(
    'CgVIZWxsbxIwCgpjb3VudGVyX2lkGAEgASgLMhEucG9zLnYxLkNvdW50ZXJJZFIJY291bnRlck'
    'lkEicKB3VzZXJfaWQYAiABKAsyDi5wb3MudjEuVXNlcklkUgZ1c2VySWQSLwoUbGFzdF9zZWVu'
    'X21lc3NhZ2VfaWQYAyABKAlSEWxhc3RTZWVuTWVzc2FnZUlk');

@$core.Deprecated('Use subscribeDescriptor instead')
const Subscribe$json = {
  '1': 'Subscribe',
  '2': [
    {'1': 'topics', '3': 1, '4': 3, '5': 9, '10': 'topics'},
  ],
};

/// Descriptor for `Subscribe`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List subscribeDescriptor =
    $convert.base64Decode('CglTdWJzY3JpYmUSFgoGdG9waWNzGAEgAygJUgZ0b3BpY3M=');

@$core.Deprecated('Use inventoryUpdateDescriptor instead')
const InventoryUpdate$json = {
  '1': 'InventoryUpdate',
  '2': [
    {'1': 'sku', '3': 1, '4': 1, '5': 9, '10': 'sku'},
    {'1': 'quantity_on_hand', '3': 2, '4': 1, '5': 3, '10': 'quantityOnHand'},
    {
      '1': 'as_of',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'asOf'
    },
  ],
};

/// Descriptor for `InventoryUpdate`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List inventoryUpdateDescriptor = $convert.base64Decode(
    'Cg9JbnZlbnRvcnlVcGRhdGUSEAoDc2t1GAEgASgJUgNza3USKAoQcXVhbnRpdHlfb25faGFuZB'
    'gCIAEoA1IOcXVhbnRpdHlPbkhhbmQSLwoFYXNfb2YYAyABKAsyGi5nb29nbGUucHJvdG9idWYu'
    'VGltZXN0YW1wUgRhc09m');

@$core.Deprecated('Use cartUpdateDescriptor instead')
const CartUpdate$json = {
  '1': 'CartUpdate',
  '2': [
    {'1': 'cart_id', '3': 1, '4': 1, '5': 9, '10': 'cartId'},
    {
      '1': 'counter_id',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.pos.v1.CounterId',
      '10': 'counterId'
    },
    {
      '1': 'state',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.pos.v1.CartUpdate.State',
      '10': 'state'
    },
    {'1': 'line_count', '3': 4, '4': 1, '5': 13, '10': 'lineCount'},
  ],
  '4': [CartUpdate_State$json],
};

@$core.Deprecated('Use cartUpdateDescriptor instead')
const CartUpdate_State$json = {
  '1': 'State',
  '2': [
    {'1': 'STATE_UNSPECIFIED', '2': 0},
    {'1': 'STATE_OPEN', '2': 1},
    {'1': 'STATE_PARKED', '2': 2},
    {'1': 'STATE_CLOSED', '2': 3},
  ],
};

/// Descriptor for `CartUpdate`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List cartUpdateDescriptor = $convert.base64Decode(
    'CgpDYXJ0VXBkYXRlEhcKB2NhcnRfaWQYASABKAlSBmNhcnRJZBIwCgpjb3VudGVyX2lkGAIgAS'
    'gLMhEucG9zLnYxLkNvdW50ZXJJZFIJY291bnRlcklkEi4KBXN0YXRlGAMgASgOMhgucG9zLnYx'
    'LkNhcnRVcGRhdGUuU3RhdGVSBXN0YXRlEh0KCmxpbmVfY291bnQYBCABKA1SCWxpbmVDb3VudC'
    'JSCgVTdGF0ZRIVChFTVEFURV9VTlNQRUNJRklFRBAAEg4KClNUQVRFX09QRU4QARIQCgxTVEFU'
    'RV9QQVJLRUQQAhIQCgxTVEFURV9DTE9TRUQQAw==');

@$core.Deprecated('Use heartbeatDescriptor instead')
const Heartbeat$json = {
  '1': 'Heartbeat',
  '2': [
    {'1': 'seq', '3': 1, '4': 1, '5': 4, '10': 'seq'},
  ],
};

/// Descriptor for `Heartbeat`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List heartbeatDescriptor =
    $convert.base64Decode('CglIZWFydGJlYXQSEAoDc2VxGAEgASgEUgNzZXE=');

@$core.Deprecated('Use goodbyeDescriptor instead')
const Goodbye$json = {
  '1': 'Goodbye',
  '2': [
    {'1': 'reason', '3': 1, '4': 1, '5': 9, '10': 'reason'},
  ],
};

/// Descriptor for `Goodbye`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List goodbyeDescriptor =
    $convert.base64Decode('CgdHb29kYnllEhYKBnJlYXNvbhgBIAEoCVIGcmVhc29u');
