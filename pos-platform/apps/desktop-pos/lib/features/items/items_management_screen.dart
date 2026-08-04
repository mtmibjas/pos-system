/// Items master — catalog management screen (distinct from item_picker_screen
/// which is the cashier sell screen). Displays the full catalog with category
/// filter chips, search, a per-row stock badge, and a detail panel for the
/// selected item including batch-tracking toggle.
///
/// All data is hardcoded from the Dostop/Greenleaf prototype (gl_app.js). No
/// network calls, no Riverpod — pure StatefulWidget with local setState.
library;

import 'package:flutter/material.dart';

import '../../ui/theme.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';

// ---------------------------------------------------------------------------
// Money helper
// ---------------------------------------------------------------------------

String rs(num n) {
  final formatted = n.toStringAsFixed(2).replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+\.)'),
        (m) => '${m[1]},',
      );
  return 'Rs $formatted';
}

// ---------------------------------------------------------------------------
// Data models
// ---------------------------------------------------------------------------

class _Item {
  const _Item({
    required this.id,
    required this.name,
    required this.sku,
    required this.price,
    required this.cost,
    required this.stock,
    required this.unit,
    required this.category,
    required this.tax,
  });

  final int id;
  final String name;
  final String sku;
  final num price;
  final num cost;
  final int stock;
  final String unit;
  final String category;
  final int tax;
}

class _Meta {
  const _Meta({
    required this.hsn,
    required this.barcode,
    required this.low,
    required this.variants,
  });

  final String hsn;
  final String barcode;
  final int low;
  final String variants;
}

// ---------------------------------------------------------------------------
// Hardcoded catalog data (from gl_app.js CATALOG + ITEM_META)
// ---------------------------------------------------------------------------

const List<_Item> _kCatalog = [
  _Item(id: 6,  name: 'Samba rice (5kg)',          sku: 'RICE-SAM5',  price: 1450, cost: 1240, stock: 30,  unit: 'kg',    category: 'Staples',       tax: 0),
  _Item(id: 4,  name: 'Highland fresh milk (1L)',   sku: 'MILK-HL1',   price: 480,  cost: 412,  stock: 8,   unit: 'L',     category: 'Dairy',         tax: 0),
  _Item(id: 3,  name: 'Eggs (dozen)',               sku: 'EGGS-DZ',    price: 780,  cost: 660,  stock: 60,  unit: 'dozen', category: 'Dairy',         tax: 0),
  _Item(id: 1,  name: 'Ambul banana (1kg)',         sku: 'BAN-AMB1',   price: 320,  cost: 245,  stock: 42,  unit: 'kg',    category: 'Produce',       tax: 0),
  _Item(id: 2,  name: 'Sliced bread (450g)',        sku: 'BREAD-450',  price: 180,  cost: 142,  stock: 18,  unit: 'pc',    category: 'Bakery',        tax: 0),
  _Item(id: 5,  name: 'Coconut oil (1L)',           sku: 'COIL-1L',    price: 1180, cost: 980,  stock: 24,  unit: 'L',     category: 'Staples',       tax: 18),
  _Item(id: 7,  name: 'White sugar (1kg)',          sku: 'SUGAR-1KG',  price: 295,  cost: 252,  stock: 0,   unit: 'kg',    category: 'Staples',       tax: 0),
  _Item(id: 8,  name: 'Mysoor dhal (1kg)',          sku: 'DHAL-MYS',   price: 685,  cost: 575,  stock: 36,  unit: 'kg',    category: 'Staples',       tax: 0),
  _Item(id: 9,  name: 'Lanka Salt (1kg)',           sku: 'SALT-1KG',   price: 120,  cost: 92,   stock: 90,  unit: 'kg',    category: 'Staples',       tax: 18),
  _Item(id: 10, name: 'Astra margarine (250g)',     sku: 'ASTRA-250',  price: 520,  cost: 430,  stock: 22,  unit: 'pc',    category: 'Dairy',         tax: 18),
  _Item(id: 11, name: 'Buffalo curd (350ml)',       sku: 'CURD-350',   price: 340,  cost: 275,  stock: 6,   unit: 'pc',    category: 'Dairy',         tax: 0),
  _Item(id: 12, name: 'Coconut (each)',             sku: 'COCO-EA',    price: 145,  cost: 110,  stock: 40,  unit: 'pc',    category: 'Produce',       tax: 0),
  _Item(id: 13, name: 'Red onion (1kg)',            sku: 'ONION-RED',  price: 480,  cost: 390,  stock: 120, unit: 'kg',    category: 'Produce',       tax: 0),
  _Item(id: 14, name: 'Tomato (1kg)',               sku: 'TOMATO-1KG', price: 390,  cost: 305,  stock: 75,  unit: 'kg',    category: 'Produce',       tax: 0),
  _Item(id: 16, name: 'Cream Soda (1.5L)',          sku: 'EH-CS15',    price: 420,  cost: 345,  stock: 48,  unit: 'pc',    category: 'Beverages',     tax: 18),
  _Item(id: 17, name: 'Ceylon tea BOPF (400g)',     sku: 'TEA-400',    price: 1250, cost: 1040, stock: 20,  unit: 'pc',    category: 'Beverages',     tax: 18),
  _Item(id: 18, name: 'Maliban Gold Marie (400g)',  sku: 'MAL-GM400',  price: 465,  cost: 385,  stock: 64,  unit: 'pc',    category: 'Snacks',        tax: 18),
  _Item(id: 19, name: 'Prima noodles (5 pack)',     sku: 'PRIMA-5',    price: 590,  cost: 495,  stock: 30,  unit: 'pack',  category: 'Snacks',        tax: 18),
  _Item(id: 20, name: 'Sunlight powder (1kg)',      sku: 'SUN-1KG',    price: 1090, cost: 905,  stock: 28,  unit: 'kg',    category: 'Household',     tax: 18),
  _Item(id: 21, name: 'Signal toothpaste (140g)',   sku: 'SIG-140',    price: 520,  cost: 425,  stock: 33,  unit: 'pc',    category: 'Personal Care', tax: 18),
  _Item(id: 22, name: 'Lifebuoy soap (4x100g)',     sku: 'LIFE-4',     price: 680,  cost: 560,  stock: 16,  unit: 'pack',  category: 'Personal Care', tax: 18),
  _Item(id: 23, name: 'Prima atta (5kg)',           sku: 'ATTA-5KG',   price: 1580, cost: 1350, stock: 12,  unit: 'kg',    category: 'Staples',       tax: 0),
];

