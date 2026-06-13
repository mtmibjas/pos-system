/// Item picker — Slice 2.9 entry point for the cashier flow.
///
/// Lists the live catalog (ItemService.ListItems), filters in-memory by
/// SKU or name, and on tap pushes the item into the cart via
/// CartController. AppBar shows a cart badge with total quantity, tap
/// → cart screen.
///
/// Errors render in-place with a Retry button. Empty results render a
/// gentle "no items" placeholder (and a hint to run `make seed-demo`).
///
/// Slice 2.13: a USB-HID barcode scanner that types into the focused
/// app is routed through ScanBuffer. We only consume key events when
/// the search field is NOT focused so manual typing still works.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_sdk/gen/pos/v1/item_service.pb.dart';

import '../cart/cart_controller.dart';
import '../cart/cart_screen.dart';
import '../cart/money_format.dart';
import '../inventory/inventory_screen.dart';
import '../lookup/sale_lookup_screen.dart';
import '../reservations/reservations_controller.dart';
import 'items_controller.dart';
import 'scan_buffer.dart';

class ItemPickerScreen extends ConsumerStatefulWidget {
  const ItemPickerScreen({super.key});

  @override
  ConsumerState<ItemPickerScreen> createState() => _ItemPickerScreenState();
}

class _ItemPickerScreenState extends ConsumerState<ItemPickerScreen> {
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  final _scanner = ScanBuffer();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  /// Routes a hardware key event into the scan buffer.
  ///
  /// Skips events while the search field is focused (so manual typing
  /// still works), while non-data routes (e.g. modifier keys) are
  /// ignored. The buffer commits on Enter / Numpad Enter — the wire
  /// terminator USB-HID scanners default to.
  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (_searchFocus.hasFocus) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      final payload = _scanner.commit();
      if (payload.isNotEmpty) _onScanned(payload);
      return KeyEventResult.handled;
    }
    final ch = event.character;
    if (ch == null || ch.isEmpty || ch.length != 1) {
      return KeyEventResult.ignored;
    }
    // Only ASCII-visible printables — barcode payloads never contain
    // control chars and ignoring them stops modifier key combos from
    // poisoning the buffer.
    final code = ch.codeUnitAt(0);
    if (code < 0x20 || code > 0x7e) return KeyEventResult.ignored;
    _scanner.add(ch);
    return KeyEventResult.handled;
  }

  void _onScanned(String sku) {
    final items = ref.read(itemsControllerProvider).valueOrNull;
    if (items == null) return;
    final match = items.firstWhere(
      (i) => i.sku == sku,
      orElse: () => Item(),
    );
    if (match.sku.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unknown SKU: $sku'),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    // Fire-and-forget; _onPick handles its own snackbars.
    _onPick(match);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(itemsControllerProvider);
    final cart = ref.watch(cartControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('pos-platform • items'),
        actions: [
          IconButton(
            tooltip: 'Find sale',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SaleLookupScreen()),
              );
            },
            icon: const Icon(Icons.receipt_long_outlined),
          ),
          IconButton(
            tooltip: 'Inventory',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const InventoryScreen()),
              );
            },
            icon: const Icon(Icons.inventory_2_outlined),
          ),
          IconButton(
            tooltip: 'Reload',
            onPressed: state.isLoading
                ? null
                : () => ref.read(itemsControllerProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh),
          ),
          _CartBadge(quantity: cart.totalQuantity),
          const SizedBox(width: 8),
        ],
      ),
      body: Focus(
        autofocus: true,
        canRequestFocus: true,
        onKeyEvent: _handleKey,
        child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _searchCtrl,
              focusNode: _searchFocus,
              decoration: const InputDecoration(
                labelText: 'Search SKU or name',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: state.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => _ErrorView(
                  error: err,
                  onRetry: () =>
                      ref.read(itemsControllerProvider.notifier).refresh(),
                ),
                data: (items) {
                  final filtered = _filter(items, _query);
                  if (filtered.isEmpty) {
                    return Center(
                      child: Text(
                        items.isEmpty
                            ? 'No items in catalog yet. Run `make seed-demo`.'
                            : 'No items match "$_query".',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    );
                  }
                  return ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) => _ItemCard(
                      item: filtered[i],
                      onTap: () => _onPick(filtered[i]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  /// Reserve a single unit, then (only on success) add to the cart.
  /// Out-of-stock surfaces as a snackbar; the cart is left unchanged
  /// so the on-screen counter stays truthful.
  Future<void> _onPick(Item item) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(reservationsControllerProvider.notifier)
          .reserveOne(item.sku);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Out of stock: ${item.sku}'),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    ref.read(cartControllerProvider.notifier).addLine(item);
    messenger.showSnackBar(
      SnackBar(
        content: Text('Added ${item.sku}'),
        duration: const Duration(milliseconds: 800),
      ),
    );
  }
}

List<Item> _filter(List<Item> items, String query) {
  if (query.isEmpty) return items;
  return items
      .where((i) =>
          i.sku.toLowerCase().contains(query) ||
          i.name.toLowerCase().contains(query))
      .toList();
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.item, required this.onTap});

  final Item item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        title: Text(item.name),
        subtitle: Text(item.sku),
        trailing: Text(
          formatMoney(item.price),
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
    );
  }
}

class _CartBadge extends StatelessWidget {
  const _CartBadge({required this.quantity});

  final int quantity;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Stack(
        alignment: Alignment.center,
        children: [
          IconButton(
            tooltip: 'Cart',
            icon: const Icon(Icons.shopping_cart_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CartScreen()),
              );
            },
          ),
          if (quantity > 0)
            Positioned(
              right: 4,
              top: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$quantity',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48),
          const SizedBox(height: 12),
          Text(
            'Failed to load items',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          SelectableText(
            '$error',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
