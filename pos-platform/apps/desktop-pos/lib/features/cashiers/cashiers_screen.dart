/// Cashiers & counter management screen — Dostop POS.
///
/// Shows the shift-state for each staff member (avatar, name, role, counter,
/// today's sales + bill count) with a local toggle for on/off-shift, plus a
/// "Today by counter" bar-chart panel.
///
/// Data is hardcoded from the Greenleaf prototype (gl_app.js CASHIERS /
/// counterTotals). No network calls, no Riverpod — local StatefulWidget only.
library;

import 'package:flutter/material.dart';

import '../../ui/tokens.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';

// ---------------------------------------------------------------------------
// Data models (plain Dart — no codegen, no network)
// ---------------------------------------------------------------------------

class _Cashier {
  const _Cashier({
    required this.id,
    required this.name,
    required this.role,
    required this.counter,
    required this.salesToday,
    required this.bills,
    required this.shift,
  });

  final String id;
  final String name;
  final String role;
  final String counter;
  final int salesToday;
  final int bills;
  final String shift;
}

class _Counter {
  const _Counter({
    required this.name,
    required this.amount,
    required this.color,
  });

  final String name;
  final int amount;
  final Color color;
}

// ---------------------------------------------------------------------------
// Hardcoded seed data (from gl_app.js CASHIERS + counterTotals)
// ---------------------------------------------------------------------------

const _kCashiers = <_Cashier>[
  _Cashier(
    id: 'c1',
    name: 'Ruwan Jayawardena',
    role: 'Owner',
    counter: 'Counter 11',
    salesToday: 184200,
    bills: 24,
    shift: '09:00 – 21:00',
  ),
  _Cashier(
    id: 'c2',
    name: 'Dilani Wickrama',
    role: 'Cashier',
    counter: 'Counter 12',
    salesToday: 149800,
    bills: 21,
    shift: '09:00 – 17:00',
  ),
  _Cashier(
    id: 'c3',
    name: 'Kasun Silva',
    role: 'Cashier',
    counter: 'Counter 13',
    salesToday: 93500,
    bills: 14,
    shift: '13:00 – 21:00',
  ),
  _Cashier(
    id: 'c4',
    name: 'Fathima Rizwan',
    role: 'Cashier',
    counter: 'Counter 12',
    salesToday: 55000,
    bills: 5,
    shift: '17:00 – 21:00',
  ),
  _Cashier(
    id: 'c5',
    name: 'Vimukthi Perera',
    role: 'Supervisor',
    counter: 'Floor',
    salesToday: 0,
    bills: 0,
    shift: 'Off today',
  ),
];

const _kCounters = <_Counter>[
  _Counter(name: 'Counter 11', amount: 184200, color: DostopColors.blue),
  _Counter(name: 'Counter 12', amount: 204800, color: DostopColors.brand),
  _Counter(name: 'Counter 13', amount: 93500, color: DostopColors.violet),
];

// Off-shift by default: only c5 starts off-shift (matches prototype state).
const _kDefaultOffShift = {'c5'};

// ---------------------------------------------------------------------------
// Public widget
// ---------------------------------------------------------------------------

class CashiersScreen extends StatefulWidget {
  const CashiersScreen({super.key});

  @override
  State<CashiersScreen> createState() => _CashiersScreenState();
}

class _CashiersScreenState extends State<CashiersScreen> {
  /// Tracks which cashier IDs are currently off-shift.
  final Set<String> _offShift = Set.from(_kDefaultOffShift);

  void _toggleShift(String id) {
    setState(() {
      if (_offShift.contains(id)) {
        _offShift.remove(id);
      } else {
        _offShift.add(id);
      }
    });
  }

  bool _isOnShift(String id) => !_offShift.contains(id);

