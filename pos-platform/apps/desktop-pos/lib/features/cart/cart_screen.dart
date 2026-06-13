/// Cart screen — review lines, adjust quantities, proceed to tender.
///
/// No tax preview here: subtotal is client-side line sums only. Final
/// tax breakdown materializes after Finalize and is shown on the
/// receipt screen.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../reservations/reservations_controller.dart';
import 'cart_controller.dart';
import 'money_format.dart';
import 'tender_screen.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartControllerProvider);
    final notifier = ref.read(cartControllerProvider.notifier);
    final reservations =
        ref.read(reservationsControllerProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);

    Future<void> bump(String sku, int delta) async {
      if (delta > 0) {
        try {
          await reservations.reserveOne(sku);
        } catch (_) {
          messenger.showSnackBar(
            SnackBar(
              content: Text('Out of stock: $sku'),
              duration: const Duration(seconds: 2),
            ),
          );
          return;
        }
      } else {
        await reservations.releaseOne(sku);
      }
      // Reservation succeeded (or release): now reflect in cart.
      final line = cart.lines.firstWhere((l) => l.sku == sku);
      notifier.setQuantity(sku, line.quantity + delta);
    }

    Future<void> removeRow(String sku) async {
      await reservations.releaseAllFor(sku);
      notifier.removeLine(sku);
    }

    Future<void> clearAll() async {
      await reservations.releaseEverything();
      notifier.clear();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cart'),
        actions: [
          if (!cart.isEmpty)
            IconButton(
              tooltip: 'Clear cart',
              icon: const Icon(Icons.delete_outline),
              onPressed: clearAll,
            ),
        ],
      ),
      body: cart.isEmpty
          ? const Center(child: Text('Cart is empty.'))
          : ListView.separated(
              itemCount: cart.lines.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final line = cart.lines[i];
                return ListTile(
                  title: Text(line.description),
                  subtitle: Text(
                    '${line.sku} • ${formatMoney(line.unitPrice)} ea',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        // qty==1 minus → release-all + remove line.
                        onPressed: () => line.quantity <= 1
                            ? removeRow(line.sku)
                            : bump(line.sku, -1),
                      ),
                      SizedBox(
                        width: 32,
                        child: Text(
                          '${line.quantity}',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () => bump(line.sku, 1),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 96,
                        child: Text(
                          formatMoney(line.lineTotal),
                          textAlign: TextAlign.right,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
      bottomNavigationBar: cart.isEmpty
          ? null
          : _CartFooter(
              subtotal: formatMoney(cart.subtotalPreview),
              onCharge: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const TenderScreen()),
                );
              },
            ),
    );
  }
}

class _CartFooter extends StatelessWidget {
  const _CartFooter({required this.subtotal, required this.onCharge});

  final String subtotal;
  final VoidCallback onCharge;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Subtotal (tax computed at finalize)',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    subtotal,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: onCharge,
              icon: const Icon(Icons.payment),
              label: const Text('Charge'),
            ),
          ],
        ),
      ),
    );
  }
}
