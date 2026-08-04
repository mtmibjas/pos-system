/// Day book — read-only general-ledger journal view for the current day.
///
/// Hardcoded sample data matches the Greenleaf/Dostop prototype
/// (JOURNAL in gl_app.js).  When a real API is wired up the `_kJournal`
/// constant below is replaced with a provider call.
library;

import 'package:flutter/material.dart';

import '../../ui/theme.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';

// ---------------------------------------------------------------------------
// Domain model (hardcoded until API exists)
// ---------------------------------------------------------------------------

class _JLine {
  const _JLine({required this.acc, required this.dr, required this.cr});
  final String acc;
  final double dr;
  final double cr;
}

class _JEntry {
  const _JEntry({
    required this.id,
    required this.time,
    required this.ref,
    required this.type,
    required this.party,
    required this.lines,
  });
  final String id;
  final String time;
  final String ref;
  final String type;
  final String party;
  final List<_JLine> lines;
}

// ---------------------------------------------------------------------------
// Hardcoded data  (gl_app.js → JOURNAL)
// ---------------------------------------------------------------------------

const _kJournal = <_JEntry>[
  _JEntry(
    id: 'j1',
    time: '1:02 PM',
    ref: 'INV-1184',
    type: 'Sale',
    party: 'Nimali Perera',
    lines: [
      _JLine(acc: 'Accounts receivable', dr: 4280, cr: 0),
      _JLine(acc: 'Sales — goods', dr: 0, cr: 4028.24),
      _JLine(acc: 'VAT payable', dr: 0, cr: 251.76),
    ],
  ),
  _JEntry(
    id: 'j2',
    time: '12:54 PM',
    ref: 'INV-1183',
    type: 'Sale',
    party: 'Walk-in',
    lines: [
      _JLine(acc: 'Cash in hand', dr: 1620, cr: 0),
      _JLine(acc: 'Sales — goods', dr: 0, cr: 1520.34),
      _JLine(acc: 'VAT payable', dr: 0, cr: 99.66),
    ],
  ),
  _JEntry(
    id: 'j3',
    time: '12:41 PM',
    ref: 'INV-1182',
    type: 'Sale',
    party: 'Dinesh Fernando',
    lines: [
      _JLine(acc: 'Bank — Commercial Bank current', dr: 8640.5, cr: 0),
      _JLine(acc: 'Sales — goods', dr: 0, cr: 7810.6),
      _JLine(acc: 'VAT payable', dr: 0, cr: 829.9),
    ],
  ),
  _JEntry(
    id: 'j4',
    time: '12:20 PM',
    ref: 'RCPT-441',
    type: 'Receipt',
    party: 'Jayasinghe Stores',
    lines: [
      _JLine(acc: 'Bank — Commercial Bank current', dr: 90000, cr: 0),
      _JLine(acc: 'Accounts receivable', dr: 0, cr: 90000),
    ],
  ),
  _JEntry(
    id: 'j5',
    time: '11:10 AM',
    ref: 'EXP-118',
    type: 'Expense',
    party: 'Ceylon Electricity Board',
    lines: [
      _JLine(acc: 'Utilities', dr: 31500, cr: 0),
      _JLine(acc: 'Cash in hand', dr: 0, cr: 31500),
    ],
  ),
  _JEntry(
    id: 'j6',
    time: '7:10 AM',
    ref: 'PB-3391',
    type: 'Purchase',
    party: 'Dambulla Fresh Produce',
    lines: [
      _JLine(acc: 'Inventory (at cost)', dr: 135238.1, cr: 0),
      _JLine(acc: 'VAT receivable', dr: 6761.9, cr: 0),
      _JLine(acc: 'Accounts payable', dr: 0, cr: 142000),
    ],
  ),
];

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Format a number as "Rs 1,234.56"
String rs(num n) {
  final abs = n.abs();
  // Simple locale-style comma formatting for en-LK style.
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

/// journal type → (bg, fg)
({Color bg, Color fg}) _typeTone(String type) => switch (type) {
      'Sale' => (bg: const Color(0xFFF0FDF4), fg: const Color(0xFF15803D)),
      'Receipt' => (bg: const Color(0xFFEFF6FF), fg: const Color(0xFF1D4ED8)),
      'Expense' => (bg: const Color(0xFFFFFBEB), fg: const Color(0xFFB45309)),
      'Purchase' => (bg: const Color(0xFFFEF2F2), fg: const Color(0xFFDC2626)),
      _ => (bg: DostopColors.slate100, fg: DostopColors.slate600),
    };

double _entryTotal(_JEntry e) => e.lines.fold(0.0, (s, l) => s + l.dr);

double _journalTotalDr() =>
    _kJournal.fold(0.0, (s, e) => s + _entryTotal(e));

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class DaybookScreen extends StatelessWidget {
  const DaybookScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final totalDr = rs(_journalTotalDr());
    return Scaffold(
      backgroundColor: DostopColors.canvas,
      body: Column(
        children: [
          DostopScreenHeader(
            title: 'Day book',
            subtitle:
                'Monday, 15 June 2026 · double-entry balanced · $totalDr posted',
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(24),
              itemCount: _kJournal.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _EntryCard(entry: _kJournal[i]),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Entry card
// ---------------------------------------------------------------------------

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry});
  final _JEntry entry;

  @override
  Widget build(BuildContext context) {
    final tone = _typeTone(entry.type);
    final total = _entryTotal(entry);
    return Container(
      decoration: BoxDecoration(
        color: DostopColors.panel,
        border: Border.all(color: const Color(0xFFE8EBEF)),
        borderRadius: BorderRadius.circular(DostopRadius.card),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: [
          _CardHeader(entry: entry, tone: tone, total: total),
          const _ColumnHeadRow(),
          ...entry.lines.asMap().entries.map(
                (e) => _LineRow(
                  line: e.value,
                  isLast: e.key == entry.lines.length - 1,
                ),
              ),
        ],
      ),
    );
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({
    required this.entry,
    required this.tone,
    required this.total,
  });
  final _JEntry entry;
  final ({Color bg, Color fg}) tone;
  final double total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      decoration: const BoxDecoration(
        color: Color(0xFFFAFBFC),
        border: Border(bottom: BorderSide(color: Color(0xFFF4F6F9))),
      ),
      child: Row(
        children: [
          // Type pill
          Container(
            height: 23,
            padding: const EdgeInsets.symmetric(horizontal: 9),
            decoration: BoxDecoration(
              color: tone.bg,
              borderRadius: BorderRadius.circular(DostopRadius.chip),
            ),
            alignment: Alignment.center,
            child: Text(
              entry.type,
              style: TextStyle(
                fontFamily: DostopFonts.sans,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: tone.fg,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Ref
          Text(
            entry.ref,
            style: DostopText.mono.copyWith(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: DostopColors.ink,
            ),
          ),
          const SizedBox(width: 12),
          // Party
          Expanded(
            child: Text(
              entry.party,
              overflow: TextOverflow.ellipsis,
              style: DostopText.label.copyWith(fontSize: 12.5),
            ),
          ),
          // Time
          Text(
            entry.time,
            style: DostopText.mono.copyWith(
              fontSize: 12,
              color: DostopColors.slate400,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 12),
          // Total
          Text(
            rs(total),
            style: DostopText.money.copyWith(fontSize: 13.5),
          ),
        ],
      ),
    );
  }
}

class _ColumnHeadRow extends StatelessWidget {
  const _ColumnHeadRow();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF4F6F9))),
      ),
      child: const Row(
        children: [
          Expanded(
            child: Text('ACCOUNT', style: DostopText.columnHead),
          ),
          SizedBox(
            width: 130,
            child:
                Text('DEBIT', textAlign: TextAlign.right, style: DostopText.columnHead),
          ),
          SizedBox(
            width: 130,
            child: Text(
              'CREDIT',
              textAlign: TextAlign.right,
              style: DostopText.columnHead,
            ),
          ),
        ],
      ),
    );
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow({required this.line, required this.isLast});
  final _JLine line;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final isCredit = line.cr > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: Color(0xFFF8FAFC))),
      ),
      child: Row(
        children: [
          // Indented account name for credits
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: isCredit ? 22 : 0),
              child: Text(
                line.acc,
                overflow: TextOverflow.ellipsis,
                style: DostopText.label.copyWith(fontSize: 12.5),
              ),
            ),
          ),
          // Debit column
          SizedBox(
            width: 130,
            child: Text(
              line.dr > 0 ? rs(line.dr) : '',
              textAlign: TextAlign.right,
              style: DostopText.mono.copyWith(
                fontSize: 12.5,
                color: DostopColors.ink,
              ),
            ),
          ),
          // Credit column
          SizedBox(
            width: 130,
            child: Text(
              line.cr > 0 ? rs(line.cr) : '',
              textAlign: TextAlign.right,
              style: DostopText.mono.copyWith(
                fontSize: 12.5,
                color: DostopColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
