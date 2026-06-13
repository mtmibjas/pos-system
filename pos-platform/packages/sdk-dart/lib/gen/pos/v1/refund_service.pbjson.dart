// This is a generated file - do not edit.
//
// Generated from pos/v1/refund_service.proto.

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

@$core.Deprecated('Use voidSaleRequestDescriptor instead')
const VoidSaleRequest$json = {
  '1': 'VoidSaleRequest',
  '2': [
    {'1': 'void_id', '3': 1, '4': 1, '5': 9, '10': 'voidId'},
    {'1': 'sale_id', '3': 2, '4': 1, '5': 9, '10': 'saleId'},
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
    {
      '1': 'cashier_id',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.pos.v1.UserId',
      '10': 'cashierId'
    },
    {'1': 'reason', '3': 6, '4': 1, '5': 9, '10': 'reason'},
    {
      '1': 'occurred_at',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'occurredAt'
    },
  ],
};

/// Descriptor for `VoidSaleRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List voidSaleRequestDescriptor = $convert.base64Decode(
    'Cg9Wb2lkU2FsZVJlcXVlc3QSFwoHdm9pZF9pZBgBIAEoCVIGdm9pZElkEhcKB3NhbGVfaWQYAi'
    'ABKAlSBnNhbGVJZBIqCghzdG9yZV9pZBgDIAEoCzIPLnBvcy52MS5TdG9yZUlkUgdzdG9yZUlk'
    'EjAKCmNvdW50ZXJfaWQYBCABKAsyES5wb3MudjEuQ291bnRlcklkUgljb3VudGVySWQSLQoKY2'
    'FzaGllcl9pZBgFIAEoCzIOLnBvcy52MS5Vc2VySWRSCWNhc2hpZXJJZBIWCgZyZWFzb24YBiAB'
    'KAlSBnJlYXNvbhI7CgtvY2N1cnJlZF9hdBgHIAEoCzIaLmdvb2dsZS5wcm90b2J1Zi5UaW1lc3'
    'RhbXBSCm9jY3VycmVkQXQ=');

@$core.Deprecated('Use voidSaleResponseDescriptor instead')
const VoidSaleResponse$json = {
  '1': 'VoidSaleResponse',
  '2': [
    {'1': 'void_id', '3': 1, '4': 1, '5': 9, '10': 'voidId'},
    {'1': 'batch_id', '3': 2, '4': 1, '5': 9, '10': 'batchId'},
    {'1': 'lamport', '3': 3, '4': 1, '5': 4, '10': 'lamport'},
    {'1': 'void', '3': 4, '4': 1, '5': 11, '6': '.pos.v1.Void', '10': 'void'},
    {'1': 'idempotent', '3': 5, '4': 1, '5': 8, '10': 'idempotent'},
  ],
};

/// Descriptor for `VoidSaleResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List voidSaleResponseDescriptor = $convert.base64Decode(
    'ChBWb2lkU2FsZVJlc3BvbnNlEhcKB3ZvaWRfaWQYASABKAlSBnZvaWRJZBIZCghiYXRjaF9pZB'
    'gCIAEoCVIHYmF0Y2hJZBIYCgdsYW1wb3J0GAMgASgEUgdsYW1wb3J0EiAKBHZvaWQYBCABKAsy'
    'DC5wb3MudjEuVm9pZFIEdm9pZBIeCgppZGVtcG90ZW50GAUgASgIUgppZGVtcG90ZW50');

@$core.Deprecated('Use voidDescriptor instead')
const Void$json = {
  '1': 'Void',
  '2': [
    {'1': 'void_id', '3': 1, '4': 1, '5': 9, '10': 'voidId'},
    {'1': 'sale_id', '3': 2, '4': 1, '5': 9, '10': 'saleId'},
    {'1': 'invoice_id', '3': 3, '4': 1, '5': 9, '10': 'invoiceId'},
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
    {'1': 'snapshot', '3': 8, '4': 1, '5': 12, '10': 'snapshot'},
    {
      '1': 'voided_at',
      '3': 9,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'voidedAt'
    },
  ],
};

