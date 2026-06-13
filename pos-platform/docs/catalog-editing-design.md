# Catalog editing & downstream sync (slice 6.6)

How the web dashboard edits items/tax categories and how those edits
reach each store — without violating golden rule 3 (*local operations
are the source of truth*).

## 1. Model: edits are intents, stores apply them

A dashboard edit never mutates a store directly. It is appended to a
cloud-side **intent queue**; each store **pulls** pending intents,
applies them locally in its own transaction, and **acks** the result.
The store's apply is the authoritative change — the next catalog
snapshot upload (slice 6.5) reflects it, which is how the dashboard
confirms the edit "took".

```
dashboard ──POST /v1/admin/catalog/edits──► cloud (catalog_edits queue)
                                               │
store ──GET /v1/sync/catalog-edits?after=N──◄──┘   (pull, ~30s tick)
  │ apply in local tx (or skip on conflict)
  └─POST /v1/sync/catalog-edits/ack ──► cloud (per-node, per-edit status)
  └─ catalog snapshot re-upload  ──► dashboard sees new state
```

Pull (not push) keeps the offline-first posture: an offline store just
catches up when connectivity returns; the cloud never needs a route to
the store.

## 2. Edit kinds (whole-record upserts)

Two kinds, each carrying the **full target record**:

| kind | payload |
|---|---|
| `upsert_item` | `{sku, name, price{currency_code,units,nanos}, tax_category_id?, archived}` |
| `upsert_tax_category` | `{id, name, price_includes_tax, archived}` |

Whole-record (not per-field patches): one conflict rule, one code
path, and the dashboard always has the full current record on screen
when editing anyway. Archive/unarchive is the `archived` flag — no
delete, consistent with SKU-never-reused.

Edits broadcast to **all nodes of the tenant**. Per-store catalogs are
out of scope (stores in a tenant share one catalog by assumption; the
per-node snapshots exist to *detect* drift, not to encourage it).

## 3. Conflict rule

A store-local manual edit beats a stale cloud intent:

> Skip the intent (status `conflict`) if the local row's `updated_at`
> is **newer** than the intent's `created_at`. Otherwise apply.

Conflicts are surfaced per-node in the dashboard's edit status — the
owner sees "node-X skipped: local change is newer" and can re-issue
the edit (a fresh intent has a fresh `created_at` and wins).

Caveat (accepted for UAT): this compares store wall-clock to cloud
wall-clock. Severe clock drift can mis-order; the production fix is a
per-row lamport on items, which is a schema change deferred until it
hurts. Sales history is never affected either way — sale lines
snapshot price at sale time.

Creating a record that doesn't exist locally never conflicts. An
`upsert_item` referencing a `tax_category_id` the store doesn't have
is a conflict (`unknown tax category`), not a crash.

## 4. Cloud schema

```sql
CREATE TABLE catalog_edits (
    seq        INTEGER PRIMARY KEY AUTOINCREMENT,  -- pull cursor, per-cloud
    edit_id    TEXT NOT NULL UNIQUE,               -- UUID, idempotency
    tenant_id  TEXT NOT NULL,
    kind       TEXT NOT NULL,
    payload    TEXT NOT NULL,                      -- JSON, full record
    created_by TEXT NOT NULL,                      -- username from JWT sub
    created_at INTEGER NOT NULL                    -- unix seconds, cloud clock
);

CREATE TABLE catalog_edit_acks (
    tenant_id TEXT NOT NULL,
    node_id   TEXT NOT NULL,
    seq       INTEGER NOT NULL,
    status    TEXT NOT NULL CHECK (status IN ('applied','conflict')),
    detail    TEXT NOT NULL DEFAULT '',
    acked_at  INTEGER NOT NULL,
    PRIMARY KEY (tenant_id, node_id, seq)
);
```

## 5. Endpoints

| Method | Path | Auth | Purpose |
|---|---|---|---|
| POST | `/v1/admin/catalog/edits` | owner | Append intent (validated) |
| GET | `/v1/admin/catalog/edits` | owner | Recent edits + per-node ack status |
| GET | `/v1/sync/catalog-edits?after=N` | JWT (store) | Pull intents with seq > N for the claim's tenant |
| POST | `/v1/sync/catalog-edits/ack` | JWT (store) | `{node_id, acks:[{seq,status,detail}]}` |

## 6. Store-side applier

`catalogsync.Applier`, sibling of the 6.5 `Uploader`:

- Tick every 30s (and once at boot): pull after the local cursor
  (`catalog_pull_state` table, single row), apply each edit in one
  SQLite transaction each, collect acks, POST them, advance cursor.
- Cursor advances **past conflicts too** — a conflict is a terminal
  state for that intent on that node (re-issue to retry), otherwise a
  clock-drifted edit would block the queue forever (we learned this
  lesson from the GL projection stall).
- After any applied edit, trigger `Uploader.UploadOnce` so the
  dashboard converges within seconds, not the 5-minute tick.
- All failures are warn-and-retry-next-tick; never fatal (offline-first).

## 7. Dashboard UX (minimum)

Catalog page gains: per-item **Edit** (name, price, tax category,
archive) and **Add item**; tax category add/edit. Submitting creates
an intent and shows it in a **Pending changes** panel with per-node
badges (pending / applied / conflict + detail). No optimistic UI — the
catalog table keeps showing snapshot truth until the store acks and
re-uploads.

## 8. Out of scope (unchanged from plan §6)

Per-field merge, per-store catalogs, lamport-based ordering on items,
edit cancellation (re-issue supersedes), inventory/stock edits (other
golden rules apply there).
