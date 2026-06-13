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
      appBar: AppBar(title: const Text('Find sale')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _ctrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Invoice # or sale UUID',
                hintText: 'INV-2026-000001',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _val = v.trim()),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: state.isLoading || _val.isEmpty ? null : _submit,
              icon: const Icon(Icons.search),
              label: const Text('Lookup'),
            ),
            const SizedBox(height: 24),
            if (state.isLoading) const Center(child: CircularProgressIndicator()),
            if (state.hasError)
              SelectableText(
                'Lookup failed: ${state.error}',
                style:
                    TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
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
