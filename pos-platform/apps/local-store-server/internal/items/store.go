package items

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"time"

	"github.com/mibjas/pos-platform/apps/local-store-server/internal/tax"
)

// Store is the data-access layer for the items table.
//
// It exposes the minimum surface ItemService needs (Upsert / Get /
// List). The tax dependency is for FK pre-validation on Upsert — we
// want to surface unknown tax_category_id as InvalidArgument, not as
// an opaque SQLite FK error.
type Store struct {
	db  *sql.DB
	tax *tax.Store
}

// NewStore wires the items store. taxStore is required; pass the same
// instance that backs TaxAdminService so the FK pre-check sees the
// same rows. Pass nil only in tests that don't exercise Upsert.
func NewStore(sqlDB *sql.DB, taxStore *tax.Store) *Store {
	return &Store{db: sqlDB, tax: taxStore}
}

// Upsert inserts or replaces an item. tenant_id is taken from the
// passed Item — callers (the api handler) pin it from server config
// before calling this method.
//
// Validation:
//   - SKU, TenantID, Name, Price.CurrencyCode all required
//   - TaxCategoryID, if non-empty, must resolve to a live tax_categories row
//   - ArchivedAt may be set on Upsert (used to un-archive: pass nil; or
//     to archive: pass time.Now() — the timestamp itself is not
//     significant beyond being non-NULL)
//
// Returns the canonical row after write (CreatedAt preserved on update,
// UpdatedAt = now).
func (s *Store) Upsert(ctx context.Context, in Item) (Item, error) {
	if err := validateForUpsert(in); err != nil {
		return Item{}, err
	}
	if in.TaxCategoryID != "" && s.tax != nil {
		if _, err := s.tax.GetCategory(ctx, in.TenantID, in.TaxCategoryID); err != nil {
			if errors.Is(err, tax.ErrCategoryNotFound) {
				return Item{}, fmt.Errorf("%w: tax_category_id=%s does not exist for tenant=%s",
					ErrInvalidItem, in.TaxCategoryID, in.TenantID)
			}
			return Item{}, fmt.Errorf("items: validate tax category: %w", err)
		}
	}

	now := time.Now().UTC()
	var archivedNS *int64
	if in.ArchivedAt != nil {
		ns := in.ArchivedAt.UnixNano()
		archivedNS = &ns
	}
	var taxCatID *string
	if in.TaxCategoryID != "" {
		taxCatID = &in.TaxCategoryID
	}

	// INSERT ... ON CONFLICT updates everything except created_at (kept
	// from the original row) and SKU/tenant_id (PK / pinned).
	_, err := s.db.ExecContext(ctx, `
		INSERT INTO items (
			sku, tenant_id, name,
			price_currency, price_units, price_nanos,
			tax_category_id, archived_at, created_at, updated_at
		) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
		ON CONFLICT(sku) DO UPDATE SET
			name             = excluded.name,
			price_currency   = excluded.price_currency,
			price_units      = excluded.price_units,
			price_nanos      = excluded.price_nanos,
			tax_category_id  = excluded.tax_category_id,
			archived_at      = excluded.archived_at,
			updated_at       = excluded.updated_at
	`,
		in.SKU, in.TenantID, in.Name,
		in.Price.CurrencyCode, in.Price.Units, in.Price.Nanos,
		taxCatID, archivedNS, now.UnixNano(), now.UnixNano(),
	)
	if err != nil {
		return Item{}, fmt.Errorf("items: upsert: %w", err)
	}
	return s.Get(ctx, in.TenantID, in.SKU)
}

// Get loads an item by (tenant, SKU). Returns ErrItemNotFound when no
// row exists. Archived items ARE returned — historical sale lookups
// need to be able to resolve a SKU even after archival.
func (s *Store) Get(ctx context.Context, tenantID, sku string) (Item, error) {
	if tenantID == "" || sku == "" {
		return Item{}, fmt.Errorf("%w: tenant=%q sku=%q", ErrItemNotFound, tenantID, sku)
	}
	row := s.db.QueryRowContext(ctx, `
		SELECT sku, tenant_id, name,
		       price_currency, price_units, price_nanos,
		       tax_category_id, archived_at, created_at, updated_at
		FROM items
		WHERE tenant_id = ? AND sku = ?
	`, tenantID, sku)
	item, err := scanItem(row)
	if errors.Is(err, sql.ErrNoRows) {
		return Item{}, fmt.Errorf("%w: tenant=%s sku=%s", ErrItemNotFound, tenantID, sku)
	}
	return item, err
}

// List returns items for the tenant, ordered by SKU ASC for stable
// pagination/test output. Archived rows are excluded unless
// includeArchived is true.
func (s *Store) List(ctx context.Context, tenantID string, includeArchived bool) ([]Item, error) {
	if tenantID == "" {
		return nil, fmt.Errorf("items: List requires tenantID")
	}
	q := `
		SELECT sku, tenant_id, name,
		       price_currency, price_units, price_nanos,
		       tax_category_id, archived_at, created_at, updated_at
		FROM items
		WHERE tenant_id = ?
	`
	if !includeArchived {
		q += ` AND archived_at IS NULL`
	}
	q += ` ORDER BY sku ASC`

	rows, err := s.db.QueryContext(ctx, q, tenantID)
	if err != nil {
		return nil, fmt.Errorf("items: list: %w", err)
	}
	defer rows.Close()
	var out []Item
	for rows.Next() {
		item, err := scanItem(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, item)
	}
	return out, rows.Err()
}

// scanItem is shared by Get (Row) and List (Rows). The scanner
// interface lets both call into the same column-order routine.
type scanner interface {
	Scan(dest ...any) error
}

func scanItem(s scanner) (Item, error) {
	var (
		i           Item
		taxCatID    sql.NullString
		archivedNS  sql.NullInt64
		createdNS   int64
		updatedNS   int64
	)
	if err := s.Scan(
		&i.SKU, &i.TenantID, &i.Name,
		&i.Price.CurrencyCode, &i.Price.Units, &i.Price.Nanos,
		&taxCatID, &archivedNS, &createdNS, &updatedNS,
	); err != nil {
		return Item{}, err
	}
	if taxCatID.Valid {
		i.TaxCategoryID = taxCatID.String
	}
	if archivedNS.Valid {
		t := time.Unix(0, archivedNS.Int64).UTC()
		i.ArchivedAt = &t
	}
	i.CreatedAt = time.Unix(0, createdNS).UTC()
	i.UpdatedAt = time.Unix(0, updatedNS).UTC()
	return i, nil
}

func validateForUpsert(in Item) error {
	switch {
	case in.SKU == "":
		return fmt.Errorf("%w: SKU is required", ErrInvalidItem)
	case in.TenantID == "":
		return fmt.Errorf("%w: TenantID is required", ErrInvalidItem)
	case in.Name == "":
		return fmt.Errorf("%w: Name is required", ErrInvalidItem)
	case in.Price.CurrencyCode == "":
		return fmt.Errorf("%w: Price.CurrencyCode is required", ErrInvalidItem)
	}
	// Money sign consistency is enforced elsewhere; the catalog itself
	// doesn't care about negative prices (some retailers store
	// deposits as -ve items).
	return nil
}
