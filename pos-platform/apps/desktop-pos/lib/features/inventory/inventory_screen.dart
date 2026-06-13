/// Inventory on-hand screen — one row per SKU with movements.
///
/// Reachable from the picker's AppBar. Reload button re-runs the
/// fetch; rows with zero on_hand still render (could be useful when
/// reconciling a stock-take). SKUs without a catalog name render in
/// muted italics.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../cart/money_format.dart';
import 'inventory_controller.dart';

class InventoryScreen extends ConsumerWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(inventoryControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory on-hand'),
        actions: [
          IconButton(
            tooltip: 'Reload',
            onPressed: state.isLoading
                ? null
                : () => ref.read(inventoryControllerProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SelectableText(
              'Failed to load inventory: $err',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ),
        data: (view) {
          final rows = view.rows;
          if (rows.isEmpty) {
            return const Center(child: Text('No stock movements yet.'));
          }
          return ListView.separated(
            itemCount: rows.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final ir = rows[i];
              final r = ir.row;
              final name = r.name.isEmpty ? '(unlinked SKU)' : r.name;
              final priceText =
                  r.hasPrice() ? formatMoney(r.price) : '—';
              final theme = Theme.of(context);
              return ListTile(
                title: Text(name,
                    style: r.name.isEmpty
                        ? const TextStyle(fontStyle: FontStyle.italic)
                        : null),
                subtitle: Text(r.sku),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${r.onHand} on hand',
                        style: theme.textTheme.titleMedium),
                    if (ir.available != null)
                      Text('${ir.available} avail',
                          style: theme.textTheme.bodySmall),
                    Text(priceText,
                        style: theme.textTheme.bodySmall),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
