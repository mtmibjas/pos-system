// Package items is the catalog data-access layer.
//
// An Item is operator-managed reference data: SKU, display name, unit
// price, and an optional tax category. The cashier UI browses/searches
// items when building a cart; the picked SKU and denormalized price /
// tax-category-id then flow through FinalizeSaleLine.
//
// Items are NOT events — they mutate the local catalog directly, like
// tax_categories. The cloud will eventually push catalogs down via a
// tenant-config channel; until then, ItemService.UpsertItem (and the
// cmd/seed-demo helper) are the only seed paths.
package items

import (
	"time"

	"github.com/mibjas/pos-platform/apps/local-store-server/internal/payments"
)

// Item is one row in the catalog.
//
// Price is decomposed via payments.Money — no floats in this struct.
// TaxCategoryID may be empty, which the tax engine treats as EXEMPT.
// ArchivedAt is a soft-delete marker; archived items don't appear in
// List() by default, but Get() still returns them so historical sale
// lines can resolve the SKU.
type Item struct {
	SKU           string
	TenantID      string
	Name          string
	Price         payments.Money
	TaxCategoryID string
	ArchivedAt    *time.Time
	CreatedAt     time.Time
	UpdatedAt     time.Time
}

// IsArchived reports whether the item has been soft-deleted.
func (i Item) IsArchived() bool { return i.ArchivedAt != nil }
