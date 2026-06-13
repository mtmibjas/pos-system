# Build Order

> **DO NOT start with UI.** Development Guide §21.

Phases are sequential. Do not start phase N+1 until phase N is correct and tested.

---

## Phase 1 — Core engine (current target)

Build, in this order:

1. **operation_log** — SQLite schema, append-only writes, UUID idempotency.
2. **sync engine** — batching, exponential backoff, idempotent retry, max-retry policy.
3. **inventory ledger** — `inventory_movements` (append-only), derivation of stock-on-hand.
4. **local DB architecture** — WAL mode mandatory, migrations, atomic batches.
5. **event contracts** — finalize `packages/proto/pos/v1/*.proto`, wire codegen.

No UI. No Flutter. No cloud. Just the engine + Go tests + chaos tests.

## Phase 2 — Basic POS

- Sales screen
- Inventory screen
- Receipt printing
- Barcode scanning
- Local persistence (talks to phase-1 engine)

Single counter only. No cloud sync yet.

## Phase 3 — Sync

- Cloud sync
- Retry logic
- Idempotency at the cloud
- Reconnect handling
- Storm protection (jitter on reconnect)

## Phase 4 — Multi-counter

- WebSocket updates (`InventoryUpdate`, `CartUpdate`)
- Inventory locks for last-item races
- Live cart visibility

## Phase 5 — Accounting & Reports

- Ledger (derived from events)
- Tax reports
- Owner dashboard (mobile-owner app)

---

## DO NOT BUILD EARLY (Development Guide §23)

- HR / payroll
- CRM
- Loyalty
- Advanced analytics
- Marketplace

These are real product asks for later. They are out of scope today.

## Priorities at every phase

1. Sync correctness
2. Inventory consistency
3. Reliability (no data loss)
4. Observability (every important event logged — see `docs/event-contracts.md`)
5. UX
6. Performance (only after the above are solid)
