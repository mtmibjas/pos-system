# Desktop POS — Backend Tasks to De-Mock the Design Screens

> **Status: DRAFT.** All 14 Dostop design screens are now implemented in the
> Flutter `apps/desktop-pos` (see `docs/desktop-pos-ui-design.md`). The
> counter-facing ones (Counter/POS, Stock, Sales lookup) run on **live**
> store-server data; the rest currently render the **prototype's static mock
> data** for visual completeness. This doc lists, per screen, the backend work
> needed to make each real — grouped by effort/ownership.

Legend: **[S]** store-server (offline-boundary), **[C]** cloud-api / GL
(back-office), **[P]** proto/contract change (`packages/proto`, bump
`schema_version`).

---

## A. Live already
- **Counter/POS** — items (`ItemService.ListItems`) + on-hand join
  (`InventoryService.ListOnHand`) + cart + reserve + tender/finalize.
- **Stock** — `InventoryService.ListOnHand` (+ realtime availability).
- **Sales register (lookup)** — `SaleService.GetSale` → refund/void.
- **Expenses** — ✅ **now live.** New `ExpenseService` (`ListExpenses` /
  `CreateExpense`), `internal/expenses` store + `000013_expenses` migration,
  seeded by `seed-demo`. Screen reads `expensesControllerProvider`. Remaining
  to finish the domain: tenant-configurable categories, VAT auto-split, and GL
  posting on create (see §C original entry).

## B. Small — extend existing store-server backends

### Items (master)  `features/items/items_management_screen.dart`
- **[P]** Add `Item` fields: `category`, `hsn_code`, `barcode`, `cost_price`,
  `reorder_point`, repeated `variants`, `batch_tracking_enabled`. Bump
  `schema_version`.
- **[S]** `ItemService.CreateItem` / `UpdateItem` (today only `ListItems`).
- **[S]** Feed `reorder_point` into the inventory projection so the low-stock
  badge fires on real thresholds (not the current heuristic ≤8).
- Optional: promote `category` to a first-class entity with its own CRUD to
  stop catalog/filter drift.

### Stock — extra tabs (moves / adjust / batch)
- **[S]** Inventory **movement history** read API (per-SKU ledger of receipts,
  sales, adjustments) for the Moves tab.
- **[S]** `AdjustStock` RPC (damage/correction) emitting an inventory event.
- **[P/S]** Batch/expiry tracking model for the Batch tab.

### Sales register — full table (beyond single lookup)
- **[S]** Paginated `ListSales(from,to,cursor)` returning per-invoice
  taxable/VAT/pay-method/status for the register table.

### Cashiers  `features/cashiers/cashiers_screen.dart`
- **[S]** Source cashier list from the existing **users** store (roles already
  tracked in auth).
- **[S]** `ShiftService` — open/close shift per cashier per counter (persisted).
- **[S]** Cash-drawer sessions (opening float, closing count) per shift.
- **[S]** Counter registry (`counter_id → assigned_cashier_id`), updated on
  clock-on (device registration already mints counter ids).
- **[S]** Per-cashier today's-sales projection (JSON read-side by `cashier_id`
  + calendar day).

### Settings  `features/settings/settings_screen.dart`
- **[S]** `TerminalConfig` persistence (partly exists from the desktop
  architecture baseline) — scanner/drawer/display flags, printer target.
- **[S]** `TaxConfig` (VAT slabs, SSCL, inclusive/round-off) consumed by the
  finalize tax engine.
- **[S]** `ReceiptConfig` (auto-print, VAT-summary, SMS) — auto-print gates the
  ESC/POS path (P7).
- **[S]** `PaymentConfig` (methods offered, card-terminal device id).
- **[S/P6]** User & role management — the users YAML→DB migration (P6) must
  land before live CRUD; PIN / void-approval need auth-middleware enforcement.

## C. Large — new store-server domains (event-sourced + sync)

### Parties + ledger  `features/parties/parties_screen.dart`  ← flagship LK feature
- **[P/S]** `Party` entity (id, name, type, phone, address, credit limit, terms,
  VAT reg) + `ListParties` / `GetParty`.
- **[S]** Append-only `LedgerEntry` projection (invoice-due, payment-in,
  bill-out, payment-sent) with running per-party balance.
- **[P/S]** Credit-sale linkage: optional `party_id` on invoices; finalize path
  debits Accounts Receivable and writes the `due` entry.
- **[S]** `RecordPayment` (customer) / `PaySupplier` (supplier) RPCs.
- **[S]** Sync-safe: idempotent by `batch_id`, LWW/CRDT for concurrent
  multi-counter edits (see `project_sync_batch_id_invariant`).

### New invoice / documents  `features/invoice/invoice_screen.dart`
- **[P/S]** Document service for INV/QT/DC/CN/DN with a draft→issued state
  machine; idempotency via client draft id.
- **[S]** Atomic per-type, per-tenant sequential numbering (`INV-NNNN`) so
  offline terminals can't collide.
- **[S]** Party ledger linkage on issue (AR debit / Sales credit) + credit-limit
  check.
- **[S]** Server-authoritative tax engine: VAT back-calc + SSCL by HS code and
  inclusive/exclusive setting (client preview is indicative only). ← P7
- **[S]** Print/PDF dispatch (ESC/POS to counter printer, or rendered PDF for
  share).

### Purchases  `features/purchases/purchases_screen.dart`
- **[S]** `PurchaseService` — `CreateBill` / `ListBills(filter,cursor)` /
  `UpdateBillStatus`.
- **[S]** Supplier linkage (party id from the Parties registry).
- **[S]** Goods-receipt → inventory **stock-in** events (credit on-hand).
- **[S]** `RecordBillPayment` → supplier ledger + Accounts Payable.
- **[S]** Flow through existing sync/batch machinery.

### Expenses  `features/expenses/expenses_screen.dart`
- **[P/S]** `Expense` model (date, category, description, payment_mode, amount,
  vat) + `ExpenseService` (Create/List/Delete).
- **[S]** Tenant-configurable expense categories.
- **[S]** Payment-mode → asset-account mapping; VAT (input tax) split.
- **[S/C]** GL auto-posting: creating an expense writes a balanced journal
  entry (transactional, server-side); participates in sync.

## D. Cloud / back-office — arguably belong in the web admin

> Per the offline-boundary design, the GL lives cloud-side and is never held on
> the till. These screens render static data now; the product decision is
> whether they stay on desktop (always-online, "Last synced…" stale banner when
> offline) or move to the Phase-6 web admin. **No local store.**

- **Dashboard** — daily summary projections (sales, low-stock counts, party
  balances, weekly buckets, drawer cash). Some pieces are store-local
  (inventory), most are aggregates.
- **Day book** `[C]` — GL journal read API (paginated by date/tenant).
- **Chart of accounts** `[C]` — GL accounts + period balances; depends on the
  GL projection worker (P5 scaffolded).
- **Reports** `[C]` — P&L, Balance sheet, GSTR-1/3B, sales register, party
  ledger, with date-range params. Note the GL cursor ordering caveat
  (`project_projection_ordering`). Cloud reports service partly exists (P5).

---

## Cross-cutting
- **Tax engine (VAT + SSCL)** underpins Invoice, Settings, Reports, Expenses —
  it's the P7 centerpiece; build it once, server-authoritative.
- **Sync invariants** — every new mutating domain must honor `batch_id`
  idempotency and the store→cloud pipeline.
- **Offline boundary** — resolve the desktop-vs-web-admin home for section D
  before investing in their backends.
