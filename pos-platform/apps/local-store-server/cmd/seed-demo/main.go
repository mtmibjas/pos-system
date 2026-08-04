// Package main is a tiny one-shot seeder for the local POS database.
//
// It opens (and migrates) the same SQLite file the local-store-server
// uses, then upserts a GST-18 tax category (CGST 9% + SGST 9%) and a
// handful of demo items priced in INR. Re-runs are idempotent — both
// the tax and items stores are ON CONFLICT upserts keyed on stable IDs.
//
// Usage:
//
//	go run ./cmd/seed-demo
//	POS_LOCAL_DB=/tmp/dev.db POS_TENANT_ID=tenant-A go run ./cmd/seed-demo
//
// This exists because manually clicking through ItemService.UpsertItem
// (or curl-ing Connect-RPC) to populate a dev catalog is tedious, and
// the slices that follow (cart, sale finalize) need a real item list
// to be usable end-to-end.
package main

import (
	"context"
	"log/slog"
	"os"

	"github.com/mibjas/pos-platform/apps/local-store-server/internal/db"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/expenses"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/items"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/payments"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/tax"
)

func main() {
	logger := slog.New(slog.NewTextHandler(os.Stdout, nil))
	ctx := context.Background()

	dbPath := envOr("POS_LOCAL_DB", "pos-local.db")
	tenantID := envOr("POS_TENANT_ID", "tenant-A")
	storeID := envOr("POS_STORE_ID", "store-1")

	sqlDB, err := db.Open(ctx, db.Config{Path: dbPath})
	if err != nil {
		logger.Error("open db", "err", err, "path", dbPath)
		os.Exit(1)
	}
	defer func() { _ = sqlDB.Close() }()

	if err := db.RunMigrations(sqlDB); err != nil {
		logger.Error("migrate", "err", err)
		os.Exit(1)
	}

	taxStore := tax.NewStore(sqlDB)
	itemStore := items.NewStore(sqlDB, taxStore)
	expenseStore := expenses.NewStore(sqlDB)

	if err := seedTax(ctx, taxStore, tenantID); err != nil {
		logger.Error("seed tax", "err", err)
		os.Exit(1)
	}
	seeded, err := seedItems(ctx, itemStore, tenantID)
	if err != nil {
		logger.Error("seed items", "err", err)
		os.Exit(1)
	}
	seededExpenses, err := seedExpenses(ctx, expenseStore, tenantID, storeID)
	if err != nil {
		logger.Error("seed expenses", "err", err)
		os.Exit(1)
	}

	logger.Info("seed complete",
		"db_path", dbPath,
		"tenant", tenantID,
		"store", storeID,
		"tax_category", "GST-18",
		"items", seeded,
		"expenses", seededExpenses,
	)
}

// seedTax registers a GST-18 category split into two 9% components
// (CGST + SGST) — India intra-state default. Idempotent via the
// tax.Store ON CONFLICT upserts.
func seedTax(ctx context.Context, s *tax.Store, tenantID string) error {
	if err := s.UpsertCategory(ctx, tax.Category{
		ID:               "GST-18",
		Name:             "GST 18%",
		TenantID:         tenantID,
		PriceIncludesTax: false,
	}); err != nil {
		return err
	}
	comps := []tax.Component{
		{ID: "GST-18-CGST", TaxCategoryID: "GST-18", Name: "CGST", RateBP: 900, SortOrder: 1},
		{ID: "GST-18-SGST", TaxCategoryID: "GST-18", Name: "SGST", RateBP: 900, SortOrder: 2},
	}
	for _, c := range comps {
		if err := s.UpsertComponent(ctx, c); err != nil {
			return err
		}
	}
	return nil
}

// seedItems writes a short demo catalog. Prices are INR, all tagged
// GST-18 so the eventual cart + finalize flow produces a non-trivial
// tax breakdown.
func seedItems(ctx context.Context, s *items.Store, tenantID string) (int, error) {
	demo := []items.Item{
		newItem("BREAD-WW", "Whole wheat bread (400g)", 45, 0),
		newItem("MILK-1L", "Toned milk (1L)", 62, 0),
		newItem("APPLE-1KG", "Apples (1kg)", 180, 0),
		newItem("EGGS-DZ", "Eggs (dozen)", 84, 0),
		newItem("RICE-5KG", "Basmati rice (5kg)", 575, 50_000_000),
		newItem("OIL-1L", "Sunflower oil (1L)", 165, 0),
	}
	for i := range demo {
		demo[i].TenantID = tenantID
		if _, err := s.Upsert(ctx, demo[i]); err != nil {
			return 0, err
		}
	}
	return len(demo), nil
}

// seedExpenses writes a short demo expense ledger for the Expenses
// screen. Amounts are LKR (Sri Lanka), mirroring the prototype
// /tmp/gl_app.js EXPENSES array. Stable IDs make re-runs idempotent
// (the store's INSERT ... ON CONFLICT(id) upserts).
func seedExpenses(ctx context.Context, s *expenses.Store, tenantID, storeID string) (int, error) {
	demo := []expenses.Expense{
		newExpense("exp-1", "2026-06-15", "Utilities", "CEB electricity — June", "Cash", 31500, 0),
		newExpense("exp-2", "2026-06-14", "Rent", "Shop rent — June", "Bank", 145000, 0),
		newExpense("exp-3", "2026-06-13", "Salaries", "Cashier wages — 1st half", "Bank", 118000, 0),
		newExpense("exp-4", "2026-06-12", "Transport", "Lorry hire — Dambulla run", "Cash", 18000, 0),
		newExpense("exp-5", "2026-06-11", "Packaging", "Carry bags · 5000 pcs", "LankaQR", 47200, 8496),
		newExpense("exp-6", "2026-06-10", "Maintenance", "Chiller servicing", "Cash", 26000, 4680),
	}
	for i := range demo {
		demo[i].TenantID = tenantID
		demo[i].StoreID = storeID
		if _, err := s.Create(ctx, demo[i]); err != nil {
			return 0, err
		}
	}
	return len(demo), nil
}

func newExpense(id, date, category, description, mode string, amtUnits, vatUnits int64) expenses.Expense {
	return expenses.Expense{
		ID:          id,
		Date:        date,
		Category:    category,
		Description: description,
		PaymentMode: mode,
		Amount:      payments.Money{CurrencyCode: "LKR", Units: amtUnits},
		VAT:         payments.Money{CurrencyCode: "LKR", Units: vatUnits},
	}
}

func newItem(sku, name string, units int64, nanos int32) items.Item {
	return items.Item{
		SKU:           sku,
		Name:          name,
		Price:         payments.Money{CurrencyCode: "INR", Units: units, Nanos: nanos},
		TaxCategoryID: "GST-18",
	}
}

func envOr(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}
