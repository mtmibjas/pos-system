/// Purchases screen — purchase bills / POs for the Dostop POS desktop app.
///
/// Translates the "isPurchases" section of the Claude-Design React prototype
/// (/tmp/gl_doc.html lines 1470-1508) into Flutter using the Dostop design
/// system (DostopColors, DostopFonts, DostopRadius, DostopText, DostopPill,
/// DostopScreenHeader).
///
/// All data is hardcoded from BILLS / poFilters / KPI values in /tmp/gl_app.js.
/// No network, no Riverpod — local setState only for the active filter chip.
library;

import 'package:flutter/material.dart';

import '../../ui/theme.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';

// ---------------------------------------------------------------------------
// Money helper
// ---------------------------------------------------------------------------

/// Format a number as Sri Lankan rupees: "Rs 1,42,000.00".
String rs(num n) {
  // Use a simple formatter that inserts commas every 3 digits from the right
  // (en-IN style lakh/crore not required — the prototype uses plain comma sep).
  final parts = n.toStringAsFixed(2).split('.');
  final intPart = parts[0];
  final decPart = parts[1];
  final buf = StringBuffer();
  int count = 0;
  for (int i = intPart.length - 1; i >= 0; i--) {
    if (count > 0 && count % 3 == 0) buf.write(',');
    buf.write(intPart[i]);
    count++;
  }
  final reversed = buf.toString().split('').reversed.join();
  return 'Rs $reversed.$decPart';
}

// ---------------------------------------------------------------------------
// Data model
// ---------------------------------------------------------------------------

class _Bill {
  const _Bill({
    required this.no,
    required this.supplier,
    required this.date,
    required this.due,
    required this.items,
    required this.amount,
    required this.status,
  });

  final String no;
  final String supplier;
  final String date;
  final String due;
  final int items;
  final num amount;
  final String status; // 'Due' | 'Partial' | 'Paid'
}

// Hardcoded from BILLS in /tmp/gl_app.js
const _bills = <_Bill>[
  _Bill(
    no: 'PB-3391',
    supplier: 'Dambulla Fresh Produce',
    date: '15 Jun 2026',
    due: '22 Jun',
    items: 34,
    amount: 142000,
    status: 'Due',
  ),
  _Bill(
    no: 'PB-3390',
    supplier: 'Highland Dairy Dist.',
    date: '15 Jun 2026',
    due: '18 Jun',
    items: 12,
    amount: 63500,
    status: 'Due',
  ),
  _Bill(
    no: 'PB-3384',
    supplier: 'Perera Bakery',
    date: '14 Jun 2026',
    due: 'Paid',
    items: 9,
    amount: 24800,
    status: 'Paid',
  ),
  _Bill(
    no: 'PB-3379',
    supplier: 'Highland Dairy Dist.',
    date: '13 Jun 2026',
    due: 'Paid',
    items: 11,
    amount: 61200,
    status: 'Paid',
  ),
  _Bill(
    no: 'PB-3372',
    supplier: 'CBL Distributors',
    date: '11 Jun 2026',
    due: '26 Jun',
    items: 58,
    amount: 228000,
    status: 'Partial',
  ),
  _Bill(
    no: 'PB-3364',
    supplier: 'Dambulla Fresh Produce',
    date: '8 Jun 2026',
    due: 'Paid',
    items: 29,
    amount: 118000,
    status: 'Paid',
  ),
  _Bill(
    no: 'PB-3350',
    supplier: 'Unilever Sri Lanka',
    date: '6 Jun 2026',
    due: 'Paid',
    items: 41,
    amount: 167500,
    status: 'Paid',
  ),
];

// KPI values from gl_app.js: poTotalFmt, poDueFmt/poDueCount, poWeekFmt
const _poTotal = 805000; // sum of all bills
const _poDue = 433500;   // sum of unpaid bills (Due + Partial)
const _poDueCount = 3;   // count of unpaid bills
const _poWeek = 205500;  // due this week (hardcoded from prototype)
const _poCount = 7;      // total bills

