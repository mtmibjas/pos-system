/// Stock (inventory on-hand) screen — one row per SKU. Restyled to the Dostop
/// design (docs/desktop-pos-ui-design.md): a panel header, column headings,
/// and stock-tone badges (out/low/ok) matching the Counter tiles. Rows with
/// zero on_hand still render (useful when reconciling a stock-take); SKUs
/// without a catalog name render muted.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ui/theme.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';
import '../cart/money_format.dart';
import 'inventory_controller.dart';

class InventoryScreen extends ConsumerWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(inventoryControllerProvider);
    final count = state.valueOrNull?.rows.length ?? 0;

    return Scaffold(
      backgroundColor: DostopColors.canvas,
      body: Column(
        children: [
          DostopScreenHeader(
            title: 'Stock',
            subtitle: count > 0 ? '$count items on hand' : null,
            actions: [
              IconButton(
                tooltip: 'Reload',
                onPressed: state.isLoading
                    ? null
                    : () =>
                        ref.read(inventoryControllerProvider.notifier).refresh(),
                icon: const Icon(Icons.refresh,
                    size: 20, color: DostopColors.slate500),
              ),
            ],
          ),
          _columnHeader(),
          Expanded(
            child: state.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: SelectableText('Failed to load stock: $err',
                      style: DostopText.label
                          .copyWith(color: DostopColors.danger)),
                ),
              ),
              data: (view) {
                if (view.rows.isEmpty) {
                  return const DostopEmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: 'No stock movements yet',
                    detail: 'On-hand quantities appear once items are received '
                        'or sold.',
                  );
                }
                return ListView.builder(
                  itemCount: view.rows.length,
                  itemBuilder: (_, i) => _StockRow(row: view.rows[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _columnHeader() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: const BoxDecoration(
          color: DostopColors.slate50,
          border: Border(bottom: BorderSide(color: DostopColors.hairline)),
        ),
        child: const Row(children: [
          SizedBox(width: 130, child: Text('SKU', style: DostopText.columnHead)),
          Expanded(child: Text('ITEM', style: DostopText.columnHead)),
          SizedBox(
              width: 110,
              child: Text('PRICE',
                  textAlign: TextAlign.right, style: DostopText.columnHead)),
          SizedBox(
              width: 150,
              child: Text('ON HAND',
                  textAlign: TextAlign.right, style: DostopText.columnHead)),
        ]),
      );
}

class _StockRow extends StatelessWidget {
  const _StockRow({required this.row});

  final InventoryRow row;

  @override
  Widget build(BuildContext context) {
    final r = row.row;
    final onHand = r.onHand.toInt();
    final tone = stockTone(onHand);
    final unlinked = r.name.isEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
      decoration: const BoxDecoration(
        color: DostopColors.panel,
        border: Border(bottom: BorderSide(color: DostopColors.slate100)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(r.sku,
                overflow: TextOverflow.ellipsis, style: DostopText.mono),
          ),
          Expanded(
            child: Text(unlinked ? '(unlinked SKU)' : r.name,
                overflow: TextOverflow.ellipsis,
                style: unlinked
                    ? DostopText.itemName.copyWith(
                        fontStyle: FontStyle.italic,
                        color: DostopColors.slate400)
                    : DostopText.itemName),
          ),
          SizedBox(
            width: 110,
            child: Text(r.hasPrice() ? formatMoney(r.price) : '—',
                textAlign: TextAlign.right, style: DostopText.money),
          ),
          SizedBox(
            width: 150,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (row.available != null) ...[
                  Text('${row.available} avail',
                      style: DostopText.mono
                          .copyWith(color: DostopColors.slate400)),
                  const SizedBox(width: 8),
                ],
                DostopPill(label: '$onHand', fg: tone.fg, bg: tone.bg),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
