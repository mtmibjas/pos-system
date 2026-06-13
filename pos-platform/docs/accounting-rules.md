# Accounting Rules

> **Finalized invoices cannot change.** Refunds and corrections are new events.

## Core invariants

- Invoices are immutable once finalized.
- Payments are a separate ledger from invoices (so split + partial payments + refunds all compose cleanly).
- Refunds are reversal events, never destructive edits.
- All monetary amounts use fixed-precision `Money` (`currency_code`, `units`, `nanos`). **No floats. Ever.**

## Tables

### `invoices`

| Column          | Type    | Notes |
|-----------------|---------|-------|
| `invoice_id`    | TEXT PK | UUID |
| `sale_id`       | TEXT    | links to the sale event |
| `store_id`      | TEXT    | |
| `subtotal`      | TEXT    | serialized Money |
| `tax_total`     | TEXT    | serialized Money |
| `grand_total`   | TEXT    | serialized Money |
| `status`        | TEXT    | `draft` / `finalized` / `voided` |
| `finalized_at`  | INTEGER | unix nanos; once set, the row is immutable except for `status → voided` |
| `created_at`    | INTEGER | |

Voiding an invoice issues a `voided` status + a compensating refund — it does **not** erase the original.

### `payments`

Separate from invoices. Supports split payments, partial payments, refunds.

| Column              | Type    | Notes |
|---------------------|---------|-------|
| `payment_id`        | TEXT PK | UUID |
| `invoice_id`        | TEXT    | |
| `method`            | TEXT    | `cash` / `card` / `upi` / `wallet` / `store_credit` / ... |
| `amount`            | TEXT    | serialized Money (signed: positive = pay, negative = refund) |
| `reference`         | TEXT    | gateway txn id, cheque number, etc. |
| `parent_payment_id` | TEXT    | nullable; refunds reference the original payment |
| `created_at`        | INTEGER | |

Sum of `amount` for an invoice = balance owed. `0` = paid in full. Positive = unpaid. Negative = over-refunded (allowed; surfaces a warning event).

## Tax

Tax is **data-driven**. The engine is dumb; the rules live in tables. Adding a new region, rate, or holiday-rule never requires a code change.

### Engine

- Tax is computed at the **line level** inside the local-store-server, then summed at the invoice level.
- The engine reads tenant-scoped tax data, evaluates applicable rules for each line, and emits per-line tax breakdowns.
- The engine is deterministic and pure: same inputs → same outputs, no side effects.

### Tables (per-tenant)

| Table             | Purpose |
|-------------------|---------|
| `tax_jurisdictions` | Country / state / city codes; hierarchy. |
| `tax_rates`         | `(jurisdiction_id, rate_code, percentage, effective_from, effective_to)`. Rates are time-bounded — never edit a past row; insert a new one with a new `effective_from`. |
| `tax_categories`    | Product taxability classes (e.g. `standard`, `food`, `tax_exempt`, `alcohol`). |
| `tax_rules`         | Maps `(jurisdiction_id, tax_category_id) → rate_code(s)`. Multiple rates can apply (e.g. state + city). |
| `product_tax_category` | Per-tenant product → tax_category mapping. |
| `tax_exemptions`    | Customer-level exemptions (e.g. resale certificate); referenced from a sale when applicable. |

All tax tables are append-mostly. **Never edit a past `tax_rates` row** — supersede with a new effective period. This preserves the historical record for audits.

### Invoice snapshot (mandatory)

At invoice finalization, the engine **snapshots** the applied tax data onto the invoice:

```
invoice_tax_snapshot {
  invoice_id
  computed_at
  engine_version           // bump if computation logic changes
  rates_applied: [
    { jurisdiction_code, rate_code, percentage, taxable_amount, tax_amount }
  ]
  rules_version_hash       // hash of tax_rules rows referenced at compute time
}
```

If tax rates change tomorrow, yesterday's finalized invoice still shows yesterday's tax — the snapshot is immutable along with the invoice itself.

### Reprice / preview

UI may show a tax preview before finalization. Previews are computed by the same engine but are **not** snapshotted. Only finalization persists a snapshot.

### Cross-jurisdiction examples

- Multi-rate stacking (state + city) → multiple entries in `rates_applied`.
- Compound vs additive tax (where tax-on-tax applies) → declared per `tax_rule`; the engine respects the declared computation mode.
- Rounding policy (per-line vs per-invoice rounding) → declared at the tenant level.

### Engine versioning

`engine_version` is recorded on every snapshot. If we ever ship a bug fix to the engine that would change historical computations, **we do not retro-recompute** — past invoices stay at their snapshot version. New invoices use the new engine.

## Double-entry posture (Phase 5)

Phase 5 introduces a general ledger **derived** from the event log — same pattern as inventory. Cloud-side only (the local store server never writes journal rows; local stays focused on transactions + sync). Never write directly to ledger tables; the only writer is the replay worker that consumes `events`.

### Scope decisions for Phase 5

