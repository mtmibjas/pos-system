package tax_test

import (
	"context"
	"database/sql"
	"path/filepath"
	"testing"
	"time"

	"github.com/stretchr/testify/require"

	"github.com/mibjas/pos-platform/apps/local-store-server/internal/db"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/payments"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/tax"
)

func ptrToNow() *time.Time {
	t := time.Now().UTC()
	return &t
}

const (
	testTenant = "tenant-A"
)

func newEngine(t *testing.T) (*tax.Engine, *tax.Store, *sql.DB) {
	t.Helper()
	ctx := context.Background()
	path := filepath.Join(t.TempDir(), "tax.db")
	sqlDB, err := db.Open(ctx, db.Config{Path: path})
	require.NoError(t, err)
	t.Cleanup(func() { _ = sqlDB.Close() })
	require.NoError(t, db.RunMigrations(sqlDB))
	store := tax.NewStore(sqlDB)
	return tax.NewEngine(store), store, sqlDB
}

// seedGST18 creates a "GST-18" category with two components (CGST 9% + SGST 9%).
// inclusive controls price_includes_tax.
func seedGST18(t *testing.T, s *tax.Store, inclusive bool) {
	t.Helper()
	ctx := context.Background()
	require.NoError(t, s.UpsertCategory(ctx, tax.Category{
		ID: "GST-18", Name: "GST 18%", TenantID: testTenant, PriceIncludesTax: inclusive,
	}))
	require.NoError(t, s.UpsertComponent(ctx, tax.Component{
		ID: "CGST-9", TaxCategoryID: "GST-18", Name: "CGST", RateBP: 900, SortOrder: 1,
	}))
	require.NoError(t, s.UpsertComponent(ctx, tax.Component{
		ID: "SGST-9", TaxCategoryID: "GST-18", Name: "SGST", RateBP: 900, SortOrder: 2,
	}))
}

func seedVAT20(t *testing.T, s *tax.Store, inclusive bool) {
	t.Helper()
	ctx := context.Background()
	require.NoError(t, s.UpsertCategory(ctx, tax.Category{
		ID: "VAT-20", Name: "VAT 20%", TenantID: testTenant, PriceIncludesTax: inclusive,
	}))
	require.NoError(t, s.UpsertComponent(ctx, tax.Component{
		ID: "VAT-20-C", TaxCategoryID: "VAT-20", Name: "VAT", RateBP: 2000,
	}))
}

func usd(units int64, nanos int32) payments.Money {
	return payments.Money{CurrencyCode: "USD", Units: units, Nanos: nanos}
}
func inr(units int64, nanos int32) payments.Money {
	return payments.Money{CurrencyCode: "INR", Units: units, Nanos: nanos}
}

// --- tests ---

func TestCompute_Exempt_NoCategoryReferenced(t *testing.T) {
	e, _, _ := newEngine(t)
	resp, err := e.Compute(context.Background(), tax.ComputeRequest{
		TenantID: testTenant,
		Lines: []tax.ComputeLine{
			{SKU: "A", LineTotal: usd(10, 0), Quantity: 1},
		},
	})
	require.NoError(t, err)
	require.Equal(t, usd(10, 0), resp.Subtotal)
	require.Equal(t, usd(0, 0), resp.TaxTotal)
	require.Equal(t, usd(10, 0), resp.GrandTotal)
	require.Empty(t, resp.Breakdown)
	require.Empty(t, resp.Lines[0].Components)
}

func TestCompute_SingleComponent_Exclusive_VAT(t *testing.T) {
	e, s, _ := newEngine(t)
	seedVAT20(t, s, false)

	// Net $100, +20% = $20 tax, gross $120.
	resp, err := e.Compute(context.Background(), tax.ComputeRequest{
		TenantID: testTenant,
		Lines: []tax.ComputeLine{
			{SKU: "A", TaxCategoryID: "VAT-20", LineTotal: usd(100, 0), Quantity: 1},
		},
	})
	require.NoError(t, err)
	require.Equal(t, usd(100, 0), resp.Subtotal)
	require.Equal(t, usd(20, 0), resp.TaxTotal)
	require.Equal(t, usd(120, 0), resp.GrandTotal)
	require.Len(t, resp.Breakdown, 1)
	require.Equal(t, "VAT", resp.Breakdown[0].Name)
	require.Equal(t, usd(20, 0), resp.Breakdown[0].Amount)
}

func TestCompute_SingleComponent_Inclusive_VAT(t *testing.T) {
	e, s, _ := newEngine(t)
	seedVAT20(t, s, true)

	// Gross $120 inclusive of 20% → net $100, tax $20.
	resp, err := e.Compute(context.Background(), tax.ComputeRequest{
		TenantID: testTenant,
		Lines: []tax.ComputeLine{
			{SKU: "A", TaxCategoryID: "VAT-20", LineTotal: usd(120, 0), Quantity: 1},
		},
	})
	require.NoError(t, err)
	require.Equal(t, usd(100, 0), resp.Subtotal)
	require.Equal(t, usd(20, 0), resp.TaxTotal)
	require.Equal(t, usd(120, 0), resp.GrandTotal)
}