/// Descriptor for `Void`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List voidDescriptor = $convert.base64Decode(
    'CgRWb2lkEhcKB3ZvaWRfaWQYASABKAlSBnZvaWRJZBIXCgdzYWxlX2lkGAIgASgJUgZzYWxlSW'
    'QSHQoKaW52b2ljZV9pZBgDIAEoCVIJaW52b2ljZUlkEioKCHN0b3JlX2lkGAQgASgLMg8ucG9z'
    'LnYxLlN0b3JlSWRSB3N0b3JlSWQSMAoKY291bnRlcl9pZBgFIAEoCzIRLnBvcy52MS5Db3VudG'
    'VySWRSCWNvdW50ZXJJZBItCgpjYXNoaWVyX2lkGAYgASgLMg4ucG9zLnYxLlVzZXJJZFIJY2Fz'
    'aGllcklkEhYKBnJlYXNvbhgHIAEoCVIGcmVhc29uEhoKCHNuYXBzaG90GAggASgMUghzbmFwc2'
    'hvdBI3Cgl2b2lkZWRfYXQYCSABKAsyGi5nb29nbGUucHJvdG9idWYuVGltZXN0YW1wUgh2b2lk'
    'ZWRBdA==');

@$core.Deprecated('Use refundSaleRequestDescriptor instead')
const RefundSaleRequest$json = {
  '1': 'RefundSaleRequest',
  '2': [
    {'1': 'refund_id', '3': 1, '4': 1, '5': 9, '10': 'refundId'},
    {'1': 'sale_id', '3': 2, '4': 1, '5': 9, '10': 'saleId'},
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
    {
      '1': 'cashier_id',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.pos.v1.UserId',
      '10': 'cashierId'
    },
    {'1': 'reason', '3': 6, '4': 1, '5': 9, '10': 'reason'},
    {
      '1': 'occurred_at',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'occurredAt'
    },
    {
      '1': 'lines',
      '3': 8,
      '4': 3,
      '5': 11,
      '6': '.pos.v1.RefundSaleLine',
      '10': 'lines'
    },
    {
      '1': 'tenders',
      '3': 9,
      '4': 3,
      '5': 11,
      '6': '.pos.v1.RefundSaleTender',
      '10': 'tenders'
    },
  ],
};

/// Descriptor for `RefundSaleRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List refundSaleRequestDescriptor = $convert.base64Decode(
    'ChFSZWZ1bmRTYWxlUmVxdWVzdBIbCglyZWZ1bmRfaWQYASABKAlSCHJlZnVuZElkEhcKB3NhbG'
    'VfaWQYAiABKAlSBnNhbGVJZBIqCghzdG9yZV9pZBgDIAEoCzIPLnBvcy52MS5TdG9yZUlkUgdz'
    'dG9yZUlkEjAKCmNvdW50ZXJfaWQYBCABKAsyES5wb3MudjEuQ291bnRlcklkUgljb3VudGVySW'
    'QSLQoKY2FzaGllcl9pZBgFIAEoCzIOLnBvcy52MS5Vc2VySWRSCWNhc2hpZXJJZBIWCgZyZWFz'
    'b24YBiABKAlSBnJlYXNvbhI7CgtvY2N1cnJlZF9hdBgHIAEoCzIaLmdvb2dsZS5wcm90b2J1Zi'
    '5UaW1lc3RhbXBSCm9jY3VycmVkQXQSLAoFbGluZXMYCCADKAsyFi5wb3MudjEuUmVmdW5kU2Fs'
    'ZUxpbmVSBWxpbmVzEjIKB3RlbmRlcnMYCSADKAsyGC5wb3MudjEuUmVmdW5kU2FsZVRlbmRlcl'
    'IHdGVuZGVycw==');

@$core.Deprecated('Use refundSaleLineDescriptor instead')
const RefundSaleLine$json = {
  '1': 'RefundSaleLine',
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
  ],
};

