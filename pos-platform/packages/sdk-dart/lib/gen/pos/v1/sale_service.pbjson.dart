// This is a generated file - do not edit.
//
// Generated from pos/v1/sale_service.proto.

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

@$core.Deprecated('Use finalizeRequestDescriptor instead')
const FinalizeRequest$json = {
  '1': 'FinalizeRequest',
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
      '6': '.pos.v1.FinalizeSaleLine',
      '10': 'lines'
    },
    {
      '1': 'tenders',
      '3': 6,
      '4': 3,
      '5': 11,
      '6': '.pos.v1.FinalizeSaleTender',
      '10': 'tenders'
    },
    {
      '1': 'subtotal',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.pos.v1.Money',
      '10': 'subtotal'
    },
    {
      '1': 'tax_total',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.pos.v1.Money',
      '10': 'taxTotal'
    },
    {
      '1': 'grand_total',
      '3': 9,
      '4': 1,
      '5': 11,
      '6': '.pos.v1.Money',
      '10': 'grandTotal'
    },
    {
      '1': 'occurred_at',
      '3': 10,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'occurredAt'
    },
    {'1': 'reservation_ids', '3': 11, '4': 3, '5': 9, '10': 'reservationIds'},
  ],
};

/// Descriptor for `FinalizeRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List finalizeRequestDescriptor = $convert.base64Decode(
    'Cg9GaW5hbGl6ZVJlcXVlc3QSFwoHc2FsZV9pZBgBIAEoCVIGc2FsZUlkEioKCHN0b3JlX2lkGA'
    'IgASgLMg8ucG9zLnYxLlN0b3JlSWRSB3N0b3JlSWQSMAoKY291bnRlcl9pZBgDIAEoCzIRLnBv'
    'cy52MS5Db3VudGVySWRSCWNvdW50ZXJJZBItCgpjYXNoaWVyX2lkGAQgASgLMg4ucG9zLnYxLl'
    'VzZXJJZFIJY2FzaGllcklkEi4KBWxpbmVzGAUgAygLMhgucG9zLnYxLkZpbmFsaXplU2FsZUxp'
    'bmVSBWxpbmVzEjQKB3RlbmRlcnMYBiADKAsyGi5wb3MudjEuRmluYWxpemVTYWxlVGVuZGVyUg'
    'd0ZW5kZXJzEikKCHN1YnRvdGFsGAcgASgLMg0ucG9zLnYxLk1vbmV5UghzdWJ0b3RhbBIqCgl0'
    'YXhfdG90YWwYCCABKAsyDS5wb3MudjEuTW9uZXlSCHRheFRvdGFsEi4KC2dyYW5kX3RvdGFsGA'
    'kgASgLMg0ucG9zLnYxLk1vbmV5UgpncmFuZFRvdGFsEjsKC29jY3VycmVkX2F0GAogASgLMhou'
    'Z29vZ2xlLnByb3RvYnVmLlRpbWVzdGFtcFIKb2NjdXJyZWRBdBInCg9yZXNlcnZhdGlvbl9pZH'
    'MYCyADKAlSDnJlc2VydmF0aW9uSWRz');

@$core.Deprecated('Use finalizeSaleLineDescriptor instead')
const FinalizeSaleLine$json = {
  '1': 'FinalizeSaleLine',
  '2': [
    {'1': 'line_id', '3': 1, '4': 1, '5': 9, '10': 'lineId'},
    {'1': 'sku', '3': 2, '4': 1, '5': 9, '10': 'sku'},
    {'1': 'description', '3': 3, '4': 1, '5': 9, '10': 'description'},
    {'1': 'quantity', '3': 4, '4': 1, '5': 3, '10': 'quantity'},
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
  ],
};

