/// Dostop POS — Dashboard screen.
///
/// Translated from the Claude-Design React prototype (isDashboard section in
/// gl_doc.html / renderVals in gl_app.js). All data is hardcoded from the
/// prototype's mock constants; replace with live service calls when real
/// backend slices are wired up.
///
/// Layout:
///   • Greeting + action buttons
///   • KPI card row (auto-wrapping grid)
///   • Two-column body:
///       Left  — Recent transactions list + Sales bar chart (7-day)
///       Right — Low-stock list + Money-position bar rows
library;

import 'package:flutter/material.dart';

import '../../ui/theme.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';

// ---------------------------------------------------------------------------
// Money formatter — mirrors the prototype's `fmt` function
// ---------------------------------------------------------------------------

String rs(num n) {
  // Thousands-separated, 2 decimal places, Sri Lanka locale conventions.
  final abs = n.abs();
  final intPart = abs.truncate();
  final fracPart = ((abs - intPart) * 100).round();
  final frac = fracPart.toString().padLeft(2, '0');

  // Insert comma separators (South Asian: last 3 then groups of 2)
  final raw = intPart.toString();
  if (raw.length <= 3) {
    return 'Rs $raw.$frac';
  }
  final tail = raw.substring(raw.length - 3);
  var head = raw.substring(0, raw.length - 3);
  final buf = StringBuffer();
  int pos = head.length % 2;
  if (pos > 0) buf.write(head.substring(0, pos));
  while (pos < head.length) {
    if (buf.isNotEmpty) buf.write(',');
    buf.write(head.substring(pos, pos + 2));
    pos += 2;
  }
  return 'Rs $buf,$tail.$frac';
}

// ---------------------------------------------------------------------------
// Mock data — sourced directly from gl_app.js renderVals / constants
// ---------------------------------------------------------------------------

// ---- KPI cards ----
// recvTotal = 4280 + 184500 + 2470 = 191250
// payTotal  = 142000 + 63500 + 228000 = 433500
// todaySales = 482500  (prototype constant)
// cashInHand = 264800  (prototype constant)
// lowItems count = items where stock==0 or stock<=8 or stock<=custom low
//   Highland milk (8 ≤ 8 → low), Buffalo curd (6), Sugar (0 → out), Coconut oil
//   (6+stock vs low:8 → low), Lifebuoy soap (16 vs low:12 → ok), Sliced bread (18 vs low:14 → ok)
//   Counting from prototype: lowItems.length shows 4 in the mock (Out: Sugar; Low: milk, curd, coconut oil)
//   prototype lowStockList slice shows: Sugar (Out), Highland milk (Low), Buffalo curd (Low), Coconut oil (Low)

const _kpiTodaySales = 482500.0;
const _kpiCashInHand = 264800.0;
const _kpiRecvTotal = 191250.0; // sum of positive party balances
const _kpiPayTotal = 433500.0; // sum of abs(negative party balances)
const _kpiRecvPartyCount = 3; // Nimali + Jayasinghe + Sunil
const _kpiPaySupplierCount = 3; // Dambulla + Highland + CBL
// _kpiLowCount = 4 (inlined in const _KpiCardData below)

// ---- Transactions (DAY_TXNS) ----
class _TxnData {
  const _TxnData({
    required this.kind,
    required this.title,
    required this.sub,
    required this.amt,
    required this.time,
  });

  final String kind; // 'sale' | 'in' | 'purchase' | 'expense'
  final String title;
  final String sub;
  final double amt;
  final String time;
}

const _transactions = <_TxnData>[
  _TxnData(kind: 'sale', title: 'INV-1184 · Nimali Perera', sub: '7 items · Credit', amt: 4280, time: '1:02 PM'),
  _TxnData(kind: 'sale', title: 'INV-1183 · Walk-in', sub: '3 items · Cash', amt: 1620, time: '12:54 PM'),
  _TxnData(kind: 'sale', title: 'INV-1182 · Dinesh Fernando', sub: '12 items · Card', amt: 8640.5, time: '12:41 PM'),
  _TxnData(kind: 'in', title: 'Payment received · Jayasinghe Stores', sub: 'Bank transfer', amt: 90000, time: '12:20 PM'),
  _TxnData(kind: 'expense', title: 'CEB electricity', sub: 'Utilities · Cash', amt: 31500, time: '11:10 AM'),
  _TxnData(kind: 'purchase', title: 'PB-3391 · Dambulla Fresh Produce', sub: '34 items · Credit 7d', amt: 142000, time: '7:10 AM'),
];

