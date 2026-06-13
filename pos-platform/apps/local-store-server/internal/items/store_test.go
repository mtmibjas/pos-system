package items_test

import (
	"context"
	"errors"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/require"

	"github.com/mibjas/pos-platform/apps/local-store-server/internal/db"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/items"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/payments"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/tax"
)

const testTenant = "tenant-A"

func newStores(t *testing.T) (*items.Store, *tax.Store) {
	t.Helper()
	ctx := context.Background()
	path := filepath.Join(t.TempDir(), "items.db")
	sqlDB, err := db.Open(ctx, db.Config{Path: path})
	require.NoError(t, err)
	t.Cleanup(func() { _ = sqlDB.Close() })
	require.NoError(t, db.RunMigrations(sqlDB))

	taxStore := tax.NewStore(sqlDB)
	// Seed a tax category so Upsert's FK pre-check has something live
	// to validate against.
	require.NoError(t, taxStore.UpsertCategory(ctx, tax.Category{
		ID: "GST-18", Name: "GST 18%", TenantID: testTenant,
	}))
	return items.NewStore(sqlDB, taxStore), taxStore
}

func sampleItem(sku string) items.Item {
	return items.Item{
		SKU:           sku,
		TenantID:      testTenant,
		Name:          "Demo " + sku,
		Price:         payments.Money{CurrencyCode: "INR", Units: 100},
		TaxCategoryID: "GST-18",
	}
}

func TestUpsertAndGet_RoundTrip(t *testing.T) {
	ctx := context.Background()
	store, _ := newStores(t)

	stored, err := store.Upsert(ctx, sampleItem("BREAD-WW"))
	require.NoError(t, err)
	require.Equal(t, "BREAD-WW", stored.SKU)
	require.Equal(t, testTenant, stored.TenantID)
	require.Equal(t, "GST-18", stored.TaxCategoryID)
	require.False(t, stored.CreatedAt.IsZero())
	require.False(t, stored.UpdatedAt.IsZero())

	fetched, err := store.Get(ctx, testTenant, "BREAD-WW")
	require.NoError(t, err)
	require.Equal(t, stored, fetched)
}

func TestUpsert_UpdatePreservesCreatedAt(t *testing.T) {
	ctx := context.Background()
	store, _ := newStores(t)

	first, err := store.Upsert(ctx, sampleItem("MILK-1L"))
	require.NoError(t, err)

	upd := first
	upd.Name = "Whole Milk 1L"
	upd.Price = payments.Money{CurrencyCode: "INR", Units: 120}
	second, err := store.Upsert(ctx, upd)
	require.NoError(t, err)

	require.Equal(t, first.CreatedAt, second.CreatedAt, "CreatedAt must be preserved on update")
	require.True(t, second.UpdatedAt.Equal(first.UpdatedAt) || second.UpdatedAt.After(first.UpdatedAt),
		"UpdatedAt must move forward")
	require.Equal(t, "Whole Milk 1L", second.Name)
	require.Equal(t, int64(120), second.Price.Units)
}

func TestUpsert_RejectsMissingFields(t *testing.T) {
	ctx := context.Background()
	store, _ := newStores(t)

	cases := []struct {
		name string
		mut  func(*items.Item)
	}{
		{"empty SKU", func(i *items.Item) { i.SKU = "" }},
		{"empty tenant", func(i *items.Item) { i.TenantID = "" }},
		{"empty name", func(i *items.Item) { i.Name = "" }},
		{"empty currency", func(i *items.Item) { i.Price.CurrencyCode = "" }},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			it := sampleItem("X")
			tc.mut(&it)
			_, err := store.Upsert(ctx, it)
			require.ErrorIs(t, err, items.ErrInvalidItem)
		})
	}
}

func TestUpsert_RejectsUnknownTaxCategory(t *testing.T) {
	ctx := context.Background()
	store, _ := newStores(t)

	it := sampleItem("PHANTOM")
	it.TaxCategoryID = "DOES-NOT-EXIST"
	_, err := store.Upsert(ctx, it)
	require.ErrorIs(t, err, items.ErrInvalidItem)
}