func TestCompute_MultiComponent_GST18_Exclusive(t *testing.T) {
	e, s, _ := newEngine(t)
	seedGST18(t, s, false)

	// Net ₹100, +18% = ₹18 (CGST ₹9 + SGST ₹9).
	resp, err := e.Compute(context.Background(), tax.ComputeRequest{
		TenantID: testTenant,
		Lines: []tax.ComputeLine{
			{SKU: "A", TaxCategoryID: "GST-18", LineTotal: inr(100, 0), Quantity: 1},
		},
	})
	require.NoError(t, err)
	require.Equal(t, inr(100, 0), resp.Subtotal)
	require.Equal(t, inr(18, 0), resp.TaxTotal)
	require.Equal(t, inr(118, 0), resp.GrandTotal)

	require.Len(t, resp.Breakdown, 2)
	require.Equal(t, "CGST", resp.Breakdown[0].Name)
	require.Equal(t, inr(9, 0), resp.Breakdown[0].Amount)
	require.Equal(t, "SGST", resp.Breakdown[1].Name)
	require.Equal(t, inr(9, 0), resp.Breakdown[1].Amount)
}

func TestCompute_MultiComponent_GST18_Inclusive(t *testing.T) {
	e, s, _ := newEngine(t)
	seedGST18(t, s, true)

	// Gross ₹118 inclusive of 18% → net ₹100, tax ₹18 split 9/9.
	resp, err := e.Compute(context.Background(), tax.ComputeRequest{
		TenantID: testTenant,
		Lines: []tax.ComputeLine{
			{SKU: "A", TaxCategoryID: "GST-18", LineTotal: inr(118, 0), Quantity: 1},
		},
	})
	require.NoError(t, err)
	require.Equal(t, inr(100, 0), resp.Subtotal)
	require.Equal(t, inr(18, 0), resp.TaxTotal)
	require.Equal(t, inr(118, 0), resp.GrandTotal)
	require.Equal(t, inr(9, 0), resp.Breakdown[0].Amount)
	require.Equal(t, inr(9, 0), resp.Breakdown[1].Amount)
}

func TestCompute_ComponentSplit_AbsorbsRoundingResidue(t *testing.T) {
	// Use a multi-component category with UNEVEN rates so the proportional
	// split has a residue. CGST 5% + SGST 13% = 18%. On ₹100 exclusive,
	// total tax = ₹18.
	// Proportional split: CGST = round(18 * 500/1800) = 5; SGST = round(18 * 1300/1800) = 13.
	// Σ = 18, residue 0. Try a fractional input to force residue.
	//
	// On ₹1.07 exclusive at 5%+13%:
	//   total tax = round(1.07 * 1800 / 10000) = round(0.1926) = 0.19
	//   CGST    = round(1.07 * 500 / 10000)  = round(0.0535) = 0.05
	//   SGST    = round(1.07 * 1300 / 10000) = round(0.1391) = 0.14
	//   Σ = 0.05 + 0.14 = 0.19 ✓ — no residue here either.
	//
	// Force a residue with weird denominators. Easier: prove the rule
	// holds by directly checking Σ components == TaxTotal across many random
	// integer line amounts.
	e, s, _ := newEngine(t)
	ctx := context.Background()
	require.NoError(t, s.UpsertCategory(ctx, tax.Category{
		ID: "MIX", Name: "Mix", TenantID: testTenant, PriceIncludesTax: false,
	}))
	require.NoError(t, s.UpsertComponent(ctx, tax.Component{
		ID: "C1", TaxCategoryID: "MIX", Name: "C1", RateBP: 333, SortOrder: 1,
	}))
	require.NoError(t, s.UpsertComponent(ctx, tax.Component{
		ID: "C2", TaxCategoryID: "MIX", Name: "C2", RateBP: 667, SortOrder: 2,
	}))

	// Try a range of awkward amounts.
	awkward := []payments.Money{
		usd(1, 230_000_000),  // 1.23
		usd(7, 770_000_000),  // 7.77
		usd(0, 990_000_000),  // 0.99
		usd(123, 456_789_012), // 123.456789012
	}
	for _, m := range awkward {
		resp, err := e.Compute(ctx, tax.ComputeRequest{
			TenantID: testTenant,
			Lines:    []tax.ComputeLine{{SKU: "X", TaxCategoryID: "MIX", LineTotal: m, Quantity: 1}},
		})
		require.NoError(t, err)

		var sum payments.Money
		sum.CurrencyCode = "USD"
		for _, c := range resp.Lines[0].Components {
			s2, err := sum.Add(c.Amount)
			require.NoError(t, err)
			sum = s2
		}
		require.True(t, sum.Equal(resp.Lines[0].Tax),
			"component sum %v must equal line tax %v for input %v", sum, resp.Lines[0].Tax, m)
	}
}

