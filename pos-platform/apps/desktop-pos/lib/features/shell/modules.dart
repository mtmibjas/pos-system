/// The desktop module registry (docs/desktop-architecture.md §4.3 table).
///
/// Offline-boundary-scoped: everything here must work against the local
/// store server without internet. Cloud/cross-store concerns stay in the
/// web admin dashboard. Billing/Inventory/Sales exist today; the rest are
/// slots the shell anticipates (built in their phase).
library;

import 'package:flutter/material.dart';

import '../inventory/inventory_screen.dart';
import '../items/item_picker_screen.dart';
import '../lookup/sale_lookup_screen.dart';
import 'feature_module.dart';
import 'placeholder_screen.dart';

/// Registry. Order = nav order. `visible` predicates gate by role
/// (RolePolicy); the shell enforces them (not UI-only).
final List<FeatureModule> kModules = [
  FeatureModule(
    id: 'sell',
    label: 'Counter (POS)',
    group: 'Sell',
    icon: Icons.point_of_sale,
    visible: (p) => p.canSell,
    builder: (_) => const ItemPickerScreen(),
  ),
  FeatureModule(
    id: 'sales',
    label: 'Sales register',
    group: 'Sell',
    icon: Icons.receipt_long,
    visible: (p) => p.canSell, // lookup → refund/void
    builder: (_) => const SaleLookupScreen(),
  ),
  FeatureModule(
    id: 'inventory',
    label: 'Stock',
    group: 'Operations',
    icon: Icons.inventory_2,
    visible: (p) => p.canManageItems,
    builder: (_) => const InventoryScreen(),
  ),
  FeatureModule(
    id: 'parties',
    label: 'Parties',
    group: 'Masters',
    icon: Icons.people_alt,
    visible: (p) => p.canSell, // udhaar/collections — cashier-facing too
    builder: (_) => const PlaceholderScreen(title: 'Parties', phase: 'P8'),
  ),
  FeatureModule(
    id: 'purchases',
    label: 'Purchases',
    group: 'Operations',
    icon: Icons.local_shipping,
    visible: (p) => p.isOwner,
    builder: (_) => const PlaceholderScreen(title: 'Purchases', phase: 'P9'),
  ),
  FeatureModule(
    id: 'reports',
    label: 'Reports',
    group: 'Insights',
    icon: Icons.bar_chart,
    visible: (p) => p.canViewReports,
    builder: (_) => const PlaceholderScreen(title: 'Reports', phase: 'a later phase'),
  ),
  FeatureModule(
    id: 'cashiers',
    label: 'Cashiers',
    group: 'Operations',
    icon: Icons.badge,
    visible: (p) => p.canManageCashiers,
    builder: (_) =>
        const PlaceholderScreen(title: 'Cashier management', phase: 'a later phase'),
  ),
  FeatureModule(
    id: 'settings',
    label: 'Settings',
    group: '',
    icon: Icons.settings,
    visible: (p) => true, // terminal/provisioning/printer/about
    builder: (_) => const PlaceholderScreen(title: 'Settings', phase: 'a later phase'),
  ),
];