- **COGS is deferred.** Unit-cost tracking would require either a schema bump on `InventoryAdjusted` or a moving-average projection on the cloud. We post Revenue / A/R / Tax / Payment-clearing only; `InventoryAdjusted` events do NOT post to the GL in Phase 5. Inventory remains its own sub-ledger.
- **Receives don't post.** `InventoryAdjusted` with `reason=receive` has no supplier or invoice link in the current event contract — until a Purchases module exists, receives are inventory-only with no GL impact. A/P is out of scope.
- **No period close.** Reports compute on-the-fly from journal rows. Locking a period (no more posts after close) is a Phase 6+ feature.
- **Single currency per tenant.** Multi-currency journals are out of scope.

### Account taxonomy (seed CoA)

Single hardcoded chart of accounts for Phase 5; per-tenant CoA customization deferred. Tax Payable uses one sub-account per `tax_category_id` (e.g. `2100.std`, `2100.food`) — this is mandatory for the tax report to split correctly.

| Code | Account | Type |
|---|---|---|
| 1000 | Cash | Asset |
| 1100 | Card Clearing | Asset |
| 1110 | UPI Clearing | Asset |
| 1200 | Accounts Receivable | Asset |
| 1300 | Inventory | Asset (informational; not posted in Phase 5) |
| 2000 | Accounts Payable | Liability (not posted in Phase 5) |
| 2100.* | Tax Payable (sub per tax_category_id) | Liability |
| 4000 | Revenue | Income |
| 5000 | COGS | Expense (not posted in Phase 5) |
| 5100 | Inventory Shrinkage | Expense (not posted in Phase 5) |

Payment-method → clearing account mapping:

| `method` (string in event) | Dr account on PaymentAdded |
|---|---|
| `cash` | 1000 Cash |
| `card` | 1100 Card Clearing |
| `upi` | 1110 UPI Clearing |
| any other | 1100 Card Clearing (fallback; logged as warning) |

### Event → journal mapping

Each row below is one Journal Entry (JE); the entry's lines balance (Σ Dr = Σ Cr).