/// Descriptor for `FinalizeSaleLine`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List finalizeSaleLineDescriptor = $convert.base64Decode(
    'ChBGaW5hbGl6ZVNhbGVMaW5lEhcKB2xpbmVfaWQYASABKAlSBmxpbmVJZBIQCgNza3UYAiABKA'
    'lSA3NrdRIgCgtkZXNjcmlwdGlvbhgDIAEoCVILZGVzY3JpcHRpb24SGgoIcXVhbnRpdHkYBCAB'
    'KANSCHF1YW50aXR5EiwKCnVuaXRfcHJpY2UYBSABKAsyDS5wb3MudjEuTW9uZXlSCXVuaXRQcm'
    'ljZRIsCgpsaW5lX3RvdGFsGAYgASgLMg0ucG9zLnYxLk1vbmV5UglsaW5lVG90YWwSJgoPdGF4'
    'X2NhdGVnb3J5X2lkGAcgASgJUg10YXhDYXRlZ29yeUlk');

@$core.Deprecated('Use finalizeSaleTenderDescriptor instead')
const FinalizeSaleTender$json = {
  '1': 'FinalizeSaleTender',
  '2': [
    {'1': 'payment_id', '3': 1, '4': 1, '5': 9, '10': 'paymentId'},
    {'1': 'method', '3': 2, '4': 1, '5': 9, '10': 'method'},
    {
      '1': 'amount',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.pos.v1.Money',
      '10': 'amount'
    },
    {'1': 'reference', '3': 4, '4': 1, '5': 9, '10': 'reference'},
  ],
};

/// Descriptor for `FinalizeSaleTender`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List finalizeSaleTenderDescriptor = $convert.base64Decode(
    'ChJGaW5hbGl6ZVNhbGVUZW5kZXISHQoKcGF5bWVudF9pZBgBIAEoCVIJcGF5bWVudElkEhYKBm'
    '1ldGhvZBgCIAEoCVIGbWV0aG9kEiUKBmFtb3VudBgDIAEoCzINLnBvcy52MS5Nb25leVIGYW1v'
    'dW50EhwKCXJlZmVyZW5jZRgEIAEoCVIJcmVmZXJlbmNl');

@$core.Deprecated('Use finalizeResponseDescriptor instead')
const FinalizeResponse$json = {
  '1': 'FinalizeResponse',
  '2': [
    {'1': 'sale_id', '3': 1, '4': 1, '5': 9, '10': 'saleId'},
    {'1': 'batch_id', '3': 2, '4': 1, '5': 9, '10': 'batchId'},
    {'1': 'lamport', '3': 3, '4': 1, '5': 4, '10': 'lamport'},
    {
      '1': 'invoice',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.pos.v1.Invoice',
      '10': 'invoice'
    },
    {'1': 'idempotent', '3': 5, '4': 1, '5': 8, '10': 'idempotent'},
  ],
};

/// Descriptor for `FinalizeResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List finalizeResponseDescriptor = $convert.base64Decode(
    'ChBGaW5hbGl6ZVJlc3BvbnNlEhcKB3NhbGVfaWQYASABKAlSBnNhbGVJZBIZCghiYXRjaF9pZB'
    'gCIAEoCVIHYmF0Y2hJZBIYCgdsYW1wb3J0GAMgASgEUgdsYW1wb3J0EikKB2ludm9pY2UYBCAB'
    'KAsyDy5wb3MudjEuSW52b2ljZVIHaW52b2ljZRIeCgppZGVtcG90ZW50GAUgASgIUgppZGVtcG'
    '90ZW50');

@$core.Deprecated('Use getSaleRequestDescriptor instead')
const GetSaleRequest$json = {
  '1': 'GetSaleRequest',
  '2': [
    {'1': 'sale_id', '3': 1, '4': 1, '5': 9, '9': 0, '10': 'saleId'},
    {
      '1': 'invoice_number',
      '3': 2,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'invoiceNumber'
    },
  ],
  '8': [
    {'1': 'key'},
  ],
};

/// Descriptor for `GetSaleRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getSaleRequestDescriptor = $convert.base64Decode(
    'Cg5HZXRTYWxlUmVxdWVzdBIZCgdzYWxlX2lkGAEgASgJSABSBnNhbGVJZBInCg5pbnZvaWNlX2'
    '51bWJlchgCIAEoCUgAUg1pbnZvaWNlTnVtYmVyQgUKA2tleQ==');

