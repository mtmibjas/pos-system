//
//  Generated code. Do not modify.
//  source: pos/v1/refund_service.proto
//

import "package:connectrpc/connect.dart" as connect;
import "refund_service.pb.dart" as posv1refund_service;
import "refund_service.connect.spec.dart" as specs;

/// RefundService exposes void + refund flows. See refunds/service.go for
/// the canonical contract — this proto is a thin adapter on top.
/// Idempotency: identical void_id / refund_id replay returns the prior
/// response with idempotent=true.
extension type RefundServiceClient (connect.Transport _transport) {
  Future<posv1refund_service.VoidSaleResponse> voidSale(
    posv1refund_service.VoidSaleRequest input, {
    connect.Headers? headers,
    connect.AbortSignal? signal,
    Function(connect.Headers)? onHeader,
    Function(connect.Headers)? onTrailer,
  }) {
    return connect.Client(_transport).unary(
      specs.RefundService.voidSale,
      input,
      signal: signal,
      headers: headers,
      onHeader: onHeader,
      onTrailer: onTrailer,
    );
  }

  Future<posv1refund_service.RefundSaleResponse> refundSale(
    posv1refund_service.RefundSaleRequest input, {
    connect.Headers? headers,
    connect.AbortSignal? signal,
    Function(connect.Headers)? onHeader,
    Function(connect.Headers)? onTrailer,
  }) {
    return connect.Client(_transport).unary(
      specs.RefundService.refundSale,
      input,
      signal: signal,
      headers: headers,
      onHeader: onHeader,
      onTrailer: onTrailer,
    );
  }
}
