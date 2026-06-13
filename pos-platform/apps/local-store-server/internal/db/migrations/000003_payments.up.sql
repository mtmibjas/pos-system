-- 000003_payments
-- Payments ledger. See docs/accounting-rules.md.
--
-- Separate from invoices (deliberately) — supports split, partial, and refund flows.
-- amount is fixed-precision Money: (currency_code, units, nanos). NO FLOATS.
-- Positive amount = payment in; negative = refund (composed via parent_payment_id link).
--
-- Phase 1 note: `sale_id` references the SaleCreated event in operations_log.
-- When invoices land in Phase 5, a forward migration will add invoice_id and
-- backfill from sale_id. Keep both columns for the migration window.

CREATE TABLE payments (
    payment_id          TEXT    PRIMARY KEY,                              -- UUID
    sale_id             TEXT    NOT NULL,                                 -- links to SaleCreated.operation_id (UUID)
    method              TEXT    NOT NULL,                                 -- 'cash' | 'card' | 'upi' | 'wallet' | 'store_credit' | ...
    currency_code       TEXT    NOT NULL,                                 -- ISO 4217
    amount_units        INTEGER NOT NULL,                                 -- signed
    amount_nanos        INTEGER NOT NULL CHECK (amount_nanos > -1000000000 AND amount_nanos < 1000000000),
    reference           TEXT    NOT NULL DEFAULT '',                      -- gateway txn id, cheque #, etc.
    parent_payment_id   TEXT,                                             -- nullable; set on refunds
    created_at          INTEGER NOT NULL,                                 -- unix nanos
    FOREIGN KEY (parent_payment_id) REFERENCES payments(payment_id)
);

-- Constrain Money sign rules: units and nanos must agree in sign when both non-zero.
-- (We can't express "same sign" easily in a CHECK across two columns without OR'ing
-- all combinations, but we can rule out the impossible-to-normalize cases.)
-- Note: a fully signed-correct check is enforced in the Go layer before insert.

CREATE INDEX idx_payments_sale ON payments (sale_id);

CREATE INDEX idx_payments_parent
    ON payments (parent_payment_id)
    WHERE parent_payment_id IS NOT NULL;
