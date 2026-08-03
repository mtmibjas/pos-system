# Desktop POS — UI Design System & Screen Mapping ("Dostop POS")

> **Status: DRAFT for review.** This maps the *Greenleaf / Dostop POS*
> Claude-Design prototype onto the Flutter `apps/desktop-pos`. It defines the
> shared **design system** (tokens + typography) and the **screen mapping**
> (prototype screen → existing feature module → backend availability), then
> scopes the **first implementation pass**. No feature behaviour changes here —
> the counter flow (reserve → cart → tender → finalize) keeps its existing
> wiring; we restyle the shell and rebuild the Counter screen on top of it.

---

## 1. Source of truth

The prototype is a self-contained Claude-Design bundle:
`~/Downloads/Greenleaf POS (standalone) (1).html`. It renders a React app
(`class Component extends DCLogic`) with mock LK-market data. This doc is the
translation contract — the Flutter build follows the tokens and layouts
recorded here, not the raw HTML.

The prototype is a **north-star for the whole suite** (14 screens). Its sidebar
already maps almost 1:1 onto `lib/features/shell/modules.dart`, where several
modules are still `PlaceholderScreen`s. We implement it **incrementally**,
one screen per phase — this pass does the design system + Counter.

---

## 2. Design tokens

### 2.1 Colour

| Token | Hex | Use |
|---|---|---|
| `brandGreen` | `#16A34A` | Primary action, active nav, Charge button |
| `brandGreenDark` | `#15803D` | Hover / pressed green, "in stock" text |
| `brandGreenWash` | `#ECFDF5` | Active nav background, avatar bg |
| `ink` | `#0F172A` | Primary text, dense headings |
| `inkPanel` | `#0B1220` | "Total payable" panel background |
| `slate600` | `#475569` | Secondary text |
| `slate500` | `#64748B` | Tertiary text, SKU mono |
| `slate400` | `#94A3B8` | Muted labels, placeholders |
| `slate300` | `#CBD5E1` | Disabled, hairline dividers-on-dark |
| `slate200` | `#E2E8F0` | Borders, chip outlines |
| `slate100` | `#F1F5F9` | Chip fill, stepper track |
| `slate50` | `#F8FAFC` | Input fill, zebra rows |
| `canvas` | `#F3F4F6` | App background |
| `panel` | `#FFFFFF` | Cards / panels |
| Sidebar dark | `#111827` bg / `#1F2937` border / `#9CA3AF` text | Dark sidebar theme |

**Semantic stock tones** (tile badges):

| State | Fg | Bg | Rule |
|---|---|---|---|
| In stock | `#16A34A` | `#F0FDF4` | on-hand > 8 |
| Low stock | `#D97706` | `#FFFBEB` | 1..8 |
| Out of stock | `#DC2626` | `#FEF2F2` | 0 |

**Payment-method tones:** Cash `#15803D/#F0FDF4`, LankaQR `#1D4ED8/#EFF6FF`,
Card `#7C3AED/#F5F3FF`, Split `#475569/#F1F5F9`.

### 2.2 Typography

- **Manrope** — UI sans (weights 500/700/800). Body, labels, headings.
- **DM Mono** — all **numerics**: money, SKUs, quantities, keycaps
  (`F2`, `Enter`), tabular figures (`font-variant-numeric: tabular-nums`).

Both are bundled as local TTF assets (offline-first — no `google_fonts`
runtime fetch). See §5.

### 2.3 Shape & elevation

- Radius: chips/steppers `6–9px`, inputs/buttons `9–11px`, cards/panels
  `13–14px`.
- Card shadow: `0 1px 2px rgba(15,23,42,.04)`; hover lift
  `0 10px 22px rgba(15,23,42,.1)`.
- Charge button glow: `0 4px 14px rgba(22,163,74,.35)`.
- Dense metrics: header bar `56px`, list rows `46px`, cart rows `~48px`,
  pay buttons `44px`, Charge CTA `52px`.

---

## 3. Screen mapping (prototype → app)

Prototype `NAV` groups → `modules.dart`. **Backend** = data source available
to the *local store server* today.

