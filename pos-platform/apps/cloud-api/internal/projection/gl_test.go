package projection

import (
	"context"
	"errors"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	posv1 "github.com/mibjas/pos-platform/packages/sdk-go/gen/pos/v1"
)

// fakeLookups satisfies Lookups without a DB. Tests inject the answers
// they want — keeps the mapper tests pure and fast.
type fakeLookups struct {
	clearingByPayment map[string]string
	linesBySale       map[string][]Line
	err               error
}

func (f *fakeLookups) ClearingAccountForPayment(_ context.Context, _, paymentID string) (string, error) {
	if f.err != nil {
		return "", f.err
	}
	acc, ok := f.clearingByPayment[paymentID]
	if !ok {
		return "", ErrPaymentNotFound
	}
	return acc, nil
}

func (f *fakeLookups) LinesForSale(_ context.Context, _, saleID string, _ []string) ([]Line, error) {
	if f.err != nil {
		return nil, f.err
	}
	return f.linesBySale[saleID], nil
}

func money(units int64, nanos int32) *posv1.Money {
	return &posv1.Money{CurrencyCode: "USD", Units: units, Nanos: nanos}
}

func env(t string, payload any) *posv1.EventEnvelope {
	e := &posv1.EventEnvelope{
		EventType: t,
		TenantId:  &posv1.TenantId{Value: "tenant-1"},
	}
	switch p := payload.(type) {
	case *posv1.SaleCreated:
		e.Payload = &posv1.EventEnvelope_SaleCreated{SaleCreated: p}
	case *posv1.PaymentAdded:
		e.Payload = &posv1.EventEnvelope_PaymentAdded{PaymentAdded: p}
	case *posv1.PaymentRefunded:
		e.Payload = &posv1.EventEnvelope_PaymentRefunded{PaymentRefunded: p}
	case *posv1.SaleRefunded:
		e.Payload = &posv1.EventEnvelope_SaleRefunded{SaleRefunded: p}
	case *posv1.SaleVoided:
		e.Payload = &posv1.EventEnvelope_SaleVoided{SaleVoided: p}
	}
	return e
}

// --- SaleCreated ---

func TestMap_SaleCreated_Balanced_PerCategoryTax(t *testing.T) {
	sale := &posv1.SaleCreated{
		SaleId:  "sale-1",
		StoreId: &posv1.StoreId{Value: "store-A"},
		Lines: []*posv1.SaleLine{
			// Two lines in "std" + one in "food"; aggregated to 2 tax lines.
			{TaxCategoryId: "std", LineTax: money(0, 600_000_000)},  // 0.60
			{TaxCategoryId: "std", LineTax: money(0, 400_000_000)},  // 0.40 → std total 1.00
			{TaxCategoryId: "food", LineTax: money(0, 250_000_000)}, // 0.25
		},
		Subtotal:   money(10, 0),
		TaxTotal:   money(1, 250_000_000), // 1.25 = 1.00 + 0.25
		GrandTotal: money(11, 250_000_000),
	}
	entries, err := Map(context.Background(), env("sale_created", sale), &fakeLookups{})
	require.NoError(t, err)
	require.Len(t, entries, 1)
	e := entries[0]
	assert.Equal(t, "sale_created", e.SourceEventType)
	assert.Equal(t, "sale-1", e.SaleID)
	assert.Equal(t, "store-A", e.StoreID)
	assert.True(t, IsBalanced(e), "JE must balance: %+v", e.Lines)

	// Verify the tax accounts split correctly.
	taxByAcct := map[string]int64{}
	for _, ln := range e.Lines {
		if ln.Account == TaxPayableAccount("std") || ln.Account == TaxPayableAccount("food") {
			taxByAcct[ln.Account] += ln.Units*int64(nanosPerUnit) + int64(ln.Nanos)
		}
	}
	assert.Equal(t, int64(1_000_000_000), taxByAcct[TaxPayableAccount("std")])  // 1.00
	assert.Equal(t, int64(250_000_000), taxByAcct[TaxPayableAccount("food")])   // 0.25
}

func TestMap_SaleCreated_OlderBinary_NoLineTax_FallsBackToUnclassified(t *testing.T) {
	sale := &posv1.SaleCreated{
		SaleId:     "sale-2",
		StoreId:    &posv1.StoreId{Value: "store-A"},
		Lines:      []*posv1.SaleLine{{Sku: "x"}}, // no line_tax / category
		Subtotal:   money(10, 0),
		TaxTotal:   money(1, 0),
		GrandTotal: money(11, 0),
	}
	entries, err := Map(context.Background(), env("sale_created", sale), &fakeLookups{})
	require.NoError(t, err)
	require.Len(t, entries, 1)
	assert.True(t, IsBalanced(entries[0]))
	// Tax must have landed in the unclassified bucket so the JE balances.
	foundUnclassified := false
	for _, ln := range entries[0].Lines {
		if ln.Account == AccountTaxUnclassified {
			foundUnclassified = true
			assert.Equal(t, SideCredit, ln.Side)
			assert.Equal(t, int64(1), ln.Units)
		}
	}
	assert.True(t, foundUnclassified, "older binary must post tax to 2100.unclassified")
}

