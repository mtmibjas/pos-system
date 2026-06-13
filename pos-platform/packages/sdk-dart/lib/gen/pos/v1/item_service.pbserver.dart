// This is a generated file - do not edit.
//
// Generated from pos/v1/item_service.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names

import 'dart:async' as $async;
import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

import 'item_service.pb.dart' as $2;
import 'item_service.pbjson.dart';

export 'item_service.pb.dart';

abstract class ItemServiceBase extends $pb.GeneratedService {
  $async.Future<$2.UpsertItemResponse> upsertItem(
      $pb.ServerContext ctx, $2.UpsertItemRequest request);
  $async.Future<$2.GetItemResponse> getItem(
      $pb.ServerContext ctx, $2.GetItemRequest request);
  $async.Future<$2.ListItemsResponse> listItems(
      $pb.ServerContext ctx, $2.ListItemsRequest request);

  $pb.GeneratedMessage createRequest($core.String methodName) {
    switch (methodName) {
      case 'UpsertItem':
        return $2.UpsertItemRequest();
      case 'GetItem':
        return $2.GetItemRequest();
      case 'ListItems':
        return $2.ListItemsRequest();
      default:
        throw $core.ArgumentError('Unknown method: $methodName');
    }
  }

  $async.Future<$pb.GeneratedMessage> handleCall($pb.ServerContext ctx,
      $core.String methodName, $pb.GeneratedMessage request) {
    switch (methodName) {
      case 'UpsertItem':
        return upsertItem(ctx, request as $2.UpsertItemRequest);
      case 'GetItem':
        return getItem(ctx, request as $2.GetItemRequest);
      case 'ListItems':
        return listItems(ctx, request as $2.ListItemsRequest);
      default:
        throw $core.ArgumentError('Unknown method: $methodName');
    }
  }

  $core.Map<$core.String, $core.dynamic> get $json => ItemServiceBase$json;
  $core.Map<$core.String, $core.Map<$core.String, $core.dynamic>>
      get $messageJson => ItemServiceBase$messageJson;
}
