// This is a generated file - do not edit.
//
// Generated from pos/v1/expense_service.proto.

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

@$core.Deprecated('Use expenseDescriptor instead')
const Expense$json = {
  '1': 'Expense',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'tenant_id', '3': 2, '4': 1, '5': 9, '10': 'tenantId'},
    {'1': 'store_id', '3': 3, '4': 1, '5': 9, '10': 'storeId'},
    {'1': 'date', '3': 4, '4': 1, '5': 9, '10': 'date'},
    {'1': 'category', '3': 5, '4': 1, '5': 9, '10': 'category'},
    {'1': 'description', '3': 6, '4': 1, '5': 9, '10': 'description'},
    {'1': 'payment_mode', '3': 7, '4': 1, '5': 9, '10': 'paymentMode'},
    {
      '1': 'amount',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.pos.v1.Money',
      '10': 'amount'
    },
    {'1': 'vat', '3': 9, '4': 1, '5': 11, '6': '.pos.v1.Money', '10': 'vat'},
    {'1': 'created_at', '3': 10, '4': 1, '5': 3, '10': 'createdAt'},
  ],
};

/// Descriptor for `Expense`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List expenseDescriptor = $convert.base64Decode(
    'CgdFeHBlbnNlEg4KAmlkGAEgASgJUgJpZBIbCgl0ZW5hbnRfaWQYAiABKAlSCHRlbmFudElkEh'
    'kKCHN0b3JlX2lkGAMgASgJUgdzdG9yZUlkEhIKBGRhdGUYBCABKAlSBGRhdGUSGgoIY2F0ZWdv'
    'cnkYBSABKAlSCGNhdGVnb3J5EiAKC2Rlc2NyaXB0aW9uGAYgASgJUgtkZXNjcmlwdGlvbhIhCg'
    'xwYXltZW50X21vZGUYByABKAlSC3BheW1lbnRNb2RlEiUKBmFtb3VudBgIIAEoCzINLnBvcy52'
    'MS5Nb25leVIGYW1vdW50Eh8KA3ZhdBgJIAEoCzINLnBvcy52MS5Nb25leVIDdmF0Eh0KCmNyZW'
    'F0ZWRfYXQYCiABKANSCWNyZWF0ZWRBdA==');

@$core.Deprecated('Use listExpensesRequestDescriptor instead')
const ListExpensesRequest$json = {
  '1': 'ListExpensesRequest',
};

/// Descriptor for `ListExpensesRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listExpensesRequestDescriptor =
    $convert.base64Decode('ChNMaXN0RXhwZW5zZXNSZXF1ZXN0');

@$core.Deprecated('Use listExpensesResponseDescriptor instead')
const ListExpensesResponse$json = {
  '1': 'ListExpensesResponse',
  '2': [
    {
      '1': 'expenses',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.pos.v1.Expense',
      '10': 'expenses'
    },
  ],
};

/// Descriptor for `ListExpensesResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listExpensesResponseDescriptor = $convert.base64Decode(
    'ChRMaXN0RXhwZW5zZXNSZXNwb25zZRIrCghleHBlbnNlcxgBIAMoCzIPLnBvcy52MS5FeHBlbn'
    'NlUghleHBlbnNlcw==');

@$core.Deprecated('Use createExpenseRequestDescriptor instead')
const CreateExpenseRequest$json = {
  '1': 'CreateExpenseRequest',
  '2': [
    {
      '1': 'expense',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.pos.v1.Expense',
      '10': 'expense'
    },
  ],
};

/// Descriptor for `CreateExpenseRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createExpenseRequestDescriptor = $convert.base64Decode(
    'ChRDcmVhdGVFeHBlbnNlUmVxdWVzdBIpCgdleHBlbnNlGAEgASgLMg8ucG9zLnYxLkV4cGVuc2'
    'VSB2V4cGVuc2U=');

@$core.Deprecated('Use createExpenseResponseDescriptor instead')
const CreateExpenseResponse$json = {
  '1': 'CreateExpenseResponse',
  '2': [
    {
      '1': 'expense',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.pos.v1.Expense',
      '10': 'expense'
    },
  ],
};

/// Descriptor for `CreateExpenseResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createExpenseResponseDescriptor = $convert.base64Decode(
    'ChVDcmVhdGVFeHBlbnNlUmVzcG9uc2USKQoHZXhwZW5zZRgBIAEoCzIPLnBvcy52MS5FeHBlbn'
    'NlUgdleHBlbnNl');

const $core.Map<$core.String, $core.dynamic> ExpenseServiceBase$json = {
  '1': 'ExpenseService',
  '2': [
    {
      '1': 'ListExpenses',
      '2': '.pos.v1.ListExpensesRequest',
      '3': '.pos.v1.ListExpensesResponse'
    },
    {
      '1': 'CreateExpense',
      '2': '.pos.v1.CreateExpenseRequest',
      '3': '.pos.v1.CreateExpenseResponse'
    },
  ],
};

@$core.Deprecated('Use expenseServiceDescriptor instead')
const $core.Map<$core.String, $core.Map<$core.String, $core.dynamic>>
    ExpenseServiceBase$messageJson = {
  '.pos.v1.ListExpensesRequest': ListExpensesRequest$json,
  '.pos.v1.ListExpensesResponse': ListExpensesResponse$json,
  '.pos.v1.Expense': Expense$json,
  '.pos.v1.Money': $0.Money$json,
  '.pos.v1.CreateExpenseRequest': CreateExpenseRequest$json,
  '.pos.v1.CreateExpenseResponse': CreateExpenseResponse$json,
};

/// Descriptor for `ExpenseService`. Decode as a `google.protobuf.ServiceDescriptorProto`.
final $typed_data.Uint8List expenseServiceDescriptor = $convert.base64Decode(
    'Cg5FeHBlbnNlU2VydmljZRJJCgxMaXN0RXhwZW5zZXMSGy5wb3MudjEuTGlzdEV4cGVuc2VzUm'
    'VxdWVzdBocLnBvcy52MS5MaXN0RXhwZW5zZXNSZXNwb25zZRJMCg1DcmVhdGVFeHBlbnNlEhwu'
    'cG9zLnYxLkNyZWF0ZUV4cGVuc2VSZXF1ZXN0Gh0ucG9zLnYxLkNyZWF0ZUV4cGVuc2VSZXNwb2'
    '5zZQ==');
