/// Role-aware navigation shell (docs/desktop-architecture.md §4.3, D4).
///
/// Replaces the old boot-into-ItemPickerScreen: a left NavigationRail lists
/// the [FeatureModule]s visible to the current role, and the selected
/// module's screen fills the rest. The footer shows the signed-in cashier +
/// a logout that returns to the AuthGate's login screen.
///
/// [modules] defaults to the registry but is injectable so tests can pass
/// lightweight modules instead of the network-backed real screens.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/connection_health_provider.dart';
import '../../domain/connection_health.dart';
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

    // NavigationRail needs ≥2 destinations; with a single visible module just
    // render it (no rail to show).
    if (mods.length < 2) {
      return mods.first.builder(context);
    }

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: true,
            minExtendedWidth: 184,
            selectedIndex: index,
            onDestinationSelected: (i) => setState(() => _selected = i),
            leading: _RailHeader(counterId: session?.counterId),
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: _RailFooter(
                  displayName: session?.displayName ?? '',
                  onLogout: () =>
                      ref.read(sessionControllerProvider.notifier).logout(),
                ),
              ),
            ),
            destinations: [
              for (final m in mods)
                NavigationRailDestination(
                  icon: Icon(m.icon),
                  label: Text(m.label),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
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
      backgroundColor: Colors.amber.shade100,
      leading: const Icon(Icons.sync_problem),
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

class _RailHeader extends StatelessWidget {
  const _RailHeader({this.counterId});
  final String? counterId;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          const Icon(Icons.storefront),
          if (counterId != null && counterId!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(counterId!, style: Theme.of(context).textTheme.labelMedium),
          ],
          const SizedBox(height: 8),
          const _HealthChip(),
        ],
      ),
    );
  }
}

/// Always-visible store-server reachability chip (§6 Q6.1: show green when
/// healthy). Ambient — never a blocking dialog. Finalize-disabling UX arrives
/// with step 6.
class _HealthChip extends ConsumerWidget {
  const _HealthChip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(connectionHealthControllerProvider);
    final (Color color, IconData icon, String label) = switch (health.state) {
      ServerReachability.reachable => (Colors.green, Icons.cloud_done, 'Connected'),
      ServerReachability.degraded => (Colors.amber, Icons.cloud_sync, 'Reconnecting…'),
      ServerReachability.unreachable => (Colors.red, Icons.cloud_off, 'Server offline'),
    };
    return Tooltip(
      message: health.state == ServerReachability.unreachable &&
              health.lastOkAt != null
          ? 'Store server unreachable — last OK ${health.lastOkAt}'
          : label,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _RailFooter extends StatelessWidget {
  const _RailFooter({required this.displayName, required this.onLogout});
  final String displayName;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, left: 8, right: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (displayName.isNotEmpty)
            Text(displayName,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: onLogout,
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}