func TestCompute_MixedCategoriesOnOneSale(t *testing.T) {
	e, s, _ := newEngine(t)
	seedGST18(t, s, false)
	seedVAT20(t, s, true) // inclusive

	resp, err := e.Compute(context.Background(), tax.ComputeRequest{
		TenantID: testTenant,
		Lines: []tax.ComputeLine{
			{SKU: "A", TaxCategoryID: "GST-18", LineTotal: usd(100, 0), Quantity: 1}, // exclusive: net 100, tax 18
			{SKU: "B", TaxCategoryID: "VAT-20", LineTotal: usd(120, 0), Quantity: 1}, // inclusive: net 100, tax 20
			{SKU: "C", LineTotal: usd(50, 0), Quantity: 1},                           // exempt: net 50
		},
	})
	require.NoError(t, err)

	require.Equal(t, usd(250, 0), resp.Subtotal)   // 100 + 100 + 50
	require.Equal(t, usd(38, 0), resp.TaxTotal)    // 18 + 20
	require.Equal(t, usd(288, 0), resp.GrandTotal) // 118 + 120 + 50

	// Breakdown groups across the whole sale.
	require.Len(t, resp.Breakdown, 3) // CGST, SGST, VAT
}

func TestCompute_UnknownCategory_Errors(t *testing.T) {
	e, _, _ := newEngine(t)
	_, err := e.Compute(context.Background(), tax.ComputeRequest{
		TenantID: testTenant,
		Lines:    []tax.ComputeLine{{SKU: "A", TaxCategoryID: "DOES-NOT-EXIST", LineTotal: usd(10, 0)}},
	})
	require.ErrorIs(t, err, tax.ErrCategoryNotFound)
}

func TestCompute_ArchivedCategory_Errors(t *testing.T) {
	e, s, _ := newEngine(t)
	seedVAT20(t, s, false)

	// Archive the category.
	cat, err := s.GetCategory(context.Background(), testTenant, "VAT-20")
	require.NoError(t, err)
	cat.ArchivedAt = ptrToNow()
	require.NoError(t, s.UpsertCategory(context.Background(), cat))

	_, err = e.Compute(context.Background(), tax.ComputeRequest{
		TenantID: testTenant,
		Lines:    []tax.ComputeLine{{SKU: "A", TaxCategoryID: "VAT-20", LineTotal: usd(10, 0)}},
	})
	require.ErrorIs(t, err, tax.ErrCategoryNotFound)
}

func TestCompute_MixedCurrency_Errors(t *testing.T) {
	e, _, _ := newEngine(t)
	_, err := e.Compute(context.Background(), tax.ComputeRequest{
		TenantID: testTenant,
		Lines: []tax.ComputeLine{
			{SKU: "A", LineTotal: usd(10, 0)},
			{SKU: "B", LineTotal: inr(10, 0)},
		},
	})
	require.ErrorIs(t, err, tax.ErrCurrencyMix)
}

func TestCompute_MissingTenant_Errors(t *testing.T) {
	e, _, _ := newEngine(t)
	_, err := e.Compute(context.Background(), tax.ComputeRequest{Lines: []tax.ComputeLine{{SKU: "A", LineTotal: usd(1, 0)}}})
	require.ErrorIs(t, err, tax.ErrEmptyTenant)
}

func TestCompute_EmptyCart_ReturnsZeroes(t *testing.T) {
	e, _, _ := newEngine(t)
	resp, err := e.Compute(context.Background(), tax.ComputeRequest{TenantID: testTenant})
	require.NoError(t, err)
	require.Empty(t, resp.Lines)
}

func TestStore_GetCategory_NotFound(t *testing.T) {
	_, s, _ := newEngine(t)
	_, err := s.GetCategory(context.Background(), testTenant, "nope")
	require.ErrorIs(t, err, tax.ErrCategoryNotFound)
}

func TestStore_UpsertCategory_Validates(t *testing.T) {
	_, s, _ := newEngine(t)
	err := s.UpsertCategory(context.Background(), tax.Category{ID: "X"})
	require.Error(t, err)
}

func TestStore_UpsertComponent_RangeCheck(t *testing.T) {
	_, s, _ := newEngine(t)
	require.NoError(t, s.UpsertCategory(context.Background(), tax.Category{
		ID: "CAT", Name: "Cat", TenantID: testTenant,
	}))
	err := s.UpsertComponent(context.Background(), tax.Component{
		ID: "BAD", TaxCategoryID: "CAT", Name: "X", RateBP: 200_000,
	})
	require.Error(t, err)
}
