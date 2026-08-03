/// Role-aware navigation shell (docs/desktop-architecture.md §4.3, D4),
/// restyled to the Dostop design (docs/desktop-pos-ui-design.md §3).
///
/// A left sidebar lists the [FeatureModule]s visible to the current role,
/// grouped by `module.group`, with the selected module's screen filling the
/// rest. Header carries the brand + counter id + a live store-server health
/// chip; the footer shows the signed-in cashier and sign-out. The role-gating,
/// the single-module fallback, and the pending-finalize banner are unchanged
/// from the NavigationRail version — only the chrome is new.
///
/// [modules] defaults to the registry but is injectable so tests can pass
/// lightweight modules instead of the network-backed real screens.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/connection_health_provider.dart';
import '../../domain/connection_health.dart';
import '../../ui/tokens.dart';
import '../auth/session_controller.dart';
import '../cart/pending_finalize_controller.dart';
import 'feature_module.dart';
import 'modules.dart';

class NavShell extends ConsumerStatefulWidget {
  NavShell({super.key, List<FeatureModule>? modules})
      : modules = modules ?? kModules;

  final List<FeatureModule> modules;

  @override
  ConsumerState<NavShell> createState() => _NavShellState();
}

class _NavShellState extends ConsumerState<NavShell> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final policy = ref.watch(rolePolicyProvider);
    final mods = visibleModules(widget.modules, policy);
    final session = ref.watch(sessionControllerProvider).valueOrNull;

    if (mods.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('No modules available for this role.')),
      );
    }
    final index = _selected.clamp(0, mods.length - 1);

    // A single visible module needs no sidebar — render it directly.
    if (mods.length < 2) {
      return mods.first.builder(context);
    }

    return Scaffold(
      backgroundColor: DostopColors.canvas,
      body: Row(
        children: [
          _Sidebar(
            modules: mods,
            selectedIndex: index,
            onSelect: (i) => setState(() => _selected = i),
            counterId: session?.counterId,
            displayName: session?.displayName ?? '',
            onLogout: () =>
                ref.read(sessionControllerProvider.notifier).logout(),
          ),
          Expanded(
            child: Column(
              children: [
                const _PendingSaleBanner(),
                Expanded(child: mods[index].builder(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The dark Dostop sidebar: brand header, grouped nav, cashier footer.
class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.modules,
    required this.selectedIndex,
    required this.onSelect,
    required this.counterId,
    required this.displayName,
    required this.onLogout,
  });

  final List<FeatureModule> modules;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final String? counterId;
  final String displayName;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 248,
      decoration: const BoxDecoration(
        color: DostopColors.sidebarBg,
        border: Border(
          right: BorderSide(color: DostopColors.sidebarBorder),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _brandHeader(),
          Expanded(child: _nav()),
          _footer(),
        ],
      ),
    );
  }

  Widget _brandHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: DostopColors.sidebarBorder)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: DostopColors.brand,
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(Icons.eco, size: 19, color: Colors.white),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Dostop POS',
                  style: TextStyle(
                    fontFamily: DostopFonts.sans,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: DostopColors.sidebarBrand,
                  ),
                ),
                Text(
                  (counterId?.isNotEmpty ?? false)
                      ? 'Counter · $counterId'
                      : 'Counter',
                  style: const TextStyle(
                    fontFamily: DostopFonts.mono,
                    fontSize: 11,
                    color: DostopColors.sidebarGroup,
                  ),
                ),
              ],
            ),
          ),
          const _HealthDot(),
        ],
      ),
    );
  }

  Widget _nav() {
    // Build a flat list of group headings interleaved with items, in
    // registry order, emitting each group's heading once.
    final children = <Widget>[const SizedBox(height: 8)];
    String? lastGroup;
    for (var i = 0; i < modules.length; i++) {
      final m = modules[i];
      if (m.group != lastGroup && m.group.isNotEmpty) {
        children.add(_groupLabel(m.group));
        lastGroup = m.group;
      } else if (m.group.isEmpty && lastGroup != null) {
        children.add(const SizedBox(height: 8));
        lastGroup = null;
      }
      children.add(_navItem(m, i == selectedIndex));
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }

  Widget _groupLabel(String label) => Padding(
        padding: const EdgeInsets.fromLTRB(10, 12, 10, 6),
        child: Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontFamily: DostopFonts.sans,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
            color: DostopColors.sidebarGroup,
          ),
        ),
      );

  Widget _navItem(FeatureModule m, bool active) {
    final int idx = modules.indexOf(m);
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Material(
        color: active ? DostopColors.brandWash : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          hoverColor: DostopColors.sidebarBorder,
          onTap: () => onSelect(idx),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
            child: Row(
              children: [
                Icon(
                  m.icon,
                  size: 19,
                  color: active ? DostopColors.brand : DostopColors.sidebarText,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    m.label,
                    style: TextStyle(
                      fontFamily: DostopFonts.sans,
                      fontSize: 13,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      color:
                          active ? DostopColors.brand : DostopColors.sidebarText,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _footer() {
    final initials = _initials(displayName);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: DostopColors.sidebarBorder)),
      ),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: DostopColors.sidebarBorder,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFF064E3B),
              child: Text(
                initials,
                style: const TextStyle(
                  fontFamily: DostopFonts.sans,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF6EE7B7),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName.isEmpty ? 'Cashier' : displayName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: DostopFonts.sans,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFF3F4F6),
                    ),
                  ),
                  const _HealthLabel(),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Sign out',
              onPressed: onLogout,
              iconSize: 18,
              color: DostopColors.sidebarText,
              icon: const Icon(Icons.logout),
            ),
          ],
        ),
      ),
    );
  }

  static String _initials(String name) {
    final parts =
        name.replaceAll(RegExp(r'[^A-Za-z ]'), '').trim().split(RegExp(r'\s+'));
    final letters = parts.where((p) => p.isNotEmpty).take(2).map((p) => p[0]);
    final s = letters.join().toUpperCase();
    return s.isEmpty ? 'C' : s;
  }
}

