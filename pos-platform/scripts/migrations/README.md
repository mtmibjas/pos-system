# scripts/migrations

DB migrations for both local (SQLite) and cloud (PostgreSQL).

## Tooling
[`golang-migrate`](https://github.com/golang-migrate/migrate) for both backends, with separate migration trees:
- `local/` — SQLite schema (operations_log, inventory_movements, payments, sync_state, …)
- `cloud/` — PostgreSQL per-tenant schema (mirrors local, plus reporting tables)

Migrations are **forward-only** (no `down`). Rollback = a new forward migration. See `docs/tenant-rules.md`.

## Rule
Tenant DBs are created from the same migration set. Never hand-edit a tenant DB.

## Status
Empty.