// ---- Weekly bar chart (WEEK constant) ----
class _WeekBar {
  const _WeekBar({
    required this.day,
    required this.short,
    required this.amt,
    required this.isToday,
  });

  final String day;
  final String short;
  final double amt;
  final bool isToday; // last entry = today (Mon 15)
}

const _weekBars = <_WeekBar>[
  _WeekBar(day: 'Tue', short: '9', amt: 412000, isToday: false),
  _WeekBar(day: 'Wed', short: '10', amt: 386500, isToday: false),
  _WeekBar(day: 'Thu', short: '11', amt: 521000, isToday: false),
  _WeekBar(day: 'Fri', short: '12', amt: 478000, isToday: false),
  _WeekBar(day: 'Sat', short: '13', amt: 684000, isToday: false),
  _WeekBar(day: 'Sun', short: '14', amt: 712500, isToday: false),
  _WeekBar(day: 'Mon', short: '15', amt: 482500, isToday: true),
];

// weekTotal = 412000+386500+521000+478000+684000+712500+482500 = 3676500
const _weekTotal = 3676500.0;

// ---- Low-stock list (lowStockList — up to 5) ----
class _LowStockItem {
  const _LowStockItem({
    required this.name,
    required this.sku,
    required this.qty,
    required this.isOut,
  });

  final String name;
  final String sku;
  final String qty;
  final bool isOut;
}

const _lowStockItems = <_LowStockItem>[
  _LowStockItem(name: 'White sugar (1kg)', sku: 'SUGAR-1KG', qty: 'Out', isOut: true),
  _LowStockItem(name: 'Highland fresh milk (1L)', sku: 'MILK-HL1', qty: '8 L', isOut: false),
  _LowStockItem(name: 'Buffalo curd (350ml)', sku: 'CURD-350', qty: '6 pc', isOut: false),
  _LowStockItem(name: 'Coconut oil (1L)', sku: 'COIL-1L', qty: '6 L', isOut: false),
];

// ---- Money position (moneyRows) ----
// stockValue = sum(cost*stock): 1240*30+412*8+660*60+245*42+142*18+980*24+252*0+575*36+92*90+430*22+275*6+110*40+390*120+305*75+345*48+1040*20+385*64+495*30+905*28+425*33+560*16+1350*12
// = 37200+3296+39600+10290+2556+23520+0+20700+8280+9460+1650+4400+46800+22875+16560+20800+24640+14850+25340+14025+8960+16200 = 371802
// mmax = max(191250, 433500, 264800, 371802) = 433500

class _MoneyRow {
  const _MoneyRow({
    required this.label,
    required this.amt,
    required this.pct,
    required this.color,
  });

  final String label;
  final double amt;
  final int pct; // 0-100
  final Color color;
}

const _moneyRows = <_MoneyRow>[
  _MoneyRow(label: 'Receivables', amt: _kpiRecvTotal, pct: 44, color: DostopColors.stockOkFg), // 191250/433500≈44%
  _MoneyRow(label: 'Payables', amt: _kpiPayTotal, pct: 100, color: DostopColors.danger),
  _MoneyRow(label: 'Cash in hand', amt: _kpiCashInHand, pct: 61, color: DostopColors.blue), // 264800/433500≈61%
  _MoneyRow(label: 'Stock value (at cost)', amt: 371802, pct: 86, color: DostopColors.violet), // 371802/433500≈86%
];

