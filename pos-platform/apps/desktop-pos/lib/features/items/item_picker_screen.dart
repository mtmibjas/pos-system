/// Counter (POS) — the cashier sell screen, restyled to the Dostop "Speed"
/// layout (docs/desktop-pos-ui-design.md §4). Three panes:
///
///   • Product list — live catalog (ItemService.ListItems) joined with
///     inventory on-hand for the stock badge; filter by SKU/name; tap or
///     scan reserves one unit then adds to the cart.
///   • Cart — the in-progress sale (CartController): qty steppers + remove.
///   • Right rail — subtotal preview, payment-method picker, Charge CTA.
///
/// Fidelity notes (see design doc §4.2): the catalog has no category field
/// yet, so the prototype's category chips are omitted. Tax / round-off /
/// grand total are server-authoritative at Finalize — the rail shows the
/// truthful **subtotal preview** and defers the real total to tender.
///
/// Barcode scanning (slice 2.13 / step 8c) is unchanged: a USB-HID scanner
/// that types into the focused app is routed through the [BarcodeScanner]
/// port; we only feed keys while the search field is NOT focused.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_sdk/gen/pos/v1/item_service.pb.dart';

import '../../hardware/hardware_providers.dart';
import '../../hardware/ports.dart';
import '../../ui/theme.dart';
import '../../ui/tokens.dart';
import '../cart/cart_controller.dart';
import '../cart/money_format.dart';
import '../cart/tender_screen.dart';
import '../inventory/inventory_controller.dart';
import '../reservations/reservations_controller.dart';
import 'items_controller.dart';

class ItemPickerScreen extends ConsumerStatefulWidget {
  const ItemPickerScreen({super.key});

  @override
  ConsumerState<ItemPickerScreen> createState() => _ItemPickerScreenState();
}

class _ItemPickerScreenState extends ConsumerState<ItemPickerScreen> {
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  late final BarcodeScanner _scanner;
  StreamSubscription<String>? _scanSub;
  String _query = '';
  PayMethod _payMethod = PayMethod.cash;