const Map<int, _Meta> _kMeta = {
  6:  _Meta(hsn: '1006', barcode: '4791234500061', low: 12, variants: '5kg · 10kg · 25kg'),
  4:  _Meta(hsn: '0401', barcode: '4791234500042', low: 20, variants: ''),
  3:  _Meta(hsn: '0403', barcode: '4791234500033', low: 15, variants: '200g · 400g'),
  1:  _Meta(hsn: '0713', barcode: '4791234500011', low: 10, variants: ''),
  2:  _Meta(hsn: '1905', barcode: '4791234500028', low: 14, variants: ''),
  5:  _Meta(hsn: '0902', barcode: '4791234500059', low: 8,  variants: '250g · 500g'),
  7:  _Meta(hsn: '1512', barcode: '4791234500074', low: 6,  variants: '1L · 5L'),
  8:  _Meta(hsn: '3401', barcode: '4791234500081', low: 18, variants: ''),
  9:  _Meta(hsn: '2106', barcode: '4791234500098', low: 10, variants: ''),
  10: _Meta(hsn: '0805', barcode: '4791234500104', low: 25, variants: ''),
  11: _Meta(hsn: '1704', barcode: '4791234500111', low: 30, variants: ''),
  12: _Meta(hsn: '3402', barcode: '4791234500128', low: 12, variants: '1kg · 2kg'),
};

_Meta _metaOf(int id) =>
    _kMeta[id] ?? const _Meta(hsn: '—', barcode: '—', low: 10, variants: '');

// Stock state: 'Out' | 'Low' | 'In stock'
String _stockState(_Item p) {
  if (p.stock == 0) return 'Out';
  final m = _metaOf(p.id);
  return p.stock <= m.low ? 'Low' : 'In stock';
}

