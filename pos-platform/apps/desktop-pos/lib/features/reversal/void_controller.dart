/// Drives RefundService.VoidSale from the receipt screen.
///
/// Whole-sale void within the configured void window. Server reverses
/// payments automatically (no client-side per-tender refund rows
/// needed — that's RefundSale's domain). Idempotent on void_id.
library;

import 'package:pos_sdk/gen/google/protobuf/timestamp.pb.dart';
import 'package:pos_sdk/gen/pos/v1/common.pb.dart';
import 'package:pos_sdk/gen/pos/v1/refund_service.connect.client.dart';
import 'package:pos_sdk/gen/pos/v1/refund_service.pb.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

import '../../config.dart';
import '../../core/transport.dart';

part 'void_controller.g.dart';

@riverpod
class VoidController extends _$VoidController {
  static const _uuid = Uuid();

  @override
  Future<VoidSaleResponse?> build() async => null;

  Future<void> voidSale({
    required String saleId,
    required String reason,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _submit(saleId, reason));
  }

  Future<VoidSaleResponse> _submit(String saleId, String reason) async {
    final client = RefundServiceClient(ref.read(transportProvider));
    final req = VoidSaleRequest(
      voidId: _uuid.v4(),
      saleId: saleId,
      storeId: StoreId(value: kStoreId),
      counterId: CounterId(value: kCounterId),
      cashierId: UserId(value: kCashierId),
      reason: reason,
      occurredAt: Timestamp.fromDateTime(DateTime.now().toUtc()),
    );
    return client.voidSale(req);
  }

  void reset() {
    state = const AsyncValue.data(null);
  }
}