@$core.Deprecated('Use getSaleResponseDescriptor instead')
const GetSaleResponse$json = {
  '1': 'GetSaleResponse',
  '2': [
    {
      '1': 'invoice',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.pos.v1.Invoice',
      '10': 'invoice'
    },
    {
      '1': 'lines',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.pos.v1.GetSaleLine',
      '10': 'lines'
    },
    {
      '1': 'payments',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.pos.v1.GetSalePayment',
      '10': 'payments'
    },
  ],
};

/// Descriptor for `GetSaleResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getSaleResponseDescriptor = $convert.base64Decode(
    'Cg9HZXRTYWxlUmVzcG9uc2USKQoHaW52b2ljZRgBIAEoCzIPLnBvcy52MS5JbnZvaWNlUgdpbn'
    'ZvaWNlEikKBWxpbmVzGAIgAygLMhMucG9zLnYxLkdldFNhbGVMaW5lUgVsaW5lcxIyCghwYXlt'
    'ZW50cxgDIAMoCzIWLnBvcy52MS5HZXRTYWxlUGF5bWVudFIIcGF5bWVudHM=');

@$core.Deprecated('Use getSaleLineDescriptor instead')
const GetSaleLine$json = {
  '1': 'GetSaleLine',
  '2': [
    {'1': 'line_id', '3': 1, '4': 1, '5': 9, '10': 'lineId'},
    {'1': 'sku', '3': 2, '4': 1, '5': 9, '10': 'sku'},
    {'1': 'description', '3': 3, '4': 1, '5': 9, '10': 'description'},
    {'1': 'quantity', '3': 4, '4': 1, '5': 3, '10': 'quantity'},
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
  ],
};

/// Descriptor for `GetSaleLine`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getSaleLineDescriptor = $convert.base64Decode(
    'CgtHZXRTYWxlTGluZRIXCgdsaW5lX2lkGAEgASgJUgZsaW5lSWQSEAoDc2t1GAIgASgJUgNza3'
    'USIAoLZGVzY3JpcHRpb24YAyABKAlSC2Rlc2NyaXB0aW9uEhoKCHF1YW50aXR5GAQgASgDUghx'
    'dWFudGl0eRIsCgp1bml0X3ByaWNlGAUgASgLMg0ucG9zLnYxLk1vbmV5Ugl1bml0UHJpY2USLA'
    'oKbGluZV90b3RhbBgGIAEoCzINLnBvcy52MS5Nb25leVIJbGluZVRvdGFs');

@$core.Deprecated('Use getSalePaymentDescriptor instead')
const GetSalePayment$json = {
  '1': 'GetSalePayment',
  '2': [
    {'1': 'payment_id', '3': 1, '4': 1, '5': 9, '10': 'paymentId'},
    {'1': 'method', '3': 2, '4': 1, '5': 9, '10': 'method'},
    {
      '1': 'amount',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.pos.v1.Money',
      '10': 'amount'
    },
    {'1': 'reference', '3': 4, '4': 1, '5': 9, '10': 'reference'},
  ],
};

/// Descriptor for `GetSalePayment`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getSalePaymentDescriptor = $convert.base64Decode(
    'Cg5HZXRTYWxlUGF5bWVudBIdCgpwYXltZW50X2lkGAEgASgJUglwYXltZW50SWQSFgoGbWV0aG'
    '9kGAIgASgJUgZtZXRob2QSJQoGYW1vdW50GAMgASgLMg0ucG9zLnYxLk1vbmV5UgZhbW91bnQS'
    'HAoJcmVmZXJlbmNlGAQgASgJUglyZWZlcmVuY2U=');

@$core.Deprecated('Use invoiceDescriptor instead')
const Invoice$json = {
  '1': 'Invoice',
  '2': [
    {'1': 'invoice_id', '3': 1, '4': 1, '5': 9, '10': 'invoiceId'},
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
    {
      '1': 'subtotal',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.pos.v1.Money',
      '10': 'subtotal'
    },
    {
      '1': 'tax_total',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.pos.v1.Money',
      '10': 'taxTotal'
    },
    {
      '1': 'grand_total',
      '3': 9,
      '4': 1,
      '5': 11,
      '6': '.pos.v1.Money',
      '10': 'grandTotal'
    },
    {'1': 'snapshot', '3': 10, '4': 1, '5': 12, '10': 'snapshot'},
    {
      '1': 'finalized_at',
      '3': 11,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'finalizedAt'
    },
  ],
};

