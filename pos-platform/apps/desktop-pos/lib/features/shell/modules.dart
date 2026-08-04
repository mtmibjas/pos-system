/// The desktop module registry (docs/desktop-architecture.md §4.3 table),
/// ordered + grouped to match the Dostop design's sidebar NAV
/// (docs/desktop-pos-ui-design.md §3).
///
/// Offline-boundary note: some screens here (Dashboard, Day book, Chart of
/// accounts, Reports) are cloud/back-office in the design and currently render
/// the prototype's static data on the desktop for visual completeness. Whether
/// they stay on the till or move to the web admin is a product decision — see
/// docs/desktop-pos-backend-tasks.md.
library;

import 'package:flutter/material.dart';

import '../accounts/chart_of_accounts_screen.dart';
import '../accounts/daybook_screen.dart';
import '../cashiers/cashiers_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../expenses/expenses_screen.dart';
import '../inventory/inventory_screen.dart';
import '../invoice/invoice_screen.dart';
import '../items/item_picker_screen.dart';
import '../items/items_management_screen.dart';
import '../lookup/sale_lookup_screen.dart';
import '../parties/parties_screen.dart';
import '../purchases/purchases_screen.dart';
import '../reports/reports_screen.dart';
import '../settings/settings_screen.dart';
import 'feature_module.dart';

/// Registry. Order = nav order; `group` = sidebar section (design NAV).
/// `visible` predicates gate by role (RolePolicy); the shell enforces them.
final List<FeatureModule> kModules = [
  // Home
  FeatureModule(
    id: 'dashboard',
    label: 'Dashboard',
    group: 'Home',
    icon: Icons.space_dashboard_outlined,
    visible: (p) => p.canViewReports,
    builder: (_) => const DashboardScreen(),
  ),

  // Sell
  FeatureModule(
    id: 'sell',
    label: 'Counter (POS)',
    group: 'Sell',
    icon: Icons.point_of_sale,
    visible: (p) => p.canSell,
    builder: (_) => const ItemPickerScreen(),
  ),
  FeatureModule(
    id: 'invoice',
    label: 'New invoice',
    group: 'Sell',
    icon: Icons.description_outlined,
    visible: (p) => p.canSell,
    builder: (_) => const InvoiceScreen(),
  ),
  FeatureModule(
    id: 'sales',
    label: 'Sales register',
    group: 'Sell',
    icon: Icons.receipt_long,
    visible: (p) => p.canSell, // lookup → refund/void
    builder: (_) => const SaleLookupScreen(),
  ),

  // Masters
  FeatureModule(
    id: 'items',
    label: 'Items',
    group: 'Masters',
    icon: Icons.category_outlined,
    visible: (p) => p.canManageItems,
    builder: (_) => const ItemsManagementScreen(),
  ),
  FeatureModule(
    id: 'parties',
    label: 'Parties',
    group: 'Masters',
    icon: Icons.people_alt,
    visible: (p) => p.canSell, // udhaar/collections — cashier-facing too
    builder: (_) => const PartiesScreen(),
  ),

  // Operations
  FeatureModule(
    id: 'purchases',
    label: 'Purchases',
    group: 'Operations',
    icon: Icons.local_shipping,
    visible: (p) => p.isOwner,
    builder: (_) => const PurchasesScreen(),
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
    id: 'expenses',
    label: 'Expenses',
    group: 'Operations',
    icon: Icons.account_balance_wallet_outlined,
    visible: (p) => p.isOwner,
    builder: (_) => const ExpensesScreen(),
  ),
  FeatureModule(
    id: 'cashiers',
    label: 'Cashiers',
    group: 'Operations',
    icon: Icons.badge,
    visible: (p) => p.canManageCashiers,
    builder: (_) => const CashiersScreen(),
  ),

  // Accounts
  FeatureModule(
    id: 'daybook',
    label: 'Day book',
    group: 'Accounts',
    icon: Icons.menu_book_outlined,
    visible: (p) => p.canViewReports,
    builder: (_) => const DaybookScreen(),
  ),
  FeatureModule(
    id: 'accounts',
    label: 'Chart of accounts',
    group: 'Accounts',
    icon: Icons.account_tree_outlined,
    visible: (p) => p.canViewReports,
    builder: (_) => const ChartOfAccountsScreen(),
  ),

  // Insights
  FeatureModule(
    id: 'reports',
    label: 'Reports',
    group: 'Insights',
    icon: Icons.bar_chart,
    visible: (p) => p.canViewReports,
    builder: (_) => const ReportsScreen(),
  ),

  // Settings (ungrouped, bottom)
  FeatureModule(
    id: 'settings',
    label: 'Settings',
    group: '',
    icon: Icons.settings,
    visible: (p) => true, // terminal/provisioning/printer/about
    builder: (_) => const SettingsScreen(),
  ),
];
