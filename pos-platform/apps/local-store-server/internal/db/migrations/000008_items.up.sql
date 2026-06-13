-- 000008_items
-- Item catalog. Items are operator-managed reference data — the cashier
-- UI browses/searches them when building a cart, and the picked SKU +
-- denormalized price/tax-category get shipped on FinalizeSaleLine.
--
-- Design:
--   - SKU is the primary key (operator-chosen string: barcode, BREAD-WW,
--     etc.). Sales already wire by SKU on FinalizeSaleLine — adding a
--     UUID indirection would be dead weight today.
--   - Like tax_categories, items are NOT events. They mutate the local
--     catalog directly. The cloud will eventually source a tenant
--     catalog push; until then ItemService.UpsertItem is the only seed
--     path (plus cmd/seed-demo for local dev).
--   - Money is stored decomposed (currency + units + nanos) so we never
--     round-trip through a float. Matches the payments.Money type.
--   - tax_category_id is a nullable FK to tax_categories. NULL = exempt,
--     which the tax engine already handles. Dangling refs are caught
--     SQL-side; ItemService.UpsertItem also pre-checks for a clearer
--     InvalidArgument error.
--
-- Deferred (forward-compatible, additive):
--   - per-store override pricing (separate item_store_overrides table)
--   - barcodes as a separate alias table (multiple barcodes per SKU)
--   - photos / descriptions
--   - inventory level join (already lives in inventory_movements)

CREATE TABLE items (
    sku              TEXT    PRIMARY KEY,                       -- operator-chosen
    tenant_id        TEXT    NOT NULL,
    name             TEXT    NOT NULL,
    price_currency   TEXT    NOT NULL,                           -- ISO 4217
    price_units      INTEGER NOT NULL,
    price_nanos      INTEGER NOT NULL,
    tax_category_id  TEXT    REFERENCES tax_categories(tax_category_id),  -- NULL = exempt
    archived_at      INTEGER,                                     -- soft-delete; SKUs never reused
    created_at       INTEGER NOT NULL,
    updated_at       INTEGER NOT NULL
);

CREATE INDEX idx_items_tenant_active ON items(tenant_id) WHERE archived_at IS NULL;
