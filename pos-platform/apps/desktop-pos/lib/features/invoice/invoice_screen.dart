/// New Invoice screen — translates the Claude-Design React prototype's
/// "isInvoice" section into Flutter, with fully local StatefulWidget state.
///
/// Layout:
///   • LEFT: invoice editor (doc-type tabs, party selector, line table,
///     bill discount, payment state, totals)
///   • RIGHT (togglable): live preview panel (A4 or 58 mm thermal)
///
/// No Riverpod / network — all data is hardcoded from the prototype.
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
  final formatted = abs.toStringAsFixed(2).replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+\.)'),
        (m) => '${m[1]},',
      );
  return 'Rs $formatted';
}

// ---------------------------------------------------------------------------
// Static mock data (translated from prototype)
// ---------------------------------------------------------------------------

class _DocType {
  const _DocType({
    required this.k,
    required this.label,
    required this.prefix,
    required this.badge,
    required this.badgeBg,
    required this.badgeFg,
    required this.cta,
    required this.docNo,
  });
  final String k;
  final String label;
  final String prefix;
  final String badge;
  final Color badgeBg;
  final Color badgeFg;
  final String cta;
  final String docNo;
}

const _kDocTypes = <_DocType>[
  _DocType(
    k: 'invoice',
    label: 'Tax invoice',
    prefix: 'INV',
    badge: 'INVOICE',
    badgeBg: Color(0xFFDCFCE7),
    badgeFg: Color(0xFF15803D),
    cta: 'Save & print',
    docNo: 'INV-1185',
  ),
  _DocType(
    k: 'quote',
    label: 'Quotation',
    prefix: 'QT',
    badge: 'ESTIMATE',
    badgeBg: Color(0xFFE0E7FF),
    badgeFg: Color(0xFF4338CA),
    cta: 'Save & send',
    docNo: 'QT-0042',
  ),
  _DocType(
    k: 'challan',
    label: 'Delivery challan',
    prefix: 'DC',
    badge: 'CHALLAN',
    badgeBg: Color(0xFFFEF3C7),
    badgeFg: Color(0xFFB45309),
    cta: 'Save & print',
    docNo: 'DC-0042',
  ),
  _DocType(
    k: 'creditnote',
    label: 'Credit note',
    prefix: 'CN',
    badge: 'CREDIT NOTE',
    badgeBg: Color(0xFFFEE2E2),
    badgeFg: Color(0xFFB91C1C),
    cta: 'Issue credit',
    docNo: 'CN-0042',
  ),
  _DocType(
    k: 'debitnote',
    label: 'Debit note',
    prefix: 'DN',
    badge: 'DEBIT NOTE',
    badgeBg: Color(0xFFF3E8FF),
    badgeFg: Color(0xFF7C3AED),
    cta: 'Issue debit',
    docNo: 'DN-0042',
  ),
];

class _Party {
  const _Party({
    required this.id,
    required this.name,
    required this.addr,
    required this.gstin,
    required this.state,
  });
  final String id;
  final String name;
  final String addr;
  final String gstin;
  final String state;
}

const _kParties = <_Party>[
  _Party(
    id: 'p1',
    name: 'Nimali Perera',
    addr: '22 Sri Sangaraja Mawatha, Colombo 10',
    gstin: '—',
    state: 'Colombo',
  ),
  _Party(
    id: 'p2',
    name: 'Jayasinghe Stores',
    addr: '8 Dalada Veediya, Kandy 20000',
    gstin: '114455667-7000',
    state: 'Kandy',
  ),
  _Party(
    id: 'p3',
    name: 'Dinesh Fernando',
    addr: '112 Havelock Road, Colombo 05',
    gstin: '—',
    state: 'Colombo',
  ),
  _Party(
    id: 'p4',
    name: 'Sunil Bandara',
    addr: '5 Station Road, Ja-Ela, Gampaha',
    gstin: '—',
    state: 'Gampaha',
  ),
  _Party(
    id: 'p5',
    name: 'Chamari Silva',
    addr: '31 Nawala Road, Rajagiriya',
    gstin: '—',
    state: 'Colombo',
  ),
];

class _CatalogItem {
  const _CatalogItem({
    required this.id,
    required this.name,
    required this.sku,
    required this.price,
    required this.unit,
    required this.tax,
    required this.hsn,
  });
  final int id;
  final String name;
  final String sku;
  final double price;
  final String unit;
  final int tax; // % VAT
  final String hsn;
}

