// This is a generated file - do not edit.
//
// Generated from pos/v1/events.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use eventEnvelopeDescriptor instead')
const EventEnvelope$json = {
  '1': 'EventEnvelope',
  '2': [
    {
      '1': 'operation_id',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.pos.v1.OperationId',
      '10': 'operationId'
    },
    {'1': 'event_type', '3': 2, '4': 1, '5': 9, '10': 'eventType'},
    {'1': 'schema_version', '3': 3, '4': 1, '5': 13, '10': 'schemaVersion'},
    {
      '1': 'tenant_id',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.pos.v1.TenantId',
      '10': 'tenantId'
    },
    {
      '1': 'origin',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.pos.v1.OriginNode',
      '10': 'origin'
    },
    {
      '1': 'clock',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.pos.v1.LamportClock',
      '10': 'clock'
    },
    {
      '1': 'occurred_at',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'occurredAt'
    },
    {
      '1': 'sale_created',
      '3': 10,
      '4': 1,
      '5': 11,
      '6': '.pos.v1.SaleCreated',
      '9': 0,
      '10': 'saleCreated'
    },
    {
      '1': 'payment_added',
      '3': 11,
      '4': 1,
      '5': 11,
      '6': '.pos.v1.PaymentAdded',
      '9': 0,
      '10': 'paymentAdded'
    },
    {
      '1': 'payment_refunded',
      '3': 12,
      '4': 1,
      '5': 11,
      '6': '.pos.v1.PaymentRefunded',
      '9': 0,
      '10': 'paymentRefunded'
    },
    {
      '1': 'inventory_adjusted',
      '3': 13,
      '4': 1,
      '5': 11,
      '6': '.pos.v1.InventoryAdjusted',
      '9': 0,
      '10': 'inventoryAdjusted'
    },
    {
      '1': 'stock_transferred',
      '3': 14,
      '4': 1,
      '5': 11,
      '6': '.pos.v1.StockTransferred',
      '9': 0,
      '10': 'stockTransferred'
    },
    {
      '1': 'sync_completed',
      '3': 15,
      '4': 1,
      '5': 11,
      '6': '.pos.v1.SyncCompleted',
      '9': 0,
      '10': 'syncCompleted'
    },
    {
      '1': 'sync_failed',
      '3': 16,
      '4': 1,
      '5': 11,
      '6': '.pos.v1.SyncFailed',
      '9': 0,
      '10': 'syncFailed'
    },
    {
      '1': 'user_logged_in',
      '3': 17,
      '4': 1,
      '5': 11,
      '6': '.pos.v1.UserLoggedIn',
      '9': 0,
      '10': 'userLoggedIn'
    },
    {
      '1': 'sale_voided',
      '3': 18,
      '4': 1,
      '5': 11,
      '6': '.pos.v1.SaleVoided',
      '9': 0,
      '10': 'saleVoided'
    },
    {
      '1': 'sale_refunded',
      '3': 19,
      '4': 1,
      '5': 11,
      '6': '.pos.v1.SaleRefunded',
      '9': 0,
      '10': 'saleRefunded'
    },
  ],
  '8': [
    {'1': 'payload'},
  ],
};

