-- 000002_gl_projection
-- Phase 5.2: cloud-side double-entry general ledger derived from the
-- events table. See docs/accounting-rules.md (§ "Phase 5 schema additions").
--
-- Postgres-portable like 000001: BLOB/INTEGER AUTOINCREMENT are the
-- only edits required to move to Postgres (BLOB→BYTEA, AUTOINCREMENT→
-- BIGSERIAL).

CREATE TABLE accounts (
    code TEXT    PRIMARY KEY,                            -- e.g. "1000", "2100.std"
    name TEXT    NOT NULL,
    type TEXT    NOT NULL
        CHECK (type IN ('asset','liability','income','expense'))
);

-- Seed chart of accounts (Phase 5 minimum — see accounting-rules.md).
-- Tax Payable sub-accounts (2100.*) are created on-demand by the projection
-- worker the first time a sale touches a given tax_category_id.
INSERT INTO accounts (code, name, type) VALUES
    ('1000',              'Cash',                'asset'),
    ('1100',              'Card Clearing',       'asset'),
    ('1110',              'UPI Clearing',        'asset'),
    ('1200',              'Accounts Receivable', 'asset'),
    ('1300',              'Inventory',           'asset'),
    ('2000',              'Accounts Payable',    'liability'),
    ('2100.unclassified', 'Tax Payable (unclassified)', 'liability'),
    ('4000',              'Revenue',             'income'),
    ('5000',              'COGS',                'expense'),
    ('5100',              'Inventory Shrinkage', 'expense');

CREATE TABLE journal_entries (
    je_id             TEXT    PRIMARY KEY,                  -- UUID
    operation_id      TEXT    NOT NULL,                     -- source event's idempotency key
    je_seq            INTEGER NOT NULL,                     -- 0..N within one event
    tenant_id         TEXT    NOT NULL,
    store_id          TEXT    NOT NULL,
    posted_at_unix_ns INTEGER NOT NULL,                     -- = event.occurred_at
    source_event_type TEXT    NOT NULL,                     -- 'sale_created' | ...
    -- Optional denormalized link columns. Empty string when not applicable.
    -- Cheap to maintain (we know them at insert time) and they turn the
    -- void-reversal path from "scan + unmarshal events" into a single
    -- indexed lookup. Postgres-portable: TEXT NOT NULL DEFAULT ''.
    sale_id           TEXT    NOT NULL DEFAULT '',          -- sale this JE belongs to (sale, refund, void, payments-of-sale)
    payment_id        TEXT    NOT NULL DEFAULT '',          -- payment this JE belongs to (PaymentAdded / PaymentRefunded)
    memo              TEXT    NOT NULL DEFAULT '',
    UNIQUE (operation_id, je_seq)                           -- idempotency anchor
);

CREATE INDEX idx_je_tenant_period
    ON journal_entries (tenant_id, posted_at_unix_ns);
CREATE INDEX idx_je_store_period
    ON journal_entries (tenant_id, store_id, posted_at_unix_ns);
-- Drives SaleVoided reversal and any per-sale audit drill-down.
CREATE INDEX idx_je_sale
    ON journal_entries (tenant_id, sale_id, source_event_type);
-- Drives PaymentRefunded → original-method lookup.
CREATE INDEX idx_je_payment
    ON journal_entries (tenant_id, payment_id);

CREATE TABLE journal_lines (
    line_id       INTEGER PRIMARY KEY AUTOINCREMENT,        -- BIGSERIAL in Postgres
    je_id         TEXT    NOT NULL
        REFERENCES journal_entries(je_id) ON DELETE RESTRICT,
    account_code  TEXT    NOT NULL
        REFERENCES accounts(code),
    side          TEXT    NOT NULL CHECK (side IN ('debit','credit')),
    currency_code TEXT    NOT NULL,
    units         INTEGER NOT NULL CHECK (units >= 0),       -- magnitude (positive)
    nanos         INTEGER NOT NULL CHECK (nanos >= 0)        -- magnitude (positive)
);

CREATE INDEX idx_jl_account_je ON journal_lines (account_code, je_id);
CREATE INDEX idx_jl_je         ON journal_lines (je_id);

-- Cursor for the projection worker. Single row keyed by name so we can
-- run multiple projectors against the same events table later (each one
-- carries its own cursor — e.g. "gl", future "tax_audit", etc.).
CREATE TABLE projection_cursor (
    name             TEXT    PRIMARY KEY,
    last_event_id    INTEGER NOT NULL DEFAULT 0,
    updated_at_unix_ns INTEGER NOT NULL DEFAULT 0
);

INSERT INTO projection_cursor (name, last_event_id, updated_at_unix_ns)
    VALUES ('gl', 0, 0);