const _kCatalog = <_CatalogItem>[
  _CatalogItem(id: 6, name: 'Samba rice (5kg)', sku: 'RICE-SAM5', price: 1450, unit: 'kg', tax: 0, hsn: '1006'),
  _CatalogItem(id: 4, name: 'Highland fresh milk (1L)', sku: 'MILK-HL1', price: 480, unit: 'L', tax: 0, hsn: '0401'),
  _CatalogItem(id: 3, name: 'Eggs (dozen)', sku: 'EGGS-DZ', price: 780, unit: 'dozen', tax: 0, hsn: '0403'),
  _CatalogItem(id: 1, name: 'Ambul banana (1kg)', sku: 'BAN-AMB1', price: 320, unit: 'kg', tax: 0, hsn: '0713'),
  _CatalogItem(id: 2, name: 'Sliced bread (450g)', sku: 'BREAD-450', price: 180, unit: 'pc', tax: 0, hsn: '1905'),
  _CatalogItem(id: 5, name: 'Coconut oil (1L)', sku: 'COIL-1L', price: 1180, unit: 'L', tax: 18, hsn: '0902'),
  _CatalogItem(id: 7, name: 'White sugar (1kg)', sku: 'SUGAR-1KG', price: 295, unit: 'kg', tax: 0, hsn: '1512'),
  _CatalogItem(id: 8, name: 'Mysoor dhal (1kg)', sku: 'DHAL-MYS', price: 685, unit: 'kg', tax: 0, hsn: '3401'),
  _CatalogItem(id: 9, name: 'Lanka Salt (1kg)', sku: 'SALT-1KG', price: 120, unit: 'kg', tax: 18, hsn: '2106'),
  _CatalogItem(id: 10, name: 'Astra margarine (250g)', sku: 'ASTRA-250', price: 520, unit: 'pc', tax: 18, hsn: '0805'),
  _CatalogItem(id: 11, name: 'Buffalo curd (350ml)', sku: 'CURD-350', price: 340, unit: 'pc', tax: 0, hsn: '1704'),
  _CatalogItem(id: 12, name: 'Coconut (each)', sku: 'COCO-EA', price: 145, unit: 'pc', tax: 0, hsn: '3402'),
  _CatalogItem(id: 13, name: 'Red onion (1kg)', sku: 'ONION-RED', price: 480, unit: 'kg', tax: 0, hsn: '0713'),
  _CatalogItem(id: 14, name: 'Tomato (1kg)', sku: 'TOMATO-1KG', price: 390, unit: 'kg', tax: 0, hsn: '0713'),
  _CatalogItem(id: 16, name: 'Cream Soda (1.5L)', sku: 'EH-CS15', price: 420, unit: 'pc', tax: 18, hsn: '2202'),
  _CatalogItem(id: 17, name: 'Ceylon tea BOPF (400g)', sku: 'TEA-400', price: 1250, unit: 'pc', tax: 18, hsn: '0902'),
  _CatalogItem(id: 18, name: 'Maliban Gold Marie (400g)', sku: 'MAL-GM400', price: 465, unit: 'pc', tax: 18, hsn: '1905'),
  _CatalogItem(id: 19, name: 'Prima noodles (5 pack)', sku: 'PRIMA-5', price: 590, unit: 'pack', tax: 18, hsn: '1902'),
  _CatalogItem(id: 20, name: 'Sunlight powder (1kg)', sku: 'SUN-1KG', price: 1090, unit: 'kg', tax: 18, hsn: '3402'),
  _CatalogItem(id: 21, name: 'Signal toothpaste (140g)', sku: 'SIG-140', price: 520, unit: 'pc', tax: 18, hsn: '3306'),
  _CatalogItem(id: 22, name: 'Lifebuoy soap (4x100g)', sku: 'LIFE-4', price: 680, unit: 'pack', tax: 18, hsn: '3401'),
  _CatalogItem(id: 23, name: 'Prima atta (5kg)', sku: 'ATTA-5KG', price: 1580, unit: 'kg', tax: 0, hsn: '1101'),
];

const _kBiz = (
  name: 'Greenleaf Mart · Colombo 03',
  gstin: '134567890-7000',
  addr: '42 Galle Road, Colombo 03',
  phone: '+94 11 234 5678',
);

// Prototype QR seed (5×5 grid)
const _kQrSeed = [1,0,1,1,0, 0,1,1,0,1, 1,1,0,1,0, 0,1,0,1,1, 1,0,1,0,1];

// ---------------------------------------------------------------------------
// Line state
// ---------------------------------------------------------------------------

class _InvLine {
  _InvLine({required this.id, required this.qty, required this.disc});
  final int id;
  int qty;
  int disc; // line discount %
}

// ---------------------------------------------------------------------------
// Computed line (derived from _InvLine + catalog)
// ---------------------------------------------------------------------------

class _ComputedLine {
  const _ComputedLine({
    required this.id,
    required this.name,
    required this.sku,
    required this.hsn,
    required this.unit,
    required this.qty,
    required this.rate,
    required this.disc,
    required this.tax,
    required this.net,
    required this.taxable,
    required this.taxAmt,
  });
  final int id;
  final String name;
  final String sku;
  final String hsn;
  final String unit;
  final int qty;
  final double rate;
  final int disc;
  final int tax;
  final double net;
  final double taxable;
  final double taxAmt;

  String get rateFmt => rs(rate);
  String get rateNum => rate.toStringAsFixed(2);
  String get amtFmt => rs(net);
  String get amtNum => net.toStringAsFixed(2);
  String get taxAmtNum => taxAmt.toStringAsFixed(2);
}

// ---------------------------------------------------------------------------
// Totals
// ---------------------------------------------------------------------------

class _TotalRow {
  const _TotalRow({
    required this.label,
    required this.value,
    required this.color,
    this.strong = false,
  });
  final String label;
  final String value;
  final Color color;
  final bool strong;
}

// ---------------------------------------------------------------------------
// Public widget
// ---------------------------------------------------------------------------

class InvoiceScreen extends StatefulWidget {
  const InvoiceScreen({super.key});

