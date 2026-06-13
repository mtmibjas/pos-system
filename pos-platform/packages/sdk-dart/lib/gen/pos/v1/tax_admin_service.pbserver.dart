// This is a generated file - do not edit.
//
// Generated from pos/v1/tax_admin_service.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names

import 'dart:async' as $async;
import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

import 'tax_admin_service.pb.dart' as $0;
import 'tax_admin_service.pbjson.dart';

export 'tax_admin_service.pb.dart';

abstract class TaxAdminServiceBase extends $pb.GeneratedService {
  $async.Future<$0.UpsertTaxCategoryResponse> upsertTaxCategory(
      $pb.ServerContext ctx, $0.UpsertTaxCategoryRequest request);
  $async.Future<$0.UpsertTaxComponentResponse> upsertTaxComponent(
      $pb.ServerContext ctx, $0.UpsertTaxComponentRequest request);
  $async.Future<$0.GetTaxCategoryResponse> getTaxCategory(
      $pb.ServerContext ctx, $0.GetTaxCategoryRequest request);

  $pb.GeneratedMessage createRequest($core.String methodName) {
    switch (methodName) {
      case 'UpsertTaxCategory':
        return $0.UpsertTaxCategoryRequest();
      case 'UpsertTaxComponent':
        return $0.UpsertTaxComponentRequest();
      case 'GetTaxCategory':
        return $0.GetTaxCategoryRequest();
      default:
        throw $core.ArgumentError('Unknown method: $methodName');
    }
  }

  $async.Future<$pb.GeneratedMessage> handleCall($pb.ServerContext ctx,
      $core.String methodName, $pb.GeneratedMessage request) {
    switch (methodName) {
      case 'UpsertTaxCategory':
        return upsertTaxCategory(ctx, request as $0.UpsertTaxCategoryRequest);
      case 'UpsertTaxComponent':
        return upsertTaxComponent(ctx, request as $0.UpsertTaxComponentRequest);
      case 'GetTaxCategory':
        return getTaxCategory(ctx, request as $0.GetTaxCategoryRequest);
      default:
        throw $core.ArgumentError('Unknown method: $methodName');
    }
  }

  $core.Map<$core.String, $core.dynamic> get $json => TaxAdminServiceBase$json;
  $core.Map<$core.String, $core.Map<$core.String, $core.dynamic>>
      get $messageJson => TaxAdminServiceBase$messageJson;
}