/// Small coloured dot in the header reflecting store-server reachability.
class _HealthDot extends ConsumerWidget {
  const _HealthDot();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(connectionHealthControllerProvider);
    final color = switch (health.state) {
      ServerReachability.reachable => DostopColors.brand,
      ServerReachability.degraded => DostopColors.stockLowFg,
      ServerReachability.unreachable => DostopColors.danger,
    };
    return Tooltip(
      message: _healthLabel(health.state),
      child: Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

/// Text form of the health state, shown under the cashier name.
class _HealthLabel extends ConsumerWidget {
  const _HealthLabel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(connectionHealthControllerProvider);
    return Text(
      _healthLabel(health.state),
      style: const TextStyle(
        fontFamily: DostopFonts.sans,
        fontSize: 11,
        color: DostopColors.sidebarGroup,
      ),
    );
  }
}

String _healthLabel(ServerReachability state) => switch (state) {
      ServerReachability.reachable => 'Connected',
      ServerReachability.degraded => 'Reconnecting…',
      ServerReachability.unreachable => 'Server offline',
    };

/// Ambient banner for a pending (lost-reply) Finalize awaiting replay
/// (docs/desktop-local-persistence.md §5.3). Auto-replays on reconnect;
/// the button lets the operator force a retry. Watching this keeps the
/// reconciler alive so auto-replay runs while signed in.
class _PendingSaleBanner extends ConsumerWidget {
  const _PendingSaleBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingFinalizeControllerProvider);
    if (!pending.hasPending) return const SizedBox.shrink();
    return MaterialBanner(
      backgroundColor: DostopColors.stockLowBg,
      leading: const Icon(Icons.sync_problem, color: DostopColors.stockLowFg),
      content: Text(pending.retrying
          ? 'Completing your last sale…'
          : 'A sale is waiting for the store server. It will finish '
              'automatically when the connection returns.'),
      actions: [
        TextButton(
          onPressed: pending.retrying
              ? null
              : () => ref
                  .read(pendingFinalizeControllerProvider.notifier)
                  .retryNow(),
          child: const Text('Retry now'),
        ),
      ],
    );
  }
}
