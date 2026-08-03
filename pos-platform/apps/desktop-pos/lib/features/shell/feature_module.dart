/// A navigable feature in the desktop shell (docs/desktop-architecture.md
/// §4.3, D4). The shell renders whatever modules are registered and visible
/// for the current role — so adding Parties (P8) / Purchases (P9) later is a
/// registry entry, not a shell rewrite.
library;

import 'package:flutter/widgets.dart';

import '../auth/session_controller.dart';

/// Whether a module is visible to a given role policy.
typedef ModuleVisible = bool Function(RolePolicy policy);

@immutable
class FeatureModule {
  const FeatureModule({
    required this.id,
    required this.label,
    required this.icon,
    required this.visible,
    required this.builder,
    this.group = '',
  });

  final String id;
  final String label;
  final IconData icon;
  final ModuleVisible visible;
  final WidgetBuilder builder;

  /// Sidebar section heading this module sits under (e.g. 'Sell', 'Masters').
  /// Empty = ungrouped. Matches the Dostop design nav groups
  /// (docs/desktop-pos-ui-design.md §3).
  final String group;
}

/// The modules a role policy may see, in registry order. Pure — unit-tested
/// without rendering the (network-backed) screens.
List<FeatureModule> visibleModules(List<FeatureModule> all, RolePolicy policy) =>
    all.where((m) => m.visible(policy)).toList(growable: false);
