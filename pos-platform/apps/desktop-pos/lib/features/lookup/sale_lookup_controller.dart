/// Sale lookup — read-side wrapper around SaleService.GetSale.
///
/// State is AsyncValue<GetSaleResponse?>. The picker AppBar pushes the
/// lookup screen; the lookup screen calls [byInvoiceNumber] (operator
/// types INV-YYYY-NNNNNN) or [bySaleId] (rare; used by tests).
///
/// Hydration: on success we don't store anything beyond the response
/// itself. The lookup *screen* projects the response into the existing
/// CartController + FinalizeController so the receipt screen renders
/// it exactly like a just-finalized sale (lets the Void/Refund flow
/// from slice 2.10 work unchanged).
library;

import 'package:pos_sdk/gen/pos/v1/sale_service.connect.client.dart';
import 'package:pos_sdk/gen/pos/v1/sale_service.pb.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/transport.dart';

part 'sale_lookup_controller.g.dart';

@riverpod
class SaleLookupController extends _$SaleLookupController {
  @override
  Future<GetSaleResponse?> build() async => null;

  Future<void> bySaleId(String saleId) async {
    if (saleId.isEmpty) return;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final client = SaleServiceClient(ref.read(transportProvider));
      return client.getSale(GetSaleRequest(saleId: saleId));
    });
  }

  Future<void> byInvoiceNumber(String invoiceNumber) async {
    if (invoiceNumber.isEmpty) return;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final client = SaleServiceClient(ref.read(transportProvider));
      return client.getSale(GetSaleRequest(invoiceNumber: invoiceNumber));
    });
  }

  void reset() {
    state = const AsyncValue.data(null);
  }
}
