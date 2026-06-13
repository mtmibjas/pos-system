// This is a generated file - do not edit.
//
// Generated from pos/v1/refund_service.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names

import 'dart:async' as $async;
import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

import 'refund_service.pb.dart' as $2;
import 'refund_service.pbjson.dart';

export 'refund_service.pb.dart';

abstract class RefundServiceBase extends $pb.GeneratedService {
  $async.Future<$2.VoidSaleResponse> voidSale(
      $pb.ServerContext ctx, $2.VoidSaleRequest request);
  $async.Future<$2.RefundSaleResponse> refundSale(
      $pb.ServerContext ctx, $2.RefundSaleRequest request);

  $pb.GeneratedMessage createRequest($core.String methodName) {
    switch (methodName) {
      case 'VoidSale':
        return $2.VoidSaleRequest();
      case 'RefundSale':
        return $2.RefundSaleRequest();
      default:
        throw $core.ArgumentError('Unknown method: $methodName');
    }
  }

  $async.Future<$pb.GeneratedMessage> handleCall($pb.ServerContext ctx,
      $core.String methodName, $pb.GeneratedMessage request) {
    switch (methodName) {
      case 'VoidSale':
        return voidSale(ctx, request as $2.VoidSaleRequest);
      case 'RefundSale':
        return refundSale(ctx, request as $2.RefundSaleRequest);
      default:
        throw $core.ArgumentError('Unknown method: $methodName');
    }
  }

  $core.Map<$core.String, $core.dynamic> get $json => RefundServiceBase$json;
  $core.Map<$core.String, $core.Map<$core.String, $core.dynamic>>
      get $messageJson => RefundServiceBase$messageJson;
}
