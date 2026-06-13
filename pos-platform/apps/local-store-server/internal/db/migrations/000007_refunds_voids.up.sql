-- 000007_refunds_voids
-- Voids + refunds: post-finalize reversal of a sale.
--
-- Both are append-only LOCAL READ PROJECTIONS layered on the synced
-- source-of-truth events (SaleVoided / SaleRefunded in operations_log).
-- The cloud derives its own views from those events; we do not sync these
-- rows as separate ops.
--
-- Distinction:
--   - Void:   full reversal, allowed only inside the same shift window.
--             Conceptually "this sale never happened". Restores inventory,
--             reverses payments. No customer-facing money movement
--             implied beyond returning the original tender.
--   - Refund: post-shift partial-or-full reversal. Per-line, per-quantity.
--             Restocking is per-line operator decision (damaged returns
--             stay off the shelf). Issues a credit-note with its own
--             gapless per-store-per-year sequence.
--
-- Snapshot storage mirrors invoices: canonical proto BLOB + JSON preview.

-- Voids ----------------------------------------------------------------------

CREATE TABLE sale_voids (
    void_id              TEXT    PRIMARY KEY,             -- UUID == SaleVoided.operation_id
    sale_id              TEXT    NOT NULL UNIQUE,         -- 1:1: a sale can be voided at most once
    invoice_id           TEXT    NOT NULL,                -- the invoice being voided
    store_id             TEXT    NOT NULL,
    counter_id           TEXT    NOT NULL DEFAULT '',
    cashier_id           TEXT    NOT NULL DEFAULT '',
    reason               TEXT    NOT NULL DEFAULT '',
    snapshot             BLOB    NOT NULL,                -- canonical: serialized pos.v1.SaleVoided
    snapshot_json        TEXT    NOT NULL,                -- debug-only preview
    voided_at_unix_ns    INTEGER NOT NULL,                -- from SaleVoided.occurred_at
    created_at_unix_ns   INTEGER NOT NULL                 -- wall clock at row insert
);

CREATE INDEX idx_sale_voids_store_voided
    ON sale_voids (store_id, voided_at_unix_ns DESC);

-- Refunds --------------------------------------------------------------------

CREATE TABLE refunds (
    refund_id            TEXT    PRIMARY KEY,             -- UUID == SaleRefunded.operation_id
    sale_id              TEXT    NOT NULL,                -- the sale being (partially) refunded
    invoice_id           TEXT    NOT NULL,                -- the originating invoice
    credit_note_number   TEXT    NOT NULL,                -- CN-YYYY-NNNNNN
    store_id             TEXT    NOT NULL,
    counter_id           TEXT    NOT NULL DEFAULT '',
    cashier_id           TEXT    NOT NULL DEFAULT '',
    reason               TEXT    NOT NULL DEFAULT '',
    currency_code        TEXT    NOT NULL,
    -- Refund totals are the amount RETURNED to the customer; stored as
    -- non-negative magnitudes (sign is implicit from the row's type).
    subtotal_units       INTEGER NOT NULL,
    subtotal_nanos       INTEGER NOT NULL CHECK (subtotal_nanos > -1000000000 AND subtotal_nanos < 1000000000),
    tax_total_units      INTEGER NOT NULL,
    tax_total_nanos      INTEGER NOT NULL CHECK (tax_total_nanos > -1000000000 AND tax_total_nanos < 1000000000),
    grand_total_units    INTEGER NOT NULL,
    grand_total_nanos    INTEGER NOT NULL CHECK (grand_total_nanos > -1000000000 AND grand_total_nanos < 1000000000),
    snapshot             BLOB    NOT NULL,                -- canonical: serialized pos.v1.SaleRefunded
    snapshot_json        TEXT    NOT NULL,                -- debug-only preview
    refunded_at_unix_ns  INTEGER NOT NULL,                -- from SaleRefunded.occurred_at
    created_at_unix_ns   INTEGER NOT NULL,
    UNIQUE (store_id, credit_note_number)
);

CREATE INDEX idx_refunds_sale            ON refunds (sale_id);
CREATE INDEX idx_refunds_store_refunded  ON refunds (store_id, refunded_at_unix_ns DESC);

-- One row per refunded (refund_id, sale_line_id, sku). Used to enforce
-- "cannot refund more than was sold" at the Service layer (sum of refunded
-- qty per sale_line_id <= original qty) — the lookup is per-sale, so
-- (sale_id, sale_line_id) is the natural index.
CREATE TABLE refund_lines (
    refund_id            TEXT    NOT NULL,
    sale_line_id         TEXT    NOT NULL,                -- references the original SaleLine.LineID
    sku                  TEXT    NOT NULL,
    quantity             INTEGER NOT NULL CHECK (quantity > 0),
    restock              INTEGER NOT NULL CHECK (restock IN (0, 1)),
    unit_price_units     INTEGER NOT NULL,
    unit_price_nanos     INTEGER NOT NULL CHECK (unit_price_nanos > -1000000000 AND unit_price_nanos < 1000000000),
    line_total_units     INTEGER NOT NULL,
    line_total_nanos     INTEGER NOT NULL CHECK (line_total_nanos > -1000000000 AND line_total_nanos < 1000000000),
    currency_code        TEXT    NOT NULL,
    PRIMARY KEY (refund_id, sale_line_id),
    FOREIGN KEY (refund_id) REFERENCES refunds(refund_id) ON DELETE CASCADE
);

CREATE INDEX idx_refund_lines_sale_line ON refund_lines (sale_line_id);

-- Per-store, per-year gapless credit-note counter. Same allocation pattern
-- as invoice_sequences: lazy seed via INSERT OR IGNORE inside the tx that
-- writes the refund row.
CREATE TABLE credit_note_sequences (
    store_id  TEXT    NOT NULL,
    year      INTEGER NOT NULL,
    last_seq  INTEGER NOT NULL,
    PRIMARY KEY (store_id, year)
);
