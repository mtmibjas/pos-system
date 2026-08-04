/// Reports screen — Dostop POS desktop.
///
/// LEFT pane: report-nav list (grouped) + date-range chip row.
/// RIGHT pane: the selected report rendered as a titled table/summary.
///
/// All datasets are hardcoded here; no network / Riverpod required.
/// When the cloud-api reports service is wired, swap the hardcoded
/// constants for async providers and wrap the body in an AsyncValue.when().
library;

import 'package:flutter/material.dart';

import '../../ui/theme.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';

// ---------------------------------------------------------------------------
// Money helper
// ---------------------------------------------------------------------------

String rs(num n) {
  final abs = n.abs();
  final s = abs.toStringAsFixed(2);
  // Insert thousands separators (en-LK style).
  final parts = s.split('.');
  final buf = StringBuffer();
  final digits = parts[0];
  int start = digits.length % 3;
  if (start > 0) buf.write(digits.substring(0, start));
  for (int i = start; i < digits.length; i += 3) {
    if (i > 0) buf.write(',');
    buf.write(digits.substring(i, i + 3));
  }
  return 'Rs ${buf.toString()}.${parts[1]}';
}

// ---------------------------------------------------------------------------
// Static datasets (translated from /tmp/gl_app.js)
// ---------------------------------------------------------------------------

// ---- Report nav list -------------------------------------------------------

class _ReportMeta {
  const _ReportMeta(this.key, this.label, this.group);
  final String key;
  final String label;
  final String group;
}

const _reports = [
  _ReportMeta('gstr1', 'Output VAT summary', 'Compliance'),
  _ReportMeta('gstr3b', 'VAT return (Form 200)', 'Compliance'),
  _ReportMeta('pnl', 'Profit & Loss', 'Financial'),
  _ReportMeta('bs', 'Balance Sheet', 'Financial'),
  _ReportMeta('salesreg', 'Sales register', 'Registers'),
  _ReportMeta('purchreg', 'Purchase register', 'Registers'),
  _ReportMeta('stocksum', 'Stock summary', 'Registers'),
  _ReportMeta('partyledger', 'Party ledger', 'Registers'),
];

const _ranges = [
  'Today',
  'This week',
  'This month',
  'This quarter',
  'FY 2026-27',
];

// ---- GSTR-1 (Output VAT summary) ------------------------------------------

class _G1Row {
  const _G1Row(this.slab, this.taxable, this.cgst, this.sgst, this.igst, this.count);
  final num slab;
  final num taxable;
  final num cgst;
  final num sgst;
  final num igst;
  final int count;
}

const _gstr1 = [
  _G1Row(0, 1240000, 0, 0, 0, 684),
  _G1Row(18, 1848000, 332640, 0, 0, 412),
  _G1Row(2.5, 3088000, 0, 77200, 0, 1096),
];

// ---- GSTR-3B (VAT return) --------------------------------------------------

class _G3BRow {
  const _G3BRow(this.label, this.taxable, this.tax, this.isDim);
  final String label;
  final String taxable; // pre-formatted or '—'
  final String tax;
  final bool isDim;
}

final _gstr3b = [
  _G3BRow('Box 1 · Standard-rated supplies (18%)', rs(1848000), rs(332640), false),
  _G3BRow('Box 2 · Exempt & zero-rated supplies', rs(1240000), '—', true),
  _G3BRow('Box 5 · SSCL on turnover (2.5%)', rs(3088000), rs(77200), false),
  _G3BRow('Box 8 · Input VAT claimed', '—', '− ${rs(168400)}', false),
  _G3BRow('Box 12 · Penalty & interest', '—', rs(0), true),
];

const _gstOut = 332640 + 77200;
const _gstItc = 168400;
const _gstNet = _gstOut - _gstItc;

// ---- P&L rows --------------------------------------------------------------

class _PnlRow {
  const _PnlRow(this.label, this.amt, this.isBold, this.isGreen, this.isHighlight);
  final String label;
  final String amt; // pre-formatted (includes − prefix when negative)
  final bool isBold;
  final bool isGreen; // green = positive/good, red = cost/expense
  final bool isHighlight; // slightly tinted row background
}

