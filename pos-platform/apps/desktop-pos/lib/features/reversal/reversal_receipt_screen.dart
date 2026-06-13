/// Terminal screen after Void or Refund completes.
///
/// One screen, two modes — we render whichever controller has data.
/// "Back to picker" clears both reversal controllers and the cart,
/// and pops to the picker (which is the root home).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_sdk/gen/pos/v1/refund_service.pb.dart';

import '../cart/cart_controller.dart';
import '../cart/finalize_controller.dart';
import '../cart/money_format.dart';
import 'refund_controller.dart';
import 'void_controller.dart';

class ReversalReceiptScreen extends ConsumerWidget {
  const ReversalReceiptScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voidResp = ref.watch(voidControllerProvider).valueOrNull;
    final refundResp = ref.watch(refundControllerProvider).valueOrNull;

    final Widget body;
    final String title;

    if (refundResp != null) {
      title = refundResp.refund.creditNoteNumber;
      body = _RefundBody(resp: refundResp);
    } else if (voidResp != null) {
      title = 'Voided';
      body = _VoidBody(resp: voidResp);
    } else {
      title = 'Reversal';
      body = const Center(child: Text('(no reversal in flight)'));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: body),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _backToPicker(context, ref),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to picker'),
            ),
          ],
        ),
      ),
    );
  }

  void _backToPicker(BuildContext context, WidgetRef ref) {
    ref.read(cartControllerProvider.notifier).clear();
    ref.read(finalizeControllerProvider.notifier).reset();
    ref.read(voidControllerProvider.notifier).reset();
    ref.read(refundControllerProvider.notifier).reset();
    Navigator.of(context).popUntil((r) => r.isFirst);
  }
}

class _VoidBody extends StatelessWidget {
  const _VoidBody({required this.resp});
  final VoidSaleResponse resp;

  @override
  Widget build(BuildContext context) {
    // `void` is reserved in Dart; the generator escapes the field as
    // `void_4` (tag number 4 on the wire).
    final v = resp.void_4;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.cancel, size: 64, color: Colors.orange),
        const SizedBox(height: 16),
        Center(
          child: Text(
            resp.idempotent ? 'Sale voided (replayed)' : 'Sale voided',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: 24),
        _kv(context, 'Void ID', resp.voidId),
        _kv(context, 'Sale ID', v.saleId),
        if (v.reason.isNotEmpty) _kv(context, 'Reason', v.reason),
      ],
    );
  }
}

class _RefundBody extends StatelessWidget {
  const _RefundBody({required this.resp});
  final RefundSaleResponse resp;

  @override
  Widget build(BuildContext context) {
    final r = resp.refund;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.replay, size: 64, color: Colors.blue),
        const SizedBox(height: 16),
        Center(
          child: Text(
            resp.idempotent ? 'Sale refunded (replayed)' : 'Sale refunded',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: 24),
        _kv(context, 'Credit note', r.creditNoteNumber),
        _kv(context, 'Refund ID', resp.refundId),
        _kv(context, 'Sale ID', r.saleId),
        _kv(context, 'Subtotal', formatMoney(r.subtotal)),
        _kv(context, 'Tax', formatMoney(r.taxTotal)),
        _kv(context, 'Grand total', formatMoney(r.grandTotal), emphasis: true),
        if (r.reason.isNotEmpty) _kv(context, 'Reason', r.reason),
      ],
    );
  }
}

Widget _kv(BuildContext context, String k, String v, {bool emphasis = false}) {
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
