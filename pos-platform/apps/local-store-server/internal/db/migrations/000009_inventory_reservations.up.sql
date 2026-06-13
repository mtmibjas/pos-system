-- 000009_inventory_reservations
-- Soft inventory reservations — Phase 4 slice 4.3.
--
-- Reservations protect "in-cart" stock so that two counters can't both
-- finalize a sale of the last unit. Unlike inventory_movements, they
-- are:
--
--   - intra-store only (NEVER synced to cloud; ephemeral coordination)
--   - not in the canonical opslog (no EventEnvelope, no batch_id)
--   - lazily expired (TTL = 5 min; expire-on-read, no background sweep
--     for 4.3 — a sweeper can land later if needed)
--
-- Available stock = SUM(non-voided movements) - SUM(active-not-expired
-- reservation quantities). See inventory.Store.Available.
--
-- Status transitions:
--   active     → finalized   (consumed by SaleService.Finalize)
--   active     → released    (counter cancelled the cart)
--   active     → expired     (lazy on read; or operator-driven sweep)
--   finalized / released / expired are terminal.

CREATE TABLE inventory_reservations (
    reservation_id  TEXT    PRIMARY KEY,                  -- UUID
    sku             TEXT    NOT NULL,
    store_id        TEXT    NOT NULL,
    counter_id      TEXT    NOT NULL,                     -- the holder; cleanup hint
    quantity        INTEGER NOT NULL CHECK (quantity > 0),
    created_at      INTEGER NOT NULL,                     -- unix nanos
    expires_at      INTEGER NOT NULL,                     -- unix nanos; created_at + TTL
    status          TEXT    NOT NULL
        CHECK (status IN ('active', 'released', 'finalized', 'expired'))
);

-- The hot query: "what's the held quantity for (store, sku) right now?"
-- Partial index — only active rows participate. Expired rows are lazily
-- transitioned and drop out.
CREATE INDEX idx_inventory_reservations_active
    ON inventory_reservations (store_id, sku, expires_at)
    WHERE status = 'active';

-- Cleanup hint: per-counter pending list (used for "counter X went away,
-- release everything it was holding").
CREATE INDEX idx_inventory_reservations_counter
    ON inventory_reservations (counter_id)
    WHERE status = 'active';