/// Descriptor for `EventEnvelope`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List eventEnvelopeDescriptor = $convert.base64Decode(
    'Cg1FdmVudEVudmVsb3BlEjYKDG9wZXJhdGlvbl9pZBgBIAEoCzITLnBvcy52MS5PcGVyYXRpb2'
    '5JZFILb3BlcmF0aW9uSWQSHQoKZXZlbnRfdHlwZRgCIAEoCVIJZXZlbnRUeXBlEiUKDnNjaGVt'
    'YV92ZXJzaW9uGAMgASgNUg1zY2hlbWFWZXJzaW9uEi0KCXRlbmFudF9pZBgEIAEoCzIQLnBvcy'
    '52MS5UZW5hbnRJZFIIdGVuYW50SWQSKgoGb3JpZ2luGAUgASgLMhIucG9zLnYxLk9yaWdpbk5v'
    'ZGVSBm9yaWdpbhIqCgVjbG9jaxgGIAEoCzIULnBvcy52MS5MYW1wb3J0Q2xvY2tSBWNsb2NrEj'
    'sKC29jY3VycmVkX2F0GAcgASgLMhouZ29vZ2xlLnByb3RvYnVmLlRpbWVzdGFtcFIKb2NjdXJy'
    'ZWRBdBI4CgxzYWxlX2NyZWF0ZWQYCiABKAsyEy5wb3MudjEuU2FsZUNyZWF0ZWRIAFILc2FsZU'
    'NyZWF0ZWQSOwoNcGF5bWVudF9hZGRlZBgLIAEoCzIULnBvcy52MS5QYXltZW50QWRkZWRIAFIM'
    'cGF5bWVudEFkZGVkEkQKEHBheW1lbnRfcmVmdW5kZWQYDCABKAsyFy5wb3MudjEuUGF5bWVudF'
    'JlZnVuZGVkSABSD3BheW1lbnRSZWZ1bmRlZBJKChJpbnZlbnRvcnlfYWRqdXN0ZWQYDSABKAsy'
    'GS5wb3MudjEuSW52ZW50b3J5QWRqdXN0ZWRIAFIRaW52ZW50b3J5QWRqdXN0ZWQSRwoRc3RvY2'
    'tfdHJhbnNmZXJyZWQYDiABKAsyGC5wb3MudjEuU3RvY2tUcmFuc2ZlcnJlZEgAUhBzdG9ja1Ry'
    'YW5zZmVycmVkEj4KDnN5bmNfY29tcGxldGVkGA8gASgLMhUucG9zLnYxLlN5bmNDb21wbGV0ZW'
    'RIAFINc3luY0NvbXBsZXRlZBI1CgtzeW5jX2ZhaWxlZBgQIAEoCzISLnBvcy52MS5TeW5jRmFp'
    'bGVkSABSCnN5bmNGYWlsZWQSPAoOdXNlcl9sb2dnZWRfaW4YESABKAsyFC5wb3MudjEuVXNlck'
    'xvZ2dlZEluSABSDHVzZXJMb2dnZWRJbhI1CgtzYWxlX3ZvaWRlZBgSIAEoCzISLnBvcy52MS5T'
    'YWxlVm9pZGVkSABSCnNhbGVWb2lkZWQSOwoNc2FsZV9yZWZ1bmRlZBgTIAEoCzIULnBvcy52MS'
    '5TYWxlUmVmdW5kZWRIAFIMc2FsZVJlZnVuZGVkQgkKB3BheWxvYWQ=');

@$core.Deprecated('Use saleCreatedDescriptor instead')
const SaleCreated$json = {
  '1': 'SaleCreated',
  '2': [
    {'1': 'sale_id', '3': 1, '4': 1, '5': 9, '10': 'saleId'},
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
    {
      '1': 'cashier_id',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.pos.v1.UserId',
      '10': 'cashierId'
    },
    {
      '1': 'lines',
      '3': 5,
      '4': 3,
      '5': 11,
      '6': '.pos.v1.SaleLine',
      '10': 'lines'
    },
    {
      '1': 'subtotal',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.pos.v1.Money',
      '10': 'subtotal'
    },
    {
      '1': 'tax_total',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.pos.v1.Money',
      '10': 'taxTotal'
    },
    {
      '1': 'grand_total',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.pos.v1.Money',
      '10': 'grandTotal'
    },
  ],
};