  @override
  State<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends State<InvoiceScreen> {
  // ---- persistent state ----
  String _docTypeK = 'invoice';
  String _partyId = 'p2';
  String _invSearch = '';
  String _payState = 'Unpaid'; // Paid | Partial | Unpaid
  int _billDisc = 0; // %
  bool _showPreview = true;
  bool _isA4 = true;
  bool _saved = false;

  final List<_InvLine> _lines = [
    _InvLine(id: 6, qty: 2, disc: 0),
    _InvLine(id: 1, qty: 3, disc: 5),
    _InvLine(id: 8, qty: 4, disc: 0),
  ];

  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ---- helpers ----
  _DocType get _docType => _kDocTypes.firstWhere((d) => d.k == _docTypeK);
  _Party get _party => _kParties.firstWhere((p) => p.id == _partyId);
  bool get _buyerReg => _party.gstin != '—' && _party.gstin.isNotEmpty;
  String get _taxMode =>
      _buyerReg ? 'VAT-registered buyer' : 'Non-registered buyer';

  _CatalogItem? _catalogById(int id) {
    try {
      return _kCatalog.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  List<_ComputedLine> get _computed {
    final result = <_ComputedLine>[];
    for (final l in _lines) {
      final p = _catalogById(l.id);
      if (p == null) continue;
      final gross = p.price * l.qty;
      final net = gross * (1 - l.disc / 100);
      final taxable = p.tax > 0 ? net / (1 + p.tax / 100) : net;
      final taxAmt = net - taxable;
      result.add(_ComputedLine(
        id: l.id,
        name: p.name,
        sku: p.sku,
        hsn: p.hsn,
        unit: p.unit,
        qty: l.qty,
        rate: p.price,
        disc: l.disc,
        tax: p.tax,
        net: net,
        taxable: taxable,
        taxAmt: taxAmt,
      ));
    }
    return result;
  }

  ({
    List<_TotalRow> rows,
    double grand,
    String grandFmt,
    String grandWords,
  }) get _totals {
    final lines = _computed;
    final invSub = lines.fold(0.0, (a, l) => a + l.taxable);
    final billDiscAmt = invSub * (_billDisc / 100);
    final invTaxable = invSub - billDiscAmt;
    final invTax =
        lines.fold(0.0, (a, l) => a + l.taxAmt) * (1 - _billDisc / 100);
    final sscl = invTaxable * 0.025;
    final preRound = invTaxable + invTax + sscl;
    final grand = preRound.roundToDouble();
    final invRound = grand - preRound;

    final rows = <_TotalRow>[
      _TotalRow(
        label: 'Taxable value',
        value: rs(invTaxable),
        color: DostopColors.slate600,
      ),
    ];
    if (_billDisc > 0) {
      rows.add(_TotalRow(
        label: 'Bill discount ($_billDisc%)',
        value: '− ${rs(billDiscAmt)}',
        color: DostopColors.danger,
        strong: true,
      ));
    }
    rows.add(_TotalRow(
      label: 'VAT (18%)',
      value: rs(invTax),
      color: DostopColors.slate600,
    ));
    rows.add(_TotalRow(
      label: 'SSCL (2.5%)',
      value: rs(sscl),
      color: DostopColors.slate600,
    ));
    rows.add(_TotalRow(
      label: 'Round off',
      value: '${invRound >= 0 ? '+ ' : '− '}${rs(invRound.abs())}',
      color: DostopColors.slate400,
    ));

    return (
      rows: rows,
      grand: grand,
      grandFmt: rs(grand),
      grandWords: _inWords(grand),
    );
  }

  List<_CatalogItem> get _suggestions {
    final q = _invSearch.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return _kCatalog
        .where((c) =>
            c.name.toLowerCase().contains(q) ||
            c.sku.toLowerCase().contains(q))
        .take(5)
        .toList();
  }

  // ---- mutations ----
  void _addLine(int id) {
    setState(() {
      final existing = _lines.where((l) => l.id == id).toList();
      if (existing.isNotEmpty) {
        existing.first.qty++;
      } else {
        _lines.add(_InvLine(id: id, qty: 1, disc: 0));
      }
      _invSearch = '';
      _searchCtrl.clear();
    });
  }

  void _incQty(int id) {
    setState(() {
      for (final l in _lines) {
        if (l.id == id) l.qty++;
      }
    });
  }

  void _decQty(int id) {
    setState(() {
      for (final l in _lines) {
        if (l.id == id && l.qty > 1) l.qty--;
      }
    });
  }

  void _setDisc(int id, int disc) {
    setState(() {
      for (final l in _lines) {
        if (l.id == id) l.disc = disc;
      }
    });
  }

  void _removeLine(int id) {
    setState(() => _lines.removeWhere((l) => l.id == id));
  }

  void _save() {
    setState(() => _saved = true);
    Future.delayed(const Duration(milliseconds: 1800),
        () => mounted ? setState(() => _saved = false) : null);
  }

  // ---- words helper ----
  String _inWords(double n) {
    // simplified for prototype fidelity
    final lakh = (n / 100000).floor();
    final rem = n % 100000;
    final thou = (rem / 1000).floor();
    final buf = StringBuffer();
    if (lakh > 0) buf.write('${_wordify(lakh)} lakh ');
    if (thou > 0) buf.write('${_wordify(thou)} thousand ');
    final rest = rem % 1000;
    if (rest >= 1) buf.write(_wordify(rest.floor()));
    return '${buf.toString().trim()} Rupees only';
  }

  static const _ones = [
    '', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine',
    'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen',
    'Seventeen', 'Eighteen', 'Nineteen'
  ];
  static const _tens = [
    '', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'
  ];

  String _wordify(int n) {
    if (n == 0) return '';
    if (n < 20) return _ones[n];
    if (n < 100) {
      return '${_tens[n ~/ 10]}${n % 10 > 0 ? ' ${_ones[n % 10]}' : ''}';
    }
    return '${_ones[n ~/ 100]} Hundred${n % 100 > 0 ? ' ${_wordify(n % 100)}' : ''}';
  }

  // ---- pay state color ----
  Color _payStateFg(String s) => switch (s) {
        'Paid' => const Color(0xFF16A34A),
        'Partial' => const Color(0xFFF59E0B),
        _ => const Color(0xFFEF4444),
      };

  // ---- build ----

  @override
  Widget build(BuildContext context) {
    final dt = _docType;
    final totals = _totals;

    return Scaffold(
      backgroundColor: DostopColors.canvas,
      body: Column(
        children: [
          _buildHeader(dt, totals),
          Expanded(child: _buildBody(dt, totals)),
        ],
      ),
    );
  }

  // ---- Header ----

  Widget _buildHeader(_DocType dt, dynamic totals) {
    return DostopScreenHeader(
      title: 'New Invoice',
      subtitle: '${dt.docNo} · 15 Jun 2026 · $_taxMode',
      actions: [
        _OutlineBtn(
          label: _showPreview ? 'Hide preview' : 'Show preview',
          onTap: () => setState(() => _showPreview = !_showPreview),
        ),
        const SizedBox(width: 8),
        _OutlineBtn(
          label: 'Save draft',
          onTap: () {},
        ),
        const SizedBox(width: 8),
        _GreenBtn(
          label: _saved ? 'Saved ✓' : dt.cta,
          onTap: _save,
        ),
        const SizedBox(width: 6),
      ],
    );
  }

  // ---- Body: two columns ----

  Widget _buildBody(_DocType dt, dynamic totals) {
    const editorMin = 620.0;
    const previewW = 400.0;
    const minTotal = editorMin + previewW;

    return LayoutBuilder(builder: (context, c) {
      final canFit = c.maxWidth >= minTotal || !_showPreview;
      final editor = _buildEditor(dt, totals);
      final preview = _showPreview ? _buildPreview(totals) : null;

      if (canFit) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: editor),
            if (preview != null)
              SizedBox(width: previewW, child: preview),
          ],
        );
      }

      // Narrow: horizontal scroll
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: minTotal,
          height: c.maxHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: editorMin, child: editor),
              if (preview != null)
                SizedBox(width: previewW, child: preview),
            ],
          ),
        ),
      );
    });
  }

  // ---- Editor panel ----

  Widget _buildEditor(_DocType dt, dynamic totals) {
    return Column(
      children: [
        _buildDocTabs(dt),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTopCards(),
                const SizedBox(height: 16),
                _buildLineTable(dt),
                const SizedBox(height: 16),
                _buildBottomSection(totals),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Doc-type tabs
  Widget _buildDocTabs(_DocType dt) {
    return Container(
      height: 46,
      decoration: const BoxDecoration(
        color: DostopColors.panel,
        border: Border(bottom: BorderSide(color: DostopColors.hairline)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: _kDocTypes.map((d) {
            final sel = d.k == _docTypeK;
            return InkWell(
              onTap: () => setState(() => _docTypeK = d.k),
              child: Container(
                height: 46,
                padding: const EdgeInsets.symmetric(horizontal: 13),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: sel ? DostopColors.brand : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                ),
                child: Center(
                  child: Text(
                    d.label,
                    style: TextStyle(
                      fontFamily: DostopFonts.sans,
                      fontSize: 13,
                      fontWeight:
                          sel ? FontWeight.w800 : FontWeight.w600,
                      color:
                          sel ? DostopColors.ink : DostopColors.slate500,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // Top cards: Bill To, Add Item, Payment Status
  Widget _buildTopCards() {
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: [
        _buildBillToCard(),
        _buildAddItemCard(),
        _buildPayStateCard(),
      ],
    );
  }

  Widget _buildBillToCard() {
    final party = _party;
    return _Card(
      label: 'Bill to',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: DostopColors.panel,
              border: Border.all(color: DostopColors.slate300),
              borderRadius: BorderRadius.circular(DostopRadius.control),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _partyId,
                isExpanded: true,
                style: const TextStyle(
                  fontFamily: DostopFonts.sans,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: DostopColors.ink,
                ),
                onChanged: (v) {
                  if (v != null) setState(() => _partyId = v);
                },
                items: _kParties
                    .map((p) => DropdownMenuItem(
                          value: p.id,
                          child: Text(p.name),
                        ))
                    .toList(),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            party.addr,
            style: const TextStyle(
              fontFamily: DostopFonts.sans,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: DostopColors.slate400,
              height: 1.55,
            ),
          ),
          Text(
            'VAT ${party.gstin} · ${party.state}',
            style: const TextStyle(
              fontFamily: DostopFonts.mono,
              fontSize: 11,
              color: DostopColors.slate400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddItemCard() {
    final sugg = _suggestions;
    return _Card(
      label: 'Add item',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _searchCtrl,
            style: const TextStyle(
              fontFamily: DostopFonts.sans,
              fontSize: 13,
              color: DostopColors.ink,
            ),
            decoration: const InputDecoration(
              hintText: 'Scan barcode or type item name…',
              prefixIcon: Icon(Icons.view_week_outlined,
                  size: 16, color: DostopColors.slate400),
            ),
            onChanged: (v) => setState(() => _invSearch = v),
            onSubmitted: (_) {
              if (sugg.isNotEmpty) _addLine(sugg.first.id);
            },
          ),
          if (sugg.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 150),
              decoration: BoxDecoration(
                border: Border.all(color: DostopColors.hairline),
                borderRadius: BorderRadius.circular(DostopRadius.control),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: sugg.length,
                itemBuilder: (_, i) {
                  final c = sugg[i];
                  return InkWell(
                    onTap: () => _addLine(c.id),
                    hoverColor: DostopColors.brandWash,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 11, vertical: 9),
                      decoration: const BoxDecoration(
                        border: Border(
                            bottom: BorderSide(color: Color(0xFFF4F6F9))),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(c.name,
                                    style: const TextStyle(
                                      fontFamily: DostopFonts.sans,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: DostopColors.ink,
                                    )),
                                Text(
                                  '${c.sku} · ${c.tax}% VAT',
                                  style: const TextStyle(
                                    fontFamily: DostopFonts.mono,
                                    fontSize: 10.5,
                                    color: DostopColors.slate400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            rs(c.price),
                            style: const TextStyle(
                              fontFamily: DostopFonts.sans,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: DostopColors.brand,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 9),
          const Text(
            'Press Enter to add the first match.',
            style: TextStyle(
              fontFamily: DostopFonts.sans,
              fontSize: 11.5,
              color: DostopColors.slate400,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPayStateCard() {
    return _Card(
      label: 'Payment status',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: ['Paid', 'Partial', 'Unpaid'].map((s) {
              final sel = s == _payState;
              final fg = _payStateFg(s);
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: InkWell(
                    borderRadius:
                        BorderRadius.circular(DostopRadius.button),
                    onTap: () => setState(() => _payState = s),
                    child: Container(
                      height: 36,
                      decoration: BoxDecoration(
                        color: sel ? fg : DostopColors.panel,
                        border: Border.all(
                          color: sel ? fg : DostopColors.slate300,
                        ),
                        borderRadius:
                            BorderRadius.circular(DostopRadius.button),
                      ),
                      child: Center(
                        child: Text(
                          s,
                          style: TextStyle(
                            fontFamily: DostopFonts.sans,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: sel ? Colors.white : DostopColors.slate600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: DostopColors.slate50,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Row(
              children: [
                // QR mock
                Container(
                  width: 52,
                  height: 52,
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: DostopColors.panel,
                    border: Border.all(color: DostopColors.slate200),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 5, mainAxisSpacing: 1.5, crossAxisSpacing: 1.5),
                    itemCount: 25,
                    itemBuilder: (_, i) => Container(
                      decoration: BoxDecoration(
                        color: _kQrSeed[i] == 1
                            ? DostopColors.ink
                            : DostopColors.panel,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 11),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('LankaQR ready',
                          style: TextStyle(
                            fontFamily: DostopFonts.sans,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: DostopColors.ink,
                          )),
                      Text(
                        'greenleaf@commercial',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: DostopFonts.mono,
                          fontSize: 10.5,
                          color: DostopColors.slate400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Line item table
  Widget _buildLineTable(_DocType dt) {
    final lines = _computed;
    return Container(
      decoration: BoxDecoration(
        color: DostopColors.panel,
        border: Border.all(color: DostopColors.hairline),
        borderRadius: BorderRadius.circular(DostopRadius.card),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0D0F172A),
              blurRadius: 3,
              offset: Offset(0, 1))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(DostopRadius.card),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: 840,
            child: Column(
              children: [
                _lineTableHeader(),
                if (lines.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                    child: Center(
                      child: Column(
                        children: [
                          Text(
                            'No items on this ${dt.label.toLowerCase()} yet',
                            style: DostopText.h1.copyWith(
                                fontSize: 14, color: DostopColors.slate600),
                          ),
                          const SizedBox(height: 5),
                          const Text(
                            'Scan a barcode or search above to add the first line.',
                            style: TextStyle(
                              fontFamily: DostopFonts.sans,
                              fontSize: 12.5,
                              color: DostopColors.slate400,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...lines.map((l) => _lineRow(l)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _lineTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: DostopColors.slate50,
        border: Border(bottom: BorderSide(color: DostopColors.hairline)),
      ),
      child: const Row(children: [
        Expanded(flex: 2, child: Text('ITEM', style: DostopText.columnHead)),
        SizedBox(width: 90, child: Center(child: Text('QTY', style: DostopText.columnHead))),
        SizedBox(width: 90, child: Align(alignment: Alignment.centerRight, child: Text('RATE', style: DostopText.columnHead))),
        SizedBox(width: 110, child: Align(alignment: Alignment.centerRight, child: Text('DISC %', style: DostopText.columnHead))),
        SizedBox(width: 80, child: Center(child: Text('VAT', style: DostopText.columnHead))),
        SizedBox(width: 110, child: Align(alignment: Alignment.centerRight, child: Text('AMOUNT', style: DostopText.columnHead))),
        SizedBox(width: 34),
      ]),
    );
  }

  Widget _lineRow(_ComputedLine l) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF4F6F9))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.name,
                    overflow: TextOverflow.ellipsis,
                    style: DostopText.itemName),
                Text('HS ${l.hsn} · ${l.unit}',
                    style: const TextStyle(
                      fontFamily: DostopFonts.mono,
                      fontSize: 10.5,
                      color: DostopColors.slate400,
                    )),
              ],
            ),
          ),
          // Qty stepper
          SizedBox(
            width: 90,
            child: Center(
              child: _QtyStepper(
                qty: l.qty,
                onDec: () => _decQty(l.id),
                onInc: () => _incQty(l.id),
              ),
            ),
          ),
          // Rate
          SizedBox(
            width: 90,
            child: Text(
              l.rateFmt,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontFamily: DostopFonts.sans,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: DostopColors.slate600,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          // Disc %
          SizedBox(
            width: 110,
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 4,
              children: [0, 5, 10].map((d) {
                final sel = l.disc == d;
                return InkWell(
                  onTap: () => _setDisc(l.id, d),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    width: 30,
                    height: 24,
                    decoration: BoxDecoration(
                      color: sel ? DostopColors.brand : DostopColors.panel,
                      border: Border.all(
                        color: sel ? DostopColors.brand : DostopColors.slate200,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text(
                        d == 0 ? '—' : '$d',
                        style: TextStyle(
                          fontFamily: DostopFonts.sans,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: sel ? Colors.white : DostopColors.slate600,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          // VAT badge
          SizedBox(
            width: 80,
            child: Center(
              child: Container(
                height: 21,
                padding: const EdgeInsets.symmetric(horizontal: 7),
                decoration: BoxDecoration(
                  color: DostopColors.slate100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(
                    '${l.tax}%',
                    style: const TextStyle(
                      fontFamily: DostopFonts.sans,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: DostopColors.slate600,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Amount
          SizedBox(
            width: 110,
            child: Text(
              l.amtFmt,
              textAlign: TextAlign.right,
              style: DostopText.money,
            ),
          ),
          // Remove
          SizedBox(
            width: 34,
            child: IconButton(
              tooltip: 'Remove line',
              onPressed: () => _removeLine(l.id),
              iconSize: 14,
              visualDensity: VisualDensity.compact,
              color: DostopColors.slate300,
              icon: const Icon(Icons.close),
            ),
          ),
        ],
      ),
    );
  }

  // Bottom: notes+bill disc (left) + totals (right)
  Widget _buildBottomSection(
      ({List<_TotalRow> rows, double grand, String grandFmt, String grandWords}) totals) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildNotesCard()),
        const SizedBox(width: 16),
        SizedBox(width: 340, child: _buildTotalsCard(totals)),
      ],
    );
  }

  Widget _buildNotesCard() {
    return _Card(
      label: 'Notes / terms',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            maxLines: 3,
            style: const TextStyle(
              fontFamily: DostopFonts.sans,
              fontSize: 12.5,
              color: DostopColors.slate600,
              height: 1.6,
            ),
            decoration: InputDecoration(
              hintText:
                  'Goods once sold will not be taken back. Payment due within the agreed credit period.',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(DostopRadius.control),
                borderSide: const BorderSide(color: DostopColors.slate300),
              ),
              contentPadding: const EdgeInsets.all(11),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('Bill discount',
                  style: TextStyle(
                    fontFamily: DostopFonts.sans,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: DostopColors.slate600,
                  )),
              ...[0, 2, 5, 10].map((d) {
                final sel = _billDisc == d;
                return InkWell(
                  onTap: () => setState(() => _billDisc = d),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    height: 30,
                    padding: const EdgeInsets.symmetric(horizontal: 11),
                    decoration: BoxDecoration(
                      color: sel ? DostopColors.ink : DostopColors.panel,
                      border: Border.all(
                        color: sel ? DostopColors.ink : DostopColors.slate200,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        d == 0 ? 'None' : '$d%',
                        style: TextStyle(
                          fontFamily: DostopFonts.sans,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: sel ? Colors.white : DostopColors.slate600,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTotalsCard(
      ({List<_TotalRow> rows, double grand, String grandFmt, String grandWords}) totals) {
    return Container(
      padding: const EdgeInsets.fromLTRB(17, 17, 18, 17),
      decoration: BoxDecoration(
        color: DostopColors.panel,
        border: Border.all(color: DostopColors.hairline),
        borderRadius: BorderRadius.circular(DostopRadius.card),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0D0F172A),
              blurRadius: 3,
              offset: Offset(0, 1))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...totals.rows.map((row) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(row.label,
                        style: TextStyle(
                          fontFamily: DostopFonts.sans,
                          fontSize: 12.5,
                          fontWeight:
                              row.strong ? FontWeight.w700 : FontWeight.w600,
                          color: row.color,
                        )),
                    Text(row.value,
                        style: TextStyle(
                          fontFamily: DostopFonts.sans,
                          fontSize: 12.5,
                          fontWeight:
                              row.strong ? FontWeight.w700 : FontWeight.w600,
                          color: row.color,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        )),
                  ],
                ),
              )),
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(vertical: 10),
            color: DostopColors.hairline,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              const Text('Total',
                  style: TextStyle(
                    fontFamily: DostopFonts.sans,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: DostopColors.ink,
                  )),
              Text(
                totals.grandFmt,
                style: const TextStyle(
                  fontFamily: DostopFonts.sans,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                  color: DostopColors.brand,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            totals.grandWords,
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

  // ---- Preview panel ----

  Widget _buildPreview(
      ({List<_TotalRow> rows, double grand, String grandFmt, String grandWords}) totals) {
    return Container(
      decoration: const BoxDecoration(
        color: DostopColors.slate50,
        border: Border(left: BorderSide(color: DostopColors.hairline)),
      ),
      child: Column(
        children: [
          _buildPreviewToggle(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: _isA4 ? _buildA4Preview(totals) : _buildThermalPreview(totals),
              ),
            ),
          ),
          _buildPreviewActions(),
        ],
      ),
    );
  }

  Widget _buildPreviewToggle() {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: const BoxDecoration(
        color: DostopColors.panel,
        border: Border(bottom: BorderSide(color: DostopColors.hairline)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 36,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: DostopColors.slate100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  _toggleBtn('A4 invoice', _isA4,
                      () => setState(() => _isA4 = true)),
                  _toggleBtn('58mm slip', !_isA4,
                      () => setState(() => _isA4 = false)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _toggleBtn(String label, bool active, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(7),
        child: Container(
          decoration: BoxDecoration(
            color: active ? DostopColors.panel : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            boxShadow: active
                ? const [
                    BoxShadow(
                        color: Color(0x1F0F172A),
                        blurRadius: 3,
                        offset: Offset(0, 1))
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: DostopFonts.sans,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: active ? DostopColors.ink : DostopColors.slate500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildA4Preview(
      ({List<_TotalRow> rows, double grand, String grandFmt, String grandWords}) totals) {
    final dt = _docType;
    final party = _party;
    final lines = _computed;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: DostopColors.panel,
        border: Border.all(color: DostopColors.slate200),
        borderRadius: BorderRadius.circular(6),
        boxShadow: const [
          BoxShadow(
              color: Color(0x140F172A),
              blurRadius: 18,
              offset: Offset(0, 4))
        ],
      ),
      child: DefaultTextStyle(
        style: const TextStyle(
          fontFamily: DostopFonts.sans,
          fontSize: 9.5,
          color: DostopColors.ink,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Biz header
            Container(
              padding: const EdgeInsets.only(bottom: 12),
              decoration: const BoxDecoration(
                border: Border(
                    bottom: BorderSide(color: DostopColors.brand, width: 2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_kBiz.name,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                        const SizedBox(height: 3),
                        Text(
                          '${_kBiz.addr}\nVAT ${_kBiz.gstin} · ${_kBiz.phone}',
                          style: const TextStyle(
                              color: DostopColors.slate500, height: 1.6),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(dt.badge,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: DostopColors.brand,
                          )),
                      const SizedBox(height: 3),
                      Text(
                        '${dt.docNo}\n15 Jun 2026',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontFamily: DostopFonts.mono,
                          color: DostopColors.slate500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Bill to / District
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: DostopColors.slate200)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('BILL TO',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 8.5,
                              letterSpacing: 0.4,
                              color: DostopColors.slate400,
                            )),
                        const SizedBox(height: 3),
                        Text(party.name,
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text(
                          '${party.addr}\nVAT ${party.gstin}',
                          style: const TextStyle(
                              color: DostopColors.slate500, height: 1.6),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('DISTRICT',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 8.5,
                            letterSpacing: 0.4,
                            color: DostopColors.slate400,
                          )),
                      const SizedBox(height: 3),
                      Text(party.state),
                      Text(_taxMode,
                          style: const TextStyle(color: DostopColors.slate500)),
                    ],
                  ),
                ],
              ),
            ),
            // Line header
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(
                      flex: 18,
                      child: Text('ITEM / HS',
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 8.5,
                              letterSpacing: 0.3,
                              color: DostopColors.slate400))),
                  SizedBox(
                      width: 40,
                      child: Text('QTY',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 8.5,
                              letterSpacing: 0.3,
                              color: DostopColors.slate400))),
                  SizedBox(
                      width: 55,
                      child: Text('RATE',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 8.5,
                              letterSpacing: 0.3,
                              color: DostopColors.slate400))),
                  SizedBox(
                      width: 55,
                      child: Text('VAT',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 8.5,
                              letterSpacing: 0.3,
                              color: DostopColors.slate400))),
                  SizedBox(
                      width: 60,
                      child: Text('AMOUNT',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 8.5,
                              letterSpacing: 0.3,
                              color: DostopColors.slate400))),
                ],
              ),
            ),
            const Divider(height: 1, color: DostopColors.slate200),
            // Lines
            ...lines.map((l) => Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: const BoxDecoration(
                    border: Border(
                        bottom: BorderSide(color: DostopColors.slate100)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(
                          flex: 18,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                              Text(l.hsn,
                                  style: const TextStyle(
                                    fontFamily: DostopFonts.mono,
                                    fontSize: 8.5,
                                    color: DostopColors.slate400,
                                  )),
                            ],
                          )),
                      SizedBox(
                          width: 40,
                          child: Text('${l.qty}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontFeatures: [
                                    FontFeature.tabularFigures()
                                  ]))),
                      SizedBox(
                          width: 55,
                          child: Text(l.rateNum,
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                  fontFeatures: [
                                    FontFeature.tabularFigures()
                                  ]))),
                      SizedBox(
                          width: 55,
                          child: Text(l.taxAmtNum,
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                  fontFeatures: [
                                    FontFeature.tabularFigures()
                                  ]))),
                      SizedBox(
                          width: 60,
                          child: Text(l.amtNum,
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ))),
                    ],
                  ),
                )),
            // Totals block (right-aligned 190px)
            Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: 190,
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    ...totals.rows.map((r) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2.5),
                          child: Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text(r.label,
                                  style: const TextStyle(
                                      color: DostopColors.slate600)),
                              Text(r.value,
                                  style: const TextStyle(
                                    fontFeatures: [
                                      FontFeature.tabularFigures()
                                    ],
                                  )),
                            ],
                          ),
                        )),
                    Container(
                      margin: const EdgeInsets.only(top: 5),
                      padding: const EdgeInsets.only(top: 7),
                      decoration: const BoxDecoration(
                        border: Border(
                            top: BorderSide(
                                color: DostopColors.ink, width: 1.5)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800)),
                          Text(totals.grandFmt,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                fontFeatures: [FontFeature.tabularFigures()],
                              )),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.only(top: 10),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: DostopColors.slate200)),
              ),
              child: Text(
                '${totals.grandWords}\nGoods once sold will not be taken back.',
                style: const TextStyle(
                    color: DostopColors.slate500, height: 1.6),
              ),
            ),
            const SizedBox(height: 22),
            const Align(
              alignment: Alignment.centerRight,
              child: Text('Authorised signatory',
                  style: TextStyle(color: DostopColors.slate400)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThermalPreview(
      ({List<_TotalRow> rows, double grand, String grandFmt, String grandWords}) totals) {
    final dt = _docType;
    final party = _party;
    final lines = _computed;

    return Container(
      width: 230,
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      decoration: BoxDecoration(
        color: DostopColors.panel,
        border: Border.all(color: DostopColors.slate200),
        borderRadius: BorderRadius.circular(3),
        boxShadow: const [
          BoxShadow(
              color: Color(0x140F172A),
              blurRadius: 18,
              offset: Offset(0, 4))
        ],
      ),
      child: DefaultTextStyle(
        style: const TextStyle(
          fontFamily: DostopFonts.mono,
          fontSize: 9.5,
          height: 1.65,
          color: DostopColors.ink,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Business header
            Container(
              padding: const EdgeInsets.only(bottom: 8),
              decoration: const BoxDecoration(
                border: Border(
                    bottom: BorderSide(
                        color: DostopColors.slate300,
                        style: BorderStyle.solid)),
              ),
              child: Column(
                children: [
                  Text(_kBiz.name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                  Text(_kBiz.addr,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: DostopColors.slate500)),
                  Text('VAT ${_kBiz.gstin}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: DostopColors.slate500)),
                ],
              ),
            ),
            // Doc info
            Container(
              padding: const EdgeInsets.symmetric(vertical: 7),
              decoration: const BoxDecoration(
                border: Border(
                    bottom: BorderSide(
                        color: DostopColors.slate300)),
              ),
              child: Text(
                '${dt.docNo}\n15 Jun 2026 · Counter 11\n${party.name}',
                style: const TextStyle(color: DostopColors.slate600),
              ),
            ),
            // Lines
            ...lines.map((l) => Container(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  decoration: const BoxDecoration(
                    border: Border(
                        bottom: BorderSide(
                            color: DostopColors.slate100)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(l.name),
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${l.qty} × ${l.rateNum}',
                              style: const TextStyle(
                                  color: DostopColors.slate600)),
                          Text(l.amtNum),
                        ],
                      ),
                    ],
                  ),
                )),
            // Totals
            ...totals.rows.map((r) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(r.label,
                          style: const TextStyle(
                              color: DostopColors.slate600)),
                      Text(r.value),
                    ],
                  ),
                )),
            // Grand total
            Container(
              padding: const EdgeInsets.only(top: 7),
              margin: const EdgeInsets.only(top: 4),
              decoration: const BoxDecoration(
                border: Border(
                    top: BorderSide(
                        color: DostopColors.slate300)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('TOTAL',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700)),
                  Text(totals.grandFmt,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            // Footer
            Container(
              padding: const EdgeInsets.only(top: 8),
              margin: const EdgeInsets.only(top: 4),
              decoration: const BoxDecoration(
                border: Border(
                    top: BorderSide(
                        color: DostopColors.slate300)),
              ),
              child: const Text(
                'Scan to pay · LankaQR\nThank you, visit again!',
                textAlign: TextAlign.center,
                style: TextStyle(color: DostopColors.slate500),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewActions() {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: const BoxDecoration(
        color: DostopColors.panel,
        border: Border(top: BorderSide(color: DostopColors.hairline)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _OutlineBtn(label: 'Print', onTap: () {}),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _OutlineBtn(label: 'PDF', onTap: () {}),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _GreenBtn(label: 'Share', onTap: () {}),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Private helper widgets
// ---------------------------------------------------------------------------

class _Card extends StatelessWidget {
  const _Card({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 260),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
        decoration: BoxDecoration(
          color: DostopColors.panel,
          border: Border.all(color: DostopColors.hairline),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label.toUpperCase(),
              style: DostopText.columnHead.copyWith(
                  letterSpacing: 0.4, color: DostopColors.slate400),
            ),
            const SizedBox(height: 9),
            child,
          ],
        ),
      ),
    );
  }
}

class _OutlineBtn extends StatelessWidget {
  const _OutlineBtn({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(DostopRadius.button),
      hoverColor: DostopColors.slate50,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          color: DostopColors.panel,
          border: Border.all(color: DostopColors.slate200),
          borderRadius: BorderRadius.circular(DostopRadius.button),
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: DostopFonts.sans,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: DostopColors.slate600,
            ),
          ),
        ),
      ),
    );
  }
}

class _GreenBtn extends StatelessWidget {
  const _GreenBtn({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(DostopRadius.button),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        decoration: BoxDecoration(
          color: DostopColors.brand,
          border: Border.all(color: DostopColors.brandDark),
          borderRadius: BorderRadius.circular(DostopRadius.button),
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: DostopFonts.sans,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _QtyStepper extends StatelessWidget {
  const _QtyStepper({
    required this.qty,
    required this.onDec,
    required this.onInc,
  });

  final int qty;
  final VoidCallback onDec;
  final VoidCallback onInc;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: DostopColors.slate100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _stepBtn(Icons.remove, onDec),
          SizedBox(
            width: 24,
            child: Text(
              '$qty',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: DostopFonts.sans,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          _stepBtn(Icons.add, onInc),
        ],
      ),
    );
  }

  Widget _stepBtn(IconData icon, VoidCallback onTap) => InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: DostopColors.panel,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 13, color: DostopColors.slate600),
        ),
      );
}