// ---------------------------------------------------------------------------
// Public widget
// ---------------------------------------------------------------------------

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DostopColors.canvas,
      body: Column(
        children: [
          DostopScreenHeader(
            title: 'Dashboard',
            subtitle: 'Monday, 15 June 2026 · Greenleaf Mart · all data on this device',
            actions: [
              _HeaderButton(label: 'New invoice', primary: false, onTap: () {}),
              const SizedBox(width: 9),
              _HeaderButton(label: 'Open counter', primary: true, onTap: () {}),
              const SizedBox(width: 4),
            ],
          ),
          const Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Greeting row
                  _GreetingRow(),
                  SizedBox(height: 18),
                  // KPI cards
                  _KpiRow(),
                  SizedBox(height: 16),
                  // Two-column body
                  _BodyGrid(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Greeting row (title + action buttons above KPIs)
// ---------------------------------------------------------------------------

class _GreetingRow extends StatelessWidget {
  const _GreetingRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ayubowan, Ruwan',
                style: DostopText.h1.copyWith(fontSize: 21, letterSpacing: -0.4),
              ),
              const SizedBox(height: 4),
              const Text(
                'Monday, 15 June 2026 · Greenleaf Mart Colombo 03 · all data stored on this device',
                style: DostopText.kicker,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// KPI cards — auto-wrap row
// ---------------------------------------------------------------------------

class _KpiRow extends StatelessWidget {
  const _KpiRow();

  @override
  Widget build(BuildContext context) {
    final cards = <_KpiCardData>[
      _KpiCardData(
        label: "Today's sales",
        value: rs(_kpiTodaySales),
        sub: '64 bills · avg ${rs(_kpiTodaySales / 64)}',
        dot: const Color(0xFF16A34A),
        valueColor: DostopColors.ink,
      ),
      _KpiCardData(
        label: 'Cash in hand',
        value: rs(_kpiCashInHand),
        sub: 'Counter 11 drawer',
        dot: DostopColors.blue,
        valueColor: DostopColors.ink,
      ),
      _KpiCardData(
        label: 'To collect',
        value: rs(_kpiRecvTotal),
        sub: '$_kpiRecvPartyCount parties overdue',
        dot: const Color(0xFFF59E0B),
        valueColor: DostopColors.stockOkFg,
      ),
      _KpiCardData(
        label: 'To pay',
        value: rs(_kpiPayTotal),
        sub: '$_kpiPaySupplierCount supplier bills open',
        dot: const Color(0xFFEF4444),
        valueColor: DostopColors.danger,
      ),
      const _KpiCardData(
        label: 'Low stock',
        value: '4 items',
        sub: 'Reorder before the weekend',
        dot: Color(0xFFF59E0B),
        valueColor: DostopColors.stockLowFg,
      ),
    ];

    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: cards
          .map((c) => ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 200),
                child: IntrinsicWidth(child: _KpiCard(data: c)),
              ))
          .toList(),
    );
  }
}

class _KpiCardData {
  const _KpiCardData({
    required this.label,
    required this.value,
    required this.sub,
    required this.dot,
    required this.valueColor,
  });

  final String label;
  final String value;
  final String sub;
  final Color dot;
  final Color valueColor;
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.data});
  final _KpiCardData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 16),
      decoration: BoxDecoration(
        color: DostopColors.panel,
        border: Border.all(color: const Color(0xFFE8EBEF)),
        borderRadius: BorderRadius.circular(15),
        boxShadow: const [BoxShadow(color: Color(0x0A0F172A), blurRadius: 2, offset: Offset(0, 1))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: data.dot, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(data.label,
                  style: const TextStyle(
                    fontFamily: DostopFonts.sans,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: DostopColors.slate500,
                  )),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            data.value,
            style: TextStyle(
              fontFamily: DostopFonts.sans,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.7,
              color: data.valueColor,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            data.sub,
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
}

// ---------------------------------------------------------------------------
// Body: two-column grid (left ~1.55fr, right ~1fr)
// ---------------------------------------------------------------------------

class _BodyGrid extends StatelessWidget {
  const _BodyGrid();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const minLeft = 360.0;
        const minRight = 260.0;
        const minTotal = minLeft + minRight + 16;
        if (constraints.maxWidth >= minTotal) {
          // Wide: two columns
          final leftW = constraints.maxWidth * (1.55 / 2.55);
          final rightW = constraints.maxWidth - leftW - 16;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: leftW, child: const _LeftColumn()),
              const SizedBox(width: 16),
              SizedBox(width: rightW, child: const _RightColumn()),
            ],
          );
        }
        // Narrow: stack vertically
        return const Column(
          children: [
            _LeftColumn(),
            SizedBox(height: 16),
            _RightColumn(),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Left column: recent transactions + weekly bar chart
// ---------------------------------------------------------------------------

class _LeftColumn extends StatelessWidget {
  const _LeftColumn();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _TxnCard(),
        SizedBox(height: 16),
        _WeekChartCard(),
      ],
    );
  }
}

