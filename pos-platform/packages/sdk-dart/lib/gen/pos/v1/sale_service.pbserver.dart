// This is a generated file - do not edit.
//
// Generated from pos/v1/sale_service.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names

import 'dart:async' as $async;
import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

import 'sale_service.pb.dart' as $2;
import 'sale_service.pbjson.dart';

export 'sale_service.pb.dart';

abstract class SaleServiceBase extends $pb.GeneratedService {
  $async.Future<$2.FinalizeResponse> finalize(
      $pb.ServerContext ctx, $2.FinalizeRequest request);
  $async.Future<$2.GetSaleResponse> getSale(
      $pb.ServerContext ctx, $2.GetSaleRequest request);

  $pb.GeneratedMessage createRequest($core.String methodName) {
    switch (methodName) {
      case 'Finalize':
        return $2.FinalizeRequest();
      case 'GetSale':
        return $2.GetSaleRequest();
      default:
        throw $core.ArgumentError('Unknown method: $methodName');
    }
  }

  $async.Future<$pb.GeneratedMessage> handleCall($pb.ServerContext ctx,
      $core.String methodName, $pb.GeneratedMessage request) {
    switch (methodName) {
      case 'Finalize':
        return finalize(ctx, request as $2.FinalizeRequest);
      case 'GetSale':
        return getSale(ctx, request as $2.GetSaleRequest);
      default:
        throw $core.ArgumentError('Unknown method: $methodName');
    }
  }

  $core.Map<$core.String, $core.dynamic> get $json => SaleServiceBase$json;
  $core.Map<$core.String, $core.Map<$core.String, $core.dynamic>>
      get $messageJson => SaleServiceBase$messageJson;
}