/// Descriptor for `SaleCreated`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List saleCreatedDescriptor = $convert.base64Decode(
    'CgtTYWxlQ3JlYXRlZBIXCgdzYWxlX2lkGAEgASgJUgZzYWxlSWQSKgoIc3RvcmVfaWQYAiABKA'
    'syDy5wb3MudjEuU3RvcmVJZFIHc3RvcmVJZBIwCgpjb3VudGVyX2lkGAMgASgLMhEucG9zLnYx'
    'LkNvdW50ZXJJZFIJY291bnRlcklkEi0KCmNhc2hpZXJfaWQYBCABKAsyDi5wb3MudjEuVXNlck'
    'lkUgljYXNoaWVySWQSJgoFbGluZXMYBSADKAsyEC5wb3MudjEuU2FsZUxpbmVSBWxpbmVzEikK'
    'CHN1YnRvdGFsGAYgASgLMg0ucG9zLnYxLk1vbmV5UghzdWJ0b3RhbBIqCgl0YXhfdG90YWwYBy'
    'ABKAsyDS5wb3MudjEuTW9uZXlSCHRheFRvdGFsEi4KC2dyYW5kX3RvdGFsGAggASgLMg0ucG9z'
    'LnYxLk1vbmV5UgpncmFuZFRvdGFs');

@$core.Deprecated('Use saleLineDescriptor instead')
const SaleLine$json = {
  '1': 'SaleLine',
  '2': [
    {'1': 'sku', '3': 1, '4': 1, '5': 9, '10': 'sku'},
    {'1': 'description', '3': 2, '4': 1, '5': 9, '10': 'description'},
    {'1': 'quantity', '3': 3, '4': 1, '5': 3, '10': 'quantity'},
    {
      '1': 'unit_price',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.pos.v1.Money',
      '10': 'unitPrice'
    },
    {
      '1': 'line_total',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.pos.v1.Money',
      '10': 'lineTotal'
    },
    {'1': 'line_id', '3': 6, '4': 1, '5': 9, '10': 'lineId'},
    {'1': 'tax_category_id', '3': 7, '4': 1, '5': 9, '10': 'taxCategoryId'},
    {
      '1': 'line_tax',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.pos.v1.Money',
      '10': 'lineTax'
    },
  ],
};

/// Descriptor for `SaleLine`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List saleLineDescriptor = $convert.base64Decode(
    'CghTYWxlTGluZRIQCgNza3UYASABKAlSA3NrdRIgCgtkZXNjcmlwdGlvbhgCIAEoCVILZGVzY3'
    'JpcHRpb24SGgoIcXVhbnRpdHkYAyABKANSCHF1YW50aXR5EiwKCnVuaXRfcHJpY2UYBCABKAsy'
    'DS5wb3MudjEuTW9uZXlSCXVuaXRQcmljZRIsCgpsaW5lX3RvdGFsGAUgASgLMg0ucG9zLnYxLk'
    '1vbmV5UglsaW5lVG90YWwSFwoHbGluZV9pZBgGIAEoCVIGbGluZUlkEiYKD3RheF9jYXRlZ29y'
    'eV9pZBgHIAEoCVINdGF4Q2F0ZWdvcnlJZBIoCghsaW5lX3RheBgIIAEoCzINLnBvcy52MS5Nb2'
    '5leVIHbGluZVRheA==');

@$core.Deprecated('Use paymentAddedDescriptor instead')
const PaymentAdded$json = {
  '1': 'PaymentAdded',
  '2': [
    {'1': 'payment_id', '3': 1, '4': 1, '5': 9, '10': 'paymentId'},
    {'1': 'sale_id', '3': 2, '4': 1, '5': 9, '10': 'saleId'},
    {'1': 'method', '3': 3, '4': 1, '5': 9, '10': 'method'},
    {
      '1': 'amount',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.pos.v1.Money',
      '10': 'amount'
    },
    {'1': 'reference', '3': 5, '4': 1, '5': 9, '10': 'reference'},
  ],
};