num _income() => 12846000 + 124000;
num _cogs() => 9624000;
num _opex() => 145000 + 118000 + 31500 + 106200;
num _gross() => _income() - _cogs();
num _net() => _gross() - _opex();

List<_PnlRow> get _pnlRows => [
      _PnlRow('Revenue', rs(_income()), true, false, false),
      _PnlRow('Cost of goods sold', '− ${rs(_cogs())}', false, false, false),
      _PnlRow('Gross profit', rs(_gross()), true, true, false),
      _PnlRow('Rent', '− ${rs(145000)}', false, false, false),
      _PnlRow('Salaries', '− ${rs(118000)}', false, false, false),
      _PnlRow('Utilities', '− ${rs(31500)}', false, false, false),
      _PnlRow('Other operating', '− ${rs(106200)}', false, false, false),
      _PnlRow('Net profit', rs(_net()), true, true, true),
    ];

// ---- Balance sheet ---------------------------------------------------------

class _BsRow {
  const _BsRow(this.code, this.name, this.bal);
  final String code;
  final String name;
  final num bal;
}

class _BsGroup {
  const _BsGroup(this.group, this.color, this.rows);
  final String group;
  final Color color;
  final List<_BsRow> rows;
}

const _assets = [
  _BsGroup(
    'Assets',
    DostopColors.blue,
    [
      _BsRow('1001', 'Cash in hand', 264800),
      _BsRow('1002', 'Bank — Commercial Bank current', 1843000),
      _BsRow('1100', 'Accounts receivable', 191250),
      _BsRow('1200', 'Inventory (at cost)', 657110),
      _BsRow('1500', 'Fixtures & equipment', 2400000),
    ],
  ),
];

const _liabs = [
  _BsGroup(
    'Liabilities',
    DostopColors.danger,
    [
      _BsRow('2001', 'Accounts payable', 433500),
      _BsRow('2100', 'VAT payable', 187400),
      _BsRow('2200', 'Salaries payable', 118000),
    ],
  ),
  _BsGroup(
    'Equity',
    DostopColors.violet,
    [
      _BsRow('3001', "Owner's capital", 4000000),
      _BsRow('3100', 'Retained earnings', 617260),
    ],
  ),
];

num _bsGroupTotal(List<_BsGroup> groups) =>
    groups.fold<num>(0, (s, g) => s + g.rows.fold<num>(0, (x, r) => x + r.bal));

// ---- Sales register --------------------------------------------------------

class _SalesRegRow {
  const _SalesRegRow(this.no, this.party, this.date, this.taxable, this.gst);
  final String no;
  final String party;
  final String date;
  final num taxable;
  final num gst;
}

const _salesRegRows = [
  _SalesRegRow('INV-1184', 'Nimali Perera', '15 Jun 2026', 4028.24, 251.76),
  _SalesRegRow('INV-1183', 'Walk-in', '15 Jun 2026', 1520.34, 99.66),
  _SalesRegRow('INV-1182', 'Dinesh Fernando', '15 Jun 2026', 7810.60, 829.90),
  _SalesRegRow('INV-1180', 'Jayasinghe Stores', '15 Jun 2026', 53904.80, 4195.20),
  _SalesRegRow('INV-1178', 'Sunil Bandara', '15 Jun 2026', 2306.67, 163.33),
  _SalesRegRow('INV-1170', 'Walk-in', '14 Jun 2026', 1142.86, 57.14),
];

// ---- Party ledger ----------------------------------------------------------

class _LedgerRow {
  const _LedgerRow(this.name, this.type, this.last, this.bal);
  final String name;
  final String type; // 'customer' | 'supplier'
  final String last;
  final num bal;
}

const _ledgerRows = [
  _LedgerRow('Nimali Perera', 'customer', 'Today, 1:02 PM', 4280),
  _LedgerRow('Jayasinghe Stores', 'customer', 'Today, 12:15 PM', 184500),
  _LedgerRow('Dinesh Fernando', 'customer', 'Today, 12:41 PM', 0),
  _LedgerRow('Sunil Bandara', 'customer', 'Today, 11:46 AM', 2470),
  _LedgerRow('Chamari Silva', 'customer', '9 Jun 2026', 0),
  _LedgerRow('Dambulla Fresh Produce', 'supplier', 'Today, 7:10 AM', -142000),
  _LedgerRow('Highland Dairy Dist.', 'supplier', 'Today, 6:40 AM', -63500),
  _LedgerRow('Perera Bakery', 'supplier', '14 Jun 2026', 0),
  _LedgerRow('CBL Distributors', 'supplier', '11 Jun 2026', -228000),
  _LedgerRow('Unilever Sri Lanka', 'supplier', '6 Jun 2026', 0),
];