  @override
  void initState() {
    super.initState();
    _scanner = ref.read(barcodeScannerProvider);
    _scanSub = _scanner.scans.listen(_onScanned);
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    // F2 focuses search from anywhere (prototype affordance, now wired).
    if (event.logicalKey == LogicalKeyboardKey.f2) {
      _searchFocus.requestFocus();
      return KeyEventResult.handled;
    }
    if (_searchFocus.hasFocus) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      _scanner.terminate();
      return KeyEventResult.handled;
    }
    final ch = event.character;
    if (ch == null || ch.isEmpty || ch.length != 1) {
      return KeyEventResult.ignored;
    }
    final code = ch.codeUnitAt(0);
    if (code < 0x20 || code > 0x7e) return KeyEventResult.ignored;
    _scanner.feedChar(ch);
    return KeyEventResult.handled;
  }

  void _onScanned(String sku) {
    if (!mounted) return;
    final items = ref.read(itemsControllerProvider).valueOrNull;
    if (items == null) return;
    final match = items.firstWhere((i) => i.sku == sku, orElse: () => Item());
    if (match.sku.isEmpty) {
      _toast('Unknown SKU: $sku');
      return;
    }
    _onPick(match);
  }

  /// Reserve a single unit, then (only on success) add to the cart.
  Future<void> _onPick(Item item) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(reservationsControllerProvider.notifier)
          .reserveOne(item.sku);
    } catch (_) {
      messenger.showSnackBar(SnackBar(
        content: Text('Out of stock: ${item.sku}'),
        duration: const Duration(seconds: 2),
      ));
      return;
    }
    ref.read(cartControllerProvider.notifier).addLine(item);
  }

  void _toast(String msg) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
      );

  /// SKU → on-hand quantity, from the inventory projection (best-effort;
  /// empty until inventory loads, in which case tiles show no stock badge).
  Map<String, int> _stockBySku() {
    final inv = ref.watch(inventoryControllerProvider).valueOrNull;
    if (inv == null) return const {};
    return {
      for (final r in inv.rows) r.row.sku: r.row.onHand.toInt(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final itemsState = ref.watch(itemsControllerProvider);
    final cart = ref.watch(cartControllerProvider);

    return Scaffold(
      backgroundColor: DostopColors.canvas,
      body: Focus(
        autofocus: true,
        canRequestFocus: true,
        onKeyEvent: _handleKey,
        child: Column(
          children: [
            _header(itemsState),
            Expanded(child: _counterBody(itemsState, cart)),
          ],
        ),
      ),
    );
  }

  /// The three-pane counter. Faithful to the prototype's `overflow-x:auto`
  /// row: panes flex to fill when there's room, otherwise clamp at their
  /// min widths and the whole counter scrolls horizontally (so a narrow
  /// window degrades to a scroll instead of overflowing).
  Widget _counterBody(AsyncValue<List<Item>> itemsState, CartState cart) {
    const productMin = 470.0, cartMin = 430.0, railW = 316.0;
    const minTotal = productMin + cartMin + railW;
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= minTotal;
        final product = _productPane(itemsState);
        final cartPane = _cartPane(cart);
        final rail = _rail(cart);
        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 155, child: product),
              Expanded(flex: 115, child: cartPane),
              SizedBox(width: railW, child: rail),
            ],
          );
        }
        // Narrow: clamp to min widths and scroll the counter horizontally.
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: minTotal,
            height: c.maxHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: productMin, child: product),
                SizedBox(width: cartMin, child: cartPane),
                SizedBox(width: railW, child: rail),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---- Header -------------------------------------------------------------

  Widget _header(AsyncValue<List<Item>> itemsState) {
    final count = itemsState.valueOrNull?.length ?? 0;
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: const BoxDecoration(
        color: DostopColors.panel,
        border: Border(bottom: BorderSide(color: DostopColors.hairline)),
      ),
      child: Row(
        children: [
          const Text('Sell', style: DostopText.h1),
          const SizedBox(width: 10),
          const Text('Speed counter · scan, tap, charge', style: DostopText.kicker),
          const Spacer(),
          IconButton(
            tooltip: 'Reload catalog',
            onPressed: itemsState.isLoading
                ? null
                : () => ref.read(itemsControllerProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh, size: 20, color: DostopColors.slate500),
          ),
          _pill('Items', '$count'),
        ],
      ),
    );
  }

  Widget _pill(String label, String value) => Container(
        margin: const EdgeInsets.only(left: 6),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(
          color: DostopColors.slate100,
          borderRadius: BorderRadius.circular(DostopRadius.chip),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text('$label ', style: DostopText.mono.copyWith(color: DostopColors.slate400)),
          Text(value, style: DostopText.mono.copyWith(
              color: DostopColors.ink, fontWeight: FontWeight.w700)),
        ]),
      );

  // ---- Product pane -------------------------------------------------------

  Widget _productPane(AsyncValue<List<Item>> itemsState) {
    return Container(
      decoration: const BoxDecoration(
        color: DostopColors.panel,
        border: Border(right: BorderSide(color: DostopColors.slate200)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
            child: TextField(
              controller: _searchCtrl,
              focusNode: _searchFocus,
              style: const TextStyle(
                fontFamily: DostopFonts.mono,
                fontSize: 13,
                color: DostopColors.ink,
              ),
              decoration: InputDecoration(
                hintText: 'Scan barcode or type SKU / name…  Enter to add',
                prefixIcon: const Icon(Icons.qr_code_scanner,
                    size: 18, color: DostopColors.slate400),
                suffixIcon: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _keycap('F2'),
                ),
                suffixIconConstraints: const BoxConstraints(minWidth: 0),
              ),
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              onSubmitted: (_) => _addFirstMatch(itemsState.valueOrNull ?? const []),
            ),
          ),
          _productHeaderRow(),
          Expanded(
            child: itemsState.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
              error: (err, _) => _ErrorView(
                error: err,
                onRetry: () =>
                    ref.read(itemsControllerProvider.notifier).refresh(),
              ),
              data: (items) => _productList(items),
            ),
          ),
        ],
      ),
    );
  }

  Widget _productHeaderRow() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: const BoxDecoration(
          color: DostopColors.slate50,
          border: Border(bottom: BorderSide(color: DostopColors.hairline)),
        ),
        child: const Row(children: [
          SizedBox(width: 104, child: Text('SKU', style: DostopText.columnHead)),
          Expanded(child: Text('ITEM', style: DostopText.columnHead)),
          SizedBox(
              width: 70,
              child: Text('STOCK',
                  textAlign: TextAlign.center, style: DostopText.columnHead)),
          SizedBox(
              width: 96,
              child: Text('PRICE',
                  textAlign: TextAlign.right, style: DostopText.columnHead)),
          SizedBox(width: 34),
        ]),
      );

  Widget _productList(List<Item> items) {
    final filtered = _filter(items, _query);
    if (filtered.isEmpty) {
      return Center(
        child: Text(
          items.isEmpty
              ? 'No items in catalog yet. Run `make seed-demo`.'
              : 'No items match "$_query".',
          style: DostopText.label,
        ),
      );
    }
    final stock = _stockBySku();
    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (_, i) {
        final item = filtered[i];
        return _ProductRow(
          item: item,
          onHand: stock[item.sku],
          onAdd: () => _onPick(item),
        );
      },
    );
  }

  void _addFirstMatch(List<Item> items) {
    final filtered = _filter(items, _query);
    if (filtered.isNotEmpty) {
      _onPick(filtered.first);
      _searchCtrl.clear();
      setState(() => _query = '');
    }
  }

  Widget _keycap(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: DostopColors.slate200,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(text, style: DostopText.keycap),
      );

  // ---- Cart pane ----------------------------------------------------------

  Widget _cartPane(CartState cart) {
    return Container(
      decoration: const BoxDecoration(
        color: DostopColors.slate50,
        border: Border(right: BorderSide(color: DostopColors.slate200)),
      ),
      child: Column(
        children: [
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: const BoxDecoration(
              color: DostopColors.panel,
              border: Border(bottom: BorderSide(color: DostopColors.hairline)),
            ),
            child: Row(
              children: [
                const Text('Cart',
                    style: TextStyle(
                        fontFamily: DostopFonts.sans,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: DostopColors.ink)),
                const SizedBox(width: 6),
                Text('· ${cart.totalQuantity} items',
                    style: DostopText.label.copyWith(fontWeight: FontWeight.w700)),
                const Spacer(),
                _ClearButton(
                  enabled: !cart.isEmpty,
                  onClear: () =>
                      ref.read(cartControllerProvider.notifier).clear(),
                ),
              ],
            ),
          ),
          Expanded(
            child: cart.isEmpty ? _emptyCart() : _cartList(cart),
          ),
          _hintsBar(),
        ],
      ),
    );
  }

  Widget _emptyCart() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('— cart empty —',
                style: DostopText.mono.copyWith(color: DostopColors.slate500)),
            const SizedBox(height: 6),
            const Text('Scan or press F2 to start', style: DostopText.label),
          ],
        ),
      );

  Widget _cartList(CartState cart) {
    return ListView.builder(
      itemCount: cart.lines.length,
      itemBuilder: (_, i) {
        final line = cart.lines[i];
        final ctrl = ref.read(cartControllerProvider.notifier);
        return _CartRow(
          index: i + 1,
          line: line,
          onDec: () => ctrl.setQuantity(line.sku, line.quantity - 1),
          onInc: () => ctrl.setQuantity(line.sku, line.quantity + 1),
          onRemove: () => ctrl.removeLine(line.sku),
        );
      },
    );
  }

  Widget _hintsBar() => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: const BoxDecoration(
          color: DostopColors.panel,
          border: Border(top: BorderSide(color: DostopColors.hairline)),
        ),
        child: const Wrap(
          spacing: 5,
          runSpacing: 5,
          children: [
            _Hint('↑↓ Navigate'),
            _Hint('+/− Qty'),
            _Hint('Del Remove'),
            _Hint('Enter Pay'),
          ],
        ),
      );

  // ---- Right rail ---------------------------------------------------------

  Widget _rail(CartState cart) {
    final subtotal = cart.isEmpty ? '—' : formatMoney(cart.subtotalPreview);
    return Container(
      color: DostopColors.panel,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _totalRow('Items in cart',
                      '${cart.lineCount} lines · ${cart.totalQuantity} qty'),
                  const SizedBox(height: 14),
                  _totalPanel(subtotal),
                  const SizedBox(height: 14),
                  for (final m in PayMethod.values) ...[
                    _payButton(m),
                    const SizedBox(height: 7),
                  ],
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: DostopColors.hairline)),
            ),
            child: _chargeButton(cart),
          ),
        ],
      ),
    );
  }

  Widget _totalRow(String label, String value, {bool strong = false}) => Row(
        children: [
          Expanded(
            child: Text(label, overflow: TextOverflow.ellipsis, style: DostopText.label),
          ),
          const SizedBox(width: 8),
          Text(value,
              style: DostopText.money.copyWith(
                  fontWeight: strong ? FontWeight.w800 : FontWeight.w700)),
        ],
      );

  Widget _totalPanel(String subtotal) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: DostopColors.inkPanel,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Subtotal',
                    style: TextStyle(
                        fontFamily: DostopFonts.sans,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: DostopColors.slate400)),
                Flexible(
                  child: Text(
                    subtotal,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontFamily: DostopFonts.sans,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: Colors.white,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('VAT & final total confirmed at payment',
                style: DostopText.keycap.copyWith(color: DostopColors.slate400)),
          ],
        ),
      );

  Widget _payButton(PayMethod m) {
    final selected = _payMethod == m;
    return InkWell(
      borderRadius: BorderRadius.circular(DostopRadius.button),
      onTap: () => setState(() => _payMethod = m),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          color: selected ? m.bg : DostopColors.panel,
          borderRadius: BorderRadius.circular(DostopRadius.button),
          border: Border.all(
            color: selected ? m.fg : DostopColors.slate200,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(_payIcon(m), size: 18, color: selected ? m.fg : DostopColors.slate500),
            const SizedBox(width: 10),
            Text(m.label,
                style: TextStyle(
                    fontFamily: DostopFonts.sans,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: selected ? m.fg : DostopColors.slate600)),
          ],
        ),
      ),
    );
  }

  IconData _payIcon(PayMethod m) => switch (m) {
        PayMethod.cash => Icons.payments_outlined,
        PayMethod.lankaQr => Icons.qr_code_2,
        PayMethod.card => Icons.credit_card,
        PayMethod.split => Icons.call_split,
      };

  Widget _chargeButton(CartState cart) {
    final enabled = !cart.isEmpty;
    final amount = enabled ? formatMoney(cart.subtotalPreview) : '';
    return SizedBox(
      height: 52,
      child: FilledButton(
        onPressed: enabled
            ? () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const TenderScreen()),
                )
            : null,
        style: FilledButton.styleFrom(
          backgroundColor: DostopColors.brand,
          disabledBackgroundColor: DostopColors.slate200,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
        ),
        child: Text(
          enabled ? 'Charge $amount' : 'Cart is empty',
          style: const TextStyle(
              fontFamily: DostopFonts.sans, fontSize: 15, fontWeight: FontWeight.w800),
        ),
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

// ---------------------------------------------------------------------------
// Row widgets
// ---------------------------------------------------------------------------

class _ProductRow extends StatelessWidget {
  const _ProductRow({required this.item, required this.onHand, required this.onAdd});

  final Item item;
  final int? onHand;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final out = onHand != null && onHand! <= 0;
    return InkWell(
      onTap: out ? null : onAdd,
      hoverColor: DostopColors.blueWash,
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFF4F6F9))),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 104,
              child: Text(item.sku,
                  overflow: TextOverflow.ellipsis, style: DostopText.mono),
            ),
            Expanded(
              child: Text(item.name,
                  overflow: TextOverflow.ellipsis, style: DostopText.itemName),
            ),
            SizedBox(width: 70, child: Center(child: _stockBadge())),
            SizedBox(
              width: 96,
              child: Text(formatMoney(item.price),
                  textAlign: TextAlign.right, style: DostopText.money),
            ),
            SizedBox(
              width: 34,
              child: Align(
                alignment: Alignment.centerRight,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: out ? DostopColors.slate100 : DostopColors.blueWash,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Icon(Icons.add,
                      size: 15,
                      color: out ? DostopColors.slate300 : DostopColors.blue),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stockBadge() {
    if (onHand == null) {
      return Text('—', style: DostopText.mono.copyWith(color: DostopColors.slate300));
    }
    final tone = stockTone(onHand!);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: tone.bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text('$onHand',
          style: TextStyle(
            fontFamily: DostopFonts.sans,
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            color: tone.fg,
            fontFeatures: const [FontFeature.tabularFigures()],
          )),
    );
  }
}