/// Descriptor for `PaymentAdded`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List paymentAddedDescriptor = $convert.base64Decode(
    'CgxQYXltZW50QWRkZWQSHQoKcGF5bWVudF9pZBgBIAEoCVIJcGF5bWVudElkEhcKB3NhbGVfaW'
    'QYAiABKAlSBnNhbGVJZBIWCgZtZXRob2QYAyABKAlSBm1ldGhvZBIlCgZhbW91bnQYBCABKAsy'
    'DS5wb3MudjEuTW9uZXlSBmFtb3VudBIcCglyZWZlcmVuY2UYBSABKAlSCXJlZmVyZW5jZQ==');

@$core.Deprecated('Use paymentRefundedDescriptor instead')
const PaymentRefunded$json = {
  '1': 'PaymentRefunded',
  '2': [
    {'1': 'refund_id', '3': 1, '4': 1, '5': 9, '10': 'refundId'},
    {
      '1': 'original_payment_id',
      '3': 2,
      '4': 1,
      '5': 9,
      '10': 'originalPaymentId'
    },
    {
      '1': 'amount',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.pos.v1.Money',
      '10': 'amount'
    },
    {'1': 'reason', '3': 4, '4': 1, '5': 9, '10': 'reason'},
  ],
};

/// Descriptor for `PaymentRefunded`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List paymentRefundedDescriptor = $convert.base64Decode(
    'Cg9QYXltZW50UmVmdW5kZWQSGwoJcmVmdW5kX2lkGAEgASgJUghyZWZ1bmRJZBIuChNvcmlnaW'
    '5hbF9wYXltZW50X2lkGAIgASgJUhFvcmlnaW5hbFBheW1lbnRJZBIlCgZhbW91bnQYAyABKAsy'
    'DS5wb3MudjEuTW9uZXlSBmFtb3VudBIWCgZyZWFzb24YBCABKAlSBnJlYXNvbg==');

@$core.Deprecated('Use inventoryAdjustedDescriptor instead')
const InventoryAdjusted$json = {
  '1': 'InventoryAdjusted',
  '2': [
    {'1': 'sku', '3': 1, '4': 1, '5': 9, '10': 'sku'},
    {'1': 'delta', '3': 2, '4': 1, '5': 3, '10': 'delta'},
    {'1': 'reason', '3': 3, '4': 1, '5': 9, '10': 'reason'},
    {'1': 'ref_id', '3': 4, '4': 1, '5': 9, '10': 'refId'},
  ],
};

/// Descriptor for `InventoryAdjusted`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List inventoryAdjustedDescriptor = $convert.base64Decode(
    'ChFJbnZlbnRvcnlBZGp1c3RlZBIQCgNza3UYASABKAlSA3NrdRIUCgVkZWx0YRgCIAEoA1IFZG'
    'VsdGESFgoGcmVhc29uGAMgASgJUgZyZWFzb24SFQoGcmVmX2lkGAQgASgJUgVyZWZJZA==');

@$core.Deprecated('Use stockTransferredDescriptor instead')
const StockTransferred$json = {
  '1': 'StockTransferred',
  '2': [
    {'1': 'transfer_id', '3': 1, '4': 1, '5': 9, '10': 'transferId'},
    {'1': 'sku', '3': 2, '4': 1, '5': 9, '10': 'sku'},
    {'1': 'quantity', '3': 3, '4': 1, '5': 3, '10': 'quantity'},
    {
      '1': 'from_store',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.pos.v1.StoreId',
      '10': 'fromStore'
    },
    {
      '1': 'to_store',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.pos.v1.StoreId',
      '10': 'toStore'
    },
  ],
};

/// Descriptor for `StockTransferred`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List stockTransferredDescriptor = $convert.base64Decode(
    'ChBTdG9ja1RyYW5zZmVycmVkEh8KC3RyYW5zZmVyX2lkGAEgASgJUgp0cmFuc2ZlcklkEhAKA3'
    'NrdRgCIAEoCVIDc2t1EhoKCHF1YW50aXR5GAMgASgDUghxdWFudGl0eRIuCgpmcm9tX3N0b3Jl'
    'GAQgASgLMg8ucG9zLnYxLlN0b3JlSWRSCWZyb21TdG9yZRIqCgh0b19zdG9yZRgFIAEoCzIPLn'
    'Bvcy52MS5TdG9yZUlkUgd0b1N0b3Jl');

