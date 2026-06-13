package tax

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"sort"
	"time"
)

// Store is the data-access layer for tax_categories and tax_rate_components.
// It exposes CRUD primitives plus a category lookup-with-components used by
// Engine.Compute.
type Store struct {
	db *sql.DB
}

func NewStore(sqlDB *sql.DB) *Store {
	return &Store{db: sqlDB}
}

// UpsertCategory inserts or replaces a category. Components are NOT
// touched — manage them via UpsertComponent / DeleteComponent.
func (s *Store) UpsertCategory(ctx context.Context, c Category) error {
	if c.ID == "" || c.Name == "" || c.TenantID == "" {
		return errors.New("tax: UpsertCategory requires ID, Name, TenantID")
	}
	includes := 0
	if c.PriceIncludesTax {
		includes = 1
	}
	var archivedNS *int64
	if c.ArchivedAt != nil {
		ns := c.ArchivedAt.UnixNano()
		archivedNS = &ns
	}
	_, err := s.db.ExecContext(ctx, `
		INSERT INTO tax_categories (tax_category_id, name, tenant_id, price_includes_tax, archived_at)
		VALUES (?, ?, ?, ?, ?)
		ON CONFLICT(tax_category_id) DO UPDATE SET
			name = excluded.name,
			tenant_id = excluded.tenant_id,
			price_includes_tax = excluded.price_includes_tax,
			archived_at = excluded.archived_at
	`, c.ID, c.Name, c.TenantID, includes, archivedNS)
	if err != nil {
		return fmt.Errorf("tax: upsert category: %w", err)
	}
	return nil
}

// UpsertComponent inserts or replaces a rate component for a category.
func (s *Store) UpsertComponent(ctx context.Context, comp Component) error {
	if comp.ID == "" || comp.Name == "" || comp.TaxCategoryID == "" {
		return errors.New("tax: UpsertComponent requires ID, Name, TaxCategoryID")
	}
	if comp.RateBP < 0 || comp.RateBP > 100_000 {
		return fmt.Errorf("tax: rate_basis_points %d out of range [0, 100000]", comp.RateBP)
	}
	_, err := s.db.ExecContext(ctx, `
		INSERT INTO tax_rate_components (component_id, tax_category_id, name, rate_basis_points, sort_order)
		VALUES (?, ?, ?, ?, ?)
		ON CONFLICT(component_id) DO UPDATE SET
			tax_category_id = excluded.tax_category_id,
			name = excluded.name,
			rate_basis_points = excluded.rate_basis_points,
			sort_order = excluded.sort_order
	`, comp.ID, comp.TaxCategoryID, comp.Name, comp.RateBP, comp.SortOrder)
	if err != nil {
		return fmt.Errorf("tax: upsert component: %w", err)
	}
	return nil
}

// GetCategory loads a category and its components for the given tenant.
// Returns ErrCategoryNotFound if no live (non-archived) row exists.
func (s *Store) GetCategory(ctx context.Context, tenantID, categoryID string) (Category, error) {
	cat, err := s.loadCategoryRow(ctx, tenantID, categoryID)
	if err != nil {
		return Category{}, err
	}
	comps, err := s.loadComponents(ctx, categoryID)
	if err != nil {
		return Category{}, err
	}
	cat.Components = comps
	return cat, nil
}

func (s *Store) loadCategoryRow(ctx context.Context, tenantID, categoryID string) (Category, error) {
	var (
		c           Category
		includes    int
		archivedNS  sql.NullInt64
	)
	err := s.db.QueryRowContext(ctx, `
		SELECT tax_category_id, name, tenant_id, price_includes_tax, archived_at
		FROM tax_categories
		WHERE tenant_id = ? AND tax_category_id = ? AND archived_at IS NULL
	`, tenantID, categoryID).Scan(&c.ID, &c.Name, &c.TenantID, &includes, &archivedNS)
	if errors.Is(err, sql.ErrNoRows) {
		return Category{}, fmt.Errorf("%w: tenant=%s id=%s", ErrCategoryNotFound, tenantID, categoryID)
	}
	if err != nil {
		return Category{}, fmt.Errorf("tax: load category: %w", err)
	}
	c.PriceIncludesTax = includes == 1
	if archivedNS.Valid {
		t := time.Unix(0, archivedNS.Int64).UTC()
		c.ArchivedAt = &t
	}
	return c, nil
}

func (s *Store) loadComponents(ctx context.Context, categoryID string) ([]Component, error) {
	rows, err := s.db.QueryContext(ctx, `
		SELECT component_id, tax_category_id, name, rate_basis_points, sort_order
		FROM tax_rate_components
		WHERE tax_category_id = ?
		ORDER BY sort_order ASC, component_id ASC
	`, categoryID)
	if err != nil {
		return nil, fmt.Errorf("tax: load components: %w", err)
	}
	defer rows.Close()
	var comps []Component
	for rows.Next() {
		var c Component
		if err := rows.Scan(&c.ID, &c.TaxCategoryID, &c.Name, &c.RateBP, &c.SortOrder); err != nil {
			return nil, fmt.Errorf("tax: scan component: %w", err)
		}
		comps = append(comps, c)
	}
	return comps, rows.Err()
}

// loadCategoriesBatch loads a set of categories (with components) in a
// single round-trip. Used by Engine.Compute to avoid N+1 queries on lines.
// Unknown ids are silently omitted from the result map — the caller treats
// missing entries as ErrCategoryNotFound at line-resolution time, so the
// error message can name the specific SKU that referenced the bad id.
func (s *Store) loadCategoriesBatch(ctx context.Context, tenantID string, ids []string) (map[string]Category, error) {
	if len(ids) == 0 {
		return map[string]Category{}, nil
	}
	// De-dupe and sort for stable test output.
	uniq := make(map[string]struct{}, len(ids))
	for _, id := range ids {
		if id == "" {
			continue
		}
		uniq[id] = struct{}{}
	}
	if len(uniq) == 0 {
		return map[string]Category{}, nil
	}
	dedup := make([]string, 0, len(uniq))
	for id := range uniq {
		dedup = append(dedup, id)
	}
	sort.Strings(dedup)

	out := make(map[string]Category, len(dedup))
	// SQLite limits the number of host parameters, but our id count is
	// bounded by line count (typically <100). Per-id query keeps the
	// implementation trivial and still O(N) round trips on a local DB.
	for _, id := range dedup {
		cat, err := s.GetCategory(ctx, tenantID, id)
		if err != nil {
			if errors.Is(err, ErrCategoryNotFound) {
				continue
			}
			return nil, err
		}
		out[id] = cat
	}
	return out, nil
}