// Initials for avatar tile (match prototype logic).
String _initials(String name) {
  final clean = name.replaceAll(RegExp(r'\s*\(.*?\)\s*'), ' ').trim();
  final parts = clean.split(' ').where((w) => w.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts[0][0].toUpperCase();
  return (parts[0][0] + parts[1][0]).toUpperCase();
}

// Deterministic hue from name (same hash as prototype).
int _hueOf(String name) {
  int h = 0;
  for (final c in name.codeUnits) {
    h = (h * 31 + c) % 360;
  }
  return h;
}

Color _tileFg(String name) {
  final h = _hueOf(name);
  return HSLColor.fromAHSL(1, h.toDouble(), 0.58, 0.36).toColor();
}

Color _tileBg(String name) {
  final h = _hueOf(name);
  return HSLColor.fromAHSL(1, h.toDouble(), 0.72, 0.95).toColor();
}

// ---------------------------------------------------------------------------
// Public widget
// ---------------------------------------------------------------------------

class ItemsManagementScreen extends StatefulWidget {
  const ItemsManagementScreen({super.key});

  @override
  State<ItemsManagementScreen> createState() => _ItemsManagementScreenState();
}

class _ItemsManagementScreenState extends State<ItemsManagementScreen> {
  final _searchCtrl = TextEditingController();

  // Selected item id (default = first in catalog).
  int _selectedId = _kCatalog.first.id;

  // Current search query (lower-case trimmed).
  String _query = '';

  // Category / stock filter chip value.
  // Special values: 'All', 'Low', 'Out'; otherwise a category name string.
  String _filter = 'All';

  // Per-item batch-tracking toggle state.
  Map<int, bool> _batchTrack = const {4: true, 3: true};

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ---- Derived data --------------------------------------------------------

  List<_Item> get _filteredItems {
    return _kCatalog.where((p) {
      // Category / stock filter
      if (_filter != 'All') {
        final st = _stockState(p);
        if (_filter == 'Low' && st != 'Low') return false;
        if (_filter == 'Out' && st != 'Out') return false;
        if (_filter != 'Low' && _filter != 'Out' && p.category != _filter) return false;
      }
      // Search query
      if (_query.isNotEmpty) {
        final m = _metaOf(p.id);
        final q = _query;
        if (!p.name.toLowerCase().contains(q) &&
            !p.sku.toLowerCase().contains(q) &&
            !m.hsn.contains(q) &&
            !m.barcode.contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  _Item get _selectedItem {
    return _kCatalog.firstWhere(
      (p) => p.id == _selectedId,
      orElse: () => _kCatalog.first,
    );
  }

  // Kicker line: total items · low/out count · stock value
  String get _kicker {
    final lowCount = _kCatalog.where((p) => _stockState(p) != 'In stock').length;
    final stockValue = _kCatalog.fold<num>(0, (a, p) => a + p.cost * p.stock);
    return '${_kCatalog.length} items · $lowCount need reorder · stock value ${rs(stockValue)}';
  }

  // Filter chips list: All | Low | Out | ...categories
  List<String> get _filterOptions {
    final cats = _kCatalog.map((p) => p.category).toSet().toList()..sort();
    return ['All', 'Low stock', 'Out of stock', ...cats];
  }

  String _filterLabel(String f) => f;

  // Internal filter value from display label.
  String _filterKey(String label) {
    if (label == 'Low stock') return 'Low';
    if (label == 'Out of stock') return 'Out';
    return label;
  }

  // ---- Actions -------------------------------------------------------------

  void _toggleBatch() {
    final on = _batchTrack[_selectedId] ?? false;
    setState(() {
      _batchTrack = Map.of(_batchTrack)..[_selectedId] = !on;
    });
  }

  // ---- Build ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DostopColors.canvas,
      body: Column(
        children: [
          DostopScreenHeader(
            title: 'Items',
            subtitle: _kicker,
            actions: [
              _ActionButton(label: 'Import CSV', onTap: () {}),
              const SizedBox(width: 8),
              _ActionButton(label: 'Export', onTap: () {}),
              const SizedBox(width: 8),
              _PrimaryButton(label: '+ Add item', onTap: () {}),
              const SizedBox(width: 6),
            ],
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // At ~900px clamp left pane and let it scroll horizontally.
                const detailWidth = 360.0;
                const listMinWidth = 560.0;
                final wide = constraints.maxWidth >= listMinWidth + detailWidth;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Left: list pane
                    wide
                        ? Expanded(child: _listPane())
                        : SizedBox(
                            width: constraints.maxWidth - detailWidth,
                            child: _listPane(),
                          ),
                    // Right: detail panel
                    SizedBox(
                      width: detailWidth,
                      child: _detailPane(),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ---- Left list pane ------------------------------------------------------

  Widget _listPane() {
    final items = _filteredItems;
    return Container(
      color: DostopColors.panel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _searchAndFilters(),
          _listHeader(),
          Expanded(
            child: items.isEmpty ? _emptyList() : _itemList(items),
          ),
        ],
      ),
    );
  }

  Widget _searchAndFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search field
          SizedBox(
            height: 38,
            child: TextField(
              controller: _searchCtrl,
              style: DostopText.mono.copyWith(color: DostopColors.ink, fontSize: 13),
              decoration: const InputDecoration(
                hintText: 'Search name, SKU, HS code or barcode…',
                prefixIcon: Icon(Icons.search, size: 18, color: DostopColors.slate400),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            ),
          ),
          const SizedBox(height: 10),
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _filterOptions.map((label) {
                final key = _filterKey(label);
                final active = _filter == key;
                return Padding(
                  padding: const EdgeInsets.only(right: 7),
                  child: _FilterChip(
                    label: _filterLabel(label),
                    active: active,
                    onTap: () => setState(() => _filter = key),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _listHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
      decoration: const BoxDecoration(
        color: DostopColors.slate50,
        border: Border(
          bottom: BorderSide(color: DostopColors.hairline),
          top: BorderSide(color: DostopColors.hairline),
        ),
      ),
      child: const Row(
        children: [
          // Item (avatar + name + sku)
          Expanded(
            flex: 5,
            child: Text('ITEM', style: DostopText.columnHead),
          ),
          // HS
          SizedBox(width: 80, child: Text('HS', style: DostopText.columnHead)),
          // Unit
          SizedBox(width: 64, child: Text('UNIT', style: DostopText.columnHead)),
          // Purchase price
          SizedBox(
            width: 100,
            child: Text('PURCHASE', textAlign: TextAlign.right, style: DostopText.columnHead),
          ),
          // Sale price
          SizedBox(
            width: 100,
            child: Text('SALE', textAlign: TextAlign.right, style: DostopText.columnHead),
          ),
          // VAT
          SizedBox(
            width: 60,
            child: Text('VAT', textAlign: TextAlign.center, style: DostopText.columnHead),
          ),
          // Stock
          SizedBox(
            width: 110,
            child: Text('STOCK', textAlign: TextAlign.right, style: DostopText.columnHead),
          ),
        ],
      ),
    );
  }

  Widget _emptyList() {
    return Center(
      child: Text(
        _query.isNotEmpty
            ? 'No item matches "$_query"'
            : 'No items match the selected filter.',
        style: DostopText.label,
      ),
    );
  }

  Widget _itemList(List<_Item> items) {
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (_, i) {
        final item = items[i];
        final selected = item.id == _selectedId;
        return _ItemRow(
          item: item,
          selected: selected,
          onTap: () => setState(() => _selectedId = item.id),
        );
      },
    );
  }

  // ---- Right detail panel --------------------------------------------------

  Widget _detailPane() {
    final item = _selectedItem;
    final meta = _metaOf(item.id);
    final batchOn = _batchTrack[item.id] ?? false;
    final margin = item.price > 0
        ? '${((item.price - item.cost) / item.price * 100).round()}%'
        : '—';
    final stockSt = _stockState(item);
    final tone = stockTone(item.stock);

    return Container(
      decoration: const BoxDecoration(
        color: DostopColors.panel,
        border: Border(left: BorderSide(color: DostopColors.hairline)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header: avatar + name + sku/hsn
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: DostopColors.hairline)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Avatar tile
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: _tileBg(item.name),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _initials(item.name),
                          style: TextStyle(
                            fontFamily: DostopFonts.sans,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: _tileFg(item.name),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: DostopText.itemName.copyWith(fontSize: 15),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${item.sku} · HS ${meta.hsn}',
                              style: DostopText.mono.copyWith(fontSize: 11),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Price + Margin tiles
                  Row(
                    children: [
                      Expanded(
                        child: _DetailTile(
                          label: 'Sale price',
                          value: rs(item.price),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _DetailTile(
                          label: 'Margin',
                          value: margin,
                          valueColor: DostopColors.brand,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Fields
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DetailField(label: 'Item name', value: item.name),
                  _DetailField(label: 'SKU', value: item.sku, mono: true),
                  _DetailField(label: 'HS code', value: meta.hsn, mono: true),
                  _DetailField(label: 'Barcode', value: meta.barcode, mono: true),
                  _DetailField(label: 'Category', value: item.category),
                  _DetailField(label: 'Unit of measure', value: item.unit),
                  _DetailField(
                    label: 'Purchase price',
                    value: item.cost.toStringAsFixed(2),
                    mono: true,
                  ),
                  _DetailField(
                    label: 'Sale price',
                    value: item.price.toStringAsFixed(2),
                    mono: true,
                  ),
                  _DetailField(label: 'VAT rate', value: '${item.tax}%'),
                  // Stock row with badge
                  _StockDetailRow(
                    stock: item.stock,
                    unit: item.unit,
                    lowAt: meta.low,
                    stockState: stockSt,
                    tone: tone,
                  ),
                  _DetailField(
                    label: 'Low-stock alert at',
                    value: '${meta.low} ${item.unit}',
                  ),
                  if (meta.variants.isNotEmpty)
                    _DetailField(label: 'Variants', value: meta.variants)
                  else
                    const _DetailField(label: 'Variants', value: 'None'),
                  const SizedBox(height: 14),

                  // Batch tracking toggle
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
                    decoration: BoxDecoration(
                      color: DostopColors.slate50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Track batch & expiry',
                                style: DostopText.label.copyWith(
                                  color: DostopColors.ink,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'For perishables and medicines',
                                style: TextStyle(
                                  fontFamily: DostopFonts.sans,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: DostopColors.slate400,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        _ToggleSwitch(on: batchOn, onChanged: (_) => _toggleBatch()),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    height: 42,
                    child: FilledButton(
                      onPressed: () {},
                      style: FilledButton.styleFrom(
                        backgroundColor: DostopColors.brand,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(DostopRadius.button),
                        ),
                      ),
                      child: const Text(
                        'Save item',
                        style: TextStyle(
                          fontFamily: DostopFonts.sans,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Item list row
// ---------------------------------------------------------------------------

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _Item item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final meta = _metaOf(item.id);
    final st = _stockState(item);

    final Color stockFg;
    final Color stockBg;
    if (st == 'Out') {
      stockFg = DostopColors.stockOutFg;
      stockBg = DostopColors.stockOutBg;
    } else if (st == 'Low') {
      stockFg = DostopColors.stockLowFg;
      stockBg = DostopColors.stockLowBg;
    } else {
      stockFg = DostopColors.stockOkFg;
      stockBg = DostopColors.stockOkBg;
    }

    final stockLabel = st == 'Out'
        ? 'Out of stock'
        : '${item.stock} ${item.unit}';

    return InkWell(
      onTap: onTap,
      hoverColor: DostopColors.brandWash,
      child: Container(
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF4FDF7) : null,
          border: const Border(bottom: BorderSide(color: Color(0xFFF4F6F9))),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: DostopColors.brand,
                    blurRadius: 0,
                    spreadRadius: 0,
                    offset: Offset(-3, 0),
                  ),
                ]
              : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        child: Row(
          children: [
            // Item: avatar + name + sku/category
            Expanded(
              flex: 5,
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: _tileBg(item.name),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _initials(item.name),
                      style: TextStyle(
                        fontFamily: DostopFonts.sans,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: _tileFg(item.name),
                      ),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: DostopText.itemName.copyWith(fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${item.sku} · ${item.category}',
                          style: DostopText.mono.copyWith(fontSize: 10.5),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // HS
            SizedBox(
              width: 80,
              child: Text(
                meta.hsn,
                style: DostopText.mono.copyWith(fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Unit
            SizedBox(
              width: 64,
              child: Text(
                item.unit,
                style: DostopText.label.copyWith(fontSize: 12.5),
              ),
            ),
            // Purchase price
            SizedBox(
              width: 100,
              child: Text(
                rs(item.cost),
                textAlign: TextAlign.right,
                style: DostopText.label.copyWith(fontSize: 12.5),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Sale price
            SizedBox(
              width: 100,
              child: Text(
                rs(item.price),
                textAlign: TextAlign.right,
                style: DostopText.money.copyWith(fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // VAT badge
            SizedBox(
              width: 60,
              child: Center(
                child: Container(
                  height: 22,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: DostopColors.slate100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${item.tax}%',
                    style: const TextStyle(
                      fontFamily: DostopFonts.sans,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: DostopColors.slate600,
                    ),
                  ),
                ),
              ),
            ),
            // Stock badge
            SizedBox(
              width: 110,
              child: Align(
                alignment: Alignment.centerRight,
                child: Container(
                  height: 24,
                  padding: const EdgeInsets.symmetric(horizontal: 9),
                  decoration: BoxDecoration(
                    color: stockBg,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    stockLabel,
                    style: TextStyle(
                      fontFamily: DostopFonts.sans,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: stockFg,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
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

// ---------------------------------------------------------------------------
// Detail panel sub-widgets
// ---------------------------------------------------------------------------

class _DetailTile extends StatelessWidget {
  const _DetailTile({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: DostopColors.slate50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontFamily: DostopFonts.sans,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
              color: DostopColors.slate400,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontFamily: DostopFonts.sans,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: valueColor ?? DostopColors.ink,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailField extends StatelessWidget {
  const _DetailField({
    required this.label,
    required this.value,
    this.mono = false,
  });

  final String label;
  final String value;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontFamily: DostopFonts.sans,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
              color: DostopColors.slate400,
            ),
          ),
          const SizedBox(height: 5),
          Container(
            width: double.infinity,
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 11),
            decoration: BoxDecoration(
              color: DostopColors.panel,
              border: Border.all(color: DostopColors.slate200),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontFamily: mono ? DostopFonts.mono : DostopFonts.sans,
                fontSize: 13,
                color: DostopColors.ink,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _StockDetailRow extends StatelessWidget {
  const _StockDetailRow({
    required this.stock,
    required this.unit,
    required this.lowAt,
    required this.stockState,
    required this.tone,
  });

  final int stock;
  final String unit;
  final int lowAt;
  final String stockState;
  final ({Color fg, Color bg, String label}) tone;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'STOCK',
            style: TextStyle(
              fontFamily: DostopFonts.sans,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
              color: DostopColors.slate400,
            ),
          ),
          const SizedBox(height: 5),
          Container(
            width: double.infinity,
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 11),
            decoration: BoxDecoration(
              color: DostopColors.panel,
              border: Border.all(color: DostopColors.slate200),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Text(
                  '$stock $unit',
                  style: const TextStyle(
                    fontFamily: DostopFonts.sans,
                    fontSize: 13,
                    color: DostopColors.ink,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 10),
                DostopPill(
                  label: tone.label,
                  fg: tone.fg,
                  bg: tone.bg,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Toggle switch (matches prototype style)
// ---------------------------------------------------------------------------

class _ToggleSwitch extends StatelessWidget {
  const _ToggleSwitch({required this.on, required this.onChanged});

  final bool on;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!on),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 44,
        height: 26,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: on ? DostopColors.brand : DostopColors.slate300,
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
              boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 3, offset: Offset(0, 1))],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Filter chip
// ---------------------------------------------------------------------------

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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: 34,
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
}

// ---------------------------------------------------------------------------
// Action / primary button helpers (header buttons)
// ---------------------------------------------------------------------------

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: DostopColors.slate600,
        backgroundColor: DostopColors.panel,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        minimumSize: Size.zero,
        side: const BorderSide(color: DostopColors.slate200),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DostopRadius.button),
        ),
        textStyle: const TextStyle(
          fontFamily: DostopFonts.sans,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
      child: Text(label),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: DostopColors.brand,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        minimumSize: Size.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DostopRadius.button),
        ),
        textStyle: const TextStyle(
          fontFamily: DostopFonts.sans,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
      child: Text(label),
    );
  }
}