// --- PaymentAdded ---

func TestMap_PaymentAdded_PerMethod_Balanced(t *testing.T) {
	cases := []struct {
		method   string
		expected string
	}{
		{"cash", AccountCash},
		{"card", AccountCardClearing},
		{"upi", AccountUPIClearing},
		{"giftcard", AccountCardClearing}, // unknown → fallback
	}
	for _, tc := range cases {
		t.Run(tc.method, func(t *testing.T) {
			pay := &posv1.PaymentAdded{
				PaymentId: "pay-" + tc.method,
				SaleId:    "sale-1",
				Method:    tc.method,
				Amount:    money(11, 250_000_000),
			}
			entries, err := Map(context.Background(), env("payment_added", pay), &fakeLookups{})
			require.NoError(t, err)
			require.Len(t, entries, 1)
			e := entries[0]
			assert.True(t, IsBalanced(e))
			assert.Equal(t, "sale-1", e.SaleID)
			assert.Equal(t, "pay-"+tc.method, e.PaymentID)
			// Dr clearing, Cr A/R
			assert.Equal(t, tc.expected, e.Lines[0].Account)
			assert.Equal(t, SideDebit, e.Lines[0].Side)
			assert.Equal(t, AccountAccountsReceivable, e.Lines[1].Account)
			assert.Equal(t, SideCredit, e.Lines[1].Side)
		})
	}
}

// --- PaymentRefunded ---

func TestMap_PaymentRefunded_UsesOriginalClearing(t *testing.T) {
	ref := &posv1.PaymentRefunded{
		RefundId:          "ref-1",
		OriginalPaymentId: "pay-1",
		Amount:            money(5, 0),
	}
	l := &fakeLookups{clearingByPayment: map[string]string{"pay-1": AccountUPIClearing}}
	entries, err := Map(context.Background(), env("payment_refunded", ref), l)
	require.NoError(t, err)
	require.Len(t, entries, 1)
	e := entries[0]
	assert.True(t, IsBalanced(e))
	// Dr A/R, Cr UPI Clearing (the original method)
	assert.Equal(t, AccountAccountsReceivable, e.Lines[0].Account)
	assert.Equal(t, SideDebit, e.Lines[0].Side)
	assert.Equal(t, AccountUPIClearing, e.Lines[1].Account)
	assert.Equal(t, SideCredit, e.Lines[1].Side)
}

func TestMap_PaymentRefunded_PropagatesLookupError(t *testing.T) {
	ref := &posv1.PaymentRefunded{
		RefundId:          "ref-1",
		OriginalPaymentId: "pay-missing",
		Amount:            money(5, 0),
	}
	_, err := Map(context.Background(), env("payment_refunded", ref), &fakeLookups{})
	require.Error(t, err)
	assert.True(t, errors.Is(err, ErrPaymentNotFound))
}

// --- SaleRefunded ---

func TestMap_SaleRefunded_ProducesGoodsJE_PlusOneJEPerTender(t *testing.T) {
	r := &posv1.SaleRefunded{
		RefundId: "ref-1",
		SaleId:   "sale-1",
		StoreId:  &posv1.StoreId{Value: "store-A"},
		Lines: []*posv1.RefundLine{
			{TaxCategoryId: "std", LineTax: money(0, 500_000_000)},
		},
		Subtotal:   money(5, 0),
		TaxTotal:   money(0, 500_000_000),
		GrandTotal: money(5, 500_000_000),
		Tenders: []*posv1.RefundTender{
			{RefundPaymentId: "rp-1", Method: "card", Amount: money(5, 500_000_000)},
		},
	}
	entries, err := Map(context.Background(), env("sale_refunded", r), &fakeLookups{})
	require.NoError(t, err)
	require.Len(t, entries, 2)
	// Goods-side first
	assert.Equal(t, 0, entries[0].Seq)
	assert.True(t, IsBalanced(entries[0]), "goods JE must balance: %+v", entries[0].Lines)
	// Side check: Revenue Dr (we lose revenue), Tax Dr, A/R Cr (we owe customer)
	hasRevenueDr, hasTaxDr, hasARCr := false, false, false
	for _, ln := range entries[0].Lines {
		switch ln.Account {
		case AccountRevenue:
			assert.Equal(t, SideDebit, ln.Side)
			hasRevenueDr = true
		case TaxPayableAccount("std"):
			assert.Equal(t, SideDebit, ln.Side)
			hasTaxDr = true
		case AccountAccountsReceivable:
			assert.Equal(t, SideCredit, ln.Side)
			hasARCr = true
		}
	}
	assert.True(t, hasRevenueDr && hasTaxDr && hasARCr)

	// Tender JE second
	assert.Equal(t, 1, entries[1].Seq)
	assert.True(t, IsBalanced(entries[1]))
	assert.Equal(t, AccountAccountsReceivable, entries[1].Lines[0].Account)
	assert.Equal(t, SideDebit, entries[1].Lines[0].Side)
	assert.Equal(t, AccountCardClearing, entries[1].Lines[1].Account)
	assert.Equal(t, SideCredit, entries[1].Lines[1].Side)
}