@$core.Deprecated('Use syncCompletedDescriptor instead')
const SyncCompleted$json = {
  '1': 'SyncCompleted',
  '2': [
    {'1': 'batch_id', '3': 1, '4': 1, '5': 9, '10': 'batchId'},
    {'1': 'operations_count', '3': 2, '4': 1, '5': 13, '10': 'operationsCount'},
  ],
};

/// Descriptor for `SyncCompleted`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List syncCompletedDescriptor = $convert.base64Decode(
    'Cg1TeW5jQ29tcGxldGVkEhkKCGJhdGNoX2lkGAEgASgJUgdiYXRjaElkEikKEG9wZXJhdGlvbn'
    'NfY291bnQYAiABKA1SD29wZXJhdGlvbnNDb3VudA==');

@$core.Deprecated('Use syncFailedDescriptor instead')
const SyncFailed$json = {
  '1': 'SyncFailed',
  '2': [
    {'1': 'batch_id', '3': 1, '4': 1, '5': 9, '10': 'batchId'},
    {'1': 'reason', '3': 2, '4': 1, '5': 9, '10': 'reason'},
    {'1': 'retry_count', '3': 3, '4': 1, '5': 13, '10': 'retryCount'},
  ],
};

/// Descriptor for `SyncFailed`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List syncFailedDescriptor = $convert.base64Decode(
    'CgpTeW5jRmFpbGVkEhkKCGJhdGNoX2lkGAEgASgJUgdiYXRjaElkEhYKBnJlYXNvbhgCIAEoCV'
    'IGcmVhc29uEh8KC3JldHJ5X2NvdW50GAMgASgNUgpyZXRyeUNvdW50');

@$core.Deprecated('Use userLoggedInDescriptor instead')
const UserLoggedIn$json = {
  '1': 'UserLoggedIn',
  '2': [
    {
      '1': 'user_id',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.pos.v1.UserId',
      '10': 'userId'
    },
    {'1': 'device_id', '3': 2, '4': 1, '5': 9, '10': 'deviceId'},
  ],
};

/// Descriptor for `UserLoggedIn`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List userLoggedInDescriptor = $convert.base64Decode(
    'CgxVc2VyTG9nZ2VkSW4SJwoHdXNlcl9pZBgBIAEoCzIOLnBvcy52MS5Vc2VySWRSBnVzZXJJZB'
    'IbCglkZXZpY2VfaWQYAiABKAlSCGRldmljZUlk');

@$core.Deprecated('Use saleVoidedDescriptor instead')
const SaleVoided$json = {
  '1': 'SaleVoided',
  '2': [
    {'1': 'void_id', '3': 1, '4': 1, '5': 9, '10': 'voidId'},
    {'1': 'sale_id', '3': 2, '4': 1, '5': 9, '10': 'saleId'},
    {'1': 'invoice_number', '3': 3, '4': 1, '5': 9, '10': 'invoiceNumber'},
    {
      '1': 'store_id',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.pos.v1.StoreId',
      '10': 'storeId'
    },
    {
      '1': 'counter_id',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.pos.v1.CounterId',
      '10': 'counterId'
    },
    {
      '1': 'cashier_id',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.pos.v1.UserId',
      '10': 'cashierId'
    },
    {'1': 'reason', '3': 7, '4': 1, '5': 9, '10': 'reason'},
  ],
};

