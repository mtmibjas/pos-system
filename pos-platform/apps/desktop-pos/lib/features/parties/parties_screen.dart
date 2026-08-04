/// Parties screen — customers & suppliers with credit ledgers.
///
/// Translates the "Parties" section of the Dostop/Greenleaf Claude-Design
/// React prototype into Flutter. All data is hardcoded (no Riverpod / network).
///
/// Layout:
///   Header (DostopScreenHeader)
///   KPI row  — "To collect" | "To pay" | total parties
///   Tab bar  — Customers / Suppliers
///   Body row — LEFT scrollable party list + search
///              RIGHT selected-party detail panel + ledger
library;

import 'package:flutter/material.dart';

import '../../ui/theme.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';

// ---------------------------------------------------------------------------
// Domain model (local, no network)
// ---------------------------------------------------------------------------

class _LedgerEntry {
  const _LedgerEntry({
    required this.label,
    required this.date,
    required this.amount,
    required this.dir, // 'due' | 'in' | 'out' | 'paid'
  });

  final String label;
  final String date;
  final double amount;
  final String dir;
}

class _Party {
  const _Party({
    required this.id,
    required this.name,
    required this.type, // 'customer' | 'supplier'
    required this.sub,
    required this.phone,
    required this.last,
    required this.bal,
    required this.ledger,
    required this.gstin,
    required this.district,
    required this.address,
    required this.terms,
    required this.creditLimit,
    required this.openingBal,
  });

  final String id;
  final String name;
  final String type;
  final String sub;
  final String phone;
  final String last;
  final double bal;
  final List<_LedgerEntry> ledger;

  // Detail fields
  final String gstin;
  final String district;
  final String address;
  final String terms;
  final double creditLimit; // 0 = no limit
  final double openingBal;

  bool get isCustomer => type == 'customer';
}

// ---------------------------------------------------------------------------
// Hardcoded dataset
// ---------------------------------------------------------------------------