/// Descriptor for `Invoice`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List invoiceDescriptor = $convert.base64Decode(
    'CgdJbnZvaWNlEh0KCmludm9pY2VfaWQYASABKAlSCWludm9pY2VJZBIXCgdzYWxlX2lkGAIgAS'
    'gJUgZzYWxlSWQSJQoOaW52b2ljZV9udW1iZXIYAyABKAlSDWludm9pY2VOdW1iZXISKgoIc3Rv'
    'cmVfaWQYBCABKAsyDy5wb3MudjEuU3RvcmVJZFIHc3RvcmVJZBIwCgpjb3VudGVyX2lkGAUgAS'
    'gLMhEucG9zLnYxLkNvdW50ZXJJZFIJY291bnRlcklkEi0KCmNhc2hpZXJfaWQYBiABKAsyDi5w'
    'b3MudjEuVXNlcklkUgljYXNoaWVySWQSKQoIc3VidG90YWwYByABKAsyDS5wb3MudjEuTW9uZX'
    'lSCHN1YnRvdGFsEioKCXRheF90b3RhbBgIIAEoCzINLnBvcy52MS5Nb25leVIIdGF4VG90YWwS'
    'LgoLZ3JhbmRfdG90YWwYCSABKAsyDS5wb3MudjEuTW9uZXlSCmdyYW5kVG90YWwSGgoIc25hcH'
    'Nob3QYCiABKAxSCHNuYXBzaG90Ej0KDGZpbmFsaXplZF9hdBgLIAEoCzIaLmdvb2dsZS5wcm90'
    'b2J1Zi5UaW1lc3RhbXBSC2ZpbmFsaXplZEF0');

const $core.Map<$core.String, $core.dynamic> SaleServiceBase$json = {
  '1': 'SaleService',
  '2': [
    {
      '1': 'Finalize',
      '2': '.pos.v1.FinalizeRequest',
      '3': '.pos.v1.FinalizeResponse'
    },
    {
      '1': 'GetSale',
      '2': '.pos.v1.GetSaleRequest',
      '3': '.pos.v1.GetSaleResponse'
    },
  ],
};

@$core.Deprecated('Use saleServiceDescriptor instead')
const $core.Map<$core.String, $core.Map<$core.String, $core.dynamic>>
    SaleServiceBase$messageJson = {
  '.pos.v1.FinalizeRequest': FinalizeRequest$json,
  '.pos.v1.StoreId': $0.StoreId$json,
  '.pos.v1.CounterId': $0.CounterId$json,
  '.pos.v1.UserId': $0.UserId$json,
  '.pos.v1.FinalizeSaleLine': FinalizeSaleLine$json,
  '.pos.v1.Money': $0.Money$json,
  '.pos.v1.FinalizeSaleTender': FinalizeSaleTender$json,
  '.google.protobuf.Timestamp': $1.Timestamp$json,
  '.pos.v1.FinalizeResponse': FinalizeResponse$json,
  '.pos.v1.Invoice': Invoice$json,
  '.pos.v1.GetSaleRequest': GetSaleRequest$json,
  '.pos.v1.GetSaleResponse': GetSaleResponse$json,
  '.pos.v1.GetSaleLine': GetSaleLine$json,
  '.pos.v1.GetSalePayment': GetSalePayment$json,
};

/// Descriptor for `SaleService`. Decode as a `google.protobuf.ServiceDescriptorProto`.
final $typed_data.Uint8List saleServiceDescriptor = $convert.base64Decode(
    'CgtTYWxlU2VydmljZRI9CghGaW5hbGl6ZRIXLnBvcy52MS5GaW5hbGl6ZVJlcXVlc3QaGC5wb3'
    'MudjEuRmluYWxpemVSZXNwb25zZRI6CgdHZXRTYWxlEhYucG9zLnYxLkdldFNhbGVSZXF1ZXN0'
    'GhcucG9zLnYxLkdldFNhbGVSZXNwb25zZQ==');
