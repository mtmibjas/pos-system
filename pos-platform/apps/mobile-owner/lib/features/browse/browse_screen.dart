/// Browse screen: period chips + date stepper + store dropdown driving
/// a multi-bucket sales-summary list. Slice 5.5 drill-down for the
/// mobile-owner dashboard.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money_format.dart';
import '../../core/reports_errors.dart';
import '../stores/stores_controller.dart';
import '../today/today_models.dart';
import 'browse_controller.dart';
import 'browse_scope.dart';

class BrowseScreen extends ConsumerWidget {
  const BrowseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = ref.watch(browseScopeProvider);
    final async = ref.watch(browseControllerProvider);
    final stores = ref.watch(storesControllerProvider);
    final notifier = ref.read(browseScopeProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Browse')),
      body: Column(
        children: [
          _Controls(
            scope: scope,
            notifier: notifier,
            storesAsync: stores,
          ),
          const Divider(height: 1),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async =>
                  ref.invalidate(browseControllerProvider),
              child: async.when(
                data: (buckets) => _Buckets(buckets: buckets),
                error: (e, _) => _ErrorBody(error: e),
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.scope,
    required this.notifier,
    required this.storesAsync,
  });

  final BrowseScope scope;
  final BrowseScopeNotifier notifier;
  final AsyncValue<dynamic> storesAsync;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<BrowsePeriod>(
            segments: const [
              ButtonSegment(value: BrowsePeriod.day, label: Text('Day')),
              ButtonSegment(value: BrowsePeriod.week, label: Text('Week')),
              ButtonSegment(value: BrowsePeriod.month, label: Text('Month')),
            ],
            selected: {scope.period},
            onSelectionChanged: (s) => notifier.setPeriod(s.first),
          ),
          const SizedBox(height: 12),
          _DateStepper(scope: scope, notifier: notifier),
          const SizedBox(height: 8),
          _StorePicker(scope: scope, notifier: notifier, async: storesAsync),
        ],
      ),
    );
  }
}

class _DateStepper extends StatelessWidget {
  const _DateStepper({required this.scope, required this.notifier});
  final BrowseScope scope;
  final BrowseScopeNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final w = scope.window;
    final label = switch (scope.period) {
      BrowsePeriod.day => _fmtDate(w.from),
      BrowsePeriod.week =>
        '${_fmtDate(w.from)} – ${_fmtDate(w.to.subtract(const Duration(days: 1)))}',
      BrowsePeriod.month => _fmtMonth(w.from),
    };
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: notifier.previous,
          tooltip: 'Previous',
        ),
        Expanded(
          child: Center(
            child: Text(label,
                style: Theme.of(context).textTheme.titleMedium),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: notifier.canStepForward ? notifier.next : null,
          tooltip: 'Next',
        ),
      ],
    );
  }
}

class _StorePicker extends ConsumerWidget {
  const _StorePicker({
    required this.scope,
    required this.notifier,
    required this.async,
  });
  final BrowseScope scope;
  final BrowseScopeNotifier notifier;
  final AsyncValue<dynamic> async;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return async.when(
      data: (data) {
        final stores = data as List;
        if (stores.length <= 1) {
          // Single-store tenant: no picker needed; keep "all" semantics.
          return const SizedBox.shrink();
        }
        final items = <DropdownMenuItem<String>>[
          const DropdownMenuItem(value: '', child: Text('All stores')),
          for (final s in stores)
            DropdownMenuItem<String>(
              value: s.storeId as String,
              child: Text(s.storeId as String),
            ),
        ];
        return DropdownButtonFormField<String>(
          initialValue: scope.storeId,
          items: items,
          decoration: const InputDecoration(
            labelText: 'Store',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (v) => notifier.setStoreId(v ?? ''),
        );
      },
      error: (_, __) => const SizedBox.shrink(),
      loading: () => const SizedBox.shrink(),
    );
  }
}

class _Buckets extends StatelessWidget {
  const _Buckets({required this.buckets});
  final List<SalesSummaryBucket> buckets;

  @override
  Widget build(BuildContext context) {
    if (buckets.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 96),
          Center(
            child: Text('No activity in this period',
                style: Theme.of(context).textTheme.titleMedium),
          ),
        ],
      );
    }
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: buckets.length,
      itemBuilder: (context, i) {
        final b = buckets[i];
        final t = Theme.of(context).textTheme;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(b.periodStart, style: t.titleMedium),
                const SizedBox(height: 8),
                _row(context, 'Revenue', b.revenue),
                _row(context, 'Tax', b.tax),
                const Divider(height: 16),
                _row(context, 'Grand total', b.grandTotal, bold: true),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _row(BuildContext context, String label, MoneyAmount m,
      {bool bold = false}) {
    final t = Theme.of(context).textTheme;
    final style =
        bold ? t.titleMedium : t.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(formatMoney(m), style: style),
        ],
      ),
    );
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
            isAuth ? 'Owner login required' : 'Could not load',
            style: t.titleMedium,
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(error.toString(),
              style: t.bodySmall, textAlign: TextAlign.center),
        ),
      ],
    );
  }
}

String _fmtDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _fmtMonth(DateTime d) {
  const names = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${names[d.month - 1]} ${d.year}';
}
