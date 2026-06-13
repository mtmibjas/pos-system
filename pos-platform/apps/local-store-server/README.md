# local-store-server

Go binary that runs at every store (even single-counter ones).

## Responsibilities
See Development Guide §7 and `docs/architecture.md`.

- Local inventory ownership (append-only ledger — see `docs/inventory-rules.md`)
- Local transaction processing
- WebSocket real-time updates between counters
- Receipt generation
- Local sync queue (`operations_log` — see `docs/sync-rules.md`)
- Offline-first operation
- Counter synchronization (mDNS discovery + manual IP fallback — see `docs/discovery.md`)

## Deployment
Single Go binary + SQLite file (WAL mode). See Development Guide §24.

## Internal packages
- `internal/db` — SQLite open with mandatory PRAGMAs (incl. `_txlock=immediate`), golang-migrate wiring, embedded migrations.
- `internal/txn` — `Apply(ctx, db, fn)` atomic-batch helper. All multi-table writes go through here.
- `internal/opslog` — Data layer for `operations_log` (append-only, idempotent insert, status transitions, tx-aware `InsertTx`). `Payload` is the serialized `*posv1.EventEnvelope` (wire bytes).
- `internal/inventory` — Data layer for `inventory_movements` (append-only, per-(store,sku) mutex, oversell guard with policy hook, tx-aware `AppendTx`).
- `internal/payments` — Data layer for `payments` (fixed-precision `Money` — no floats, idempotent insert, refund linkage, balance derivation, tx-aware `InsertTx`).
- `internal/syncstate` — K/V wrapper over `sync_state` (typed getters/setters for time, uint64, UUID).
- `internal/events` — `Pack(payload, meta) -> (*EventEnvelope, []byte)` and `Unpack(wire)` — typed boundary between domain code and the opslog wire format. Drives `event_type` from the oneof case.
- `internal/clock` — Monotonic Lamport counter persisted via syncstate; supports `Next`, `Observe` (for inbound peer ops), and `Peek`.
- `internal/sync` — Sync engine. `Backoff` (full-jitter exponential), `Batcher` (respects pre-existing `batch_id` grouping for atomic sale trios), `HTTPTransport` (POSTs `application/x-protobuf` to `/v1/sync/batches`; classifies 5xx/429/network as transient and 4xx as permanent), and `Worker` (tick + wake loop with per-batch retry, ack-status handling for APPLIED/DUPLICATE/REJECTED/RETRY_LATER, terminal `MarkFailed` after exhausted retries, durable `last_sync_at` + `failed_ops_count` in syncstate).
- `internal/integration` — Cross-layer atomic-batch tests proving sale finalization is all-or-nothing AND that the persisted payload round-trips back to a typed `SaleCreated`. Also includes E2E sync-worker tests driving the real HTTP transport against an in-process stub.

## Quickstart
```sh
# from repo root
make test          # runs all packages' tests
make build         # builds the binary

# run it (creates ./pos-local.db with migrations applied)
POS_LOCAL_DB=./pos-local.db ./local-store-server
```

## Status
**Phase 1 Slice 4** complete — sync engine end-to-end:
- `opslog.MarkRetry` (transient → re-queue) + `BatchID` accepted at insert time so SaleService can ship its three-op atomic group together.
- Full-jitter exponential backoff (`internal/sync/backoff.go`).
- `HTTPTransport` with transient/permanent classification and a pluggable `AuthHeaderFunc` (no-op in Phase 1, wired for JWT in Phase 1.5/2).
- `Batcher` respects pre-existing `batch_id` grouping.
- `Worker` drives the loop: tick + wakeup + initial drain, per-batch retry with backoff, ack-status handling, terminal `MarkFailed` after exhausted retries, durable `last_sync_at` / `last_sync_batch_id` / `failed_ops_count` in `sync_state`.
- `main.go` wires the worker — it now blocks on the engine and shuts down cleanly on SIGINT/SIGTERM.
- Companion `apps/cloud-api` minimal stub binary with in-process duplicate detection and an `X-Test-Force` header for driving worker scenarios.
- E2E integration test in `internal/integration/sync_e2e_test.go`.

Configuration:
- `POS_LOCAL_DB` — SQLite path (default `pos-local.db`).
- `POS_CLOUD_URL` — base URL of the cloud sync endpoint (default `http://localhost:8080`).
- `POS_TENANT_ID` — tenant id stamped on outbound batches (default `tenant-A`).

Coming next (Phase 2): `SaleService` to actually enqueue sale_created + inventory_adjusted + payment_added under one batch, the HTTP/WebSocket API, mDNS discovery.

Note: Dart codegen is intentionally deferred to Phase 2 (desktop-pos / mobile-owner).