/// Descriptor for `RefundSaleLine`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List refundSaleLineDescriptor = $convert.base64Decode(
    'Cg5SZWZ1bmRTYWxlTGluZRIgCgxzYWxlX2xpbmVfaWQYASABKAlSCnNhbGVMaW5lSWQSEAoDc2'
    't1GAIgASgJUgNza3USGgoIcXVhbnRpdHkYAyABKANSCHF1YW50aXR5EhgKB3Jlc3RvY2sYBCAB'
    'KAhSB3Jlc3RvY2sSLAoKdW5pdF9wcmljZRgFIAEoCzINLnBvcy52MS5Nb25leVIJdW5pdFByaW'
    'NlEiwKCmxpbmVfdG90YWwYBiABKAsyDS5wb3MudjEuTW9uZXlSCWxpbmVUb3RhbBImCg90YXhf'
    'Y2F0ZWdvcnlfaWQYByABKAlSDXRheENhdGVnb3J5SWQ=');

@$core.Deprecated('Use refundSaleTenderDescriptor instead')
const RefundSaleTender$json = {
  '1': 'RefundSaleTender',
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

/// Descriptor for `RefundSaleTender`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List refundSaleTenderDescriptor = $convert.base64Decode(
    'ChBSZWZ1bmRTYWxlVGVuZGVyEioKEXJlZnVuZF9wYXltZW50X2lkGAEgASgJUg9yZWZ1bmRQYX'
    'ltZW50SWQSLgoTb3JpZ2luYWxfcGF5bWVudF9pZBgCIAEoCVIRb3JpZ2luYWxQYXltZW50SWQS'
    'FgoGbWV0aG9kGAMgASgJUgZtZXRob2QSJQoGYW1vdW50GAQgASgLMg0ucG9zLnYxLk1vbmV5Ug'
    'ZhbW91bnQSHAoJcmVmZXJlbmNlGAUgASgJUglyZWZlcmVuY2U=');

@$core.Deprecated('Use refundSaleResponseDescriptor instead')
const RefundSaleResponse$json = {
  '1': 'RefundSaleResponse',
  '2': [
    {'1': 'refund_id', '3': 1, '4': 1, '5': 9, '10': 'refundId'},
    {'1': 'batch_id', '3': 2, '4': 1, '5': 9, '10': 'batchId'},
    {'1': 'lamport', '3': 3, '4': 1, '5': 4, '10': 'lamport'},
    {
      '1': 'refund',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.pos.v1.Refund',
      '10': 'refund'
    },
    {'1': 'idempotent', '3': 5, '4': 1, '5': 8, '10': 'idempotent'},
  ],
};

/// Descriptor for `RefundSaleResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List refundSaleResponseDescriptor = $convert.base64Decode(
    'ChJSZWZ1bmRTYWxlUmVzcG9uc2USGwoJcmVmdW5kX2lkGAEgASgJUghyZWZ1bmRJZBIZCghiYX'
    'RjaF9pZBgCIAEoCVIHYmF0Y2hJZBIYCgdsYW1wb3J0GAMgASgEUgdsYW1wb3J0EiYKBnJlZnVu'
    'ZBgEIAEoCzIOLnBvcy52MS5SZWZ1bmRSBnJlZnVuZBIeCgppZGVtcG90ZW50GAUgASgIUgppZG'
    'VtcG90ZW50');

@$core.Deprecated('Use refundDescriptor instead')
const Refund$json = {
  '1': 'Refund',
  '2': [
    {'1': 'refund_id', '3': 1, '4': 1, '5': 9, '10': 'refundId'},
    {'1': 'sale_id', '3': 2, '4': 1, '5': 9, '10': 'saleId'},
    {'1': 'invoice_id', '3': 3, '4': 1, '5': 9, '10': 'invoiceId'},
    {
      '1': 'credit_note_number',
      '3': 4,
      '4': 1,
      '5': 9,
      '10': 'creditNoteNumber'
    },
    {
      '1': 'store_id',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.pos.v1.StoreId',
      '10': 'storeId'
    },
    {
      '1': 'counter_id',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.pos.v1.CounterId',
      '10': 'counterId'
    },
    {
      '1': 'cashier_id',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.pos.v1.UserId',
      '10': 'cashierId'
    },
    {'1': 'reason', '3': 8, '4': 1, '5': 9, '10': 'reason'},
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
    {'1': 'snapshot', '3': 12, '4': 1, '5': 12, '10': 'snapshot'},
    {
      '1': 'refunded_at',
      '3': 13,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'refundedAt'
    },
  ],
};

