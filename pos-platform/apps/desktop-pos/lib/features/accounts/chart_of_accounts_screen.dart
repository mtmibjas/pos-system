/// Chart of accounts — grouped account list with balances.
///
/// Hardcoded sample data matches the Greenleaf/Dostop prototype
/// (ACCOUNTS in gl_app.js).  Replace `_kAccounts` with a provider
/// call when a real GL read API is available.
library;

import 'package:flutter/material.dart';

import '../../ui/theme.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';

// ---------------------------------------------------------------------------
// Domain model (hardcoded until API exists)
// ---------------------------------------------------------------------------

class _AccountRow {
  const _AccountRow({
    required this.name,
    required this.code,
    required this.bal,
  });
  final String name;
  final String code;
  final double bal;
}

class _AccountGroup {
  const _AccountGroup({
    required this.group,
    required this.color,
    required this.rows,
  });
  final String group;
  final Color color;
  final List<_AccountRow> rows;

  double get total => rows.fold(0.0, (s, r) => s + r.bal);
}

// ---------------------------------------------------------------------------
// Hardcoded data  (gl_app.js → ACCOUNTS)
// ---------------------------------------------------------------------------

const _kAccounts = <_AccountGroup>[
  _AccountGroup(
    group: 'Assets',
    color: Color(0xFF2563EB),
    rows: [
      _AccountRow(name: 'Cash in hand', code: '1001', bal: 264800),
      _AccountRow(
          name: 'Bank — Commercial Bank current', code: '1002', bal: 1843000),
      _AccountRow(name: 'Accounts receivable', code: '1100', bal: 191250),
      _AccountRow(name: 'Inventory (at cost)', code: '1200', bal: 657110),
      _AccountRow(name: 'Fixtures & equipment', code: '1500', bal: 2400000),
    ],
  ),
  _AccountGroup(
    group: 'Liabilities',
    color: Color(0xFFDC2626),
    rows: [
      _AccountRow(name: 'Accounts payable', code: '2001', bal: 433500),
      _AccountRow(name: 'VAT payable', code: '2100', bal: 187400),
      _AccountRow(name: 'Salaries payable', code: '2200', bal: 118000),
    ],
  ),
  _AccountGroup(
    group: 'Equity',
    color: Color(0xFF7C3AED),
    rows: [
      _AccountRow(name: "Owner's capital", code: '3001', bal: 4000000),
      _AccountRow(name: 'Retained earnings', code: '3100', bal: 617260),
    ],
  ),
  _AccountGroup(
    group: 'Income',
    color: Color(0xFF16A34A),
    rows: [
      _AccountRow(name: 'Sales — goods', code: '4001', bal: 12846000),
      _AccountRow(name: 'Other income', code: '4900', bal: 124000),
    ],
  ),
  _AccountGroup(
    group: 'Expenses',
    color: Color(0xFFD97706),
    rows: [
      _AccountRow(name: 'Cost of goods sold', code: '5001', bal: 9624000),
      _AccountRow(name: 'Rent', code: '5100', bal: 145000),
      _AccountRow(name: 'Salaries', code: '5200', bal: 118000),
      _AccountRow(name: 'Utilities', code: '5300', bal: 31500),
      _AccountRow(name: 'Other operating', code: '5900', bal: 106200),
    ],
  ),
];

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Format a number as "Rs 1,234.56"
String rs(num n) {
  final abs = n.abs();
  final str = abs.toStringAsFixed(2);
  final parts = str.split('.');
  final intPart = parts[0];
  final decPart = parts[1];
  final buf = StringBuffer();
  for (var i = 0; i < intPart.length; i++) {
    if (i > 0 && (intPart.length - i) % 3 == 0) buf.write(',');
    buf.write(intPart[i]);
  }
  return 'Rs ${buf.toString()}.$decPart';
}

int get _totalAccountCount =>
    _kAccounts.fold(0, (s, g) => s + g.rows.length);

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class ChartOfAccountsScreen extends StatelessWidget {
  const ChartOfAccountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final count = _totalAccountCount;
    return Scaffold(
      backgroundColor: DostopColors.canvas,
      body: Column(
        children: [
          DostopScreenHeader(
            title: 'Chart of accounts',
            subtitle:
                '$count accounts · balances as at 15 June 2026',
          ),
          const Expanded(
            child: _AccountsBody(),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Body — responsive grid
// ---------------------------------------------------------------------------

class _AccountsBody extends StatelessWidget {
  const _AccountsBody();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 2-column grid when wide enough, 1-column otherwise.
        final cols = constraints.maxWidth >= 700 ? 2 : 1;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _SimpleGrid(cols: cols, groups: _kAccounts),
        );
      },
    );
  }
}

/// A dead-simple wrapping grid without package dependencies.
class _SimpleGrid extends StatelessWidget {
  const _SimpleGrid({required this.cols, required this.groups});
  final int cols;
  final List<_AccountGroup> groups;

  @override
  Widget build(BuildContext context) {
    // Distribute groups into columns in order.
    final columns = List.generate(cols, (_) => <_AccountGroup>[]);
    for (var i = 0; i < groups.length; i++) {
      columns[i % cols].add(groups[i]);
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var c = 0; c < cols; c++) ...[
            if (c > 0) const SizedBox(width: 14),
            Expanded(
              child: Column(
                children: [
                  for (final g in columns[c]) ...[
                    _GroupCard(group: g),
                    const SizedBox(height: 14),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Group card
// ---------------------------------------------------------------------------

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.group});
  final _AccountGroup group;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: DostopColors.panel,
        border: Border.all(color: const Color(0xFFE8EBEF)),
        borderRadius: BorderRadius.circular(DostopRadius.card),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D0F172A),
            blurRadius: 6,
            offset: Offset(0, 1),
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: [
          _GroupHeader(group: group),
          ...group.rows.asMap().entries.map(
                (e) => _AccountRowTile(
                  row: e.value,
                  groupColor: group.color,
                  isLast: e.key == group.rows.length - 1,
                ),
              ),
        ],
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.group});
  final _AccountGroup group;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF1F4F8))),
      ),
      child: Row(
        children: [
          // Coloured dot
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: group.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 9),
          Text(
            group.group,
            style: const TextStyle(
              fontFamily: DostopFonts.sans,
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: DostopColors.ink,
            ),
          ),
          const Spacer(),
          Text(
            rs(group.total),
            style: TextStyle(
              fontFamily: DostopFonts.sans,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: group.color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountRowTile extends StatelessWidget {
  const _AccountRowTile({
    required this.row,
    required this.groupColor,
    required this.isLast,
  });
  final _AccountRow row;
  final Color groupColor;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: Color(0xFFF6F8FA))),
      ),
      child: Row(
        children: [
          // Account code
          SizedBox(
            width: 44,
            child: Text(
              row.code,
              style: DostopText.mono.copyWith(
                fontSize: 11,
                color: DostopColors.slate400,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Account name
          Expanded(
            child: Text(
              row.name,
              overflow: TextOverflow.ellipsis,
              style: DostopText.label.copyWith(fontSize: 12.5),
            ),
          ),
          const SizedBox(width: 12),
          // Balance
          Text(
            rs(row.bal),
            style: DostopText.money.copyWith(fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}