const _kParties = <_Party>[
  _Party(
    id: 'p1',
    name: 'Nimali Perera',
    type: 'customer',
    sub: 'Regular · since 2023',
    phone: '77 412 3344',
    last: 'Today, 1:02 PM',
    bal: 4280,
    gstin: '—',
    district: 'Colombo',
    address: '22 Sri Sangaraja Mawatha, Colombo 10',
    terms: 'On delivery',
    creditLimit: 15000,
    openingBal: 0,
    ledger: [
      _LedgerEntry(label: 'INV-1184 · 7 items', date: 'Today, 1:02 PM', amount: 4280, dir: 'due'),
      _LedgerEntry(label: 'Payment received · LankaQR', date: '12 Jun 2026', amount: 6100, dir: 'in'),
      _LedgerEntry(label: 'INV-1102 · 11 items', date: '12 Jun 2026', amount: 6100, dir: 'due'),
      _LedgerEntry(label: 'Payment received · Cash', date: '4 Jun 2026', amount: 2860, dir: 'in'),
    ],
  ),
  _Party(
    id: 'p2',
    name: 'Jayasinghe Stores',
    type: 'customer',
    sub: 'Wholesale · Kandy · credit 15d',
    phone: '81 222 8910',
    last: 'Today, 12:15 PM',
    bal: 184500,
    gstin: '114455667-7000',
    district: 'Kandy',
    address: '8 Dalada Veediya, Kandy 20000',
    terms: 'Credit 15 days',
    creditLimit: 500000,
    openingBal: 120000,
    ledger: [
      _LedgerEntry(label: 'INV-1180 · 24 items', date: 'Today, 12:15 PM', amount: 58100, dir: 'due'),
      _LedgerEntry(label: 'INV-1166 · 31 items', date: '11 Jun 2026', amount: 126400, dir: 'due'),
      _LedgerEntry(label: 'Payment received · Bank', date: '2 Jun 2026', amount: 90000, dir: 'in'),
    ],
  ),
  _Party(
    id: 'p3',
    name: 'Dinesh Fernando',
    type: 'customer',
    sub: 'Regular',
    phone: '71 903 5578',
    last: 'Today, 12:41 PM',
    bal: 0,
    gstin: '—',
    district: 'Colombo',
    address: '112 Havelock Road, Colombo 05',
    terms: 'On delivery',
    creditLimit: 10000,
    openingBal: 0,
    ledger: [
      _LedgerEntry(label: 'INV-1182 · 12 items', date: 'Today, 12:41 PM', amount: 8640.5, dir: 'due'),
      _LedgerEntry(label: 'Payment received · Card', date: 'Today, 12:41 PM', amount: 8640.5, dir: 'in'),
    ],
  ),
  _Party(
    id: 'p4',
    name: 'Sunil Bandara',
    type: 'customer',
    sub: 'Regular',
    phone: '76 330 1147',
    last: 'Today, 11:46 AM',
    bal: 2470,
    gstin: '—',
    district: 'Gampaha',
    address: '5 Station Road, Ja-Ela, Gampaha',
    terms: 'On delivery',
    creditLimit: 8000,
    openingBal: 0,
    ledger: [
      _LedgerEntry(label: 'INV-1178 · 5 items', date: 'Today, 11:46 AM', amount: 2470, dir: 'due'),
      _LedgerEntry(label: 'Payment received · LankaQR', date: '8 Jun 2026', amount: 3180, dir: 'in'),
    ],
  ),
  _Party(
    id: 'p5',
    name: 'Chamari Silva',
    type: 'customer',
    sub: 'New · joined June',
    phone: '70 611 8840',
    last: '9 Jun 2026',
    bal: 0,
    gstin: '—',
    district: 'Colombo',
    address: '31 Nawala Road, Rajagiriya',
    terms: 'On delivery',
    creditLimit: 8000,
    openingBal: 0,
    ledger: [
      _LedgerEntry(label: 'INV-1120 · 3 items', date: '9 Jun 2026', amount: 1180, dir: 'due'),
      _LedgerEntry(label: 'Payment received · Cash', date: '9 Jun 2026', amount: 1180, dir: 'in'),
    ],
  ),
  _Party(
    id: 's1',
    name: 'Dambulla Fresh Produce',
    type: 'supplier',
    sub: 'Produce · weekly',
    phone: '66 228 4410',
    last: 'Today, 7:10 AM',
    bal: -142000,
    gstin: '132244556-7000',
    district: 'Matale',
    address: 'Dedicated Economic Centre, Dambulla',
    terms: 'Credit 7 days',
    creditLimit: 0,
    openingBal: -84000,
    ledger: [
      _LedgerEntry(label: 'PB-3391 · Produce crate', date: 'Today, 7:10 AM', amount: 142000, dir: 'out'),
      _LedgerEntry(label: 'Payment sent · Bank', date: '8 Jun 2026', amount: 118000, dir: 'paid'),
      _LedgerEntry(label: 'PB-3364 · Produce crate', date: '8 Jun 2026', amount: 118000, dir: 'out'),
    ],
  ),
  _Party(
    id: 's2',
    name: 'Highland Dairy Dist.',
    type: 'supplier',
    sub: 'Dairy · daily',
    phone: '11 268 1190',
    last: 'Today, 6:40 AM',
    bal: -63500,
    gstin: '118877665-7000',
    district: 'Colombo',
    address: 'Dairy Depot, Peliyagoda',
    terms: 'Credit 3 days',
    creditLimit: 0,
    openingBal: 0,
    ledger: [
      _LedgerEntry(label: 'PB-3390 · Milk & curd', date: 'Today, 6:40 AM', amount: 63500, dir: 'out'),
      _LedgerEntry(label: 'Payment sent · LankaQR', date: '13 Jun 2026', amount: 61200, dir: 'paid'),
    ],
  ),
  _Party(
    id: 's3',
    name: 'Perera Bakery',
    type: 'supplier',
    sub: 'Bakery · alt days',
    phone: '11 274 1007',
    last: '14 Jun 2026',
    bal: 0,
    gstin: '109933441-7000',
    district: 'Colombo',
    address: '12 Bakery Lane, Maradana, Colombo 10',
    terms: 'On delivery',
    creditLimit: 0,
    openingBal: 0,
    ledger: [
      _LedgerEntry(label: 'PB-3384 · Bread & buns', date: '14 Jun 2026', amount: 24800, dir: 'out'),
      _LedgerEntry(label: 'Payment sent · Cash', date: '14 Jun 2026', amount: 24800, dir: 'paid'),
    ],
  ),
  _Party(
    id: 's4',
    name: 'CBL Distributors',
    type: 'supplier',
    sub: 'Snacks & staples',
    phone: '11 240 6332',
    last: '11 Jun 2026',
    bal: -228000,
    gstin: '124466778-7000',
    district: 'Gampaha',
    address: 'CBL Depot, Ranala, Kaduwela',
    terms: 'Credit 30 days',
    creditLimit: 0,
    openingBal: -194000,
    ledger: [
      _LedgerEntry(label: 'PB-3372 · Monthly stock', date: '11 Jun 2026', amount: 228000, dir: 'out'),
      _LedgerEntry(label: 'Payment sent · Bank', date: '1 Jun 2026', amount: 194000, dir: 'paid'),
    ],
  ),
  _Party(
    id: 's5',
    name: 'Unilever Sri Lanka',
    type: 'supplier',
    sub: 'Household & care',
    phone: '11 259 2045',
    last: '6 Jun 2026',
    bal: 0,
    gstin: '127788990-7000',
    district: 'Colombo',
    address: 'Unilever Sri Lanka, Horana Road, Colombo',
    terms: 'Credit 30 days',
    creditLimit: 0,
    openingBal: 0,
    ledger: [
      _LedgerEntry(label: 'PB-3350 · Detergent & soap', date: '6 Jun 2026', amount: 167500, dir: 'out'),
      _LedgerEntry(label: 'Payment sent · Bank', date: '6 Jun 2026', amount: 167500, dir: 'paid'),
    ],
  ),
];

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Formats a number as "Rs X,XXX.XX".
String rs(num n) {
  final abs = n.abs();
  final whole = abs.truncate();
  final frac = ((abs - whole) * 100).round();
  final digits = whole.toString();
  final buf = StringBuffer();
  int rem = digits.length % 3;
  if (rem == 0 && digits.length > 3) rem = 3;
  buf.write(digits.substring(0, rem));
  for (int i = rem; i < digits.length; i += 3) {
    if (i > 0) buf.write(',');
    buf.write(digits.substring(i, i + 3));
  }
  return 'Rs ${buf.toString()}.${frac.toString().padLeft(2, '0')}';
}