/// Descriptor for `SaleVoided`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List saleVoidedDescriptor = $convert.base64Decode(
    'CgpTYWxlVm9pZGVkEhcKB3ZvaWRfaWQYASABKAlSBnZvaWRJZBIXCgdzYWxlX2lkGAIgASgJUg'
    'ZzYWxlSWQSJQoOaW52b2ljZV9udW1iZXIYAyABKAlSDWludm9pY2VOdW1iZXISKgoIc3RvcmVf'
    'aWQYBCABKAsyDy5wb3MudjEuU3RvcmVJZFIHc3RvcmVJZBIwCgpjb3VudGVyX2lkGAUgASgLMh'
    'EucG9zLnYxLkNvdW50ZXJJZFIJY291bnRlcklkEi0KCmNhc2hpZXJfaWQYBiABKAsyDi5wb3Mu'
    'djEuVXNlcklkUgljYXNoaWVySWQSFgoGcmVhc29uGAcgASgJUgZyZWFzb24=');

@$core.Deprecated('Use saleRefundedDescriptor instead')
const SaleRefunded$json = {
  '1': 'SaleRefunded',
  '2': [
    {'1': 'refund_id', '3': 1, '4': 1, '5': 9, '10': 'refundId'},
    {'1': 'sale_id', '3': 2, '4': 1, '5': 9, '10': 'saleId'},
    {
      '1': 'credit_note_number',
      '3': 3,
      '4': 1,
      '5': 9,
      '10': 'creditNoteNumber'
    },
    {
      '1': 'store_id',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.pos.v1.StoreId',
      '10': 'storeId'
    },
    {
      '1': 'counter_id',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.pos.v1.CounterId',
      '10': 'counterId'
    },
    {
      '1': 'cashier_id',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.pos.v1.UserId',
      '10': 'cashierId'
    },
    {'1': 'reason', '3': 7, '4': 1, '5': 9, '10': 'reason'},
    {
      '1': 'lines',
      '3': 8,
      '4': 3,
      '5': 11,
      '6': '.pos.v1.RefundLine',
      '10': 'lines'
    },
    {
      '1': 'subtotal',
      '3': 9,
      '4': 1,
      '5': 11,
      '6': '.pos.v1.Money',
      '10': 'subtotal'
    },
    {
      '1': 'tax_total',
      '3': 10,
      '4': 1,
      '5': 11,
      '6': '.pos.v1.Money',
      '10': 'taxTotal'
    },
    {
      '1': 'grand_total',
      '3': 11,
      '4': 1,
      '5': 11,
      '6': '.pos.v1.Money',
      '10': 'grandTotal'
    },
    {
      '1': 'tenders',
      '3': 12,
      '4': 3,
      '5': 11,
      '6': '.pos.v1.RefundTender',
      '10': 'tenders'
    },
  ],
};

/// Descriptor for `SaleRefunded`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List saleRefundedDescriptor = $convert.base64Decode(
    'CgxTYWxlUmVmdW5kZWQSGwoJcmVmdW5kX2lkGAEgASgJUghyZWZ1bmRJZBIXCgdzYWxlX2lkGA'
    'IgASgJUgZzYWxlSWQSLAoSY3JlZGl0X25vdGVfbnVtYmVyGAMgASgJUhBjcmVkaXROb3RlTnVt'
    'YmVyEioKCHN0b3JlX2lkGAQgASgLMg8ucG9zLnYxLlN0b3JlSWRSB3N0b3JlSWQSMAoKY291bn'
    'Rlcl9pZBgFIAEoCzIRLnBvcy52MS5Db3VudGVySWRSCWNvdW50ZXJJZBItCgpjYXNoaWVyX2lk'
    'GAYgASgLMg4ucG9zLnYxLlVzZXJJZFIJY2FzaGllcklkEhYKBnJlYXNvbhgHIAEoCVIGcmVhc2'
    '9uEigKBWxpbmVzGAggAygLMhIucG9zLnYxLlJlZnVuZExpbmVSBWxpbmVzEikKCHN1YnRvdGFs'
    'GAkgASgLMg0ucG9zLnYxLk1vbmV5UghzdWJ0b3RhbBIqCgl0YXhfdG90YWwYCiABKAsyDS5wb3'
    'MudjEuTW9uZXlSCHRheFRvdGFsEi4KC2dyYW5kX3RvdGFsGAsgASgLMg0ucG9zLnYxLk1vbmV5'
    'UgpncmFuZFRvdGFsEi4KB3RlbmRlcnMYDCADKAsyFC5wb3MudjEuUmVmdW5kVGVuZGVyUgd0ZW'
    '5kZXJz');

