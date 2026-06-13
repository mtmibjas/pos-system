-- 000005_invoices
-- Immutable invoice records, issued atomically with each sale.
--
-- An invoice is a LOCAL READ PROJECTION of a sale. The synced source of
-- truth remains operations_log (SaleCreated). The cloud derives its own
-- invoices from those events; we do not sync invoices as separate ops.
--
-- Why this table exists:
--   - Human-facing numbering (INV-YYYY-NNNNNN, per-store-per-year).
--   - Indexed query surface for receipts and reports.
--   - Stable reference target for refunds (Slice 2.4).
--
-- Snapshot storage is HYBRID:
--   - `snapshot`      → canonical proto bytes (schema-versioned, compact).
--   - `snapshot_json` → human-readable preview for `sqlite3` debugging.
-- The proto bytes are authoritative; the JSON column is a courtesy and is
-- never read by the application.
--
-- Customer columns are intentionally omitted; they land when the customer
-- entity does (deferred slice).

CREATE TABLE invoices (
    invoice_id            TEXT    PRIMARY KEY,             -- UUID
    sale_id               TEXT    NOT NULL UNIQUE,         -- 1:1 with SaleCreated.operation_id
    invoice_number        TEXT    NOT NULL,                -- INV-YYYY-NNNNNN
    store_id              TEXT    NOT NULL,
    counter_id            TEXT    NOT NULL DEFAULT '',
    cashier_id            TEXT    NOT NULL DEFAULT '',
    currency_code         TEXT    NOT NULL,
    subtotal_units        INTEGER NOT NULL,
    subtotal_nanos        INTEGER NOT NULL CHECK (subtotal_nanos > -1000000000 AND subtotal_nanos < 1000000000),
    tax_total_units       INTEGER NOT NULL,
    tax_total_nanos       INTEGER NOT NULL CHECK (tax_total_nanos > -1000000000 AND tax_total_nanos < 1000000000),
    grand_total_units     INTEGER NOT NULL,
    grand_total_nanos     INTEGER NOT NULL CHECK (grand_total_nanos > -1000000000 AND grand_total_nanos < 1000000000),
    snapshot              BLOB    NOT NULL,                -- canonical: serialized pos.v1.SaleCreated
    snapshot_json         TEXT    NOT NULL,                -- debug-only preview; not read by code
    finalized_at_unix_ns  INTEGER NOT NULL,                -- from the originating SaleCreated.occurred_at
    created_at_unix_ns    INTEGER NOT NULL,                -- wall clock at row insert
    UNIQUE (store_id, invoice_number)
);

CREATE INDEX idx_invoices_store_finalized
    ON invoices (store_id, finalized_at_unix_ns DESC);

-- Per-store, per-year gapless counter. The (store_id, year) row is created
-- lazily on the first sale of that year via INSERT OR IGNORE inside the
-- issuing transaction.
CREATE TABLE invoice_sequences (
    store_id  TEXT    NOT NULL,
    year      INTEGER NOT NULL,
    last_seq  INTEGER NOT NULL,
    PRIMARY KEY (store_id, year)
);
