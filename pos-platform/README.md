# pos-platform

Offline-first, multi-tenant SaaS POS platform.

> This is **not** a CRUD app — it is a **distributed retail synchronization platform**.
> Competitive advantage is reliable offline-first sync, not UI/reports.

## Layout

```
apps/
  local-store-server/   Go binary running at each store (single Go module)
  cloud-api/            Go cloud backend (multi-tenant)
  desktop-pos/          Flutter desktop POS (Windows + macOS)
  mobile-owner/         Flutter mobile app (owner dashboard)

packages/
  proto/                Protobuf contracts (events, sync, websocket, internal RPC)
  shared-domain/        Language-agnostic domain notes & invariants
  sync-sdk/             Sync engine SDK (shared by clients/servers)
  sdk-go/               Generated Go clients + shared Go helpers

docs/                   Rule docs — sync, inventory, accounting, events, tenant, security
infra/                  docker / kubernetes / terraform
scripts/                local_dev / migrations / backup
```

## Read these first
- [`docs/architecture.md`](docs/architecture.md) — golden rules, invariants, high-level picture
- [`docs/build-order.md`](docs/build-order.md) — phases (core engine before UI)
- The six mandatory rule docs in `docs/`

## Status
**Phase 1 in progress.** `apps/local-store-server` has slices 1–3 complete:
opslog, inventory ledger (with per-SKU lock + oversell guard), payments
ledger (fixed-precision Money + refund linkage), sync_state K/V, atomic-batch
helper, typed Protobuf event envelope (oneof payload, no Any), and a
durable Lamport clock. Generated Go types live under `packages/sdk-go/gen/`.

Next: slice 4 (sync engine — retry + batching + HTTP transport). Dart codegen
is intentionally deferred to Phase 2 (desktop-pos). See `docs/build-order.md`.

## Common commands
```
make help          # list targets
make proto-gen     # regenerate protobuf (TODO)
make openapi-gen   # regenerate OpenAPI clients (TODO)
make test          # run all Go tests
make fmt           # format all Go code
```
