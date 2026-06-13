-- 000002_inventory_movements
-- Append-only inventory ledger. See docs/inventory-rules.md.
--
-- Current stock-on-hand is DERIVED:
--   SUM(delta) WHERE sku = ? AND store_id = ? AND voided_at IS NULL
-- A snapshot cache may exist later for performance; the ledger is authoritative.
--
-- Voiding: a corrected movement appends TWO new rows:
--   1) a reversal (delta = -original_delta, reason = 'void', ref_id = original_movement_id)
--   2) the corrected movement (if applicable)
-- The voiding reversal also flips voided_at / voided_by_id on the original row.
-- That single forward-update is the ONLY mutation allowed on this table.

CREATE TABLE inventory_movements (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    movement_id     TEXT    NOT NULL UNIQUE,
    sku             TEXT    NOT NULL,
    store_id        TEXT    NOT NULL,
    counter_id      TEXT,                                                 -- nullable (stock-take is store-level)
    delta           INTEGER NOT NULL CHECK (delta != 0),                  -- never zero
    reason          TEXT    NOT NULL
        CHECK (reason IN (
            'sale', 'receive', 'transfer_in', 'transfer_out',
            'stock_take', 'shrinkage', 'refund', 'void'
        )),
    ref_type        TEXT    NOT NULL,                                     -- 'sale' | 'transfer' | 'stock_take' | 'refund' | 'void'
    ref_id          TEXT    NOT NULL,                                     -- links to the originating entity
    occurred_at     INTEGER NOT NULL,                                     -- unix nanos at origin
    lamport         INTEGER NOT NULL,
    origin_node_id  TEXT    NOT NULL,
    voided_at       INTEGER,                                              -- nullable; set by voiding reversal
    voided_by_id    TEXT                                                  -- movement_id of the voider
);

CREATE INDEX idx_inventory_sku_store
    ON inventory_movements (sku, store_id, voided_at);                    -- supports stock-on-hand sum

CREATE INDEX idx_inventory_ref
    ON inventory_movements (ref_type, ref_id);
