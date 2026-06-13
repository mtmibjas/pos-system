# cloud-api

Cloud backend (Go). Multi-tenant SaaS API.

## Responsibilities
See Development Guide §7 and `docs/architecture.md`.

- Authentication (JWT + refresh rotation)
- Tenant management — tenant resolved via **JWT claim** (`tenant_id`). See `docs/tenant-rules.md`.
- Reporting + cross-branch aggregation
- Mobile dashboard APIs
- Global sync ingestion — must be idempotent. See `docs/sync-rules.md`.

## Multi-tenant data model
**Separate PostgreSQL database per tenant** (Development Guide §5).
Routing happens after JWT validation; no cross-tenant query is ever issued.

## Status
**Phase 1 stub** — an in-process HTTP server hosting only `POST /v1/sync/batches`
(`application/x-protobuf` in/out). No persistence, no auth, no tenant routing.
Its job is to give `local-store-server`'s sync engine a real HTTP peer to talk
to during dev + integration tests.

- Tracks `batch_id` in-process so a retried batch correctly returns `STATUS_DUPLICATE`.
- `X-Test-Force` request header drives every ack branch deterministically. Values:
  `applied` (default), `duplicate`, `rejected`, `retry_later`, `500` (transient), `400` (permanent).
- `GET /healthz` → `200 ok`.

```sh
# from this directory
go run . --addr :8080
```

Real cloud features (JWT, tenant routing, PostgreSQL per tenant, reporting,
mobile dashboards) land in Phase 2.