class _CartRow extends StatelessWidget {
  const _CartRow({
    required this.index,
    required this.line,
    required this.onDec,
    required this.onInc,
    required this.onRemove,
  });

  final int index;
  final CartLine line;
  final VoidCallback onDec;
  final VoidCallback onInc;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: const BoxDecoration(
        color: DostopColors.panel,
        border: Border(bottom: BorderSide(color: DostopColors.slate100)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            child: Text('$index',
                style: DostopText.mono.copyWith(
                    color: DostopColors.slate300, fontWeight: FontWeight.w700)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line.description,
                    overflow: TextOverflow.ellipsis,
                    style: DostopText.itemName.copyWith(fontSize: 12.5)),
                Text('${formatMoney(line.unitPrice)} · ${line.sku}',
                    overflow: TextOverflow.ellipsis,
                    style: DostopText.mono.copyWith(
                        fontSize: 10.5, color: DostopColors.slate400)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _stepper(),
          const SizedBox(width: 8),
          SizedBox(
            width: 84,
            child: Text(formatMoney(line.lineTotal),
                textAlign: TextAlign.right,
                style: DostopText.money.copyWith(fontSize: 13)),
          ),
          IconButton(
            tooltip: 'Remove',
            onPressed: onRemove,
            iconSize: 15,
            visualDensity: VisualDensity.compact,
            color: DostopColors.slate300,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  Widget _stepper() => Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: DostopColors.slate100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _stepBtn(Icons.remove, onDec),
            SizedBox(
              width: 24,
              child: Text('${line.quantity}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: DostopFonts.sans,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    fontFeatures: [FontFeature.tabularFigures()],
                  )),
            ),
            _stepBtn(Icons.add, onInc),
          ],
        ),
      );

  Widget _stepBtn(IconData icon, VoidCallback onTap) => InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: DostopColors.panel,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 13, color: DostopColors.slate600),
        ),
      );
}

class _ClearButton extends StatelessWidget {
  const _ClearButton({required this.enabled, required this.onClear});
  final bool enabled;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: enabled ? onClear : null,
      style: TextButton.styleFrom(
        foregroundColor: DostopColors.slate500,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        minimumSize: Size.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        side: const BorderSide(color: DostopColors.slate200),
      ),
      child: const Text('Clear · Esc',
          style: TextStyle(
              fontFamily: DostopFonts.sans, fontSize: 11.5, fontWeight: FontWeight.w700)),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: DostopColors.slate100,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(text,
          style: DostopText.mono.copyWith(
              fontSize: 10.5, color: DostopColors.slate400)),
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
          const Icon(Icons.error_outline, size: 48, color: DostopColors.danger),
          const SizedBox(height: 12),
          const Text('Failed to load items', style: DostopText.h1),
          const SizedBox(height: 8),
          SelectableText('$error',
              style: DostopText.label, textAlign: TextAlign.center),
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