@$core.Deprecated('Use refundLineDescriptor instead')
const RefundLine$json = {
  '1': 'RefundLine',
  '2': [
    {'1': 'sale_line_id', '3': 1, '4': 1, '5': 9, '10': 'saleLineId'},
    {'1': 'sku', '3': 2, '4': 1, '5': 9, '10': 'sku'},
    {'1': 'quantity', '3': 3, '4': 1, '5': 3, '10': 'quantity'},
    {'1': 'restock', '3': 4, '4': 1, '5': 8, '10': 'restock'},
    {
      '1': 'unit_price',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.pos.v1.Money',
      '10': 'unitPrice'
    },
    {
      '1': 'line_total',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.pos.v1.Money',
      '10': 'lineTotal'
    },
    {'1': 'tax_category_id', '3': 7, '4': 1, '5': 9, '10': 'taxCategoryId'},
    {
      '1': 'line_tax',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.pos.v1.Money',
      '10': 'lineTax'
    },
  ],
};

/// Descriptor for `RefundLine`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List refundLineDescriptor = $convert.base64Decode(
    'CgpSZWZ1bmRMaW5lEiAKDHNhbGVfbGluZV9pZBgBIAEoCVIKc2FsZUxpbmVJZBIQCgNza3UYAi'
    'ABKAlSA3NrdRIaCghxdWFudGl0eRgDIAEoA1IIcXVhbnRpdHkSGAoHcmVzdG9jaxgEIAEoCFIH'
    'cmVzdG9jaxIsCgp1bml0X3ByaWNlGAUgASgLMg0ucG9zLnYxLk1vbmV5Ugl1bml0UHJpY2USLA'
    'oKbGluZV90b3RhbBgGIAEoCzINLnBvcy52MS5Nb25leVIJbGluZVRvdGFsEiYKD3RheF9jYXRl'
    'Z29yeV9pZBgHIAEoCVINdGF4Q2F0ZWdvcnlJZBIoCghsaW5lX3RheBgIIAEoCzINLnBvcy52MS'
    '5Nb25leVIHbGluZVRheA==');

@$core.Deprecated('Use refundTenderDescriptor instead')
const RefundTender$json = {
  '1': 'RefundTender',
  '2': [
    {'1': 'refund_payment_id', '3': 1, '4': 1, '5': 9, '10': 'refundPaymentId'},
    {
      '1': 'original_payment_id',
      '3': 2,
      '4': 1,
      '5': 9,
      '10': 'originalPaymentId'
    },
    {'1': 'method', '3': 3, '4': 1, '5': 9, '10': 'method'},
    {
      '1': 'amount',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.pos.v1.Money',
      '10': 'amount'
    },
    {'1': 'reference', '3': 5, '4': 1, '5': 9, '10': 'reference'},
  ],
};

/// Descriptor for `RefundTender`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List refundTenderDescriptor = $convert.base64Decode(
    'CgxSZWZ1bmRUZW5kZXISKgoRcmVmdW5kX3BheW1lbnRfaWQYASABKAlSD3JlZnVuZFBheW1lbn'
    'RJZBIuChNvcmlnaW5hbF9wYXltZW50X2lkGAIgASgJUhFvcmlnaW5hbFBheW1lbnRJZBIWCgZt'
    'ZXRob2QYAyABKAlSBm1ldGhvZBIlCgZhbW91bnQYBCABKAsyDS5wb3MudjEuTW9uZXlSBmFtb3'
    'VudBIcCglyZWZlcmVuY2UYBSABKAlSCXJlZmVyZW5jZQ==');
