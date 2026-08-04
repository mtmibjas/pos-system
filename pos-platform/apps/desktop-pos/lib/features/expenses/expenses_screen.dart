/// Expenses screen — translates the Greenleaf/Dostop prototype's "Expenses"
/// section into Flutter using the Dostop design system tokens.
///
/// Layout (faithful to the prototype's two-column grid):
///   Left (1.6fr):  category filter chips + expenses table (date, category,
///                  description, payment-mode pill, amount, VAT).
///   Right (1fr):   total spend card + by-category bar breakdown.
///
/// Data is live: ExpenseService.ListExpenses via [ExpensesController] (see
/// expenses_controller.dart). The category-filter state stays local
/// [setState]. The visual design is unchanged from the prototype — only
/// the data source moved from a hardcoded list to the store-server.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_sdk/gen/pos/v1/common.pb.dart' as pb;
import 'package:pos_sdk/gen/pos/v1/expense_service.pb.dart' as pb;

import '../../ui/theme.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';
import 'expenses_controller.dart';

// ---------------------------------------------------------------------------
// Money helper
// ---------------------------------------------------------------------------

/// Format a number as "Rs X,XXX.XX" (Sri Lanka locale style).
String rs(num n) {
  final abs = n.abs();
  final intPart = abs.truncate();
  final fracPart = ((abs - intPart) * 100).round();

  final s = intPart.toString();
  final buf = StringBuffer();
  int digitsLeft = s.length;
  for (int i = 0; i < s.length; i++) {
    final remaining = digitsLeft - i;
    buf.write(s[i]);
    if (remaining > 1 && (remaining - 1) % 3 == 0) buf.write(',');
  }
  final frac = fracPart.toString().padLeft(2, '0');
  return 'Rs ${buf.toString()}.$frac';
}

// ---------------------------------------------------------------------------
// Data model
// ---------------------------------------------------------------------------

enum _PayMode {
  cash('Cash', DostopColors.brandDark, DostopColors.stockOkBg),
  bank('Bank', DostopColors.blue, DostopColors.blueWash),
  lankaQr('LankaQR', DostopColors.violet, DostopColors.violetWash);

  const _PayMode(this.label, this.fg, this.bg);
  final String label;
  final Color fg;
  final Color bg;

  /// Resolve a free-form payment_mode string to a styled pill mode.
  /// Unknown modes fall back to [cash] styling so the row still renders.
  static _PayMode fromString(String raw) {
    final v = raw.trim().toLowerCase();
    switch (v) {
      case 'bank':
        return _PayMode.bank;
      case 'lankaqr':
      case 'lanka qr':
        return _PayMode.lankaQr;
      case 'cash':
      default:
        return _PayMode.cash;
    }
  }
}

class _Expense {
  const _Expense({
    required this.id,
    required this.date,
    required this.cat,
    required this.desc,
    required this.mode,
    required this.amt,
    required this.vat,
  });

  /// Build the presentation model from a wire [pb.Expense]. Money is
  /// rendered in whole rupees (the existing table/summary display works
  /// in integer LKR), rounding the fractional nanos into the unit.
  factory _Expense.fromProto(pb.Expense e) {
    return _Expense(
      id: e.id,
      date: e.date,
      cat: e.category,
      desc: e.description,
      mode: _PayMode.fromString(e.paymentMode),
      amt: _moneyToWholeRupees(e.amount),
      vat: _moneyToWholeRupees(e.vat),
    );
  }

  final String id;
  final String date;
  final String cat;
  final String desc;
  final _PayMode mode;
  final int amt;
  final int vat;
}

/// Collapse a fixed-precision [pb.Money] to whole rupees (units + rounded
/// nanos). Sufficient for the display, which never does sub-rupee math.
int _moneyToWholeRupees(pb.Money m) {
  final units = m.units.toInt();
  final frac = (m.nanos / 1000000000).round();
  return units + frac;
}

// Derive the category filter list from the live expenses.
List<String> _buildCats(List<_Expense> expenses) {
  final seen = <String>{};
  final out = <String>['All'];
  for (final e in expenses) {
    if (seen.add(e.cat)) out.add(e.cat);
  }
  return out;
}

// "By category" breakdown sorted descending by total amount.
List<({String cat, int amt, int pct})> _buildByCat(List<_Expense> expenses) {
  final total = expenses.fold<int>(0, (s, e) => s + e.amt);
  if (total == 0) return const [];
  final map = <String, int>{};
  for (final e in expenses) {
    map[e.cat] = (map[e.cat] ?? 0) + e.amt;
  }
  final rows = map.entries
      .map((kv) =>
          (cat: kv.key, amt: kv.value, pct: (kv.value / total * 100).round()))
      .toList()
    ..sort((a, b) => b.amt.compareTo(a.amt));
  return rows;
}

