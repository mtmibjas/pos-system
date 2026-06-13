//
//  Generated code. Do not modify.
//  source: pos/v1/refund_service.proto
//

import "package:connectrpc/connect.dart" as connect;
import "refund_service.pb.dart" as posv1refund_service;

/// RefundService exposes void + refund flows. See refunds/service.go for
/// the canonical contract — this proto is a thin adapter on top.
/// Idempotency: identical void_id / refund_id replay returns the prior
/// response with idempotent=true.
abstract final class RefundService {
  /// Fully-qualified name of the RefundService service.
  static const name = 'pos.v1.RefundService';

  static const voidSale = connect.Spec(
    '/$name/VoidSale',
    connect.StreamType.unary,
    posv1refund_service.VoidSaleRequest.new,
    posv1refund_service.VoidSaleResponse.new,
  );

  static const refundSale = connect.Spec(
    '/$name/RefundSale',
    connect.StreamType.unary,
    posv1refund_service.RefundSaleRequest.new,
    posv1refund_service.RefundSaleResponse.new,
  );
}
