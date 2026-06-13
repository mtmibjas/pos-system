# Phase 6 — Web Admin Dashboard (admin-dashboard)

React + Vite SPA served alongside cloud-api. Browser-based admin for
tenant owners first, platform operators later.

> **Status:** ALL slices 6.1–6.7 implemented (Phase 6 complete,
> 2026-06-13). 6.6 design in `catalog-editing-design.md`. 6.7 notes:
> tenants table (suspend, no delete), `platform_admin` role gates
> /v1/platform/*, suspension blocks login + sync ingest, tenant-admin
> API cannot assign platform_admin (privilege ceiling); bootstrap the
> first platform admin with `cmd/seed-platform-admin`.

---

## 1. Personas & phasing

| Phase | Persona | Sees |
|-------|---------|------|
| 6A | **Tenant owner** (e.g. retail chain owner) | Own tenant only: reports, own users, own catalog |
| 6B | **Platform operator** (us, the SaaS vendor) | Cross-tenant: create tenants, manage any user, usage overview |

Both share one SPA; the platform-admin area mounts behind a
`platform_admin` role claim. 6A ships first and is UAT-relevant; 6B
has no backend support today (no tenant CRUD endpoints) and waits.

## 2. Business features

### 6A — Tenant owner

| Feature | Value | Backend delta |
|---------|-------|---------------|
| **Login** | Same credentials as mobile | None — `/v1/auth/login` exists |
| **Today dashboard** | Revenue/tax/payment-methods at a glance on a big screen | None — `/v1/reports/*` exists |
| **Browse periods** | Day/week/month drill-down, per-store filter | None |
| **CSV export** | Hand reports to an accountant | Small — `Accept: text/csv` on reports, or client-side from JSON |
| **User management** | Add cashiers/managers, disable leavers, reset passwords without vendor support | New — users move YAML → DB, `/v1/admin/users` CRUD |
| **Catalog view** (read-only) | See item catalog + tax categories across stores | New — stores upload catalog snapshots via sync |
| **Catalog & tax editing** | Maintain prices/taxes centrally, push to stores | Large — downstream sync (see §6) |

### 6B — Platform operator (later)

- Tenant CRUD (create tenant, suspend, delete)
- Cross-tenant user search / impersonation audit
- Per-tenant usage metrics (event volume, last sync)

## 3. Technical architecture

```
apps/admin-dashboard/        # React + Vite + TypeScript
  src/
    api/        # typed fetch client (token injection, error mapping)
    auth/       # login page, token store, route guard
    features/
      reports/  # today, browse, stores
      users/    # list, create, disable, reset password
      catalog/  # read-only first
    ui/         # shared components (table, money, layout)
```

- **Stack:** React 18, Vite, TypeScript, React Router, TanStack Query
  (server state), no heavyweight UI kit — Tailwind CSS + headless
  primitives. TanStack Table for data grids.
- **Dev serving:** `vite dev` on `:5173`, proxying `/v1/*` to
  cloud-api (`:18080` locally) — avoids CORS in dev.
- **Prod serving:** `vite build` → static files; cloud-api gains a
  `--static-dir` flag to serve the SPA from the same origin (no CORS
  in prod either). CORS middleware added anyway for flexibility.
- **Auth:** POST `/v1/auth/login`, keep JWT in memory + `sessionStorage`
  (survives reload, dies with tab — deliberate UAT-grade tradeoff;
  refresh tokens are a production delta). 401 anywhere → redirect to
  login, same pattern as mobile-owner.
- **Money:** integer units+nanos from the wire, formatted client-side —
  mirror mobile-owner's `money_format` logic; never float math.

## 4. Backend deltas (cloud-api)

### 4.1 Users: YAML → DB table

Migration `users` table: `username PK, tenant_id, roles (JSON),
bcrypt_hash, disabled (bool), created_at, updated_at`.

- Boot: if `--users users.yaml` is set and table is empty, import the
  YAML once (idempotent seed path stays useful).
- `users.Store` gains a DB-backed implementation behind the existing
  interface; login handler unchanged.

### 4.2 Admin endpoints (all `RequireRole("owner")`, tenant-scoped from JWT)

| Method | Path | Body | Notes |
|--------|------|------|-------|
| GET | `/v1/admin/users` | — | List own-tenant users (no hashes) |
| POST | `/v1/admin/users` | `{username, password, roles}` | tenant_id forced from JWT claim |
| PATCH | `/v1/admin/users/{username}` | `{disabled?, password?, roles?}` | Reset password / disable / change roles |
| DELETE | — | — | Not offered; disable instead (audit trail) |

Rules: cannot disable yourself; cannot remove your own `owner` role;
username immutable. `platform_admin` role (6B) will widen tenant scope
later — design the handler tenant-check as a function, not inline.

### 4.3 CORS + static serving

- `WithCORS(origins)` option — permissive `http://localhost:5173` in dev.
- `WithStaticDir(path)` option — serve SPA build, SPA fallback to
  `index.html` for client routes.

## 5. Slice plan

| Slice | Deliverable | Depends on |
|-------|-------------|------------|
| 6.1 | Users table migration + DB store + YAML import + admin CRUD endpoints + tests | — |
| 6.2 | React scaffold: Vite, routing, login page, auth guard, API client, CI test run | — (parallel w/ 6.1) |
| 6.3 | Reports pages (today, browse, stores) + CSV export | 6.2 |
| 6.4 | User management UI | 6.1 + 6.2 |
| 6.5 | Catalog upload (store → cloud snapshot via sync) + read-only catalog page | 6.2 |
| 6.6 | Catalog/tax editing + downstream sync (cloud → store) | 6.5, design doc first |
| 6.7 | Platform-admin area (tenant CRUD, `platform_admin` role) | 6.4 |

Order: 6.1 → 6.2 → 6.3 → 6.4 → 6.5 → (6.6, 6.7 post-UAT).

## 6. The downstream-sync problem (6.6) — read before building

Golden rule 3: *local operations are source of truth*. Catalog editing
from the cloud inverts that for one entity class. Constraints:

- Store must keep selling offline with its last-known catalog.
- A cloud edit is an *intent*; the store applies it when connected and
  the store's apply is the authoritative event (`catalog_updated`
  flows back up through normal sync).
- Price changes must not rewrite history — sales keep the price at
  time of sale (already true: sale lines snapshot price).
- Conflict rule: store-local manual edit beats stale cloud push
  (last-writer-wins on a per-field `updated_lamport`), surfaced in the
  dashboard as a drift warning rather than silently merged.

This is a Phase-7-sized slice. 6.6 starts with its own design doc.

## 7. Testing

- Go: handler tests for `/v1/admin/users` (authz matrix: wrong tenant,
  non-owner, self-disable refusal), store tests for YAML import.
- React: Vitest + Testing Library; MSW for API mocks. Cover auth
  guard redirect, user CRUD flows, money formatting.
- E2E smoke addition to `docs/local-env-setup.md` §8 once 6.3 lands.

## 8. Production deltas (extends local-env-setup.md §12)

| Local choice | Production change |
|---|---|
| sessionStorage JWT | httpOnly cookie + refresh token rotation |
| Vite dev proxy | same-origin static serving behind TLS |
| No rate limit on login | per-IP backoff + lockout on `/v1/auth/login` |
| Owner self-service only | email invitations, password reset links |