class _TxnCard extends StatelessWidget {
  const _TxnCard();

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      headerTitle: 'Recent transactions',
      headerAction: _SecondaryButton(label: 'Day book', onTap: () {}),
      child: Column(
        children: _transactions
            .map((t) => _TxnRow(txn: t))
            .toList(),
      ),
    );
  }
}

class _TxnRow extends StatelessWidget {
  const _TxnRow({required this.txn});
  final _TxnData txn;

  ({Color fg, Color bg, String glyph}) get _style {
    switch (txn.kind) {
      case 'sale':
        return (fg: DostopColors.stockOkFg, bg: DostopColors.stockOkBg, glyph: '↓');
      case 'in':
        return (fg: DostopColors.stockOkFg, bg: DostopColors.stockOkBg, glyph: '↓');
      case 'purchase':
        return (fg: DostopColors.danger, bg: DostopColors.stockOutBg, glyph: '↑');
      case 'expense':
        return (fg: DostopColors.stockLowFg, bg: DostopColors.stockLowBg, glyph: '↑');
      default:
        return (fg: DostopColors.slate500, bg: DostopColors.slate100, glyph: '·');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _style;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF6F8FA))),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: s.bg,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Center(
              child: Text(
                s.glyph,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: s.fg,
                ),
              ),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  txn.title,
                  overflow: TextOverflow.ellipsis,
                  style: DostopText.itemName.copyWith(fontSize: 13),
                ),
                Text(
                  txn.sub,
                  style: DostopText.kicker,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                rs(txn.amt),
                style: TextStyle(
                  fontFamily: DostopFonts.sans,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: s.fg,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                txn.time,
                style: const TextStyle(
                  fontFamily: DostopFonts.sans,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: DostopColors.slate400,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeekChartCard extends StatelessWidget {
  const _WeekChartCard();

  @override
  Widget build(BuildContext context) {
    const maxAmt = 712500.0; // max of WEEK
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: DostopColors.panel,
        border: Border.all(color: const Color(0xFFE8EBEF)),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x0D0F172A), blurRadius: 3, offset: Offset(0, 1))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Sales · last 7 days',
                  style: TextStyle(
                    fontFamily: DostopFonts.sans,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: DostopColors.ink,
                  )),
              Text(
                '${rs(_weekTotal)} total',
                style: const TextStyle(
                  fontFamily: DostopFonts.sans,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: DostopColors.slate400,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 150,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: _weekBars.map((w) {
                final heightPct = w.amt / maxAmt;
                final barColor = w.isToday
                    ? const Color(0xFF16A34A)
                    : const Color(0xFFBBF7D0);
                final labelColor = w.isToday
                    ? const Color(0xFF16A34A)
                    : DostopColors.slate400;
                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        w.short,
                        style: const TextStyle(
                          fontFamily: DostopFonts.sans,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: DostopColors.slate400,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Flexible(
                        child: FractionallySizedBox(
                          heightFactor: heightPct,
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              color: barColor,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(8),
                                topRight: Radius.circular(8),
                                bottomLeft: Radius.circular(3),
                                bottomRight: Radius.circular(3),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        w.day,
                        style: TextStyle(
                          fontFamily: DostopFonts.sans,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: labelColor,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Right column: low-stock list + money position
// ---------------------------------------------------------------------------

class _RightColumn extends StatelessWidget {
  const _RightColumn();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _LowStockCard(),
        SizedBox(height: 16),
        _MoneyPositionCard(),
      ],
    );
  }
}

class _LowStockCard extends StatelessWidget {
  const _LowStockCard();

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      headerTitle: 'Low stock',
      headerAction: _SecondaryButton(label: 'Reorder', onTap: () {}),
      child: Column(
        children: _lowStockItems.map((item) => _LowStockRow(item: item)).toList(),
      ),
    );
  }
}

class _LowStockRow extends StatelessWidget {
  const _LowStockRow({required this.item});
  final _LowStockItem item;

  @override
  Widget build(BuildContext context) {
    final fg = item.isOut ? DostopColors.danger : DostopColors.stockLowFg;
    final bg = item.isOut ? DostopColors.stockOutBg : DostopColors.stockLowBg;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF6F8FA))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: DostopFonts.sans,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: DostopColors.ink,
                  ),
                ),
                Text(
                  item.sku,
                  style: DostopText.mono.copyWith(fontSize: 10.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            height: 23,
            padding: const EdgeInsets.symmetric(horizontal: 9),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(7),
            ),
            alignment: Alignment.center,
            child: Text(
              item.qty,
              style: TextStyle(
                fontFamily: DostopFonts.sans,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MoneyPositionCard extends StatelessWidget {
  const _MoneyPositionCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: DostopColors.panel,
        border: Border.all(color: const Color(0xFFE8EBEF)),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x0D0F172A), blurRadius: 3, offset: Offset(0, 1))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Money position',
              style: TextStyle(
                fontFamily: DostopFonts.sans,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: DostopColors.ink,
              )),
          const SizedBox(height: 14),
          ...List.generate(
            _moneyRows.length,
            (i) => Padding(
              padding: EdgeInsets.only(bottom: i < _moneyRows.length - 1 ? 11 : 0),
              child: _MoneyBar(row: _moneyRows[i]),
            ),
          ),
        ],
      ),
    );
  }
}

