-- 000001_sync_ingest
-- Cloud-side persistence for sync ingest. Mirrors the local
-- operations_log shape but flipped to the receiver's POV: the cloud
-- never writes here from anywhere except the /v1/sync/batches handler,
-- and the *batch* (not the operation) is the unit of idempotency.
--
-- Schema is intentionally Postgres-portable (no rowid magic, no
-- AUTOINCREMENT-only columns referenced by FKs). When this migrates
-- to Postgres in a later phase, swap INTEGER PRIMARY KEY AUTOINCREMENT
-- → BIGSERIAL and BLOB → BYTEA — that's the only edit required.

CREATE TABLE applied_batches (
    batch_id            TEXT    PRIMARY KEY,                   -- UUID; idempotency key
    tenant_id           TEXT    NOT NULL,
    operation_count     INTEGER NOT NULL,                      -- diagnostic; len(operations) on first apply
    applied_at_unix_ns  INTEGER NOT NULL                       -- wall clock at cloud at ingest
);

CREATE INDEX idx_applied_batches_tenant
    ON applied_batches (tenant_id, applied_at_unix_ns);

CREATE TABLE events (
    -- Surrogate key for stable read-side ordering (slice 3.4 cursor). Not
    -- exposed on the wire — operation_id is the durable identity.
    id                    INTEGER PRIMARY KEY AUTOINCREMENT,
    operation_id          TEXT    NOT NULL UNIQUE,             -- UUID; per-operation idempotency key
    batch_id              TEXT    NOT NULL
        REFERENCES applied_batches(batch_id) ON DELETE RESTRICT,
    tenant_id             TEXT    NOT NULL,
    operation_type        TEXT    NOT NULL,                    -- e.g. 'sale_created'
    entity_type           TEXT    NOT NULL,                    -- 'sale' | 'payment' | 'inventory' | ...
    entity_id             TEXT    NOT NULL,
    payload               BLOB    NOT NULL,                    -- serialized EventEnvelope
    lamport               INTEGER NOT NULL,                    -- origin's logical clock
    origin_node_id        TEXT    NOT NULL,                    -- stable per-device install id
    occurred_at_unix_ns   INTEGER NOT NULL,                    -- wall clock at origin
    received_at_unix_ns   INTEGER NOT NULL                     -- wall clock at cloud
);

-- Tenant-scoped cursor scans for the read-side stream (slice 3.4).
CREATE INDEX idx_events_tenant_lamport
    ON events (tenant_id, lamport, id);
