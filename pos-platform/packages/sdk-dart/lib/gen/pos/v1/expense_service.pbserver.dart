// This is a generated file - do not edit.
//
// Generated from pos/v1/expense_service.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names

import 'dart:async' as $async;
import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

import 'expense_service.pb.dart' as $1;
import 'expense_service.pbjson.dart';

export 'expense_service.pb.dart';

abstract class ExpenseServiceBase extends $pb.GeneratedService {
  $async.Future<$1.ListExpensesResponse> listExpenses(
      $pb.ServerContext ctx, $1.ListExpensesRequest request);
  $async.Future<$1.CreateExpenseResponse> createExpense(
      $pb.ServerContext ctx, $1.CreateExpenseRequest request);

  $pb.GeneratedMessage createRequest($core.String methodName) {
    switch (methodName) {
      case 'ListExpenses':
        return $1.ListExpensesRequest();
      case 'CreateExpense':
        return $1.CreateExpenseRequest();
      default:
        throw $core.ArgumentError('Unknown method: $methodName');
    }
  }

  $async.Future<$pb.GeneratedMessage> handleCall($pb.ServerContext ctx,
      $core.String methodName, $pb.GeneratedMessage request) {
    switch (methodName) {
      case 'ListExpenses':
        return listExpenses(ctx, request as $1.ListExpensesRequest);
      case 'CreateExpense':
        return createExpense(ctx, request as $1.CreateExpenseRequest);
      default:
        throw $core.ArgumentError('Unknown method: $methodName');
    }
  }

  $core.Map<$core.String, $core.dynamic> get $json => ExpenseServiceBase$json;
  $core.Map<$core.String, $core.Map<$core.String, $core.dynamic>>
      get $messageJson => ExpenseServiceBase$messageJson;
}
