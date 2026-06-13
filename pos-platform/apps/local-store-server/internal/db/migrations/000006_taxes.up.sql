-- 000006_taxes
-- Tax categories and their rate components. The tax engine is server-
-- authoritative — SaleService.Finalize recomputes line tax from these tables
-- and rejects caller-supplied totals that disagree.
--
-- Design:
--   - A tax_category is a label assigned to SKUs ("GST-18", "EXEMPT").
--     Categories are NOT rates themselves.
--   - A category is composed of 1..N rate components ("CGST", "SGST", ...),
--     so India GST's intra-state split (CGST+SGST) and inter-state (IGST)
--     are first-class. Single-component regimes (EU VAT) just have N=1.
--   - Rates are basis points (10000 = 100%). No floats anywhere in tax math.
--   - price_includes_tax is set per CATEGORY, not per line. A retailer that
--     prices "Restaurant" gross-of-tax and "Retail" net-of-tax can do both
--     on the same receipt by assigning different categories.
--
-- Deferred to later slices (forward-compatible, additive):
--   - per-jurisdiction rate variants (add `jurisdiction` column)
--   - rate effective windows (add `effective_from`/`effective_until`)
--   - compound taxes (PST-on-GST style)
--   - tax-exempt customers
--
-- Seed data is intentionally empty. Admin CRUD and tenant-bootstrap seeding
-- land in their own slice.

CREATE TABLE tax_categories (
    tax_category_id    TEXT PRIMARY KEY,                       -- caller-chosen id (e.g. "GST-18")
    name               TEXT    NOT NULL,
    tenant_id          TEXT    NOT NULL,
    price_includes_tax INTEGER NOT NULL DEFAULT 0 CHECK (price_includes_tax IN (0, 1)),
    archived_at        INTEGER                                  -- soft-delete; never reuse ids
);

CREATE INDEX idx_tax_categories_tenant ON tax_categories(tenant_id);

CREATE TABLE tax_rate_components (
    component_id      TEXT    PRIMARY KEY,
    tax_category_id   TEXT    NOT NULL REFERENCES tax_categories(tax_category_id),
    name              TEXT    NOT NULL,                         -- "CGST" | "SGST" | "IGST" | "VAT" | ...
    rate_basis_points INTEGER NOT NULL CHECK (rate_basis_points >= 0 AND rate_basis_points <= 100000),
    sort_order        INTEGER NOT NULL DEFAULT 0                -- stable receipt rendering order
);

CREATE INDEX idx_rate_components_category ON tax_rate_components(tax_category_id);