  int get _onShiftCount =>
      _kCashiers.where((c) => _isOnShift(c.id)).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DostopColors.canvas,
      body: Column(
        children: [
          DostopScreenHeader(
            title: 'Cashiers',
            subtitle:
                '$_onShiftCount on shift now · ${_kCashiers.length} staff · ${_kCounters.length} counters',
            actions: [
              _HeaderButton(
                label: 'Shift report',
                onTap: () {},
              ),
              const SizedBox(width: 9),
              _HeaderButton(
                label: '+ Add cashier',
                filled: true,
                onTap: () {},
              ),
            ],
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _CashierGrid(
                      cashiers: _kCashiers,
                      isOnShift: _isOnShift,
                      onToggle: _toggleShift,
                    ),
                    const SizedBox(height: 22),
                    const _CounterPanel(counters: _kCounters),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header action button
// ---------------------------------------------------------------------------

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: filled
          ? FilledButton(
              onPressed: onTap,
              style: FilledButton.styleFrom(
                backgroundColor: DostopColors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(DostopRadius.button),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                textStyle: const TextStyle(
                  fontFamily: DostopFonts.sans,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: Text(label),
            )
          : OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                foregroundColor: DostopColors.slate600,
                side: const BorderSide(color: DostopColors.slate200),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(DostopRadius.button),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                textStyle: const TextStyle(
                  fontFamily: DostopFonts.sans,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: Text(label),
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Cashier grid
// ---------------------------------------------------------------------------

class _CashierGrid extends StatelessWidget {
  const _CashierGrid({
    required this.cashiers,
    required this.isOnShift,
    required this.onToggle,
  });

  final List<_Cashier> cashiers;
  final bool Function(String id) isOnShift;
  final void Function(String id) onToggle;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive: 1 col below 500px, 2 cols up to 820px, 3+ above.
        final w = constraints.maxWidth;
        final crossCount = w < 500
            ? 1
            : w < 820
                ? 2
                : 3;
        const cardAspect = 1.35;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossCount,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: cardAspect,
          ),
          itemCount: cashiers.length,
          itemBuilder: (_, i) {
            final c = cashiers[i];
            return _CashierCard(
              cashier: c,
              onShift: isOnShift(c.id),
              onToggle: () => onToggle(c.id),
            );
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Cashier card
// ---------------------------------------------------------------------------

// Avatar palette: cycles through a small set of brand-consistent tones.
const _kAvatarPalettes = <(Color, Color)>[
  (Color(0xFFECFDF5), Color(0xFF16A34A)), // green wash
  (Color(0xFFEFF6FF), Color(0xFF2563EB)), // blue wash
  (Color(0xFFF5F3FF), Color(0xFF7C3AED)), // violet wash
  (Color(0xFFFFFBEB), Color(0xFFD97706)), // amber wash
  (Color(0xFFFEF2F2), Color(0xFFDC2626)), // red wash
];

(Color, Color) _avatarTone(int index) =>
    _kAvatarPalettes[index % _kAvatarPalettes.length];

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
  return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
}

String _fmtSales(int amount) {
  // Format as "Rs 184,200" using simple comma grouping.
  final s = amount.toString();
  final buf = StringBuffer('Rs ');
  final len = s.length;
  for (var i = 0; i < len; i++) {
    if (i > 0 && (len - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

class _CashierCard extends StatelessWidget {
  const _CashierCard({
    required this.cashier,
    required this.onShift,
    required this.onToggle,
  });

  final _Cashier cashier;
  final bool onShift;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final idx = _kCashiers.indexOf(cashier);
    final tone = _avatarTone(idx);
    final bg = tone.$1;
    final fg = tone.$2;
    final dotColor = onShift ? DostopColors.brand : DostopColors.slate300;
    final switchBg = onShift ? DostopColors.brand : DostopColors.slate300;
    final stateBg =
        onShift ? DostopColors.stockOkBg : DostopColors.slate100;
    final stateFg =
        onShift ? DostopColors.brandDark : DostopColors.slate500;
    final stateLabel = onShift ? 'On shift' : 'Off shift';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DostopColors.panel,
        border: Border.all(color: const Color(0xFFE8EBEF)),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x090F172A),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---- Top row: avatar + name + toggle ----
          Row(
            children: [
              // Avatar with status dot
              SizedBox(
                width: 48,
                height: 48,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _initials(cashier.name),
                        style: TextStyle(
                          fontFamily: DostopFonts.sans,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: fg,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 13,
                        height: 13,
                        decoration: BoxDecoration(
                          color: dotColor,
                          shape: BoxShape.circle,
                          border: const Border.fromBorderSide(
                            BorderSide(color: DostopColors.panel, width: 2.5),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Name + role
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cashier.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: DostopFonts.sans,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        color: DostopColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${cashier.role} · ${cashier.counter}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: DostopFonts.sans,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: DostopColors.slate400,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Shift toggle
              GestureDetector(
                onTap: onToggle,
                child: _ShiftToggle(on: onShift, bg: switchBg),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // ---- Stats row ----
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _StatBox(
                    label: 'Sales today',
                    value: _fmtSales(cashier.salesToday),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatBox(
                    label: 'Bills',
                    value: '${cashier.bills}',
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ---- Bottom row: state pill + shift hours ----
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              DostopPill(
                label: stateLabel,
                fg: stateFg,
                bg: stateBg,
              ),
              Text(
                cashier.shift,
                style: const TextStyle(
                  fontFamily: DostopFonts.sans,
                  fontSize: 11.5,
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

// ---------------------------------------------------------------------------
// Toggle switch widget
// ---------------------------------------------------------------------------

class _ShiftToggle extends StatelessWidget {
  const _ShiftToggle({required this.on, required this.bg});

  final bool on;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 44,
      height: 26,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 160),
        alignment: on ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 20,
          height: 20,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Color(0x470F172A),
                blurRadius: 3,
                offset: Offset(0, 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stat box (sales today / bills)
// ---------------------------------------------------------------------------

class _StatBox extends StatelessWidget {
  const _StatBox({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: DostopColors.slate50,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: DostopText.columnHead,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontFamily: DostopFonts.sans,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: DostopColors.ink,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Counter bar-chart panel
// ---------------------------------------------------------------------------

class _CounterPanel extends StatelessWidget {
  const _CounterPanel({required this.counters});

  final List<_Counter> counters;

  @override
  Widget build(BuildContext context) {
    final maxAmt =
        counters.fold(0, (prev, c) => c.amount > prev ? c.amount : prev);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: DostopColors.panel,
        border: Border.all(color: const Color(0xFFE8EBEF)),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x090F172A),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Today by counter',
            style: TextStyle(
              fontFamily: DostopFonts.sans,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: DostopColors.ink,
            ),
          ),
          const SizedBox(height: 16),
          for (final ct in counters) ...[
            _CounterBar(counter: ct, maxAmount: maxAmt),
            if (ct != counters.last) const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

class _CounterBar extends StatelessWidget {
  const _CounterBar({
    required this.counter,
    required this.maxAmount,
  });

  final _Counter counter;
  final int maxAmount;

  @override
  Widget build(BuildContext context) {
    final pct = maxAmount > 0 ? counter.amount / maxAmount : 0.0;
    final amtStr = _fmtSales(counter.amount);

    return Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(
            counter.name,
            style: const TextStyle(
              fontFamily: DostopFonts.sans,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: DostopColors.slate600,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 10,
            decoration: BoxDecoration(
              color: DostopColors.hairline,
              borderRadius: BorderRadius.circular(6),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: pct.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: counter.color,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        SizedBox(
          width: 110,
          child: Text(
            amtStr,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontFamily: DostopFonts.sans,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: DostopColors.ink,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}