/// Descriptor for `Refund`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List refundDescriptor = $convert.base64Decode(
    'CgZSZWZ1bmQSGwoJcmVmdW5kX2lkGAEgASgJUghyZWZ1bmRJZBIXCgdzYWxlX2lkGAIgASgJUg'
    'ZzYWxlSWQSHQoKaW52b2ljZV9pZBgDIAEoCVIJaW52b2ljZUlkEiwKEmNyZWRpdF9ub3RlX251'
    'bWJlchgEIAEoCVIQY3JlZGl0Tm90ZU51bWJlchIqCghzdG9yZV9pZBgFIAEoCzIPLnBvcy52MS'
    '5TdG9yZUlkUgdzdG9yZUlkEjAKCmNvdW50ZXJfaWQYBiABKAsyES5wb3MudjEuQ291bnRlcklk'
    'Ugljb3VudGVySWQSLQoKY2FzaGllcl9pZBgHIAEoCzIOLnBvcy52MS5Vc2VySWRSCWNhc2hpZX'
    'JJZBIWCgZyZWFzb24YCCABKAlSBnJlYXNvbhIpCghzdWJ0b3RhbBgJIAEoCzINLnBvcy52MS5N'
    'b25leVIIc3VidG90YWwSKgoJdGF4X3RvdGFsGAogASgLMg0ucG9zLnYxLk1vbmV5Ugh0YXhUb3'
    'RhbBIuCgtncmFuZF90b3RhbBgLIAEoCzINLnBvcy52MS5Nb25leVIKZ3JhbmRUb3RhbBIaCghz'
    'bmFwc2hvdBgMIAEoDFIIc25hcHNob3QSOwoLcmVmdW5kZWRfYXQYDSABKAsyGi5nb29nbGUucH'
    'JvdG9idWYuVGltZXN0YW1wUgpyZWZ1bmRlZEF0');

const $core.Map<$core.String, $core.dynamic> RefundServiceBase$json = {
  '1': 'RefundService',
  '2': [
    {
      '1': 'VoidSale',
      '2': '.pos.v1.VoidSaleRequest',
      '3': '.pos.v1.VoidSaleResponse'
    },
    {
      '1': 'RefundSale',
      '2': '.pos.v1.RefundSaleRequest',
      '3': '.pos.v1.RefundSaleResponse'
    },
  ],
};

@$core.Deprecated('Use refundServiceDescriptor instead')
const $core.Map<$core.String, $core.Map<$core.String, $core.dynamic>>
    RefundServiceBase$messageJson = {
  '.pos.v1.VoidSaleRequest': VoidSaleRequest$json,
  '.pos.v1.StoreId': $0.StoreId$json,
  '.pos.v1.CounterId': $0.CounterId$json,
  '.pos.v1.UserId': $0.UserId$json,
  '.google.protobuf.Timestamp': $1.Timestamp$json,
  '.pos.v1.VoidSaleResponse': VoidSaleResponse$json,
  '.pos.v1.Void': Void$json,
  '.pos.v1.RefundSaleRequest': RefundSaleRequest$json,
  '.pos.v1.RefundSaleLine': RefundSaleLine$json,
  '.pos.v1.Money': $0.Money$json,
  '.pos.v1.RefundSaleTender': RefundSaleTender$json,
  '.pos.v1.RefundSaleResponse': RefundSaleResponse$json,
  '.pos.v1.Refund': Refund$json,
};

/// Descriptor for `RefundService`. Decode as a `google.protobuf.ServiceDescriptorProto`.
final $typed_data.Uint8List refundServiceDescriptor = $convert.base64Decode(
    'Cg1SZWZ1bmRTZXJ2aWNlEj0KCFZvaWRTYWxlEhcucG9zLnYxLlZvaWRTYWxlUmVxdWVzdBoYLn'
    'Bvcy52MS5Wb2lkU2FsZVJlc3BvbnNlEkMKClJlZnVuZFNhbGUSGS5wb3MudjEuUmVmdW5kU2Fs'
    'ZVJlcXVlc3QaGi5wb3MudjEuUmVmdW5kU2FsZVJlc3BvbnNl');
