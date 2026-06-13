# Architecture

> **This is not a CRUD app. It is a distributed retail synchronization platform.**
> Your competitive advantage is **reliable offline-first sync**. Engineer for that.

---

## Golden Rules (NEVER violate)

From Development Guide §1.

1. Local store always works.
2. Cloud is asynchronous.
3. Local operations are the source of truth.
4. Internet is optional.
5. Sync must be idempotent.
6. Inventory changes are append-only ledger events.
7. Finalized invoices must never be edited.
8. Multi-counter consistency is owned by the local store server.
9. Sync events are more important than current-state snapshots.
10. The event log is the heart of the system.

## Invariants (CRITICAL — Development Guide §16)

- Finalized invoice cannot change.
- Inventory ledger is append-only.
- Sync operations are idempotent.
- Refunds are reversal events (never destructive edits).
- Local completed sales are never rejected by the cloud.

---

## High-level picture

```
                  CLOUD PLATFORM (one PostgreSQL DB per tenant)

                         API Gateway / Auth (JWT)
                                  ↓
                            Tenant Service
                                  ↓
                            Reporting APIs
                                  ↓
                           Global Sync APIs
                                  ↓
                              PostgreSQL

  ─────────────────────────────────────────────────────────────────

                  STORE LEVEL (every store, even single-counter)

                          Flutter POS Clients
                                  ↓  (HTTP + WebSocket)
                          Local Store Server (Go)
                                  ↓
                            SQLite (WAL)
                                  ↓
                            Sync Worker (Go)
                                  ↓
                              Cloud APIs
```

## Components

| Component             | Lang    | Talks to                                  | Responsibility |
|-----------------------|---------|--------------------------------------------|----------------|
| `desktop-pos`         | Flutter | local-store-server (HTTP + WS)            | UI for cashiers |
| `local-store-server`  | Go      | desktop-pos clients, cloud-api (sync)     | Source of truth at the store |
| `cloud-api`           | Go      | local-store-servers, mobile-owner         | Auth, sync ingest, reports |
| `mobile-owner`        | Flutter | cloud-api only                            | Owner dashboards |

## Data flow — a sale

1. Cashier presses "Complete sale" on `desktop-pos`.
2. `desktop-pos` POSTs the sale to `local-store-server` (localhost or LAN).
3. `local-store-server`:
   a. Writes `sale_created`, `payment_added`, `inventory_adjusted` as an **atomic batch** to `operations_log`.
   b. Derives new stock-on-hand from `inventory_movements` (append-only).
   c. Broadcasts `InventoryUpdate` over WebSocket to other counters.
   d. Returns OK to `desktop-pos`. **Sale is final right here — independent of internet.**
4. `sync worker` (inside local-store-server) batches the operations and POSTs them to `cloud-api`.
5. `cloud-api` ingests the batch idempotently (operation_uuid dedupe), persists to that tenant's PostgreSQL, and acks.

If step 4–5 fail, retry forever with exponential backoff. The sale was already final at step 3.

## Multi-tenancy

- **One PostgreSQL database per tenant** (Development Guide §5).
- Tenant is resolved via **JWT claim** (`tenant_id`) — not subdomain, not header.
- Tenant routing happens after JWT validation. Cross-tenant queries are physically impossible (separate DBs).

## Discovery (multi-counter LAN)

- Single counter: clients connect to `localhost:8080`.
- Multi-counter: local-store-server advertises via **mDNS**; clients auto-discover. If mDNS fails, fall back to manual IP entry. See `docs/discovery.md`.

## Contracts

- **Protobuf** for events, sync, WebSocket, internal RPC. Source of truth in `packages/proto`.
- **OpenAPI** for REST (cloud-api dashboards, admin, mobile-owner).
- See `docs/contracts-strategy.md`.

## See also

- `docs/build-order.md` — what to build when (and what NOT to build early)
- `docs/sync-rules.md`, `docs/inventory-rules.md`, `docs/accounting-rules.md`, `docs/event-contracts.md`, `docs/tenant-rules.md`, `docs/security-rules.md`