const _filters = <String>['All', 'Due', 'Partial', 'Paid'];

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class PurchasesScreen extends StatefulWidget {
  const PurchasesScreen({super.key});

  @override
  State<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends State<PurchasesScreen> {
  String _activeFilter = 'All';

  List<_Bill> get _filtered => _activeFilter == 'All'
      ? _bills
      : _bills.where((b) => b.status == _activeFilter).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DostopColors.canvas,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DostopScreenHeader(
            title: 'Purchases',
            subtitle:
                'June 2026 · 5 suppliers · Greenleaf Mart Colombo 03',
            actions: [
              _ActionButton(
                label: 'Purchase order',
                onTap: () {},
              ),
              const SizedBox(width: 8),
              _PrimaryButton(
                label: '+ New bill',
                onTap: () {},
              ),
            ],
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _kpiRow(),
                  const SizedBox(height: 18),
                  _filterRow(),
                  const SizedBox(height: 14),
                  _billsTable(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---- KPI row ----------------------------------------------------------------

  Widget _kpiRow() {
    return Row(
      children: [
        Expanded(
          child: _KpiCard(
            label: 'Purchased this month',
            value: rs(_poTotal),
            sub: '$_poCount bills',
            borderColor: DostopColors.slate200,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _KpiCard(
            label: 'Outstanding',
            value: rs(_poDue),
            sub: '$_poDueCount bills unpaid',
            borderColor: const Color(0xFFFECACA),
            valueColor: DostopColors.danger,
            labelColor: const Color(0xFFB91C1C),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _KpiCard(
            label: 'Due this week',
            value: rs(_poWeek),
            sub: 'Highland Dairy, Dambulla Fresh',
            borderColor: const Color(0xFFFDE68A),
            valueColor: const Color(0xFFD97706),
            labelColor: const Color(0xFFB45309),
          ),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: _KpiCard(
            label: 'Open orders',
            value: '3',
            sub: '1 arriving today',
            borderColor: DostopColors.slate200,
          ),
        ),
      ],
    );
  }

  // ---- Filter row -------------------------------------------------------------

  Widget _filterRow() {
    return Row(
      children: [
        for (final f in _filters) ...[
          _FilterChip(
            label: f == 'All' ? 'All bills' : f,
            active: _activeFilter == f,
            onTap: () => setState(() => _activeFilter = f),
          ),
          if (f != _filters.last) const SizedBox(width: 8),
        ],
      ],
    );
  }

  // ---- Bills table ------------------------------------------------------------

  Widget _billsTable() {
    final rows = _filtered;
    return Container(
      decoration: BoxDecoration(
        color: DostopColors.panel,
        border: Border.all(color: const Color(0xFFE8EBEF)),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D0F172A),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: 940,
          child: Column(
            children: [
              _tableHeader(),
              if (rows.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: DostopEmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'No bills match "$_activeFilter"',
                    detail: 'Try a different filter above.',
                  ),
                )
              else
                for (int i = 0; i < rows.length; i++)
                  _BillRow(bill: rows[i], isLast: i == rows.length - 1),
            ],
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
          SizedBox(width: 120, child: Text('BILL NO.', style: DostopText.columnHead)),
          Expanded(
            flex: 3,
            child: Text('SUPPLIER', style: DostopText.columnHead),
          ),
          SizedBox(
            width: 110,
            child: Text('DATE', style: DostopText.columnHead),
          ),
          SizedBox(
            width: 110,
            child: Text('DUE', style: DostopText.columnHead),
          ),
          SizedBox(
            width: 80,
            child: Text('ITEMS', textAlign: TextAlign.center, style: DostopText.columnHead),
          ),
          SizedBox(
            width: 130,
            child: Text('AMOUNT', textAlign: TextAlign.right, style: DostopText.columnHead),
          ),
          SizedBox(
            width: 120,
            child: Text('STATUS', textAlign: TextAlign.center, style: DostopText.columnHead),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Private widgets
// ---------------------------------------------------------------------------

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.sub,
    required this.borderColor,
    this.valueColor,
    this.labelColor,
  });

  final String label;
  final String value;
  final String sub;
  final Color borderColor;
  final Color? valueColor;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DostopColors.panel,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(DostopRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: DostopText.columnHead.copyWith(
              color: labelColor ?? DostopColors.slate400,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontFamily: DostopFonts.sans,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: valueColor ?? DostopColors.ink,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            sub,
            style: DostopText.mono.copyWith(
              fontSize: 11.5,
              color: DostopColors.slate400,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: active ? DostopColors.ink : DostopColors.panel,
          border: Border.all(
            color: active ? DostopColors.ink : DostopColors.slate200,
          ),
          borderRadius: BorderRadius.circular(9),
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
}

class _BillRow extends StatefulWidget {
  const _BillRow({required this.bill, required this.isLast});

  final _Bill bill;
  final bool isLast;

  @override
  State<_BillRow> createState() => _BillRowState();
}

class _BillRowState extends State<_BillRow> {
  bool _hovered = false;

  // Derive supplier initials (max 2 uppercase letters)
  String _initials(String name) {
    final words = name
        .replaceAll(RegExp(r'[^A-Za-z ]'), '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .take(2)
        .toList();
    if (words.isEmpty) return '?';
    return words.map((w) => w[0].toUpperCase()).join();
  }

  // Deterministic hue from supplier name (matching prototype hueOf())
  Color _tileFg(String name) {
    int h = 0;
    for (int i = 0; i < name.length; i++) {
      h = (h * 31 + name.codeUnitAt(i)) % 360;
    }
    return HSLColor.fromAHSL(1, h.toDouble(), 0.58, 0.36).toColor();
  }

  Color _tileBg(String name) {
    int h = 0;
    for (int i = 0; i < name.length; i++) {
      h = (h * 31 + name.codeUnitAt(i)) % 360;
    }
    return HSLColor.fromAHSL(1, h.toDouble(), 0.72, 0.95).toColor();
  }

  ({Color fg, Color bg}) _statusTone(String status) => switch (status) {
        'Paid' => (fg: const Color(0xFF15803D), bg: const Color(0xFFF0FDF4)),
        'Partial' => (fg: const Color(0xFFD97706), bg: const Color(0xFFFFFBEB)),
        _ => (fg: DostopColors.danger, bg: const Color(0xFFFEF2F2)),
      };

  Color _dueColor(String status) => switch (status) {
        'Paid' => DostopColors.slate400,
        'Partial' => const Color(0xFFD97706),
        _ => DostopColors.danger,
      };

  @override
  Widget build(BuildContext context) {
    final b = widget.bill;
    final initials = _initials(b.supplier);
    final tileFg = _tileFg(b.supplier);
    final tileBg = _tileBg(b.supplier);
    final tone = _statusTone(b.status);
    final dueColor = _dueColor(b.status);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        decoration: BoxDecoration(
          color: _hovered ? DostopColors.slate50 : DostopColors.panel,
          border: widget.isLast
              ? null
              : const Border(
                  bottom: BorderSide(color: Color(0xFFF4F6F9)),
                ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Row(
          children: [
            // Bill no.
            SizedBox(
              width: 120,
              child: Text(
                b.no,
                style: DostopText.mono.copyWith(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: DostopColors.blue,
                ),
              ),
            ),
            // Supplier
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: tileBg,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      initials,
                      style: TextStyle(
                        fontFamily: DostopFonts.sans,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: tileFg,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      b.supplier,
                      overflow: TextOverflow.ellipsis,
                      style: DostopText.itemName,
                    ),
                  ),
                ],
              ),
            ),
            // Date
            SizedBox(
              width: 110,
              child: Text(
                b.date,
                style: DostopText.label.copyWith(fontSize: 12.5),
              ),
            ),
            // Due
            SizedBox(
              width: 110,
              child: Text(
                b.due,
                style: TextStyle(
                  fontFamily: DostopFonts.sans,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: dueColor,
                ),
              ),
            ),
            // Items
            SizedBox(
              width: 80,
              child: Text(
                '${b.items}',
                textAlign: TextAlign.center,
                style: DostopText.money.copyWith(
                  fontSize: 13,
                  color: DostopColors.slate600,
                ),
              ),
            ),
            // Amount
            SizedBox(
              width: 130,
              child: Text(
                rs(b.amount),
                textAlign: TextAlign.right,
                style: DostopText.money.copyWith(fontSize: 13.5),
              ),
            ),
            // Status
            SizedBox(
              width: 120,
              child: Center(
                child: _StatusPill(label: b.status, fg: tone.fg, bg: tone.bg),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Status pill with a leading dot (matches prototype's inline dot+label span).
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.fg, required this.bg});

  final String label;
  final Color fg;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(DostopRadius.chip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontFamily: DostopFonts.sans,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(DostopRadius.button),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: DostopColors.panel,
          border: Border.all(color: DostopColors.slate200),
          borderRadius: BorderRadius.circular(DostopRadius.button),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(DostopRadius.button),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: DostopColors.blue,
          borderRadius: BorderRadius.circular(DostopRadius.button),
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
