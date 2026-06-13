-- 000004_sync_state
-- Sync metadata key/value store. See docs/sync-rules.md.
--
-- Used for:
--   - last_sync_at        — last successful batch ack timestamp
--   - last_sync_batch_id  — UUID of the last acked batch
--   - next_lamport        — monotonic logical clock counter
--   - failed_ops_count    — count of operations parked in 'failed' (for ops dashboards)
--
-- Why a K/V table instead of named columns: keys come and go as sync evolves
-- (checkpoints, new diagnostics, feature flags). A migration per new datum is
-- friction we don't need.

CREATE TABLE sync_state (
    key          TEXT    PRIMARY KEY,
    value        TEXT    NOT NULL,
    updated_at   INTEGER NOT NULL                                         -- unix nanos
);
