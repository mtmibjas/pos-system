/// Settings screen — translated from the Dostop/Greenleaf Claude-Design
/// React prototype (gl_app.js / gl_doc.html). All data is hardcoded locally;
/// local setState controls selected section and toggle values. No Riverpod.
library;

import 'package:flutter/material.dart';

import '../../ui/theme.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';

// ---------------------------------------------------------------------------
// Data model types
// ---------------------------------------------------------------------------

class _Section {
  const _Section({
    required this.key,
    required this.label,
    required this.title,
    required this.desc,
  });
  final String key;
  final String label;
  final String title;
  final String desc;
}

class _ToggleDef {
  const _ToggleDef({required this.key, required this.label, required this.desc});
  final String key;
  final String label;
  final String desc;
}

class _GstSlab {
  const _GstSlab({required this.rate, required this.label, required this.items});
  final double rate;
  final String label;
  final String items;
}

class _Role {
  const _Role({
    required this.role,
    required this.who,
    required this.can,
    required this.fgColor,
    required this.bgColor,
  });
  final String role;
  final String who;
  final String can;
  final Color fgColor;
  final Color bgColor;
}

// ---------------------------------------------------------------------------
// Hardcoded data (mirroring gl_app.js)
// ---------------------------------------------------------------------------

const _kSections = <_Section>[
  _Section(
    key: 'store',
    label: 'Store profile',
    title: 'Store profile',
    desc: 'Business details printed on every invoice.',
  ),
  _Section(
    key: 'tax',
    label: 'Tax & pricing',
    title: 'Tax & pricing',
    desc: 'VAT rates, SSCL, rounding and price display rules.',
  ),
  _Section(
    key: 'receipt',
    label: 'Receipt',
    title: 'Receipt',
    desc: 'What gets printed after each sale.',
  ),
  _Section(
    key: 'payments',
    label: 'Payments',
    title: 'Payments',
    desc: 'Methods offered at the counter.',
  ),
  _Section(
    key: 'devices',
    label: 'Devices',
    title: 'Devices & counter',
    desc: 'Scanner, printer and cash drawer for this terminal.',
  ),
  _Section(
    key: 'users',
    label: 'Users & roles',
    title: 'Users & roles',
    desc: 'Who can do what at the counter and in the books.',
  ),
  _Section(
    key: 'backup',
    label: 'Backup & restore',
    title: 'Backup & restore',
    desc: 'Your data lives on this device. Keep a copy somewhere safe.',
  ),
];

const _kToggles = <String, List<_ToggleDef>>{
  'store': [
    _ToggleDef(
      key: 'multi',
      label: 'Multi-outlet mode',
      desc: 'Show the outlet switcher in the header.',
    ),
    _ToggleDef(
      key: 'audit',
      label: 'Audit log',
      desc: 'Record every price override and void.',
    ),
  ],
  'tax': [
    _ToggleDef(
      key: 'incl',
      label: 'Prices include VAT',
      desc: 'Shelf prices are tax-inclusive.',
    ),
    _ToggleDef(
      key: 'round',
      label: 'Round off bill total',
      desc: 'Round the grand total to the nearest rupee.',
    ),
    _ToggleDef(
      key: 'override',
      label: 'Allow price override',
      desc: 'Cashiers can edit line prices at the counter.',
    ),
  ],
  'receipt': [
    _ToggleDef(
      key: 'autoprint',
      label: 'Auto-print on payment',
      desc: 'Print immediately when a sale completes.',
    ),
    _ToggleDef(
      key: 'gstsum',
      label: 'Show VAT summary',
      desc: 'Print the rate-wise tax breakdown.',
    ),
    _ToggleDef(
      key: 'sms',
      label: 'Send SMS receipt',
      desc: 'Text a copy when the customer has a number on file.',
    ),
  ],
  'payments': [
    _ToggleDef(
      key: 'upi',
      label: 'LankaQR at counter',
      desc: 'Show a dynamic QR on the customer display.',
    ),
    _ToggleDef(
      key: 'card',
      label: 'Card terminal',
      desc: 'Integrated Commercial Bank terminal on Counter 11.',
    ),
    _ToggleDef(
      key: 'split',
      label: 'Split payments',
      desc: 'Let one bill be settled across two methods.',
    ),
    _ToggleDef(
      key: 'credit',
      label: 'Credit sales',
      desc: 'Allow billing to a party ledger.',
    ),
  ],
  'devices': [
    _ToggleDef(
      key: 'scanner',
      label: 'Barcode scanner',
      desc: 'Honeywell 1250g · connected',
    ),
    _ToggleDef(
      key: 'drawer',
      label: 'Cash drawer kick',
      desc: 'Open the drawer on cash payments.',
    ),
    _ToggleDef(
      key: 'display',
      label: 'Customer display',
      desc: 'Mirror the cart on the second screen.',
    ),
  ],
  'users': [
    _ToggleDef(
      key: 'pin',
      label: 'Require PIN at counter',
      desc: 'Cashiers unlock the till with a 4-digit PIN.',
    ),
    _ToggleDef(
      key: 'voidapp',
      label: 'Owner approval to void',
      desc: 'A void or refund needs the owner PIN.',
    ),
  ],
  'backup': [
    _ToggleDef(
      key: 'autobackup',
      label: 'Automatic daily backup',
      desc: 'Runs at 11 PM to the folder below.',
    ),
    _ToggleDef(
      key: 'cloudsync',
      label: 'Cloud sync when online',
      desc: 'Optional — the app works fully offline without it.',
    ),
  ],
};

