-- 000001_operations_log
-- Append-only sync source + retry queue + audit trail.
-- See docs/sync-rules.md for the canonical schema spec.

CREATE TABLE operations_log (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    operation_id    TEXT    NOT NULL UNIQUE,                              -- UUID; idempotency key
    operation_type  TEXT    NOT NULL,                                     -- e.g. 'sale_created'
    entity_type     TEXT    NOT NULL,                                     -- 'sale' | 'payment' | 'inventory' | ...
    entity_id       TEXT    NOT NULL,                                     -- UUID or SKU
    payload         BLOB    NOT NULL,                                     -- serialized EventEnvelope (Protobuf)
    created_at      INTEGER NOT NULL,                                     -- unix nanos at origin
    lamport         INTEGER NOT NULL,                                     -- logical clock counter
    origin_node_id  TEXT    NOT NULL,                                     -- stable per-device install id
    sync_status     TEXT    NOT NULL
        CHECK (sync_status IN ('pending','in_flight','acked','failed')),
    retry_count     INTEGER NOT NULL DEFAULT 0,
    last_error      TEXT    NOT NULL DEFAULT '',
    batch_id        TEXT                                                  -- UUID; nullable until shipped
);

-- The hot-path scan for the sync worker: oldest pending first.
CREATE INDEX idx_operations_log_status_created
    ON operations_log (sync_status, created_at);

-- Batch-level lookups (acks, diagnostics). Partial index — most rows have NULL batch_id.
CREATE INDEX idx_operations_log_batch
    ON operations_log (batch_id)
    WHERE batch_id IS NOT NULL;