// ---------------------------------------------------------------------------
// Public widget
// ---------------------------------------------------------------------------

class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  String _cat = 'All';

  List<_Expense> _filtered(List<_Expense> all) =>
      _cat == 'All' ? all : all.where((e) => e.cat == _cat).toList();

  int _totalSpend(List<_Expense> all) => all.fold(0, (s, e) => s + e.amt);
  int _totalVat(List<_Expense> all) => all.fold(0, (s, e) => s + e.vat);

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(expensesControllerProvider);
    final count = state.valueOrNull?.length ?? 0;

    return Scaffold(
      backgroundColor: DostopColors.canvas,
      body: Column(
        children: [
          DostopScreenHeader(
            title: 'Expenses',
            subtitle: count > 0
                ? '$count ${count == 1 ? 'entry' : 'entries'} · each entry posts to the ledger'
                : 'Each entry posts to the ledger',
            actions: [
              IconButton(
                tooltip: 'Reload',
                onPressed: state.isLoading
                    ? null
                    : () => ref
                        .read(expensesControllerProvider.notifier)
                        .refresh(),
                icon: const Icon(Icons.refresh,
                    size: 20, color: DostopColors.slate500),
              ),
              const SizedBox(width: 4),
              _OutlineButton(label: 'Export', onTap: () {}),
              const SizedBox(width: 8),
              _PrimaryButton(label: '+ Add expense', onTap: () {}),
            ],
          ),
          Expanded(
            child: state.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(strokeWidth: 2.5)),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: SelectableText('Failed to load expenses: $err',
                      style: DostopText.label
                          .copyWith(color: DostopColors.danger)),
                ),
              ),
              data: (rows) {
                final all = rows.map(_Expense.fromProto).toList();
                if (all.isEmpty) {
                  return const DostopEmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'No expenses recorded yet',
                    detail:
                        'Recorded outgoings (rent, utilities, salaries, …) '
                        'appear here once added.',
                  );
                }
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: _body(all),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ---- Two-column body -------------------------------------------------------

  Widget _body(List<_Expense> all) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Below 860 px collapse to single column so nothing overflows.
        if (constraints.maxWidth < 860) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _leftPane(all),
              const SizedBox(height: 16),
              _rightPane(all),
            ],
          );
        }
        // Two-column: left 1.6fr, right 1fr — mirrors the prototype grid.
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 16, child: _leftPane(all)),
            const SizedBox(width: 16),
            Expanded(flex: 10, child: _rightPane(all)),
          ],
        );
      },
    );
  }

  // ---- Left pane: filter chips + table --------------------------------------

  Widget _leftPane(List<_Expense> all) {
    final rows = _filtered(all);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category filter chips.
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _buildCats(all).map(_chip).toList(),
        ),
        const SizedBox(height: 14),
        // Expenses table card.
        Container(
          decoration: BoxDecoration(
            color: DostopColors.panel,
            border: Border.all(color: const Color(0xFFE8EBEF)),
            borderRadius: BorderRadius.circular(DostopRadius.card + 2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D0F172A),
                blurRadius: 3,
                offset: Offset(0, 1),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _tableHeader(),
              if (rows.isEmpty)
                const _EmptyRows()
              else
                ...rows.map(_tableRow),
            ],
          ),
        ),
      ],
    );
  }

  Widget _chip(String label) {
    final active = _cat == label;
    return GestureDetector(
      onTap: () => setState(() => _cat = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: 33,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          color: active ? DostopColors.ink : DostopColors.panel,
          borderRadius: BorderRadius.circular(DostopRadius.control),
          border: Border.all(
            color: active ? DostopColors.ink : DostopColors.slate200,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontFamily: DostopFonts.sans,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : DostopColors.slate600,
          ),
        ),
      ),
    );
  }

  Widget _tableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      decoration: const BoxDecoration(
        color: DostopColors.slate50,
        border: Border(bottom: BorderSide(color: DostopColors.hairline)),
      ),
      child: const Row(
        children: [
          SizedBox(
              width: 110,
              child: Text('DATE', style: DostopText.columnHead)),
          Expanded(
              child: Text('DESCRIPTION', style: DostopText.columnHead)),
          SizedBox(
              width: 120,
              child: Text('CATEGORY', style: DostopText.columnHead)),
          SizedBox(
              width: 100,
              child: Text('MODE',
                  textAlign: TextAlign.center,
                  style: DostopText.columnHead)),
          SizedBox(
              width: 110,
              child: Text('AMOUNT',
                  textAlign: TextAlign.right,
                  style: DostopText.columnHead)),
        ],
      ),
    );
  }

  Widget _tableRow(_Expense e) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF4F6F9))),
      ),
      child: Row(
        children: [
          // Date.
          SizedBox(
            width: 110,
            child: Text(
              e.date,
              style: DostopText.label.copyWith(fontSize: 12.5),
            ),
          ),
          // Description + VAT sub-line.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.desc,
                  overflow: TextOverflow.ellipsis,
                  style: DostopText.itemName.copyWith(fontSize: 13),
                ),
                Text(
                  'VAT paid ${e.vat > 0 ? rs(e.vat) : '—'}',
                  style: DostopText.mono.copyWith(
                      fontSize: 11, color: DostopColors.slate400),
                ),
              ],
            ),
          ),
          // Category.
          SizedBox(
            width: 120,
            child: Text(
              e.cat,
              overflow: TextOverflow.ellipsis,
              style: DostopText.label
                  .copyWith(fontSize: 12.5, color: DostopColors.slate600),
            ),
          ),
          // Payment mode pill.
          SizedBox(
            width: 100,
            child: Center(
              child: DostopPill(
                label: e.mode.label,
                fg: e.mode.fg,
                bg: e.mode.bg,
              ),
            ),
          ),
          // Amount.
          SizedBox(
            width: 110,
            child: Text(
              rs(e.amt),
              textAlign: TextAlign.right,
              style: DostopText.money,
            ),
          ),
        ],
      ),
    );
  }

  // ---- Right pane: summary card + by-category breakdown ---------------------

  Widget _rightPane(List<_Expense> all) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _totalCard(all),
        const SizedBox(height: 14),
        _byCatCard(all),
      ],
    );
  }

  Widget _totalCard(List<_Expense> all) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: DostopColors.panel,
        border: Border.all(color: const Color(0xFFE8EBEF)),
        borderRadius: BorderRadius.circular(DostopRadius.card + 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Total spend',
            style: TextStyle(
              fontFamily: DostopFonts.sans,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: DostopColors.slate400,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            rs(_totalSpend(all)),
            style: const TextStyle(
              fontFamily: DostopFonts.sans,
              fontSize: 27,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.7,
              color: DostopColors.danger,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Input VAT claimable ${rs(_totalVat(all))}',
            style: const TextStyle(
              fontFamily: DostopFonts.sans,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: DostopColors.slate400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _byCatCard(List<_Expense> all) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: DostopColors.panel,
        border: Border.all(color: const Color(0xFFE8EBEF)),
        borderRadius: BorderRadius.circular(DostopRadius.card + 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'By category',
            style: TextStyle(
              fontFamily: DostopFonts.sans,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: DostopColors.ink,
            ),
          ),
          const SizedBox(height: 15),
          ..._buildByCat(all).map(_catBar),
        ],
      ),
    );
  }

  Widget _catBar(({String cat, int amt, int pct}) row) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                row.cat,
                style: DostopText.label.copyWith(
                    fontSize: 12.5, color: DostopColors.slate600),
              ),
              Text(
                rs(row.amt),
                style: DostopText.money.copyWith(fontSize: 12.5),
              ),
            ],
          ),
          const SizedBox(height: 5),
          // Progress bar.
          LayoutBuilder(builder: (context, c) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: SizedBox(
                width: c.maxWidth,
                height: 7,
                child: Stack(
                  children: [
                    Container(color: DostopColors.slate100),
                    FractionallySizedBox(
                      widthFactor: (row.pct / 100).clamp(0.0, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B),
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Local helper widgets
// ---------------------------------------------------------------------------

class _EmptyRows extends StatelessWidget {
  const _EmptyRows();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Text(
          'No expenses in this category.',
          style: DostopText.label,
        ),
      ),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  const _OutlineButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          color: DostopColors.panel,
          borderRadius: BorderRadius.circular(DostopRadius.button - 1),
          border: Border.all(color: DostopColors.slate200),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: DostopFonts.sans,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: DostopColors.slate600,
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: DostopColors.brand,
          borderRadius: BorderRadius.circular(DostopRadius.button - 1),
          border: Border.all(color: DostopColors.brandDark),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: DostopFonts.sans,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
