/// Tender screen — single-tender entry. Prefilled with the cart's
/// subtotal preview; cashier picks method (cash/card/upi) and confirms.
///
/// On success → pop to ReceiptScreen via pushReplacement so Back from
/// the receipt goes straight to the picker (no stale tender screen).
/// On error → AsyncError renders inline with the Connect message.
library;

import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_sdk/gen/pos/v1/common.pb.dart';

import 'cart_controller.dart';
import 'finalize_controller.dart';
import 'money_format.dart';
import 'receipt_screen.dart';

class TenderScreen extends ConsumerStatefulWidget {
  const TenderScreen({super.key});

  @override
  ConsumerState<TenderScreen> createState() => _TenderScreenState();
}

class _TenderScreenState extends ConsumerState<TenderScreen> {
  TenderMethod _method = TenderMethod.cash;
  late final TextEditingController _amountCtrl;

  @override
  void initState() {
    super.initState();
    final cart = ref.read(cartControllerProvider);
    // Prefill with subtotal preview — the cashier only confirms unless
    // they're entering a partial / over-tender (deferred to Slice 2.10+).
    _amountCtrl =
        TextEditingController(text: _moneyToInputText(cart.subtotalPreview));
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartControllerProvider);
    final finalize = ref.watch(finalizeControllerProvider);

    // Navigate to receipt on success. Use a post-frame callback so we
    // don't push during a build.
    ref.listen<AsyncValue<dynamic>>(finalizeControllerProvider, (prev, next) {
      next.whenOrNull(data: (resp) {
        if (resp == null) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const ReceiptScreen()),
          );
        });
      });
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Tender')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Cart subtotal',
                style: Theme.of(context).textTheme.bodySmall),
            Text(
              formatMoney(cart.subtotalPreview),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),
            DropdownButtonFormField<TenderMethod>(
              initialValue: _method,
              decoration: const InputDecoration(
                labelText: 'Method',
                border: OutlineInputBorder(),
              ),
              items: TenderMethod.values
                  .map((m) => DropdownMenuItem(
                        value: m,
                        child: Text(m.wireName),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _method = v ?? _method),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountCtrl,
              decoration: const InputDecoration(
                labelText: 'Amount tendered',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 24),
            if (finalize.hasError)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: SelectableText(
                  'Failed: ${finalize.error}',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            FilledButton.icon(
              onPressed: finalize.isLoading
                  ? null
                  : () => _pay(cart),
              icon: finalize.isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.check_circle_outline),
              label: Text(finalize.isLoading ? 'Charging…' : 'Pay'),
            ),
          ],
        ),
      ),
    );
  }

  void _pay(CartState cart) {
    final amount = _parseMoney(
      _amountCtrl.text.trim(),
      cart.subtotalPreview.currencyCode,
    );
    if (amount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount')),
      );
      return;
    }
    ref
        .read(finalizeControllerProvider.notifier)
        .charge(cart: cart, method: _method, amount: amount);
  }
}

/// Format Money for the amount input — "45.00", no currency prefix.
String _moneyToInputText(Money m) {
  if (m.currencyCode.isEmpty) return '';
  final units = m.units.toInt().abs();
  final fractional = (m.nanos / 10000000).round().abs();
  return '$units.${fractional.toString().padLeft(2, '0')}';
}

/// Parse "45", "45.0", "45.50" into a Money. Returns null on garbage.
/// Two-decimal precision — anything finer is dropped silently
/// (sufficient for cash tender).
Money? _parseMoney(String input, String currencyCode) {
  if (input.isEmpty || currencyCode.isEmpty) return null;
  final parts = input.split('.');
  if (parts.length > 2) return null;
  final unitsStr = parts[0];
  final fracStr = parts.length == 2 ? parts[1] : '';
  final units = int.tryParse(unitsStr);
  if (units == null || units < 0) return null;
  // Pad/truncate to 2 digits, then convert to nanos.
  final frac2 = fracStr.padRight(2, '0').substring(0, fracStr.length.clamp(0, 2));
  final fracInt = int.tryParse(frac2.isEmpty ? '0' : frac2) ?? 0;
  final nanos = fracInt * 10000000; // 2 decimals → 10^7 nanos per cent.
  return Money(
    currencyCode: currencyCode,
    units: Int64(units),
    nanos: nanos,
  );
}