const _kGstSlabs = <_GstSlab>[
  _GstSlab(
    rate: 0,
    label: 'Exempt',
    items: 'Rice, bread, fresh milk, vegetables, dhal, sugar',
  ),
  _GstSlab(
    rate: 0,
    label: 'Zero-rated (export)',
    items: 'Goods supplied for export',
  ),
  _GstSlab(
    rate: 18,
    label: 'Standard VAT',
    items: 'Oils, soap, detergent, biscuits, beverages, tea',
  ),
  _GstSlab(
    rate: 2.5,
    label: 'SSCL',
    items: 'Social Security Contribution Levy on turnover',
  ),
  _GstSlab(
    rate: 1,
    label: 'Tourism VAT (SVAT)',
    items: 'Simplified VAT scheme — suspended supplies',
  ),
];

const _kRoles = <_Role>[
  _Role(
    role: 'Owner',
    who: 'Ruwan Jayawardena',
    can: 'Everything — pricing, reports, VAT filing, user management',
    fgColor: Color(0xFF16A34A),
    bgColor: Color(0xFFF0FDF4),
  ),
  _Role(
    role: 'Supervisor',
    who: 'Vimukthi Perera',
    can: 'Billing, purchases, stock adjustments, shift reports',
    fgColor: DostopColors.blue,
    bgColor: DostopColors.blueWash,
  ),
  _Role(
    role: 'Cashier',
    who: 'Dilani Wickrama, Kasun Silva, Fathima Rizwan',
    can: 'Billing and receipts only — no price edits, no reports',
    fgColor: DostopColors.violet,
    bgColor: DostopColors.violetWash,
  ),
];

// BIZ business profile data
const _kBiz = <String, String>{
  'Store name': 'Greenleaf Mart · Colombo 03',
  'VAT registration no.': '134567890-7000',
  'Phone': '+94 11 234 5678',
  'Currency': 'LKR (Rs) · en-LK',
  'Address': '42 Galle Road, Colombo 03',
};

// Initial toggle states (matching prototype state.toggles)
const _kInitialToggles = <String, bool>{
  'multi': true,
  'audit': false,
  'incl': true,
  'round': true,
  'override': false,
  'autoprint': true,
  'gstsum': true,
  'sms': false,
  'upi': true,
  'card': true,
  'split': true,
  'credit': false,
  'scanner': true,
  'drawer': true,
  'display': false,
  'pin': false,
  'voidapp': false,
  'autobackup': false,
  'cloudsync': false,
};

// Initial slab active states (matching prototype state.slabs)
const _kInitialSlabs = <int, bool>{
  0: true, // index 0 = Exempt
  1: true, // index 1 = Zero-rated
  2: true, // index 2 = Standard 18%
  3: true, // index 3 = SSCL 2.5%
  4: false, // index 4 = SVAT 1%
};

// Chip colors per slab index (matching prototype tone array)
const _kSlabChipColors = <int, ({Color bg, Color fg})>{
  0: (bg: DostopColors.slate100, fg: DostopColors.slate600),
  1: (bg: DostopColors.stockOkBg, fg: DostopColors.brandDark),
  2: (bg: DostopColors.blueWash, fg: Color(0xFF1D4ED8)),
  3: (bg: Color(0xFFFEF3C7), fg: Color(0xFFB45309)),
  4: (bg: Color(0xFFFEE2E2), fg: Color(0xFFB91C1C)),
};

