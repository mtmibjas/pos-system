/// CartController tests — pure state-machine coverage.
///
/// No transport, no widgets. Exercises add/dedupe/qty/remove/clear and
/// the subtotal preview Money math (carry across nanos boundaries).
library;

import 'package:desktop_pos/features/cart/cart_controller.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_sdk/gen/pos/v1/common.pb.dart';
import 'package:pos_sdk/gen/pos/v1/item_service.pb.dart' as itempb;

itempb.Item _item(String sku, {int units = 0, int nanos = 0, String tax = ''}) {
  return itempb.Item(
    sku: sku,
    name: 'name-$sku',
    price: Money(currencyCode: 'INR', units: Int64(units), nanos: nanos),
    taxCategoryId: tax,
  );
}

void main() {
  ProviderContainer fresh() {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    return c;
  }

  test('starts empty', () {
    final c = fresh();
    final s = c.read(cartControllerProvider);
    expect(s.isEmpty, isTrue);
    expect(s.lineCount, 0);
    expect(s.totalQuantity, 0);
    expect(s.subtotalPreview.currencyCode, isEmpty);
  });

  test('addLine inserts new SKUs in order', () {
    final c = fresh();
    final n = c.read(cartControllerProvider.notifier);
    n.addLine(_item('A', units: 10));
    n.addLine(_item('B', units: 20));
    final s = c.read(cartControllerProvider);
    expect(s.lines.map((l) => l.sku), ['A', 'B']);
    expect(s.lines.every((l) => l.quantity == 1), isTrue);
  });

  test('addLine on existing SKU bumps quantity (does not duplicate)', () {
    final c = fresh();
    final n = c.read(cartControllerProvider.notifier);
    n.addLine(_item('A', units: 10));
    n.addLine(_item('A', units: 10));
    n.addLine(_item('A', units: 10));
    final s = c.read(cartControllerProvider);
    expect(s.lineCount, 1);
    expect(s.lines.single.quantity, 3);
    expect(s.totalQuantity, 3);
  });

  test('setQuantity replaces, clamps to [1, max], removes on <=0', () {
    final c = fresh();
    final n = c.read(cartControllerProvider.notifier);
    n.addLine(_item('A', units: 10));
    n.setQuantity('A', 5);
    expect(c.read(cartControllerProvider).lines.single.quantity, 5);

    // Clamp upper bound.
    n.setQuantity('A', 10000);
    expect(c.read(cartControllerProvider).lines.single.quantity,
        kMaxQtyPerLine);

    // <= 0 removes.
    n.setQuantity('A', 0);
    expect(c.read(cartControllerProvider).isEmpty, isTrue);
  });

  test('removeLine drops the matching SKU only', () {
    final c = fresh();
    final n = c.read(cartControllerProvider.notifier);
    n.addLine(_item('A'));
    n.addLine(_item('B'));
    n.removeLine('A');
    expect(c.read(cartControllerProvider).lines.map((l) => l.sku), ['B']);
  });

  test('clear resets to empty', () {
    final c = fresh();
    final n = c.read(cartControllerProvider.notifier);
    n.addLine(_item('A'));
    n.addLine(_item('B'));
    n.clear();
    expect(c.read(cartControllerProvider).isEmpty, isTrue);
  });

  test('subtotalPreview sums units across lines', () {
    final c = fresh();
    final n = c.read(cartControllerProvider.notifier);
    n.addLine(_item('A', units: 45)); // 45.00
    n.addLine(_item('B', units: 62)); // 62.00
    n.setQuantity('A', 2); // 90.00 + 62.00 = 152.00
    final sub = c.read(cartControllerProvider).subtotalPreview;
    expect(sub.currencyCode, 'INR');
    expect(sub.units.toInt(), 152);
    expect(sub.nanos, 0);
  });

  test('subtotalPreview carries nanos into units', () {
    final c = fresh();
    final n = c.read(cartControllerProvider.notifier);
    // 575.50 × 2 = 1151.00 — exercises both unit-mul and nanos carry.
    n.addLine(_item('RICE', units: 575, nanos: 500000000));
    n.setQuantity('RICE', 2);
    final sub = c.read(cartControllerProvider).subtotalPreview;
    expect(sub.units.toInt(), 1151);
    expect(sub.nanos, 0);
  });

  test('addLine after removal restarts qty at 1', () {
    final c = fresh();
    final n = c.read(cartControllerProvider.notifier);
    n.addLine(_item('A'));
    n.addLine(_item('A'));
    n.removeLine('A');
    n.addLine(_item('A'));
    expect(c.read(cartControllerProvider).lines.single.quantity, 1);
  });
}