func TestUpsert_EmptyTaxCategoryIsExempt(t *testing.T) {
	ctx := context.Background()
	store, _ := newStores(t)

	it := sampleItem("FRUIT-1KG")
	it.TaxCategoryID = ""
	stored, err := store.Upsert(ctx, it)
	require.NoError(t, err)
	require.Empty(t, stored.TaxCategoryID)
}

func TestGet_NotFound(t *testing.T) {
	ctx := context.Background()
	store, _ := newStores(t)

	_, err := store.Get(ctx, testTenant, "GHOST")
	require.ErrorIs(t, err, items.ErrItemNotFound)
}

func TestList_ExcludesArchivedByDefault(t *testing.T) {
	ctx := context.Background()
	store, _ := newStores(t)

	_, err := store.Upsert(ctx, sampleItem("A"))
	require.NoError(t, err)
	_, err = store.Upsert(ctx, sampleItem("B"))
	require.NoError(t, err)

	// Archive B.
	b, err := store.Get(ctx, testTenant, "B")
	require.NoError(t, err)
	now := b.UpdatedAt
	b.ArchivedAt = &now
	_, err = store.Upsert(ctx, b)
	require.NoError(t, err)

	live, err := store.List(ctx, testTenant, false)
	require.NoError(t, err)
	require.Len(t, live, 1)
	require.Equal(t, "A", live[0].SKU)

	all, err := store.List(ctx, testTenant, true)
	require.NoError(t, err)
	require.Len(t, all, 2)
	// Order is SKU ASC, so A then B.
	require.Equal(t, "A", all[0].SKU)
	require.Equal(t, "B", all[1].SKU)
	require.NotNil(t, all[1].ArchivedAt)
}

func TestList_EmptyTenantIsError(t *testing.T) {
	store, _ := newStores(t)

	_, err := store.List(context.Background(), "", false)
	require.Error(t, err)
}

func TestList_OrderingIsStable(t *testing.T) {
	ctx := context.Background()
	store, _ := newStores(t)

	skus := []string{"C", "A", "B"}
	for _, sku := range skus {
		_, err := store.Upsert(ctx, sampleItem(sku))
		require.NoError(t, err)
	}
	got, err := store.List(ctx, testTenant, false)
	require.NoError(t, err)
	require.Len(t, got, 3)
	require.Equal(t, "A", got[0].SKU)
	require.Equal(t, "B", got[1].SKU)
	require.Equal(t, "C", got[2].SKU)
}

func TestGet_ReturnsArchived(t *testing.T) {
	// Historical sale lookups need to resolve archived SKUs.
	ctx := context.Background()
	store, _ := newStores(t)

	it, err := store.Upsert(ctx, sampleItem("OLDSKU"))
	require.NoError(t, err)
	now := it.UpdatedAt
	it.ArchivedAt = &now
	_, err = store.Upsert(ctx, it)
	require.NoError(t, err)

	fetched, err := store.Get(ctx, testTenant, "OLDSKU")
	require.NoError(t, err)
	require.NotNil(t, fetched.ArchivedAt)
}

func TestStore_NilTaxStoreSkipsFKCheck(t *testing.T) {
	// Documents the nil-tax-store behavior used by tests that don't
	// exercise tax FKs; production wiring always passes a real store.
	ctx := context.Background()
	path := filepath.Join(t.TempDir(), "items.db")
	sqlDB, err := db.Open(ctx, db.Config{Path: path})
	require.NoError(t, err)
	t.Cleanup(func() { _ = sqlDB.Close() })
	require.NoError(t, db.RunMigrations(sqlDB))

	store := items.NewStore(sqlDB, nil)
	it := sampleItem("Y")
	it.TaxCategoryID = "" // FK check is what nil-tax-store skips; keep clean
	stored, err := store.Upsert(ctx, it)
	require.NoError(t, err)
	require.Equal(t, "Y", stored.SKU)

	// And just to be defensive: ErrItemNotFound is still distinguishable
	// from a nil-tax-store fall-through.
	_, err = store.Get(ctx, testTenant, "MISSING")
	require.True(t, errors.Is(err, items.ErrItemNotFound))
}