// ===========================================================================
// Main widget
// ===========================================================================

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String _report = 'gstr1';
  String _range = 'This month';

  _ReportMeta get _selectedMeta =>
      _reports.firstWhere((r) => r.key == _report, orElse: () => _reports[0]);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DostopColors.canvas,
      body: Column(
        children: [
          DostopScreenHeader(
            title: 'Reports',
            subtitle: '${_selectedMeta.label} · $_range',
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _NavPane(
                  selected: _report,
                  range: _range,
                  onSelect: (k) => setState(() => _report = k),
                  onRange: (r) => setState(() => _range = r),
                ),
                const VerticalDivider(width: 1, color: DostopColors.slate200),
                Expanded(child: _ReportPane(report: _report, range: _range)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Left nav pane
// ===========================================================================

class _NavPane extends StatelessWidget {
  const _NavPane({
    required this.selected,
    required this.range,
    required this.onSelect,
    required this.onRange,
  });

  final String selected;
  final String range;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onRange;

  @override
  Widget build(BuildContext context) {
    // Group nav items.
    final groups = <String, List<_ReportMeta>>{};
    for (final r in _reports) {
      groups.putIfAbsent(r.group, () => []).add(r);
    }

    return SizedBox(
      width: 230,
      child: Container(
        color: DostopColors.panel,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Date-range chips
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _ranges
                    .map((r) => _RangeChip(
                          label: r,
                          selected: r == range,
                          onTap: () => onRange(r),
                        ))
                    .toList(),
              ),
            ),
            const Divider(height: 1, color: DostopColors.hairline),
            const SizedBox(height: 6),
            // Report nav grouped
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                children: [
                  for (final entry in groups.entries) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
                      child: Text(
                        entry.key.toUpperCase(),
                        style: DostopText.columnHead,
                      ),
                    ),
                    for (final r in entry.value)
                      _NavItem(
                        label: r.label,
                        selected: r.key == selected,
                        onTap: () => onSelect(r.key),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RangeChip extends StatelessWidget {
  const _RangeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? DostopColors.ink : DostopColors.slate100,
          borderRadius: BorderRadius.circular(DostopRadius.chip),
          border: Border.all(
            color: selected ? DostopColors.ink : DostopColors.slate200,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: DostopFonts.sans,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : DostopColors.slate600,
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(DostopRadius.control),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? DostopColors.brandWash : Colors.transparent,
          borderRadius: BorderRadius.circular(DostopRadius.control),
        ),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? DostopColors.brand : DostopColors.slate300,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: DostopFonts.sans,
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: selected ? DostopColors.brand : DostopColors.slate600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// Right report pane — switches on [report]
// ===========================================================================

class _ReportPane extends StatelessWidget {
  const _ReportPane({required this.report, required this.range});

  final String report;
  final String range;

  @override
  Widget build(BuildContext context) {
    return switch (report) {
      'gstr1' => const _G1View(),
      'gstr3b' => const _G3BView(),
      'pnl' => const _PnlView(),
      'bs' => const _BsView(),
      'salesreg' => const _SalesRegView(),
      'partyledger' => const _LedgerView(),
      _ => const DostopEmptyState(
          icon: Icons.bar_chart_rounded,
          title: 'Report coming soon',
          detail: 'Select a report from the left panel.',
        ),
    };
  }
}

// ===========================================================================
// Shared report chrome helpers
// ===========================================================================

/// Wraps a report in a scrollable panel with a title bar and content.
class _ReportShell extends StatelessWidget {
  const _ReportShell({required this.title, required this.child, this.kicker});

  final String title;
  final String? kicker;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: const BoxDecoration(
            color: DostopColors.panel,
            border: Border(bottom: BorderSide(color: DostopColors.hairline)),
          ),
          child: Row(
            children: [
              Text(title, style: DostopText.h1),
              if (kicker != null) ...[
                const SizedBox(width: 10),
                Text(kicker!, style: DostopText.kicker),
              ],
            ],
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

/// A plain card container used inside reports.
class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: DostopColors.panel,
        borderRadius: BorderRadius.circular(DostopRadius.card),
        border: Border.all(color: DostopColors.slate200),
      ),
      child: child,
    );
  }
}

/// Column header row background.
class _TableHead extends StatelessWidget {
  const _TableHead({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: const BoxDecoration(
        color: DostopColors.slate50,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(DostopRadius.card),
          topRight: Radius.circular(DostopRadius.card),
        ),
        border: Border(bottom: BorderSide(color: DostopColors.hairline)),
      ),
      child: Row(children: children),
    );
  }
}

/// A single table data row with alternating background.
class _TableRow extends StatelessWidget {
  const _TableRow({required this.children, this.isLast = false, this.bg});

  final List<Widget> children;
  final bool isLast;
  final Color? bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: bg ?? DostopColors.panel,
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: DostopColors.hairline),
              ),
      ),
      child: Row(children: children),
    );
  }
}

