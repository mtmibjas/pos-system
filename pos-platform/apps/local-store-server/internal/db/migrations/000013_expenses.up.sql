-- 000013_expenses
-- Store expense ledger. Expenses are operator-recorded outgoings (rent,
-- utilities, salaries, transport, …) that feed the Expenses screen and,
-- later, a cloud-side GL projection.
--
-- Design:
--   - id is a server-assigned UUID primary key (operators don't pick it,
--     unlike items' SKU).
--   - Like items and tax_categories, expenses are NOT sync events. They
--     mutate the local store ledger directly. ExpenseService.CreateExpense
--     is the only write path (plus cmd/seed-demo for local dev).
--   - amount / vat are stored decomposed (currency + units + nanos) so we
--     never round-trip through a float. Matches the payments.Money type.
--     vat MAY be zero (currency kept) when no input VAT applies.
--   - date is a display-friendly YYYY-MM-DD string — the ledger groups /
--     reports on it but never does arithmetic, so a string is enough.
--   - category / payment_mode are free-form operator strings.

CREATE TABLE expenses (
    id               TEXT    PRIMARY KEY,                         -- server-assigned UUID
    tenant_id        TEXT    NOT NULL,
    store_id         TEXT    NOT NULL,
    date             TEXT    NOT NULL,                            -- YYYY-MM-DD
    category         TEXT    NOT NULL,
    description      TEXT    NOT NULL,
    payment_mode     TEXT    NOT NULL,
    amount_currency  TEXT    NOT NULL,                            -- ISO 4217
    amount_units     INTEGER NOT NULL,
    amount_nanos     INTEGER NOT NULL,
    vat_currency     TEXT    NOT NULL,                            -- ISO 4217
    vat_units        INTEGER NOT NULL,
    vat_nanos        INTEGER NOT NULL,
    created_at       INTEGER NOT NULL
);

CREATE INDEX idx_expenses_store ON expenses(tenant_id, store_id);
