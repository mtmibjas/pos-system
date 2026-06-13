/// Money rendering helper. Lifted out of item_picker_screen because
/// cart / tender / receipt screens all need it.
///
/// Renders as "INR 45.00", 2 decimals, ISO code prefix. Real locale-
/// aware currency formatting (₹, $, ¥) is a Phase 3 concern.
library;

import 'package:pos_sdk/gen/pos/v1/common.pb.dart';

String formatMoney(Money m) {
  // Empty / zero-currency money (from an empty cart) renders as a dash
  // so we don't show a confusing "0.00" with no unit.
  if (m.currencyCode.isEmpty) return '—';
  final units = m.units.toInt();
  final fractional = (m.nanos / 10000000).round().abs(); // 0..99
  final sign = (units < 0 || m.nanos < 0) ? '-' : '';
  final whole = units.abs();
  final frac = fractional.toString().padLeft(2, '0');
  return '${m.currencyCode} $sign$whole.$frac';
}