| Event | Dr | Cr | Notes |
|---|---|---|---|
| `SaleCreated` | A/R: grand_total | Revenue: subtotal; Tax Payable[cat]: per-line tax sum | One JE per sale. Tax Payable split is per `tax_category_id`; lines with no category post to `2100.unclassified`. |
| `PaymentAdded` | Cash/Card-Clearing/UPI-Clearing (per `method`): amount | A/R: amount | One JE per payment. |
| `PaymentRefunded` | A/R: amount | Same clearing account as the original payment | Looked up via `original_payment_id` → original `PaymentAdded.method`. |
| `SaleVoided` | Reverses every JE previously posted under `sale_id` (sale + payments). | | Posts in the **current** period (event's `occurred_at`), not back-dated. Reversal is by re-posting flipped lines with the void's own `operation_id` — original JEs stay untouched. |
| `SaleRefunded` | Revenue: subtotal; Tax Payable[cat]: tax_total | A/R: grand_total | Partial refunds OK; only the refunded magnitudes post. |
| `SaleRefunded.tenders[*]` (child `RefundTender`) | A/R: amount | Clearing account per `method` | One JE per tender returned. |
| `InventoryAdjusted` | — | — | Deferred (see Scope decisions). |
| `StockTransferred` | — | — | Internal location move; sub-ledger, not GL. |
| `SyncCompleted` / `SyncFailed` / `UserLoggedIn` | — | — | Operational events; not GL-relevant. |

### Posting invariants (enforced at insert time)

1. **Every JE balances.** Σ Dr lines = Σ Cr lines, in the same currency. Insert must fail otherwise.
2. **Idempotent on `(operation_id, je_seq)`.** Replaying the same event produces no new rows. `je_seq` distinguishes the multiple JEs a single event may produce (e.g. `SaleRefunded` produces one JE + one per refund tender).
3. **Post date = event `occurred_at`.** This drives period bucketing for reports. Origin wall-clock is acceptable here because period reports are bucketed (day/month) — the small clock skew across stores doesn't move buckets.
4. **Void and refund post in the current period.** Even if the original sale was prior. Audit trail keeps both the original JE and its reversal.
5. **Sign convention.** Amounts on journal_lines are always positive magnitudes; direction is encoded by the `side` column (`debit` | `credit`). Refunds and voids reverse direction; they never carry negative amounts.

## Reports

All reports are derived live from `journal_entries` + `journal_lines` (and source `events` where richer detail is needed, like top-item SKUs).

| Report | Source | Group by | Filters | Phase |
|---|---|---|---|---|
| Sales summary | JE rows touching Revenue + A/R; SaleVoided/SaleRefunded reversals reduce | day / week / month | from, to, store_id | 5.3 |
| Sales by payment method | JE rows touching clearing accounts | method, day | from, to, store_id | 5.3 |
| Tax summary | JE rows touching `2100.*` | tax_category, period | from, to, store_id | 5.3 |
| Top items | `SaleCreated.lines` − `SaleRefunded.lines` (event-level, not GL) | sku | from, to, store_id, limit | 5.5 |
| Low stock | last `InventoryAdjusted` per (store, sku); compare to threshold | sku | store_id, threshold | 5.5 |

**No pre-aggregation** in 5.2/5.3 — compute on read. If perf demands it, materialized rollups arrive in 5.5+ and the contract is "rebuildable from journal_entries at any time".

## Phase 5 schema additions

### Proto bump — per-line tax category in events

`FinalizeSaleLine` already carries `tax_category_id`, but the corresponding `SaleLine` in `events.proto` does not. Without it, the cloud cannot split Tax Payable by category, which kills the tax report.

Required change (one slice, before 5.2 starts):

```proto
// events.proto
message SaleLine {
  string sku = 1;
  string description = 2;
  int64 quantity = 3;
  Money unit_price = 4;
  Money line_total = 5;
  string line_id = 6;
  string tax_category_id = 7;   // ← NEW; empty = "unclassified", posts to 2100.unclassified
  Money line_tax = 8;            // ← NEW; per-line tax magnitude. Sum across lines = SaleCreated.tax_total.
}

message RefundLine {
  string sale_line_id = 1;
  string sku = 2;
  int64  quantity = 3;
  bool   restock = 4;
  Money  unit_price = 5;
  Money  line_total = 6;
  string tax_category_id = 7;   // ← NEW; copied forward from the original sale line at refund time
  Money  line_tax = 8;            // ← NEW; per-line refund tax magnitude
}
```

Bump `EventEnvelope.schema_version` for the two affected events when the local-store emitter starts populating these fields. Cloud-side reader treats missing fields as `tax_category_id=""` (→ unclassified bucket) for events emitted by older binaries — backwards compatible during rollout.

### New tables (cloud-api, sqlite portable to Postgres)

```sql
CREATE TABLE accounts (
    code         TEXT    PRIMARY KEY,             -- e.g. "1000", "2100.std"
    name         TEXT    NOT NULL,
    type         TEXT    NOT NULL                 -- 'asset'|'liability'|'income'|'expense'
        CHECK (type IN ('asset','liability','income','expense'))
);

CREATE TABLE journal_entries (
    je_id              TEXT    PRIMARY KEY,         -- UUID
    operation_id       TEXT    NOT NULL,            -- source event's idempotency key
    je_seq             INTEGER NOT NULL,            -- 0..N within one event
    tenant_id          TEXT    NOT NULL,
    store_id           TEXT    NOT NULL,
    posted_at_unix_ns  INTEGER NOT NULL,            -- = event.occurred_at
    source_event_type  TEXT    NOT NULL,            -- 'sale_created' | ...
    memo               TEXT,
    UNIQUE (operation_id, je_seq)                   -- idempotency anchor
);

CREATE INDEX idx_je_tenant_period ON journal_entries (tenant_id, posted_at_unix_ns);
CREATE INDEX idx_je_store_period  ON journal_entries (tenant_id, store_id, posted_at_unix_ns);

CREATE TABLE journal_lines (
    line_id        INTEGER PRIMARY KEY AUTOINCREMENT,  -- BIGSERIAL in Postgres
    je_id          TEXT    NOT NULL REFERENCES journal_entries(je_id) ON DELETE RESTRICT,
    account_code   TEXT    NOT NULL REFERENCES accounts(code),
    side           TEXT    NOT NULL CHECK (side IN ('debit','credit')),
    currency_code  TEXT    NOT NULL,
    units          INTEGER NOT NULL,                  -- magnitude (positive)
    nanos          INTEGER NOT NULL,                  -- magnitude (positive)
    CHECK (units >= 0 AND nanos >= 0)
);

CREATE INDEX idx_jl_account_je ON journal_lines (account_code, je_id);
```

`(operation_id, je_seq)` is the idempotency anchor — the replay worker uses `INSERT … ON CONFLICT DO NOTHING` (or a SELECT-then-INSERT under the same txn for SQLite) so re-processing the events stream produces no duplicates.

Balance enforcement is at the replay-worker layer (it constructs the lines and verifies Σ Dr = Σ Cr per JE before inserting), not via a CHECK — CHECK across rows isn't a SQLite primitive.

## Refunds

- A refund references the **original payment** via `parent_payment_id`.
- A refund **does not** edit the invoice. The invoice stays finalized; the payment ledger now nets to a smaller amount.
- If goods were returned, an `InventoryAdjusted` event also fires with `reason = 'refund'`.

## Edge cases (Development Guide §13)

| Case                                | Handling |
|-------------------------------------|----------|
| Payment success but invoice failure | Both must be in the same atomic sync batch. If the batch failed at the cloud, retry. If it failed locally, neither is persisted. |
| Split payments                      | Multiple `payments` rows with the same `invoice_id`. |
| Refund after sync                   | New event (`PaymentRefunded`), normal sync flow. |
| Duplicate payment retry             | Idempotency by `payment_id`. Cloud returns `DUPLICATE`, client clears queue. |

## Tests required

- Unit: Money arithmetic (no float drift), tax calc per region, refund netting.
- Integration: split payment + partial refund flow, invoice immutability after finalize, tax-rule snapshotting.
- Chaos: cloud rejection of a refund (must not be allowed; cloud may only conflict-resolve, not reject).