// ---------------------------------------------------------------------------
// Public widget
// ---------------------------------------------------------------------------

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _selectedKey = 'store';
  final Map<String, bool> _toggles = Map.of(_kInitialToggles);
  final Map<int, bool> _slabs = Map.of(_kInitialSlabs);

  _Section get _selectedSection =>
      _kSections.firstWhere((s) => s.key == _selectedKey);

  void _selectSection(String key) => setState(() => _selectedKey = key);

  void _toggleKey(String key) =>
      setState(() => _toggles[key] = !(_toggles[key] ?? false));

  void _toggleSlab(int index) =>
      setState(() => _slabs[index] = !(_slabs[index] ?? true));

  @override
  Widget build(BuildContext context) {
    final sec = _selectedSection;
    return Scaffold(
      backgroundColor: DostopColors.canvas,
      body: Column(
        children: [
          const DostopScreenHeader(title: 'Settings', subtitle: 'Store configuration'),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SectionNav(
                  sections: _kSections,
                  selectedKey: _selectedKey,
                  onSelect: _selectSection,
                ),
                Expanded(
                  child: _ContentPane(
                    section: sec,
                    toggles: _toggles,
                    slabs: _slabs,
                    onToggle: _toggleKey,
                    onToggleSlab: _toggleSlab,
                  ),
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
// Left nav panel
// ---------------------------------------------------------------------------

class _SectionNav extends StatelessWidget {
  const _SectionNav({
    required this.sections,
    required this.selectedKey,
    required this.onSelect,
  });

  final List<_Section> sections;
  final String selectedKey;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 232,
      decoration: const BoxDecoration(
        color: DostopColors.panel,
        border: Border(right: BorderSide(color: DostopColors.hairline)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
              child: Text(
                'SETTINGS',
                style: DostopText.columnHead.copyWith(letterSpacing: 0.4),
              ),
            ),
            for (final s in sections) _NavItem(section: s, selected: selectedKey == s.key, onTap: () => onSelect(s.key)),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.section,
    required this.selected,
    required this.onTap,
  });

  final _Section section;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? DostopColors.brandWash : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: selected ? DostopColors.brand : DostopColors.slate300,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                section.label,
                style: TextStyle(
                  fontFamily: DostopFonts.sans,
                  fontSize: 13,
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

// ---------------------------------------------------------------------------
// Right content pane
// ---------------------------------------------------------------------------

class _ContentPane extends StatelessWidget {
  const _ContentPane({
    required this.section,
    required this.toggles,
    required this.slabs,
    required this.onToggle,
    required this.onToggleSlab,
  });

  final _Section section;
  final Map<String, bool> toggles;
  final Map<int, bool> slabs;
  final ValueChanged<String> onToggle;
  final ValueChanged<int> onToggleSlab;

  @override
  Widget build(BuildContext context) {
    final sectionToggles = _kToggles[section.key] ?? const [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section title + description
              _SectionHeader(section: section),
              const SizedBox(height: 20),

              // Section-specific content
              if (section.key == 'store') const _StoreCard(),
              if (section.key == 'tax') ...[
                _TaxSlabCard(slabs: slabs, onToggle: onToggleSlab),
                const SizedBox(height: 14),
                const _TaxInfoCard(),
              ],
              if (section.key == 'users') ...[
                const _UsersCard(),
                const SizedBox(height: 14),
              ],
              if (section.key == 'backup') ...[
                const _BackupCard(),
                const SizedBox(height: 14),
              ],

              // Generic toggle card (shown for all sections that have toggles)
              if (sectionToggles.isNotEmpty) ...[
                if (section.key != 'store' && section.key != 'users' && section.key != 'backup')
                  const SizedBox(height: 0)
                else
                  const SizedBox(height: 0),
                _TogglesCard(
                  toggleDefs: sectionToggles,
                  toggles: toggles,
                  onToggle: onToggle,
                ),
              ],

              const SizedBox(height: 18),
              const _SaveBar(),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section header
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.section});
  final _Section section;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          section.title,
          style: const TextStyle(
            fontFamily: DostopFonts.sans,
            fontSize: 21,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            color: DostopColors.ink,
          ),
        ),
        const SizedBox(height: 4),
        Text(section.desc, style: DostopText.kicker),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Store profile card
// ---------------------------------------------------------------------------

class _StoreCard extends StatelessWidget {
  const _StoreCard();

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        children: [
          _TwoColumnGrid(
            children: [
              for (final entry in _kBiz.entries.take(4))
                _BizField(label: entry.key, value: entry.value),
            ],
          ),
          const SizedBox(height: 14),
          _BizField(label: 'Address', value: _kBiz['Address']!, fullWidth: true),
        ],
      ),
    );
  }
}

class _BizField extends StatelessWidget {
  const _BizField({
    required this.label,
    required this.value,
    this.fullWidth = false,
  });

  final String label;
  final String value;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final isMono = label == 'VAT registration no.';
    final isReadOnly = label == 'Currency';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: DostopFonts.sans,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: DostopColors.slate600,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: isReadOnly ? DostopColors.slate50 : DostopColors.panel,
            borderRadius: BorderRadius.circular(DostopRadius.control),
            border: Border.all(color: DostopColors.slate300),
          ),
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: isMono ? DostopFonts.mono : DostopFonts.sans,
              fontSize: 13,
              color: isReadOnly ? DostopColors.slate500 : DostopColors.ink,
            ),
          ),
        ),
      ],
    );
  }
}