/// Deterministic hue from a name string (matches the JS prototype's hueOf).
double _hueOf(String name) {
  int h = 0;
  for (int i = 0; i < name.length; i++) {
    h = (h * 31 + name.codeUnitAt(i)) % 360;
  }
  return h.toDouble();
}

/// Avatar initials (up to 2 words, first letters, uppercase).
String _initials(String name) {
  final words = name.replaceAll(RegExp(r'[^A-Za-z ]'), '').trim().split(RegExp(r'\s+'));
  return words.take(2).map((w) => w.isEmpty ? '' : w[0].toUpperCase()).join();
}

/// Foreground / background colours for an avatar tile.
({Color fg, Color bg}) _avatarTone(String name) {
  final h = _hueOf(name);
  return (
    fg: HSLColor.fromAHSL(1, h, 0.58, 0.36).toColor(),
    bg: HSLColor.fromAHSL(1, h, 0.72, 0.95).toColor(),
  );
}

// ---------------------------------------------------------------------------
// Public widget
// ---------------------------------------------------------------------------

class PartiesScreen extends StatefulWidget {
  const PartiesScreen({super.key});

  @override
  State<PartiesScreen> createState() => _PartiesScreenState();
}

class _PartiesScreenState extends State<PartiesScreen> {
  String _tab = 'customer'; // 'customer' | 'supplier'
  String _query = '';
  String _selectedId = 'p1';

  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<_Party> get _visibleParties {
    final q = _query.trim().toLowerCase();
    return _kParties.where((p) {
      if (p.type != _tab) return false;
      if (q.isEmpty) return true;
      final phone = p.phone.replaceAll(' ', '');
      final qPhone = q.replaceAll(' ', '');
      return p.name.toLowerCase().contains(q) || phone.contains(qPhone);
    }).toList();
  }

