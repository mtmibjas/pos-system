# Tenant Rules

> **One PostgreSQL database per tenant.** Tenant resolved via **JWT claim**.

## Why DB-per-tenant (Development Guide §5)

- Better isolation (a slow tenant cannot starve others)
- Easier backup + restore (per-tenant `pg_dump`)
- Easier migration (per-tenant rollout)
- Better security (physical separation; a bug cannot leak data across tenants)
- Easier scaling (move heavy tenants to bigger DBs)
- Enterprise-friendly (some customers contractually require their data in their own DB)

## Routing

```
HTTP request
  ↓
[Middleware] Validate JWT signature + expiry
  ↓
Extract `tenant_id` claim from JWT
  ↓
[Middleware] Resolve tenant_id → DB connection (cached pool, capped per-process)
  ↓
Inject *sql.DB / *pgxpool.Pool into request context
  ↓
Handler runs queries against THAT pool ONLY
```

**Required JWT claims** (`docs/security-rules.md` is the canonical list):
- `sub` — user_id
- `tenant_id` — UUID; tenant resolution key
- `role` — `cashier` / `manager` / `owner` / `admin`
- `device_id` — registered device fingerprint
- `exp`, `iat`, `jti`

If `tenant_id` is missing, malformed, or unknown → **401**. Never default to "first tenant" or "no tenant". Never read tenant from query string, header, or subdomain.

## Forbidden patterns

- ❌ `SELECT * FROM sales WHERE tenant_id = ?` — no tenant column on cross-tenant DBs in the first place.
- ❌ Shared cache key without tenant prefix (see Cache rules below).
- ❌ Cross-tenant query of any kind. There is no admin endpoint that "looks across tenants" — instead, the admin app talks to a dedicated, separate analytics service (Phase 5+) that aggregates from per-tenant snapshots.
- ❌ Reusing a connection pool across tenants in a single request lifecycle.

## Cache rules

Any cache key (in-memory, Redis, on-disk) MUST be prefixed with `tenant_id`:

```
key = f"{tenant_id}:{logical_key}"
```

Code review rejects un-prefixed cache keys. A linter rule will enforce this once we have caching.

## Tenant provisioning

- A tenant is created via an admin API. Provisioning runs the migration set against a newly created PostgreSQL database.
- Migration sets are versioned. **All** tenant DBs run the same migrations in the same order.
- Migrations are **forward-only** (no `down`). Rollback is by deploying a forward fix.

## Tenant deletion

- Soft-delete first (status = `disabled`); the DB stays for 30 days.
- Hard-delete after the retention window: `DROP DATABASE tenant_<uuid>`. Backups are also expired per the tenant's data-retention agreement.

## Multi-tenant risks (Development Guide §13)

| Risk                  | Mitigation |
|-----------------------|------------|
| Tenant data leakage   | DB-per-tenant + JWT-routed connection pool; no tenant_id in queries. |
| Shared cache pollution| Tenant-prefixed keys; linter rule. |
| Auth token misuse     | Short-lived access tokens + refresh rotation + device binding. See `docs/security-rules.md`. |
| Noisy-neighbour       | Per-tenant rate limits at the API gateway; long-running reports run async on per-tenant workers. |

## Cross-tenant operations (legitimate ones)

There are a few legitimate cross-tenant needs (platform analytics, billing). They run through a **separate** ingest pipeline that pulls anonymized/aggregated data into a dedicated DB. The application code path NEVER opens a cross-tenant connection.

## Tests required

- Unit: tenant-id extraction from JWT (happy path, missing claim, malformed claim, wrong sig).
- Integration: a handler with a forged tenant_id is rejected; cache keys are tenant-prefixed.
- Security: fuzz JWT to confirm we don't leak across tenants on edge cases (clock skew, kid swap, etc.).