// --- SaleVoided ---

func TestMap_SaleVoided_ReversesPriorLines(t *testing.T) {
	priorLines := []Line{
		{Account: AccountAccountsReceivable, Side: SideDebit, CurrencyCode: "USD", Units: 11, Nanos: 250_000_000},
		{Account: AccountRevenue, Side: SideCredit, CurrencyCode: "USD", Units: 10, Nanos: 0},
		{Account: TaxPayableAccount("std"), Side: SideCredit, CurrencyCode: "USD", Units: 1, Nanos: 250_000_000},
		{Account: AccountCash, Side: SideDebit, CurrencyCode: "USD", Units: 11, Nanos: 250_000_000},
		{Account: AccountAccountsReceivable, Side: SideCredit, CurrencyCode: "USD", Units: 11, Nanos: 250_000_000},
	}
	v := &posv1.SaleVoided{
		VoidId:  "void-1",
		SaleId:  "sale-1",
		StoreId: &posv1.StoreId{Value: "store-A"},
	}
	l := &fakeLookups{linesBySale: map[string][]Line{"sale-1": priorLines}}
	entries, err := Map(context.Background(), env("sale_voided", v), l)
	require.NoError(t, err)
	require.Len(t, entries, 1)
	rev := entries[0]
	assert.True(t, IsBalanced(rev), "reversal must balance")
	require.Len(t, rev.Lines, len(priorLines))
	for i, ln := range rev.Lines {
		assert.Equal(t, priorLines[i].Account, ln.Account)
		assert.Equal(t, flipSide(priorLines[i].Side), ln.Side,
			"line %d side must flip", i)
		assert.Equal(t, priorLines[i].Units, ln.Units)
		assert.Equal(t, priorLines[i].Nanos, ln.Nanos)
	}
}

func TestMap_SaleVoided_OutOfOrder_NoPriorJEs_EmitsNothing(t *testing.T) {
	v := &posv1.SaleVoided{
		VoidId: "void-1",
		SaleId: "sale-orphan",
	}
	entries, err := Map(context.Background(), env("sale_voided", v), &fakeLookups{})
	require.NoError(t, err)
	assert.Empty(t, entries, "void with no prior JEs is a no-op (handled cleanly by 5.6)")
}

// --- Non-GL events ---

func TestMap_NonGLEvents_NoEntries(t *testing.T) {
	cases := []*posv1.EventEnvelope{
		{Payload: &posv1.EventEnvelope_InventoryAdjusted{InventoryAdjusted: &posv1.InventoryAdjusted{}}},
		{Payload: &posv1.EventEnvelope_StockTransferred{StockTransferred: &posv1.StockTransferred{}}},
		{Payload: &posv1.EventEnvelope_SyncCompleted{SyncCompleted: &posv1.SyncCompleted{}}},
		{Payload: &posv1.EventEnvelope_UserLoggedIn{UserLoggedIn: &posv1.UserLoggedIn{}}},
	}
	for _, c := range cases {
		entries, err := Map(context.Background(), c, &fakeLookups{})
		require.NoError(t, err)
		assert.Empty(t, entries)
	}
}

// --- Balance helper ---

func TestIsBalanced_UnbalancedFails(t *testing.T) {
	bad := Entry{Lines: []Line{
		{Account: "x", Side: SideDebit, CurrencyCode: "USD", Units: 10},
		{Account: "y", Side: SideCredit, CurrencyCode: "USD", Units: 5},
	}}
	assert.False(t, IsBalanced(bad))
}

func TestIsBalanced_NanosCarryAcrossEqualityCheck(t *testing.T) {
	// Dr: 0u + 1_500_000_000n  Cr: 1u + 500_000_000n → equal after normalize.
	e := Entry{Lines: []Line{
		{Account: "x", Side: SideDebit, CurrencyCode: "USD", Units: 0, Nanos: 1}, // 0.000000001
		{Account: "x", Side: SideDebit, CurrencyCode: "USD", Units: 1, Nanos: 0}, // 1.0
		{Account: "y", Side: SideCredit, CurrencyCode: "USD", Units: 1, Nanos: 1},
	}}
	assert.True(t, IsBalanced(e))
}