  _Party get _selectedParty {
    return _kParties.firstWhere(
      (p) => p.id == _selectedId,
      orElse: () => _kParties.firstWhere((p) => p.type == _tab, orElse: () => _kParties.first),
    );
  }

  double get _toCollect =>
      _kParties.where((p) => p.bal > 0).fold(0.0, (a, p) => a + p.bal);

  int get _toCollectCount => _kParties.where((p) => p.bal > 0).length;

  double get _toPay =>
      _kParties.where((p) => p.bal < 0).fold(0.0, (a, p) => a + p.bal.abs());

  int get _toPayCount => _kParties.where((p) => p.bal < 0).length;

  void _selectParty(_Party p) => setState(() => _selectedId = p.id);

  void _switchTab(String tab) {
    setState(() {
      _tab = tab;
      final first = _kParties.firstWhere(
        (p) => p.type == tab,
        orElse: () => _kParties.first,
      );
      _selectedId = first.id;
    });
  }

  @override
  Widget build(BuildContext context) {
    final customers = _kParties.where((p) => p.isCustomer).length;
    final suppliers = _kParties.where((p) => !p.isCustomer).length;
    final kicker = _tab == 'customer'
        ? '$customers customers · ledger balances'
        : '$suppliers suppliers · ledger balances';

    return Scaffold(
      backgroundColor: DostopColors.canvas,
      body: Column(
        children: [
          DostopScreenHeader(title: 'Parties', subtitle: kicker),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Keep a usable layout down to ~900 px wide.
                const detailW = 340.0;
                const listMin = 520.0;
                final wide = constraints.maxWidth >= listMin + detailW;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _leftPane(customers, suppliers),
                    ),
                    if (wide) _rightPanel(),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ---- Left pane -----------------------------------------------------------

  Widget _leftPane(int customers, int suppliers) {
    final visible = _visibleParties;
    return Container(
      color: DostopColors.canvas,
      child: Column(
        children: [
          _kpiRow(),
          _tabAndSearch(),
          Expanded(child: _partyList(visible)),
        ],
      ),
    );
  }

  Widget _kpiRow() {
    final total = _kParties.length;
    final customers = _kParties.where((p) => p.isCustomer).length;
    final suppliers = total - customers;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
      child: Row(
        children: [
          Expanded(child: _kpiCard(
            label: 'To collect',
            value: rs(_toCollect),
            sub: '$_toCollectCount customers with dues',
            valueColor: DostopColors.stockOkFg,
          )),
          const SizedBox(width: 14),
          Expanded(child: _kpiCard(
            label: 'To pay',
            value: rs(_toPay),
            sub: '$_toPayCount supplier bills open',
            valueColor: DostopColors.danger,
          )),
          const SizedBox(width: 14),
          Expanded(child: _kpiCard(
            label: 'Parties',
            value: '$total',
            sub: '$customers customers · $suppliers suppliers',
            valueColor: DostopColors.ink,
          )),
        ],
      ),
    );
  }

  Widget _kpiCard({
    required String label,
    required String value,
    required String sub,
    required Color valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DostopColors.panel,
        border: Border.all(color: const Color(0xFFE8EBEF)),
        borderRadius: BorderRadius.circular(DostopRadius.card),
        boxShadow: const [
          BoxShadow(color: Color(0x0A0F172A), blurRadius: 2, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: DostopText.columnHead),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontFamily: DostopFonts.sans,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: valueColor,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 4),
          Text(sub, style: DostopText.mono.copyWith(fontSize: 11)),
        ],
      ),
    );
  }

