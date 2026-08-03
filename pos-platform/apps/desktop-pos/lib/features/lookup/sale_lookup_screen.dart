/// Sale lookup screen — operator types an invoice number (or pastes a
/// sale_id) and we fetch the canonical record via SaleService.GetSale.
///
/// On success we project the GetSaleResponse into the existing cart +
/// finalize controllers so the reused ReceiptScreen renders it with
/// the same Void/Refund affordances as a just-completed sale. The
/// projection synthesizes:
///   - a FinalizeRecord with the looked-up invoice + sale_id + per-SKU
///     line_ids + TenderRecord list (so refund_controller can build
///     RefundSale tenders referencing original_payment_id)
///   - a CartState containing CartLines mirroring the response (the
///     receipt screen reads `cart.lines` for its line summary)
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_sdk/gen/pos/v1/sale_service.pb.dart';

import '../../ui/theme.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';
import '../cart/cart_controller.dart';
import '../cart/finalize_controller.dart';
import '../cart/receipt_screen.dart';
import 'sale_lookup_controller.dart';

class SaleLookupScreen extends ConsumerStatefulWidget {
  const SaleLookupScreen({super.key});

  @override
  ConsumerState<SaleLookupScreen> createState() => _SaleLookupScreenState();
}

class _SaleLookupScreenState extends ConsumerState<SaleLookupScreen> {
  final _ctrl = TextEditingController();
  String _val = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(saleLookupControllerProvider);

    ref.listen<AsyncValue<GetSaleResponse?>>(saleLookupControllerProvider,
        (prev, next) {
      next.whenOrNull(data: (resp) {
        if (resp == null) return;
        _hydrateAndNavigate(resp);
      });
    });

    return Scaffold(
      backgroundColor: DostopColors.canvas,
      body: Column(
        children: [
          const DostopScreenHeader(
            title: 'Sales register',
            subtitle: 'Find a sale to reprint, void or refund',
          ),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Container(
                  margin: const EdgeInsets.all(24),
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: DostopColors.panel,
                    borderRadius: BorderRadius.circular(DostopRadius.card),
                    border: Border.all(color: DostopColors.slate200),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('Look up a sale', style: DostopText.h1),
                      const SizedBox(height: 4),
                      const Text('Enter an invoice number or paste a sale UUID.',
                          style: DostopText.label),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _ctrl,
                        autofocus: true,
                        decoration: const InputDecoration(
                          hintText: 'INV-2026-000001',
                          prefixIcon: Icon(Icons.receipt_long_outlined,
                              size: 18, color: DostopColors.slate400),
                        ),
                        onChanged: (v) => setState(() => _val = v.trim()),
                        onSubmitted: (_) => _submit(),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 46,
                        child: FilledButton.icon(
                          onPressed:
                              state.isLoading || _val.isEmpty ? null : _submit,
                          icon: const Icon(Icons.search, size: 18),
                          label: const Text('Look up sale'),
                        ),
                      ),
                      if (state.isLoading) ...[
                        const SizedBox(height: 20),
                        const Center(
                            child:
                                CircularProgressIndicator(strokeWidth: 2.5)),
                      ],
                      if (state.hasError) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: DostopColors.stockOutBg,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: SelectableText('Lookup failed: ${state.error}',
                              style: DostopText.label
                                  .copyWith(color: DostopColors.danger)),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _submit() {
    final v = _val;
    final notifier = ref.read(saleLookupControllerProvider.notifier);
    // Heuristic: 36-char dashed input is a UUID; everything else is an
    // invoice number. Lets the operator paste either form.
    if (_looksLikeUuid(v)) {
      notifier.bySaleId(v);
    } else {
      notifier.byInvoiceNumber(v);
    }
  }

  void _hydrateAndNavigate(GetSaleResponse resp) {
    // Project response → cart + finalize controllers, then push the
    // existing ReceiptScreen so Void/Refund work unchanged.
    final cartLines = resp.lines
        .map((l) => CartLine(
              sku: l.sku,
              description: l.description,
              unitPrice: l.unitPrice,
              // tax_category_id isn't on the read-side payload; harmless
              // because lookup → receipt only refunds/voids, never
              // re-finalizes.
              taxCategoryId: '',
              quantity: l.quantity.toInt(),
            ))
        .toList(growable: false);
    final lineIds = <String, String>{
      for (final l in resp.lines) l.sku: l.lineId,
    };
    final tenders = resp.payments
        .map((p) => TenderRecord(
              paymentId: p.paymentId,
              method: _methodFromWire(p.method),
              amount: p.amount,
            ))
        .toList(growable: false);
    final record = FinalizeRecord(
      response: FinalizeResponse(
        saleId: resp.invoice.saleId,
        invoice: resp.invoice,
      ),
      saleId: resp.invoice.saleId,
      lineIdsBySku: lineIds,
      tenders: tenders,
    );

    ref.read(cartControllerProvider.notifier).replaceLines(cartLines);
    ref.read(finalizeControllerProvider.notifier).loadFromLookup(record);
    ref.read(saleLookupControllerProvider.notifier).reset();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ReceiptScreen()),
      );
    });
  }
}

bool _looksLikeUuid(String s) {
  // Quick shape check — 8-4-4-4-12 hex with dashes at the canonical
  // offsets. Avoids pulling in a UUID parser just for input routing.
  if (s.length != 36) return false;
  for (final i in const [8, 13, 18, 23]) {
    if (s[i] != '-') return false;
  }
  return true;
}

TenderMethod _methodFromWire(String s) {
  // Unknown methods fall back to cash — read-only path; the field is
  // only used by the refund flow to repopulate the wire method.
  for (final m in TenderMethod.values) {
    if (m.wireName == s) return m;
  }
  return TenderMethod.cash;
}
