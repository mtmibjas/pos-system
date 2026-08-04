package expenses_test

import (
	"context"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/require"

	"github.com/mibjas/pos-platform/apps/local-store-server/internal/db"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/expenses"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/payments"
)

const (
	testTenant = "tenant-A"
	testStore  = "store-1"
)

func newStore(t *testing.T) *expenses.Store {
	t.Helper()
	ctx := context.Background()
	path := filepath.Join(t.TempDir(), "expenses.db")
	sqlDB, err := db.Open(ctx, db.Config{Path: path})
	require.NoError(t, err)
	t.Cleanup(func() { _ = sqlDB.Close() })
	require.NoError(t, db.RunMigrations(sqlDB))
	return expenses.NewStore(sqlDB)
}

func sampleExpense(cat string) expenses.Expense {
	return expenses.Expense{
		TenantID:    testTenant,
		StoreID:     testStore,
		Date:        "2026-06-15",
		Category:    cat,
		Description: "Demo " + cat,
		PaymentMode: "Cash",
		Amount:      payments.Money{CurrencyCode: "LKR", Units: 31500},
		VAT:         payments.Money{CurrencyCode: "LKR"},
	}
}

func TestCreate_AssignsIDAndTimestamp(t *testing.T) {
	ctx := context.Background()
	store := newStore(t)

	stored, err := store.Create(ctx, sampleExpense("Utilities"))
	require.NoError(t, err)
	require.NotEmpty(t, stored.ID, "Create must assign a server-side ID")
	require.False(t, stored.CreatedAt.IsZero())
	require.Equal(t, testTenant, stored.TenantID)
	require.Equal(t, testStore, stored.StoreID)
	require.Equal(t, "Utilities", stored.Category)
	require.Equal(t, int64(31500), stored.Amount.Units)
}

func TestCreate_RoundTripsThroughList(t *testing.T) {
	ctx := context.Background()
	store := newStore(t)

	in := sampleExpense("Packaging")
	in.VAT = payments.Money{CurrencyCode: "LKR", Units: 8496}
	stored, err := store.Create(ctx, in)
	require.NoError(t, err)

	rows, err := store.List(ctx, testTenant, testStore)
	require.NoError(t, err)
	require.Len(t, rows, 1)
	got := rows[0]
	require.Equal(t, stored.ID, got.ID)
	require.Equal(t, "Packaging", got.Category)
	require.Equal(t, "Cash", got.PaymentMode)
	require.Equal(t, int64(8496), got.VAT.Units)
	require.Equal(t, "LKR", got.VAT.CurrencyCode)
}

func TestCreate_DefaultsVatCurrencyToAmount(t *testing.T) {
	ctx := context.Background()
	store := newStore(t)

	in := sampleExpense("Rent")
	in.VAT = payments.Money{} // no currency, zero VAT
	stored, err := store.Create(ctx, in)
	require.NoError(t, err)
	require.Equal(t, "LKR", stored.VAT.CurrencyCode, "zero VAT should inherit amount currency")
	require.True(t, stored.VAT.IsZero())
}

func TestCreate_RejectsMissingFields(t *testing.T) {
	ctx := context.Background()
	store := newStore(t)

	cases := []struct {
		name string
		mut  func(*expenses.Expense)
	}{
		{"empty tenant", func(e *expenses.Expense) { e.TenantID = "" }},
		{"empty store", func(e *expenses.Expense) { e.StoreID = "" }},
		{"empty date", func(e *expenses.Expense) { e.Date = "" }},
		{"empty category", func(e *expenses.Expense) { e.Category = "" }},
		{"empty currency", func(e *expenses.Expense) { e.Amount.CurrencyCode = "" }},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			ex := sampleExpense("X")
			tc.mut(&ex)
			_, err := store.Create(ctx, ex)
			require.ErrorIs(t, err, expenses.ErrInvalidExpense)
		})
	}
}

func TestList_EmptyTenantOrStoreIsError(t *testing.T) {
	store := newStore(t)
	ctx := context.Background()

	_, err := store.List(ctx, "", testStore)
	require.Error(t, err)
	_, err = store.List(ctx, testTenant, "")
	require.Error(t, err)
}

func TestList_ScopedByStore(t *testing.T) {
	ctx := context.Background()
	store := newStore(t)

	_, err := store.Create(ctx, sampleExpense("Utilities"))
	require.NoError(t, err)

	other := sampleExpense("Rent")
	other.StoreID = "store-2"
	_, err = store.Create(ctx, other)
	require.NoError(t, err)

	rows, err := store.List(ctx, testTenant, testStore)
	require.NoError(t, err)
	require.Len(t, rows, 1)
	require.Equal(t, "Utilities", rows[0].Category)
}

func TestList_EmptyIsNotError(t *testing.T) {
	ctx := context.Background()
	store := newStore(t)

	rows, err := store.List(ctx, testTenant, testStore)
	require.NoError(t, err)
	require.Empty(t, rows)
}