/// Summary KPI card (a small box showing a label + big money figure).
class _KpiBox extends StatelessWidget {
  const _KpiBox({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DostopColors.panel,
        borderRadius: BorderRadius.circular(DostopRadius.card),
        border: Border.all(color: DostopColors.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: DostopText.columnHead),
          const SizedBox(height: 6),
          Text(
            value,
            style: DostopText.money.copyWith(
              fontSize: 16,
              color: valueColor ?? DostopColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// GSTR-1 — Output VAT summary
// ===========================================================================

class _G1View extends StatelessWidget {
  const _G1View();

  @override
  Widget build(BuildContext context) {
    // Totals
    num tTaxable = 0, tCgst = 0, tSgst = 0, tIgst = 0;
    int tCount = 0;
    for (final r in _gstr1) {
      tTaxable += r.taxable;
      tCgst += r.cgst;
      tSgst += r.sgst;
      tIgst += r.igst;
      tCount += r.count;
    }
    final tTotal = tTaxable + tCgst + tSgst + tIgst;

    return _ReportShell(
      title: 'Output VAT Summary',
      kicker: 'GSTR-1 style · $tCount invoices',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // KPI row
            Row(
              children: [
                Expanded(child: _KpiBox(label: 'TAXABLE VALUE', value: rs(tTaxable))),
                const SizedBox(width: 12),
                Expanded(child: _KpiBox(label: 'OUTPUT VAT', value: rs(tCgst + tSgst + tIgst), valueColor: DostopColors.danger)),
                const SizedBox(width: 12),
                Expanded(child: _KpiBox(label: 'GROSS TOTAL', value: rs(tTotal))),
              ],
            ),
            const SizedBox(height: 20),
            // Table
            _Card(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 640),
                  child: Column(
                    children: [
                      const _TableHead(
                        children: [
                          SizedBox(width: 80, child: Text('RATE', style: DostopText.columnHead)),
                          SizedBox(width: 100, child: Text('INVOICES', style: DostopText.columnHead, textAlign: TextAlign.right)),
                          Expanded(child: Text('TAXABLE VALUE', style: DostopText.columnHead, textAlign: TextAlign.right)),
                          SizedBox(width: 130, child: Text('CGST / VAT', style: DostopText.columnHead, textAlign: TextAlign.right)),
                          SizedBox(width: 130, child: Text('SGST / SSCL', style: DostopText.columnHead, textAlign: TextAlign.right)),
                          SizedBox(width: 130, child: Text('TOTAL', style: DostopText.columnHead, textAlign: TextAlign.right)),
                        ],
                      ),
                      for (int i = 0; i < _gstr1.length; i++) ...[
                        _G1RowWidget(row: _gstr1[i], isLast: i == _gstr1.length - 1),
                      ],
                      // Totals row
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: const BoxDecoration(
                          color: DostopColors.inkPanel,
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(DostopRadius.card),
                            bottomRight: Radius.circular(DostopRadius.card),
                          ),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 80,
                              child: Text('Total', style: TextStyle(fontFamily: DostopFonts.sans, fontSize: 12.5, fontWeight: FontWeight.w800, color: Colors.white)),
                            ),
                            SizedBox(
                              width: 100,
                              child: Text('$tCount', textAlign: TextAlign.right,
                                  style: const TextStyle(fontFamily: DostopFonts.sans, fontSize: 12.5, fontWeight: FontWeight.w700, color: DostopColors.slate400)),
                            ),
                            Expanded(child: Text(rs(tTaxable), textAlign: TextAlign.right,
                                style: const TextStyle(fontFamily: DostopFonts.sans, fontSize: 12.5, fontWeight: FontWeight.w800, color: Colors.white))),
                            SizedBox(width: 130, child: Text(rs(tCgst), textAlign: TextAlign.right,
                                style: const TextStyle(fontFamily: DostopFonts.sans, fontSize: 12.5, fontWeight: FontWeight.w700, color: DostopColors.slate400))),
                            SizedBox(width: 130, child: Text(rs(tSgst), textAlign: TextAlign.right,
                                style: const TextStyle(fontFamily: DostopFonts.sans, fontSize: 12.5, fontWeight: FontWeight.w700, color: DostopColors.slate400))),
                            SizedBox(width: 130, child: Text(rs(tTotal), textAlign: TextAlign.right,
                                style: const TextStyle(fontFamily: DostopFonts.sans, fontSize: 12.5, fontWeight: FontWeight.w800, color: Colors.white))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _G1RowWidget extends StatelessWidget {
  const _G1RowWidget({required this.row, required this.isLast});

  final _G1Row row;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final slabLabel = row.slab == 0
        ? 'Exempt / 0%'
        : '${row.slab}%';
    final total = row.taxable + row.cgst + row.sgst + row.igst;

    return _TableRow(
      isLast: isLast,
      children: [
        SizedBox(
          width: 80,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: row.slab == 0 ? DostopColors.slate100 : DostopColors.brandWash,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              slabLabel,
              style: TextStyle(
                fontFamily: DostopFonts.sans,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: row.slab == 0 ? DostopColors.slate500 : DostopColors.brand,
              ),
            ),
          ),
        ),
        SizedBox(
          width: 100,
          child: Text('${row.count}', textAlign: TextAlign.right, style: DostopText.mono),
        ),
        Expanded(child: Text(rs(row.taxable), textAlign: TextAlign.right, style: DostopText.money)),
        SizedBox(width: 130, child: Text(row.cgst > 0 ? rs(row.cgst) : '—', textAlign: TextAlign.right, style: DostopText.money)),
        SizedBox(width: 130, child: Text(row.sgst > 0 ? rs(row.sgst) : '—', textAlign: TextAlign.right, style: DostopText.money)),
        SizedBox(width: 130, child: Text(rs(total), textAlign: TextAlign.right, style: DostopText.money)),
      ],
    );
  }
}

// ===========================================================================
// GSTR-3B — VAT return (Form 200 boxes)
// ===========================================================================

class _G3BView extends StatelessWidget {
  const _G3BView();

  @override
  Widget build(BuildContext context) {
    return _ReportShell(
      title: 'VAT Return — Form 200',
      kicker: 'GSTR-3B style',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary KPIs
            Row(
              children: [
                Expanded(child: _KpiBox(label: 'OUTPUT TAX', value: rs(_gstOut), valueColor: DostopColors.danger)),
                const SizedBox(width: 12),
                Expanded(child: _KpiBox(label: 'INPUT VAT CREDIT', value: rs(_gstItc), valueColor: DostopColors.brand)),
                const SizedBox(width: 12),
                Expanded(
                    child: _KpiBox(
                        label: 'NET TAX PAYABLE',
                        value: rs(_gstNet),
                        valueColor: _gstNet > 0 ? DostopColors.danger : DostopColors.brand)),
              ],
            ),
            const SizedBox(height: 20),
            _Card(
              child: Column(
                children: [
                  const _TableHead(
                    children: [
                      Expanded(child: Text('DESCRIPTION', style: DostopText.columnHead)),
                      SizedBox(width: 160, child: Text('TAXABLE VALUE', style: DostopText.columnHead, textAlign: TextAlign.right)),
                      SizedBox(width: 160, child: Text('TAX AMOUNT', style: DostopText.columnHead, textAlign: TextAlign.right)),
                    ],
                  ),
                  for (int i = 0; i < _gstr3b.length; i++) ...[
                    _G3BRowWidget(row: _gstr3b[i], isLast: i == _gstr3b.length - 1),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Net payable call-out
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: DostopColors.inkPanel,
                borderRadius: BorderRadius.circular(DostopRadius.card),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Net VAT + SSCL payable to IRD',
                      style: TextStyle(fontFamily: DostopFonts.sans, fontSize: 13, fontWeight: FontWeight.w700, color: DostopColors.slate400),
                    ),
                  ),
                  Text(
                    rs(_gstNet),
                    style: const TextStyle(
                      fontFamily: DostopFonts.sans,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _G3BRowWidget extends StatelessWidget {
  const _G3BRowWidget({required this.row, required this.isLast});

  final _G3BRow row;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return _TableRow(
      isLast: isLast,
      children: [
        Expanded(
          child: Text(
            row.label,
            style: TextStyle(
              fontFamily: DostopFonts.sans,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: row.isDim ? DostopColors.slate400 : DostopColors.ink,
            ),
          ),
        ),
        SizedBox(
            width: 160,
            child: Text(row.taxable, textAlign: TextAlign.right,
                style: DostopText.money.copyWith(color: row.isDim ? DostopColors.slate400 : DostopColors.ink))),
        SizedBox(
            width: 160,
            child: Text(row.tax, textAlign: TextAlign.right,
                style: DostopText.money.copyWith(
                    color: row.tax.startsWith('− ')
                        ? DostopColors.brand
                        : (row.isDim ? DostopColors.slate400 : DostopColors.ink)))),
      ],
    );
  }
}

// ===========================================================================
// Profit & Loss
// ===========================================================================

class _PnlView extends StatelessWidget {
  const _PnlView();

  @override
  Widget build(BuildContext context) {
    final rows = _pnlRows;
    final margin = (_net() / _income() * 100).round();

    return _ReportShell(
      title: 'Profit & Loss',
      kicker: 'Net margin $margin%',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: _KpiBox(label: 'REVENUE', value: rs(_income()))),
                const SizedBox(width: 12),
                Expanded(child: _KpiBox(label: 'GROSS PROFIT', value: rs(_gross()), valueColor: DostopColors.brand)),
                const SizedBox(width: 12),
                Expanded(child: _KpiBox(label: 'NET PROFIT', value: rs(_net()), valueColor: DostopColors.brand)),
              ],
            ),
            const SizedBox(height: 20),
            _Card(
              child: Column(
                children: [
                  const _TableHead(
                    children: [
                      Expanded(child: Text('DESCRIPTION', style: DostopText.columnHead)),
                      SizedBox(width: 200, child: Text('AMOUNT', style: DostopText.columnHead, textAlign: TextAlign.right)),
                    ],
                  ),
                  for (int i = 0; i < rows.length; i++) ...[
                    _PnlRowWidget(row: rows[i], isLast: i == rows.length - 1),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PnlRowWidget extends StatelessWidget {
  const _PnlRowWidget({required this.row, required this.isLast});

  final _PnlRow row;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    Color amtColor;
    if (row.isGreen) {
      amtColor = DostopColors.brand;
    } else if (row.amt.startsWith('−') || row.amt.startsWith('- ')) {
      amtColor = DostopColors.danger;
    } else {
      amtColor = DostopColors.ink;
    }

    return _TableRow(
      isLast: isLast,
      bg: row.isHighlight ? DostopColors.brandWash : null,
      children: [
        Expanded(
          child: Text(
            row.label,
            style: TextStyle(
              fontFamily: DostopFonts.sans,
              fontSize: 13,
              fontWeight: row.isBold ? FontWeight.w800 : FontWeight.w600,
              color: DostopColors.ink,
            ),
          ),
        ),
        SizedBox(
          width: 200,
          child: Text(
            row.amt,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontFamily: DostopFonts.sans,
              fontSize: 13,
              fontWeight: row.isBold ? FontWeight.w800 : FontWeight.w600,
              color: amtColor,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}

// ===========================================================================
// Balance Sheet
// ===========================================================================

class _BsView extends StatelessWidget {
  const _BsView();

  @override
  Widget build(BuildContext context) {
    final assetTotal = _bsGroupTotal(_assets);
    final liabTotal = _bsGroupTotal(_liabs);
    final balanced = (assetTotal - liabTotal).abs() < 1;

    return _ReportShell(
      title: 'Balance Sheet',
      kicker: balanced ? 'Balanced ✓' : 'Out of balance — check ledger',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Assets column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('ASSETS', style: DostopText.columnHead),
                  const SizedBox(height: 8),
                  for (final g in _assets) _BsGroupCard(group: g),
                  const SizedBox(height: 8),
                  _BsTotalRow(label: 'Total Assets', value: rs(assetTotal), color: DostopColors.blue),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Liabilities + Equity column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('LIABILITIES & EQUITY', style: DostopText.columnHead),
                  const SizedBox(height: 8),
                  for (final g in _liabs) _BsGroupCard(group: g),
                  const SizedBox(height: 8),
                  _BsTotalRow(label: 'Total Liabilities & Equity', value: rs(liabTotal), color: DostopColors.violet),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BsGroupCard extends StatelessWidget {
  const _BsGroupCard({required this.group});
  final _BsGroup group;

  @override
  Widget build(BuildContext context) {
    final total = group.rows.fold<num>(0, (s, r) => s + r.bal);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _Card(
        child: Column(
          children: [
            // Group header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: const BoxDecoration(
                color: DostopColors.slate50,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(DostopRadius.card),
                  topRight: Radius.circular(DostopRadius.card),
                ),
                border: Border(bottom: BorderSide(color: DostopColors.hairline)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 14,
                    decoration: BoxDecoration(
                      color: group.color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      group.group.toUpperCase(),
                      style: DostopText.columnHead.copyWith(color: group.color),
                    ),
                  ),
                  Text(rs(total),
                      style: DostopText.money.copyWith(fontSize: 12, color: group.color)),
                ],
              ),
            ),
            // Rows
            for (int i = 0; i < group.rows.length; i++) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  border: i < group.rows.length - 1
                      ? const Border(bottom: BorderSide(color: DostopColors.hairline))
                      : null,
                ),
                child: Row(
                  children: [
                    Text(
                      group.rows[i].code,
                      style: DostopText.mono.copyWith(fontSize: 10.5),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        group.rows[i].name,
                        style: DostopText.label.copyWith(fontSize: 12.5),
                      ),
                    ),
                    Text(
                      rs(group.rows[i].bal),
                      style: DostopText.money.copyWith(fontSize: 12.5),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BsTotalRow extends StatelessWidget {
  const _BsTotalRow({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: DostopColors.inkPanel,
        borderRadius: BorderRadius.circular(DostopRadius.card),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  fontFamily: DostopFonts.sans, fontSize: 12.5, fontWeight: FontWeight.w700, color: DostopColors.slate400)),
          Text(value,
              style: TextStyle(
                  fontFamily: DostopFonts.sans, fontSize: 15, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }
}

// ===========================================================================
// Sales register
// ===========================================================================

class _SalesRegView extends StatelessWidget {
  const _SalesRegView();

  @override
  Widget build(BuildContext context) {
    num tTaxable = 0, tGst = 0;
    for (final r in _salesRegRows) {
      tTaxable += r.taxable;
      tGst += r.gst;
    }

    return _ReportShell(
      title: 'Sales Register',
      kicker: '${_salesRegRows.length} invoices',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: _KpiBox(label: 'TAXABLE', value: rs(tTaxable))),
                const SizedBox(width: 12),
                Expanded(child: _KpiBox(label: 'VAT', value: rs(tGst), valueColor: DostopColors.danger)),
                const SizedBox(width: 12),
                Expanded(child: _KpiBox(label: 'TOTAL', value: rs(tTaxable + tGst))),
              ],
            ),
            const SizedBox(height: 20),
            _Card(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 700),
                  child: Column(
                    children: [
                      const _TableHead(
                        children: [
                          SizedBox(width: 110, child: Text('INVOICE', style: DostopText.columnHead)),
                          SizedBox(width: 100, child: Text('DATE', style: DostopText.columnHead)),
                          Expanded(child: Text('PARTY', style: DostopText.columnHead)),
                          SizedBox(width: 140, child: Text('TAXABLE', style: DostopText.columnHead, textAlign: TextAlign.right)),
                          SizedBox(width: 130, child: Text('VAT', style: DostopText.columnHead, textAlign: TextAlign.right)),
                          SizedBox(width: 140, child: Text('TOTAL', style: DostopText.columnHead, textAlign: TextAlign.right)),
                        ],
                      ),
                      for (int i = 0; i < _salesRegRows.length; i++) ...[
                        _SalesRegRowWidget(row: _salesRegRows[i], isLast: i == _salesRegRows.length - 1),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SalesRegRowWidget extends StatelessWidget {
  const _SalesRegRowWidget({required this.row, required this.isLast});
  final _SalesRegRow row;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return _TableRow(
      isLast: isLast,
      children: [
        SizedBox(width: 110, child: Text(row.no, style: DostopText.mono)),
        SizedBox(width: 100, child: Text(row.date, style: DostopText.mono.copyWith(fontSize: 10.5))),
        Expanded(child: Text(row.party, style: DostopText.label.copyWith(fontSize: 12.5))),
        SizedBox(width: 140, child: Text(rs(row.taxable), textAlign: TextAlign.right, style: DostopText.money)),
        SizedBox(width: 130, child: Text(rs(row.gst), textAlign: TextAlign.right,
            style: DostopText.money.copyWith(color: DostopColors.danger))),
        SizedBox(width: 140, child: Text(rs(row.taxable + row.gst), textAlign: TextAlign.right, style: DostopText.money)),
      ],
    );
  }
}

// ===========================================================================
// Party ledger
// ===========================================================================

class _LedgerView extends StatelessWidget {
  const _LedgerView();

  @override
  Widget build(BuildContext context) {
    return _ReportShell(
      title: 'Party Ledger',
      kicker: '${_ledgerRows.length} parties',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: _Card(
          child: Column(
            children: [
              const _TableHead(
                children: [
                  Expanded(child: Text('PARTY', style: DostopText.columnHead)),
                  SizedBox(width: 90, child: Text('TYPE', style: DostopText.columnHead)),
                  SizedBox(width: 160, child: Text('LAST TRANSACTION', style: DostopText.columnHead)),
                  SizedBox(width: 150, child: Text('BALANCE', style: DostopText.columnHead, textAlign: TextAlign.right)),
                ],
              ),
              for (int i = 0; i < _ledgerRows.length; i++) ...[
                _LedgerRowWidget(row: _ledgerRows[i], isLast: i == _ledgerRows.length - 1),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LedgerRowWidget extends StatelessWidget {
  const _LedgerRowWidget({required this.row, required this.isLast});
  final _LedgerRow row;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final isCustomer = row.type == 'customer';
    final Color balColor = row.bal == 0
        ? DostopColors.slate400
        : (row.bal > 0 ? DostopColors.brand : DostopColors.danger);
    final String balText = row.bal == 0
        ? 'Settled'
        : rs(row.bal.abs());

    return _TableRow(
      isLast: isLast,
      children: [
        Expanded(
          child: Text(row.name, style: DostopText.label.copyWith(fontSize: 12.5)),
        ),
        SizedBox(
          width: 90,
          child: DostopPill(
            label: isCustomer ? 'Customer' : 'Supplier',
            fg: isCustomer ? DostopColors.blue : DostopColors.violet,
            bg: isCustomer ? DostopColors.blueWash : DostopColors.violetWash,
          ),
        ),
        SizedBox(
          width: 160,
          child: Text(row.last, style: DostopText.mono.copyWith(fontSize: 10.5)),
        ),
        SizedBox(
          width: 150,
          child: Text(
            balText,
            textAlign: TextAlign.right,
            style: DostopText.money.copyWith(fontSize: 12.5, color: balColor),
          ),
        ),
      ],
    );
  }
}
