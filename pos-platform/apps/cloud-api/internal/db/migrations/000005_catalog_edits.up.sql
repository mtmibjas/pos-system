-- Slice 6.6: downstream catalog editing. Edits are INTENTS appended by
-- the dashboard; each store node pulls them, applies locally (its
-- SQLite stays the source of truth), and acks per-edit. See
-- docs/catalog-editing-design.md.

CREATE TABLE catalog_edits (
    seq        INTEGER PRIMARY KEY AUTOINCREMENT,  -- pull cursor
    edit_id    TEXT NOT NULL UNIQUE,               -- UUID, idempotency
    tenant_id  TEXT NOT NULL,
    kind       TEXT NOT NULL,                      -- upsert_item | upsert_tax_category
    payload    TEXT NOT NULL,                      -- JSON, full record
    created_by TEXT NOT NULL,                      -- username from JWT sub
    created_at INTEGER NOT NULL                    -- unix seconds, cloud clock
);

CREATE INDEX idx_catalog_edits_tenant_seq ON catalog_edits (tenant_id, seq);

CREATE TABLE catalog_edit_acks (
    tenant_id TEXT NOT NULL,
    node_id   TEXT NOT NULL,
    seq       INTEGER NOT NULL,
    status    TEXT NOT NULL CHECK (status IN ('applied','conflict')),
    detail    TEXT NOT NULL DEFAULT '',
    acked_at  INTEGER NOT NULL,
    PRIMARY KEY (tenant_id, node_id, seq)
);