class _TwoColumnGrid extends StatelessWidget {
  const _TwoColumnGrid({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    // Pair children into rows of 2
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += 2) {
      final left = children[i];
      final right = i + 1 < children.length ? children[i + 1] : const SizedBox.shrink();
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: left),
            const SizedBox(width: 14),
            Expanded(child: right),
          ],
        ),
      );
      if (i + 2 < children.length) rows.add(const SizedBox(height: 14));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rows,
    );
  }
}

// ---------------------------------------------------------------------------
// Tax slabs card
// ---------------------------------------------------------------------------

class _TaxSlabCard extends StatelessWidget {
  const _TaxSlabCard({required this.slabs, required this.onToggle});

  final Map<int, bool> slabs;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: _CardBordered(
        child: Column(
          children: [
            // Header row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              color: DostopColors.slate50,
              child: const Row(
                children: [
                  SizedBox(
                    width: 72,
                    child: Text('RATE', style: DostopText.columnHead),
                  ),
                  SizedBox(width: 12),
                  Expanded(child: Text('NAME', style: DostopText.columnHead)),
                  SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: Text('TYPICAL ITEMS', style: DostopText.columnHead),
                  ),
                  SizedBox(width: 12),
                  SizedBox(
                    width: 64,
                    child: Text('ACTIVE', textAlign: TextAlign.center, style: DostopText.columnHead),
                  ),
                ],
              ),
            ),
            for (var i = 0; i < _kGstSlabs.length; i++)
              _SlabRow(
                index: i,
                slab: _kGstSlabs[i],
                active: slabs[i] ?? true,
                onToggle: () => onToggle(i),
              ),
          ],
        ),
      ),
    );
  }
}

class _SlabRow extends StatelessWidget {
  const _SlabRow({
    required this.index,
    required this.slab,
    required this.active,
    required this.onToggle,
  });