  Widget _tabAndSearch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 12),
      child: Row(
        children: [
          _tabPill(),
          const SizedBox(width: 10),
          _searchBox(),
        ],
      ),
    );
  }

  Widget _tabPill() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF1F5),
        border: Border.all(color: const Color(0xFFE8EBEF)),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _tabBtn('customer', 'Customers'),
          _tabBtn('supplier', 'Suppliers'),
        ],
      ),
    );
  }

  Widget _tabBtn(String tab, String label) {
    final active = _tab == tab;
    return GestureDetector(
      onTap: () => _switchTab(tab),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        decoration: BoxDecoration(
          color: active ? DostopColors.ink : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontFamily: DostopFonts.sans,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : DostopColors.slate500,
          ),
        ),
      ),
    );
  }

  Widget _searchBox() {
    return SizedBox(
      width: 280,
      child: TextField(
        controller: _searchCtrl,
        style: const TextStyle(
          fontFamily: DostopFonts.sans,
          fontSize: 13,
          color: DostopColors.ink,
        ),
        decoration: const InputDecoration(
          hintText: 'Search name or phone…',
          prefixIcon: Icon(Icons.search, size: 16, color: DostopColors.slate400),
        ),
        onChanged: (v) => setState(() => _query = v),
      ),
    );
  }

  Widget _partyList(List<_Party> parties) {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      decoration: BoxDecoration(
        color: DostopColors.panel,
        border: Border.all(color: const Color(0xFFE8EBEF)),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x0D0F172A), blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _listHeader(),
          Expanded(
            child: parties.isEmpty
                ? _emptyList()
                : ListView.builder(
                    itemCount: parties.length,
                    itemBuilder: (_, i) => _PartyRow(
                      party: parties[i],
                      selected: parties[i].id == _selectedId,
                      onTap: () => _selectParty(parties[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _listHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      decoration: const BoxDecoration(
        color: Color(0xFFFAFBFC),
        border: Border(bottom: BorderSide(color: Color(0xFFEEF1F5))),
      ),
      child: const Row(
        children: [
          Expanded(flex: 2, child: Text('PARTY', style: DostopText.columnHead)),
          SizedBox(width: 120, child: Text('PHONE', style: DostopText.columnHead)),
          Expanded(child: Text('LAST ACTIVITY', style: DostopText.columnHead)),
          SizedBox(
            width: 120,
            child: Text('BALANCE', textAlign: TextAlign.right, style: DostopText.columnHead),
          ),
          SizedBox(
            width: 100,
            child: Text('TYPE', textAlign: TextAlign.center, style: DostopText.columnHead),
          ),
        ],
      ),
    );
  }

  Widget _emptyList() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(44),
        child: Text(
          'No party matches "$_query".',
          style: DostopText.label.copyWith(color: DostopColors.slate400),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  // ---- Right panel ---------------------------------------------------------

  Widget _rightPanel() {
    final p = _selectedParty;
    final tone = _avatarTone(p.name);
    final initials = _initials(p.name);

    final balLabel = p.bal > 0
        ? 'You will receive'
        : (p.bal < 0 ? 'You will pay' : 'Balance settled');
    final balColor = p.bal == 0
        ? DostopColors.ink
        : (p.bal > 0 ? DostopColors.stockOkFg : DostopColors.danger);
    final balBg = p.bal == 0
        ? DostopColors.slate50
        : (p.bal > 0 ? DostopColors.stockOkBg : DostopColors.stockOutBg);

    final limitPct = (p.creditLimit > 0)
        ? (p.bal.clamp(0, p.creditLimit) / p.creditLimit * 100).round()
        : 0;
    final limitText = p.creditLimit > 0
        ? '${rs(p.bal.clamp(0, double.infinity))} of ${rs(p.creditLimit)}'
        : 'No credit limit set';
    final limitFg = p.creditLimit > 0 && p.bal / p.creditLimit > 0.8
        ? DostopColors.danger
        : DostopColors.stockOkFg;
    final limitBg = p.creditLimit > 0 && p.bal / p.creditLimit > 0.8
        ? DostopColors.stockOutBg
        : DostopColors.slate50;

    final action = p.isCustomer ? 'Record payment' : 'Pay supplier';

    return Container(
      width: 340,
      decoration: const BoxDecoration(
        color: DostopColors.panel,
        border: Border(left: BorderSide(color: Color(0xFFE8EBEF))),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ---- Header card ----
            Container(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFF1F4F8))),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      _Avatar(initials: initials, fg: tone.fg, bg: tone.bg, size: 46),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: DostopFonts.sans,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                                color: DostopColors.ink,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${p.sub} · ${p.phone}',
                              overflow: TextOverflow.ellipsis,
                              style: DostopText.mono.copyWith(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: balBg,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          balLabel.toUpperCase(),
                          style: DostopText.columnHead,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          p.bal == 0 ? rs(0) : rs(p.bal.abs()),
                          style: TextStyle(
                            fontFamily: DostopFonts.sans,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: balColor,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _ActionButton(label: action, primary: true),
                      ),
                      const SizedBox(width: 8),
                      const _ActionButton(
                        label: '',
                        primary: false,
                        icon: Icons.phone_outlined,
                        fixedWidth: 38,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ---- Party details ----
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFF1F4F8))),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('PARTY DETAILS', style: DostopText.columnHead),
                  const SizedBox(height: 12),
                  _detailField('Party name', p.name, mono: false),
                  _detailField('Phone', '+94 ${p.phone}', mono: true),
                  _detailField('VAT registration no.', p.gstin, mono: true),
                  _detailField('District', p.district, mono: false),
                  _detailField('Billing address', p.address, mono: false),
                  _detailField('Opening balance', rs(p.openingBal.abs()), mono: true),
                  _detailField(
                    'Credit limit',
                    p.creditLimit > 0 ? rs(p.creditLimit) : 'No limit',
                    mono: true,
                  ),
                  _detailField('Payment terms', p.terms, mono: false),
                  const SizedBox(height: 12),
                  // Credit usage bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                    decoration: BoxDecoration(
                      color: limitBg,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Credit used',
                              style: DostopText.mono.copyWith(
                                fontSize: 11.5,
                                color: DostopColors.slate600,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              limitText,
                              style: DostopText.mono.copyWith(
                                fontSize: 11.5,
                                color: limitFg,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: limitPct / 100,
                            minHeight: 6,
                            backgroundColor: DostopColors.slate200,
                            valueColor: AlwaysStoppedAnimation<Color>(limitFg),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ---- Recent activity / ledger ----
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('RECENT ACTIVITY', style: DostopText.columnHead),
                  const SizedBox(height: 12),
                  ...p.ledger.map((l) => _LedgerRow(entry: l)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailField(String label, String value, {required bool mono}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: DostopText.columnHead.copyWith(letterSpacing: 0.3),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            height: 36,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 11),
            decoration: BoxDecoration(
              color: DostopColors.panel,
              border: Border.all(color: DostopColors.slate200),
              borderRadius: BorderRadius.circular(DostopRadius.control),
            ),
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: mono ? DostopFonts.mono : DostopFonts.sans,
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

// ---------------------------------------------------------------------------
// Party list row
// ---------------------------------------------------------------------------

class _PartyRow extends StatelessWidget {
  const _PartyRow({
    required this.party,
    required this.selected,
    required this.onTap,
  });

  final _Party party;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tone = _avatarTone(party.name);
    final initials = _initials(party.name);

    final balFmt = party.bal == 0 ? 'Settled' : rs(party.bal.abs());
    final balColor = party.bal == 0
        ? DostopColors.slate400
        : (party.bal > 0 ? DostopColors.stockOkFg : DostopColors.danger);

    final typeBg = party.isCustomer ? DostopColors.blueWash : DostopColors.violetWash;
    final typeFg = party.isCustomer ? DostopColors.blue : DostopColors.violet;
    final typeLabel = party.isCustomer ? 'Customer' : 'Supplier';

    return InkWell(
      onTap: onTap,
      hoverColor: DostopColors.slate50,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF5F9FF) : Colors.transparent,
          border: const Border(bottom: BorderSide(color: Color(0xFFF4F6F9))),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: DostopColors.blue,
                    blurRadius: 0,
                    spreadRadius: 0,
                    offset: Offset(-3, 0),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  _Avatar(initials: initials, fg: tone.fg, bg: tone.bg, size: 36),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          party.name,
                          overflow: TextOverflow.ellipsis,
                          style: DostopText.itemName.copyWith(fontSize: 13),
                        ),
                        Text(
                          party.sub,
                          overflow: TextOverflow.ellipsis,
                          style: DostopText.mono.copyWith(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 120,
              child: Text(
                party.phone,
                overflow: TextOverflow.ellipsis,
                style: DostopText.mono.copyWith(fontSize: 12),
              ),
            ),
            Expanded(
              child: Text(
                party.last,
                overflow: TextOverflow.ellipsis,
                style: DostopText.label.copyWith(fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
            ),
            SizedBox(
              width: 120,
              child: Text(
                balFmt,
                textAlign: TextAlign.right,
                style: DostopText.money.copyWith(fontSize: 13.5, color: balColor),
              ),
            ),
            SizedBox(
              width: 100,
              child: Center(
                child: DostopPill(label: typeLabel, fg: typeFg, bg: typeBg),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Ledger row
// ---------------------------------------------------------------------------

class _LedgerRow extends StatelessWidget {
  const _LedgerRow({required this.entry});

  final _LedgerEntry entry;

  @override
  Widget build(BuildContext context) {
    final isIn = entry.dir == 'in';
    final isPaid = entry.dir == 'paid';
    final isOut = entry.dir == 'out';

    final Color fg;
    final Color bg;
    final String glyph;

    if (isIn) {
      fg = DostopColors.stockOkFg;
      bg = DostopColors.stockOkBg;
      glyph = '↓';
    } else if (isPaid) {
      fg = DostopColors.blue;
      bg = DostopColors.blueWash;
      glyph = '↓';
    } else if (isOut) {
      fg = DostopColors.danger;
      bg = DostopColors.stockOutBg;
      glyph = '↑';
    } else {
      // due
      fg = DostopColors.danger;
      bg = DostopColors.stockOutBg;
      glyph = '↑';
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF4F6F9))),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(9),
            ),
            alignment: Alignment.center,
            child: Text(
              glyph,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: fg,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: DostopFonts.sans,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: DostopColors.ink,
                  ),
                ),
                Text(
                  entry.date,
                  style: DostopText.mono.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            rs(entry.amount),
            style: DostopText.money.copyWith(fontSize: 13, color: fg),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Avatar circle
// ---------------------------------------------------------------------------

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.initials,
    required this.fg,
    required this.bg,
    required this.size,
  });

  final String initials;
  final Color fg;
  final Color bg;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(size * 0.27),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          fontFamily: DostopFonts.sans,
          fontSize: size * 0.29,
          fontWeight: FontWeight.w800,
          color: fg,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Action button
// ---------------------------------------------------------------------------

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.primary,
    this.icon,
    this.fixedWidth,
  });

  final String label;
  final bool primary;
  final IconData? icon;
  final double? fixedWidth;

  @override
  Widget build(BuildContext context) {
    Widget child = icon != null
        ? Icon(icon, size: 16, color: primary ? Colors.white : DostopColors.slate500)
        : Text(
            label,
            style: const TextStyle(
              fontFamily: DostopFonts.sans,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          );

    final decoration = BoxDecoration(
      color: primary ? DostopColors.blue : DostopColors.panel,
      border: Border.all(
        color: primary ? const Color(0xFF1D4ED8) : DostopColors.slate200,
      ),
      borderRadius: BorderRadius.circular(DostopRadius.button),
    );

    return GestureDetector(
      onTap: () {},
      child: Container(
        width: fixedWidth,
        height: 38,
        decoration: decoration,
        alignment: Alignment.center,
        child: child,
      ),
    );
  }
}
