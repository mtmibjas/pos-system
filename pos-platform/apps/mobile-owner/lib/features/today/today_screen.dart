/// Today dashboard screen.
///
/// Layout: AppBar (tenant + date), pull-to-refresh body with three
/// sections — Totals, Payment methods, footer states (empty/error).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth_controller.dart';
import '../../core/auth_state.dart';
import '../../core/money_format.dart';
import '../browse/browse_screen.dart';
import '../settings/settings_screen.dart';
import 'today_controller.dart';
import 'today_models.dart';
import 'today_repository.dart';

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(todayControllerProvider);
    // 401 from cloud-api → drop the session. The auth gate routes back
    // to LoginScreen; the user just re-enters credentials.
    ref.listen<AsyncValue<TodayDashboard>>(todayControllerProvider, (_, next) {
      next.whenOrNull(error: (e, _) {
        if (e is AuthException) {
          ref.read(authControllerProvider.notifier).signOut();
        }
      });
    });
    final auth = ref.watch(authControllerProvider);
    final tenantLabel = switch (auth) {
      SignedIn(:final tenantId) => tenantId,
      SignedOut() => '',
    };
    return Scaffold(
      appBar: AppBar(
        title: const Text('Today'),
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics_outlined),
            tooltip: 'Browse periods',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BrowseScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(
              child: Text(
                tenantLabel,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(todayControllerProvider),
        child: async.when(
          data: (d) => _Body(dashboard: d),
          error: (e, _) => _ErrorBody(error: e),
          loading: () => const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.dashboard});
  final TodayDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    if (dashboard.isEmpty) {
      // Wrap in a ListView so RefreshIndicator still works on an empty
      // state (it needs a scrollable child to anchor the gesture).
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 96),
          Center(
            child: Text(
              'No sales yet today',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              dashboard.date,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      );
    }
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        _TotalsCard(d: dashboard),
        const SizedBox(height: 16),
        _MethodsCard(methods: dashboard.methods),
      ],
    );
  }
}

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({required this.d});
  final TodayDashboard d;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(d.date, style: t.bodySmall),
            const SizedBox(height: 8),
            Text(
              formatMoney(d.grandTotal),
              style: t.displaySmall,
            ),
            const SizedBox(height: 4),
            Text('Grand total', style: t.bodySmall),
            const Divider(height: 24),
            _row(context, 'Revenue', d.revenue),
            const SizedBox(height: 4),
            _row(context, 'Tax', d.tax),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, MoneyAmount m) {
    final t = Theme.of(context).textTheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: t.bodyMedium),
        Text(formatMoney(m), style: t.bodyMedium),
      ],
    );
  }
}

class _MethodsCard extends StatelessWidget {
  const _MethodsCard({required this.methods});
  final List<SalesByMethodBucket> methods;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    if (methods.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('No payments today', style: t.bodyMedium),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Payments', style: t.titleMedium),
            const SizedBox(height: 12),
            for (final m in methods) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_methodLabel(m.method), style: t.bodyMedium),
                  Text(formatMoney(m.amount), style: t.bodyMedium),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }

  String _methodLabel(String wire) {
    switch (wire) {
      case 'cash':
        return 'Cash';
      case 'card':
        return 'Card';
      case 'upi':
        return 'UPI';
      default:
        return 'Other';
    }
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.error});
  final Object error;

  @override
  Widget build(BuildContext context) {
    final isAuth = error is AuthException;
    final t = Theme.of(context).textTheme;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 64),
        Icon(
          isAuth ? Icons.lock_outline : Icons.cloud_off,
          size: 64,
          color: Theme.of(context).colorScheme.error,
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            isAuth ? 'Owner login required' : 'Could not load today',
            style: t.titleMedium,
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            error.toString(),
            style: t.bodySmall,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