class _MoneyBar extends StatelessWidget {
  const _MoneyBar({required this.row});
  final _MoneyRow row;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              row.label,
              style: const TextStyle(
                fontFamily: DostopFonts.sans,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: DostopColors.slate600,
              ),
            ),
            Text(
              rs(row.amt),
              style: TextStyle(
                fontFamily: DostopFonts.sans,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: row.color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: SizedBox(
            height: 7,
            child: LinearProgressIndicator(
              value: row.pct / 100,
              backgroundColor: const Color(0xFFEEF1F5),
              valueColor: AlwaysStoppedAnimation<Color>(row.color),
              minHeight: 7,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shared card chrome
// ---------------------------------------------------------------------------

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.headerTitle,
    required this.headerAction,
    required this.child,
  });

  final String headerTitle;
  final Widget headerAction;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: DostopColors.panel,
        border: Border.all(color: const Color(0xFFE8EBEF)),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x0D0F172A), blurRadius: 3, offset: Offset(0, 1))],
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFF1F4F8))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  headerTitle,
                  style: const TextStyle(
                    fontFamily: DostopFonts.sans,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: DostopColors.ink,
                  ),
                ),
                headerAction,
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Small button variants
// ---------------------------------------------------------------------------

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 11),
        decoration: BoxDecoration(
          color: DostopColors.panel,
          border: Border.all(color: DostopColors.slate200),
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: DostopFonts.sans,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: DostopColors.slate600,
          ),
        ),
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.label,
    required this.primary,
    required this.onTap,
  });
  final String label;
  final bool primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: primary ? DostopColors.brand : DostopColors.panel,
          border: Border.all(
            color: primary ? DostopColors.brandDark : DostopColors.slate200,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontFamily: DostopFonts.sans,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: primary ? Colors.white : DostopColors.slate600,
          ),
        ),
      ),
    );
  }
}