  final int index;
  final _GstSlab slab;
  final bool active;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final chip = _kSlabChipColors[index] ?? (bg: DostopColors.slate100, fg: DostopColors.slate600);
    final rateLabel = slab.rate == 0
        ? '0%'
        : slab.rate == slab.rate.truncateToDouble()
            ? '${slab.rate.toInt()}%'
            : '${slab.rate}%';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF4F6F9))),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Container(
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: chip.bg,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(
                rateLabel,
                style: TextStyle(
                  fontFamily: DostopFonts.sans,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: chip.fg,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              slab.label,
              style: DostopText.itemName.copyWith(fontSize: 13),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              slab.items,
              style: DostopText.kicker,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 64,
            child: Center(child: _Toggle(active: active, onToggle: onToggle)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tax info card
// ---------------------------------------------------------------------------

class _TaxInfoCard extends StatelessWidget {
  const _TaxInfoCard();

  @override
  Widget build(BuildContext context) {
    return const _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How tax is applied',
            style: TextStyle(
              fontFamily: DostopFonts.sans,
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: DostopColors.ink,
            ),
          ),
          SizedBox(height: 5),
          Text(
            'Prices are VAT-inclusive. VAT is backed out of the shelf price, SSCL is applied on turnover.',
            style: DostopText.kicker,
          ),
          SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _InfoTile(
                  bg: Color(0xFFF0FDF4),
                  border: Color(0xFFBBF7D0),
                  titleColor: DostopColors.brandDark,
                  title: 'Standard rate → VAT 18%',
                  body: 'Oils, soap, biscuits, beverages and tea.',
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _InfoTile(
                  bg: DostopColors.blueWash,
                  border: Color(0xFFBFDBFE),
                  titleColor: Color(0xFF1D4ED8),
                  title: 'Essentials → Exempt',
                  body: 'Rice, bread, milk, vegetables, dhal and sugar.',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.bg,
    required this.border,
    required this.titleColor,
    required this.title,
    required this.body,
  });

  final Color bg;
  final Color border;
  final Color titleColor;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: DostopFonts.sans,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            body,
            style: DostopText.label.copyWith(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Generic toggles card
// ---------------------------------------------------------------------------

class _TogglesCard extends StatelessWidget {
  const _TogglesCard({
    required this.toggleDefs,
    required this.toggles,
    required this.onToggle,
  });

  final List<_ToggleDef> toggleDefs;
  final Map<String, bool> toggles;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: _CardBordered(
        child: Column(
          children: [
            for (final def in toggleDefs)
              _ToggleRow(
                def: def,
                value: toggles[def.key] ?? false,
                onToggle: () => onToggle(def.key),
              ),
          ],
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.def,
    required this.value,
    required this.onToggle,
  });

  final _ToggleDef def;
  final bool value;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF4F6F9))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  def.label,
                  style: const TextStyle(
                    fontFamily: DostopFonts.sans,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: DostopColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(def.desc, style: DostopText.kicker),
              ],
            ),
          ),
          const SizedBox(width: 16),
          _Toggle(active: value, onToggle: onToggle, large: true),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Users & roles card
// ---------------------------------------------------------------------------

class _UsersCard extends StatelessWidget {
  const _UsersCard();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final role in _kRoles) ...[
          _RoleCard(role: role),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({required this.role});
  final _Role role;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 24,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: role.bgColor,
                  borderRadius: BorderRadius.circular(7),
                ),
                alignment: Alignment.center,
                child: Text(
                  role.role,
                  style: TextStyle(
                    fontFamily: DostopFonts.sans,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: role.fgColor,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  role.who,
                  style: DostopText.itemName,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            role.can,
            style: DostopText.kicker.copyWith(
              fontSize: 12.5,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Backup & restore card
// ---------------------------------------------------------------------------

class _BackupCard extends StatelessWidget {
  const _BackupCard();

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: DostopColors.brand,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFFDCFCE7),
                        spreadRadius: 4,
                        blurRadius: 0,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Last backup 11:00 PM, 14 June 2026',
                        style: TextStyle(
                          fontFamily: DostopFonts.sans,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF15803D),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '4,812 records · 2.4 MB · this device',
                        style: DostopText.label.copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Backup folder',
            style: TextStyle(
              fontFamily: DostopFonts.sans,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: DostopColors.slate600,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: DostopColors.panel,
              borderRadius: BorderRadius.circular(DostopRadius.control),
              border: Border.all(color: DostopColors.slate300),
            ),
            alignment: Alignment.centerLeft,
            child: const Text(
              r'C:\GreenleafPOS\backups',
              style: TextStyle(
                fontFamily: DostopFonts.mono,
                fontSize: 13,
                color: DostopColors.ink,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: [
              _ActionButton(
                label: 'Back up now',
                primary: true,
                onTap: () {},
              ),
              _ActionButton(
                label: 'Restore from file',
                onTap: () {},
              ),
              _ActionButton(
                label: 'Erase local data',
                danger: true,
                onTap: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.onTap,
    this.primary = false,
    this.danger = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool primary;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    Color border;

    if (primary) {
      bg = DostopColors.brand;
      fg = Colors.white;
      border = DostopColors.brandDark;
    } else if (danger) {
      bg = DostopColors.panel;
      fg = DostopColors.danger;
      border = const Color(0xFFFECACA);
    } else {
      bg = DostopColors.panel;
      fg = DostopColors.slate600;
      border = DostopColors.slate300;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: border),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontFamily: DostopFonts.sans,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: fg,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Save bar
// ---------------------------------------------------------------------------

class _SaveBar extends StatelessWidget {
  const _SaveBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ActionButton(label: 'Save changes', primary: true, onTap: () {}),
        const SizedBox(width: 10),
        _ActionButton(label: 'Discard', onTap: () {}),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Toggle thumb widget
// ---------------------------------------------------------------------------

class _Toggle extends StatelessWidget {
  const _Toggle({required this.active, required this.onToggle, this.large = false});

  final bool active;
  final VoidCallback onToggle;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final trackW = large ? 46.0 : 42.0;
    final trackH = large ? 27.0 : 24.0;
    final thumbSize = large ? 21.0 : 18.0;

    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: trackW,
        height: trackH,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: active ? DostopColors.brand : DostopColors.slate300,
          borderRadius: BorderRadius.circular(trackH / 2),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 160),
          alignment: active ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: thumbSize,
            height: thumbSize,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.28),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared card containers
// ---------------------------------------------------------------------------

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: DostopColors.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DostopColors.hairline),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.05),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _CardBordered extends StatelessWidget {
  const _CardBordered({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: DostopColors.panel,
        border: Border.all(color: DostopColors.hairline),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.05),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: child,
    );
  }
}
