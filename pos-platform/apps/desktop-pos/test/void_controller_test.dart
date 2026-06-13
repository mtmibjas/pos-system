/// VoidController tests using a FakeTransport.
///
/// Covers happy path (request shape, response surfaced) and the
/// void-window-closed FailedPrecondition surfacing as AsyncError.
library;

import 'package:connectrpc/connect.dart' as connect;
import 'package:connectrpc/test.dart' as ctest;
import 'package:desktop_pos/config.dart';
import 'package:desktop_pos/core/transport.dart';
import 'package:desktop_pos/features/reversal/void_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_sdk/gen/pos/v1/refund_service.connect.spec.dart';
import 'package:pos_sdk/gen/pos/v1/refund_service.pb.dart';

void main() {
  test('voidSale() sends a well-formed request and surfaces response',
      () async {
    VoidSaleRequest? captured;
    final fake = ctest.FakeTransportBuilder()
        .unary(RefundService.voidSale, (req, _) async {
      captured = req;
      return VoidSaleResponse(
        voidId: req.voidId,
        void_4: Void(
          voidId: req.voidId,
          saleId: req.saleId,
          reason: req.reason,
        ),
      );
    }).build();

    final c = ProviderContainer(overrides: [
      transportProvider.overrideWithValue(fake),
    ]);
    addTearDown(c.dispose);

    await c
        .read(voidControllerProvider.notifier)
        .voidSale(saleId: 'sale-xyz', reason: 'duplicate ring-up');

    final state = c.read(voidControllerProvider);
    expect(state.hasValue, isTrue);
    expect(state.value?.void_4.saleId, 'sale-xyz');

    expect(captured, isNotNull);
    expect(captured!.voidId, hasLength(36));
    expect(captured!.saleId, 'sale-xyz');
    expect(captured!.reason, 'duplicate ring-up');
    expect(captured!.storeId.value, kStoreId);
    expect(captured!.counterId.value, kCounterId);
    expect(captured!.cashierId.value, kCashierId);
  });

  test('voidSale() surfaces FailedPrecondition (window closed) as AsyncError',
      () async {
    final fake = ctest.FakeTransportBuilder()
        .unary(RefundService.voidSale, (req, _) async {
      throw connect.ConnectException(
        connect.Code.failedPrecondition,
        'void window closed',
      );
    }).build();

    final c = ProviderContainer(overrides: [
      transportProvider.overrideWithValue(fake),
    ]);
    addTearDown(c.dispose);

    await c
        .read(voidControllerProvider.notifier)
        .voidSale(saleId: 'sale-xyz', reason: 'too late');

    final state = c.read(voidControllerProvider);
    expect(state.hasError, isTrue);
    expect(
      (state.error as connect.ConnectException).code,
      connect.Code.failedPrecondition,
    );
  });

  test('reset() returns state to idle (null value)', () async {
    final fake = ctest.FakeTransportBuilder()
        .unary(RefundService.voidSale, (req, _) async => VoidSaleResponse(
              voidId: req.voidId,
              void_4: Void(voidId: req.voidId, saleId: req.saleId),
            ))
        .build();

    final c = ProviderContainer(overrides: [
      transportProvider.overrideWithValue(fake),
    ]);
    addTearDown(c.dispose);

    await c
        .read(voidControllerProvider.notifier)
        .voidSale(saleId: 's', reason: 'r');
    expect(c.read(voidControllerProvider).hasValue, isTrue);

    c.read(voidControllerProvider.notifier).reset();
    expect(c.read(voidControllerProvider).valueOrNull, isNull);
  });
}
