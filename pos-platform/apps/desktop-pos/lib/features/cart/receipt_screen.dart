/// Receipt screen — terminal state of the cashier flow.
///
/// Reads the most-recent FinalizeRecord from FinalizeController and
/// renders invoice number, grand total, tax total, and per-line
/// summary from the cart. The cart is intentionally NOT cleared until
/// the operator hits "New sale" — gives them a chance to re-read the
/// receipt without losing context.
///
/// Slice 2.10 adds void + refund affordances. The buttons trigger a
/// confirmation dialog (free-form reason) and dispatch the matching
/// controller. On success we push the ReversalReceiptScreen.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_sdk/gen/pos/v1/refund_service.pb.dart';

import '../reversal/refund_controller.dart';
import '../reversal/reversal_receipt_screen.dart';
import '../reversal/void_controller.dart';
import 'cart_controller.dart';
import 'finalize_controller.dart';
import 'money_format.dart';

class ReceiptScreen extends ConsumerWidget {
  const ReceiptScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final record = ref.watch(finalizeControllerProvider).valueOrNull;
    final cart = ref.watch(cartControllerProvider);
    final voidState = ref.watch(voidControllerProvider);
    final refundState = ref.watch(refundControllerProvider);

    // Defensive fallback if state was reset between push and build.
    if (record == null) {
      return const Scaffold(
        body: Center(child: Text('(no invoice — start a new sale)')),
      );
    }
    final resp = record.response;
    final invoice = resp.invoice;

    // Push the reversal receipt as soon as either reversal lands.
    ref.listen<AsyncValue<VoidSaleResponse?>>(voidControllerProvider,
        (prev, next) {
      next.whenOrNull(data: (r) {
        if (r == null) return;
        _navigateToReversalReceipt(context);
      });
    });
    ref.listen<AsyncValue<RefundSaleResponse?>>(refundControllerProvider,
        (prev, next) {
      next.whenOrNull(data: (r) {
        if (r == null) return;
        _navigateToReversalReceipt(context);
      });
    });

    final reversalInFlight = voidState.isLoading || refundState.isLoading;

    return Scaffold(
      appBar: AppBar(
        title: Text(invoice.invoiceNumber),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.check_circle, size: 64, color: Colors.green),
            const SizedBox(height: 16),
            Center(
              child: Text(
                resp.idempotent ? 'Replayed (idempotent)' : 'Sale complete',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: 24),
            _kv(context, 'Invoice', invoice.invoiceNumber),
            _kv(context, 'Sale ID', record.saleId),
            _kv(context, 'Subtotal', formatMoney(invoice.subtotal)),
            _kv(context, 'Tax', formatMoney(invoice.taxTotal)),
            _kv(context, 'Grand total', formatMoney(invoice.grandTotal),
                emphasis: true),
            const Divider(height: 32),
            Text('Lines', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: cart.lines
                    .map((l) => ListTile(
                          dense: true,
                          title: Text(l.description),
                          subtitle: Text('${l.sku} × ${l.quantity}'),
                          trailing: Text(formatMoney(l.lineTotal)),
                        ))
                    .toList(),
              ),
            ),
            if (voidState.hasError)
              _ErrorText(label: 'Void failed', err: voidState.error!),
            if (refundState.hasError)
              _ErrorText(label: 'Refund failed', err: refundState.error!),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: reversalInFlight
                        ? null
                        : () => _confirmAndRun(
                              context,
                              title: 'Void sale',
                              actionLabel: 'Void',
                              onConfirm: (reason) => ref
                                  .read(voidControllerProvider.notifier)
                                  .voidSale(
                                    saleId: record.saleId,
                                    reason: reason,
                                  ),
                            ),
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Void'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: reversalInFlight
                        ? null
                        : () => _confirmAndRun(
                              context,
                              title: 'Refund sale',
                              actionLabel: 'Refund',
                              onConfirm: (reason) => ref
                                  .read(refundControllerProvider.notifier)
                                  .refundAll(
                                    cart: cart,
                                    record: record,
                                    reason: reason,
                                  ),
                            ),
                    icon: const Icon(Icons.replay_outlined),
                    label: const Text('Refund'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: reversalInFlight ? null : () => _newSale(context, ref),
              icon: const Icon(Icons.add_shopping_cart),
              label: const Text('New sale'),
            ),
          ],
        ),
      ),
    );
  }

  void _newSale(BuildContext context, WidgetRef ref) {
    ref.read(cartControllerProvider.notifier).clear();
    ref.read(finalizeControllerProvider.notifier).reset();
    ref.read(voidControllerProvider.notifier).reset();
    ref.read(refundControllerProvider.notifier).reset();
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  void _navigateToReversalReceipt(BuildContext context) {
    // Post-frame so we don't push during a notification cycle.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ReversalReceiptScreen()),
      );
    });
  }

  Future<void> _confirmAndRun(
    BuildContext context, {
    required String title,
    required String actionLabel,
    required void Function(String reason) onConfirm,
  }) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _ReasonDialog(),
    );
    if (reason == null || reason.isEmpty) return;
    if (!context.mounted) return;
    onConfirm(reason);
  }

  Widget _kv(BuildContext context, String k, String v,
      {bool emphasis = false}) {
    final style = emphasis
        ? Theme.of(context).textTheme.titleLarge
        : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 140, child: Text(k)),
          Expanded(child: Text(v, style: style)),
        ],
      ),
    );
  }
}

/// Inline reason prompt — required, non-empty. Cancel returns null.
class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog();

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _ctrl = TextEditingController();
  String _val = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reason'),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Why?',
          border: OutlineInputBorder(),
        ),
        onChanged: (v) => setState(() => _val = v.trim()),
        onSubmitted: (v) {
          final t = v.trim();
          if (t.isNotEmpty) Navigator.of(context).pop(t);
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _val.isEmpty
              ? null
              : () => Navigator.of(context).pop(_ctrl.text.trim()),
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}

class _ErrorText extends StatelessWidget {
  const _ErrorText({required this.label, required this.err});
  final String label;
  final Object err;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SelectableText(
        '$label: $err',
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    );
  }
}
