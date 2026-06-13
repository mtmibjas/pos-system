/// Money rendering for the dashboard.
///
/// Mobile-owner does NOT depend on pos_sdk (it talks REST/JSON to
/// cloud-api, not Connect-RPC to local-store-server), so this works on
/// the in-app [MoneyAmount] DTO from features/today/today_models.dart
/// rather than the protobuf Money. Same 2-decimal-place convention as
/// desktop-pos's formatMoney for visual parity.
library;

import '../features/today/today_models.dart';

String formatMoney(MoneyAmount m) {
  if (m.currencyCode.isEmpty) return '—';
  final negative = m.units < 0 || m.nanos < 0;
  // Sub-unit magnitude. Money.nanos is the sub-unit remainder; both
  // fields share a sign (server emits both with the same sign), so
  // taking abs separately is safe.
  final whole = m.units.abs();
  final fractional = (m.nanos.abs() / 10000000).round(); // 0..99
  final frac = fractional.toString().padLeft(2, '0');
  final sign = negative ? '-' : '';
  return '${m.currencyCode} $sign$whole.$frac';
}