| Prototype screen | Module id | Status today | Backend | Gaps |
|---|---|---|---|---|
| Dashboard | *(none)* | new | reports (cloud) | KPIs are cloud/back-office; not offline |
| **Counter (POS)** | `sell` | `ItemPickerScreen` (live) | Items + Inventory + Cart + Finalize | category, live totals (see §4) |
| New invoice | `invoice` | *(none)* | invoices svc (partial) | doc types, party ledger |
| Sales register | `sales` | `SaleLookupScreen` (live) | Sales lookup | table styling |
| Items | `items` | `ItemPickerScreen` reused | Items | edit/HSN/batch = later phase |
| Parties | `parties` | Placeholder (P8) | none yet | whole feature |
| Purchases | `purchases` | Placeholder (P9) | none yet | whole feature |
| Stock | `inventory` | `InventoryScreen` (live) | Inventory on-hand | moves/adjust/batch tabs |
| Expenses | `expenses` | *(none)* | none yet | whole feature |
| Cashiers | `cashiers` | Placeholder | users (partial) | shift mgmt |
| Day book | `daybook` | *(none)* | GL (cloud) | back-office |
| Chart of accounts | `accounts` | *(none)* | GL (cloud) | back-office |
| Reports | `reports` | Placeholder | reports (cloud) | back-office |
| Settings | `settings` | Placeholder | terminal/local | store/tax/receipt/devices/users |

**Offline-boundary note:** several prototype screens (Dashboard, Day book,
Chart of accounts, Reports) are **cloud/back-office** and per
`desktop-architecture.md` belong in the web admin, not the offline terminal.
On desktop they stay placeholders or are dropped; we won't fake cloud data at
the till.

---

## 4. Counter/POS — this pass

The prototype ships two counter layouts toggled at runtime:

- **Concept B — "Speed"** (default): dense, keyboard-first. Three panes —
  product **list** (SKU · Item · Stock · Price), cart list with qty steppers,
  right rail with totals + payment methods + Charge CTA. Matches the existing
  scanner/`F2`-search focus.
- **Concept C — "Enterprise"**: KPI cards + product **tile grid** + action
  toolbar (Hold bill, Returns, Reprint, Day close).

**Decision:** implement **Speed** as the counter for this pass (right default
for a till terminal); Enterprise/tiles can be a later toggle.

### 4.1 Data wiring (real, not mock)

| UI element | Source |
|---|---|
| Product rows | `itemsControllerProvider` (sku/name/price/taxCategoryId) |
| Stock badge | join `inventoryControllerProvider` on-hand by SKU |
| Add to cart | existing reserve-then-add (`reservationsController` → `cartController.addLine`) |
| Cart rows / qty / remove | `cartController` (`setQuantity`, `removeLine`, `clear`) |
| Subtotal | `cartState.subtotalPreview` |
| Category chips | **no backend field** — omit in pass 1 (see gap) |
| Payment method select | local UI state; hands off to existing tender flow |
| Charge → | existing `CartScreen`/tender → `finalize` |

### 4.2 Fidelity gaps (flagged, not faked)

1. **Category** — `Item` has no `category`; the prototype's colour-coded
   category chips have no data source. Pass 1 omits the chip row (or shows a
   single "All"). Adding a category field is a catalog/proto change for later.
2. **Live tax / round-off / grand total** — authoritative totals come from the
   **server at Finalize** (Development Guide: client never pre-computes tax).
   The Counter rail shows the **subtotal preview** truthfully and labels the
   total row "Subtotal — VAT & total at payment"; the true grand total appears
   in the tender/receipt step. We do **not** invent client-side VAT.
3. **Keyboard hints** (`F1`–`F4` on pay buttons, `↑↓ / +− / Del / Enter`) are
   rendered as visual affordances; only the already-wired `F2`-search and
   scanner behaviour is functional in pass 1.

---

## 5. Fonts (offline-first)

`assets/fonts/` bundles Manrope (500/700/800) and DM Mono (400/500) TTFs,
declared under `flutter: fonts:` in `pubspec.yaml`. No network fetch — the till
must theme correctly offline.

---

## 6. Out of scope for this pass

Enterprise tile layout, all back-office screens, Parties/Purchases/Expenses
features, invoice document types, settings sub-sections. Each lands in its own
phase against this design system.
