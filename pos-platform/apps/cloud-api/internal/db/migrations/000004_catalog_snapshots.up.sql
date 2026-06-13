-- Slice 6.5: read-only catalog mirror. Each store node uploads its full
-- catalog as one JSON blob; the cloud stores latest-per-node and never
-- interprets it beyond display (golden rule 3: the store's SQLite is
-- the source of truth — this is a mirror, not a master).

CREATE TABLE catalog_snapshots (
    tenant_id  TEXT NOT NULL,
    node_id    TEXT NOT NULL,
    payload    TEXT NOT NULL,               -- JSON CatalogSnapshot, opaque to cloud
    updated_at INTEGER NOT NULL,            -- unix seconds, server clock
    PRIMARY KEY (tenant_id, node_id)
);
