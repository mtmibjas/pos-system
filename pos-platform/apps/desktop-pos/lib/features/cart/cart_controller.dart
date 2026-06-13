/// Cart state machine — synchronous, in-memory, top-level (keepAlive).
///
/// The cart is the in-progress sale: a list of (SKU, qty, unit_price,
/// tax_category_id, description) tuples accumulated from the item
/// picker. It survives navigation (picker ↔ cart ↔ tender ↔ receipt)
/// because the provider is keepAlive — operators expect their cart not
/// to evaporate if they hit Back to grab another item.
///
/// Subtotal is a client-side preview only (sum of line totals, NO tax).
/// The authoritative subtotal/tax/grand comes back inside FinalizeResponse
/// once the engine has run on the server. We do NOT pre-compute tax
/// locally — that's the server's job per the Development Guide.
///
/// All Money math here is integer-only via payments.Money's Add / Mul
/// equivalents... but the Dart side doesn't have those helpers. We use
/// the same units+nanos representation as the proto and do the carry
/// arithmetic inline. Quantities are bounded to int64 by the server;
/// the client clamps to 1..999 per line as a UX guard.
library;

import 'package:fixnum/fixnum.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:pos_sdk/gen/pos/v1/common.pb.dart';
import 'package:pos_sdk/gen/pos/v1/item_service.pb.dart' as itempb;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'cart_controller.g.dart';

/// One row in the cart, keyed by SKU.
@immutable
class CartLine {
  const CartLine({
    required this.sku,
    required this.description,
    required this.unitPrice,
    required this.taxCategoryId,
    required this.quantity,
  });

  final String sku;
  final String description;
  final Money unitPrice;
  final String taxCategoryId;
  final int quantity;

  CartLine copyWith({int? quantity}) => CartLine(
        sku: sku,
        description: description,
        unitPrice: unitPrice,
        taxCategoryId: taxCategoryId,
        quantity: quantity ?? this.quantity,
      );

  /// unit_price × quantity, computed in units+nanos.
  Money get lineTotal => _mulMoney(unitPrice, quantity);
}

/// Cart aggregate. Immutable; replaced wholesale on every mutation
/// (Riverpod relies on referential change to fire rebuilds).
@immutable
class CartState {
  const CartState({this.lines = const []});

  final List<CartLine> lines;

  bool get isEmpty => lines.isEmpty;
  int get lineCount => lines.length;
  int get totalQuantity =>
      lines.fold(0, (sum, l) => sum + l.quantity);

  /// Subtotal preview. Empty cart returns a zero-Money with no currency
  /// — callers should special-case `isEmpty`. We assume all lines share
  /// one currency (true for the seeded INR catalog); cross-currency carts
  /// would fail server-side anyway.
  Money get subtotalPreview {
    if (lines.isEmpty) return Money();
    final currency = lines.first.unitPrice.currencyCode;
    Money acc = Money(currencyCode: currency, units: Int64(0), nanos: 0);
    for (final l in lines) {
      acc = _addMoney(acc, l.lineTotal);
    }
    return acc;
  }
}

/// Quantity clamp — same value used by the stepper UI.
const int kMaxQtyPerLine = 999;

@Riverpod(keepAlive: true)
class CartController extends _$CartController {
  @override
  CartState build() => const CartState();

  /// Adds a picker tap. If the SKU is already in the cart, bumps qty
  /// by 1 (capped); otherwise inserts a new line at the end.
  void addLine(itempb.Item item) {
    final idx = state.lines.indexWhere((l) => l.sku == item.sku);
    if (idx >= 0) {
      final cur = state.lines[idx];
      final nextQty = (cur.quantity + 1).clamp(1, kMaxQtyPerLine);
      _replaceAt(idx, cur.copyWith(quantity: nextQty));
      return;
    }
    state = CartState(lines: [
      ...state.lines,
      CartLine(
        sku: item.sku,
        description: item.name,
        unitPrice: item.price,
        taxCategoryId: item.taxCategoryId,
        quantity: 1,
      ),
    ]);
  }

  /// Sets an absolute quantity. qty <= 0 removes the line. Clamps to
  /// [1, kMaxQtyPerLine] otherwise.
  void setQuantity(String sku, int qty) {
    final idx = state.lines.indexWhere((l) => l.sku == sku);
    if (idx < 0) return;
    if (qty <= 0) {
      removeLine(sku);
      return;
    }
    final clamped = qty.clamp(1, kMaxQtyPerLine);
    _replaceAt(idx, state.lines[idx].copyWith(quantity: clamped));
  }

  void removeLine(String sku) {
    state = CartState(
      lines: state.lines.where((l) => l.sku != sku).toList(growable: false),
    );
  }

  void clear() {
    state = const CartState();
  }

  /// Replaces the cart wholesale with `lines`. Used by the sale-lookup
  /// flow (slice 2.11) to seed the cart from a previously finalized
  /// sale so the receipt screen can render it for void/refund.
  void replaceLines(List<CartLine> lines) {
    state = CartState(lines: List<CartLine>.unmodifiable(lines));
  }

  void _replaceAt(int idx, CartLine line) {
    final next = [...state.lines];
    next[idx] = line;
    state = CartState(lines: next);
  }
}

// --- Money helpers --------------------------------------------------------
//
// proto Money is (currency_code, units int64, nanos int32). All math
// here mirrors the Go-side payments.Money helpers (Add / Mul) — same
// carry rules. We don't expose these publicly; cart-only use.

const int _nanosPerUnit = 1000000000;

Money _addMoney(Money a, Money b) {
  // Assume same currency; the cart enforces it on add (single-currency
  // catalog for now). Cross-currency arithmetic would be a bug.
  var units = a.units + b.units;
  var nanos = a.nanos + b.nanos;
  if (nanos >= _nanosPerUnit) {
    units += Int64(1);
    nanos -= _nanosPerUnit;
  } else if (nanos <= -_nanosPerUnit) {
    units -= Int64(1);
    nanos += _nanosPerUnit;
  }
  return Money(
    currencyCode: a.currencyCode,
    units: units,
    nanos: nanos,
  );
}

Money _mulMoney(Money m, int n) {
  if (n == 0) {
    return Money(currencyCode: m.currencyCode, units: Int64(0), nanos: 0);
  }
  final unitsWide = m.units * Int64(n);
  final nanosWide = Int64(m.nanos) * Int64(n);
  final carry = (nanosWide ~/ Int64(_nanosPerUnit));
  final nanosRem = (nanosWide - carry * Int64(_nanosPerUnit)).toInt();
  return Money(
    currencyCode: m.currencyCode,
    units: unitsWide + carry,
    nanos: nanosRem,
  );
}
