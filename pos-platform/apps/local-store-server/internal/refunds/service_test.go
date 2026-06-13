package refunds_test

import (
	"context"
	"database/sql"
	"errors"
	"path/filepath"
	"sync/atomic"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/require"

	"github.com/mibjas/pos-platform/apps/local-store-server/internal/clock"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/db"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/inventory"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/invoices"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/opslog"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/payments"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/refunds"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/sales"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/syncstate"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/tax"
)

const (
	testNode   = "node-refunds-test"
	testTenant = "tenant-A"
	testStore  = "store-1"
)

type fakeNotifier struct{ n atomic.Int64 }

func (f *fakeNotifier) Notify()    { f.n.Add(1) }
func (f *fakeNotifier) Count() int { return int(f.n.Load()) }

type harness struct {
	db       *sql.DB
	ops      *opslog.Store
	inv      *inventory.Store
	pays     *payments.Store
	invs     *invoices.Store
	refs     *refunds.Store
	taxStore *tax.Store
	taxEng   *tax.Engine
	clk      *clock.Lamport
	notifier *fakeNotifier
	sales    *sales.Service
	svc      *refunds.Service
}

func newHarness(t *testing.T) *harness {
	t.Helper()
	ctx := context.Background()
	path := filepath.Join(t.TempDir(), "refunds.db")
	sqlDB, err := db.Open(ctx, db.Config{Path: path})
	require.NoError(t, err)
	t.Cleanup(func() { _ = sqlDB.Close() })
	require.NoError(t, db.RunMigrations(sqlDB))

	state := syncstate.NewStore(sqlDB)
	clk, err := clock.New(ctx, state)
	require.NoError(t, err)

	taxStore := tax.NewStore(sqlDB)
	h := &harness{
		db:       sqlDB,
		ops:      opslog.NewStore(sqlDB),
		inv:      inventory.NewStore(sqlDB, nil),
		pays:     payments.NewStore(sqlDB),
		invs:     invoices.NewStore(sqlDB, time.UTC),
		refs:     refunds.NewStore(sqlDB, time.UTC),
		taxStore: taxStore,
		taxEng:   tax.NewEngine(taxStore),
		clk:      clk,
		notifier: &fakeNotifier{},
	}
	h.sales, err = sales.NewService(sales.Config{
		DB: h.db, Ops: h.ops, Inv: h.inv, Pays: h.pays, Invoices: h.invs,
		Tax: h.taxEng, Clock: h.clk, Notifier: sales.NoopNotifier{},
		NodeID: testNode, TenantID: testTenant,
	})
	require.NoError(t, err)
	h.svc, err = refunds.NewService(refunds.Config{
		DB: h.db, Ops: h.ops, Inv: h.inv, Pays: h.pays, Invoices: h.invs,
		Refunds: h.refs, Tax: h.taxEng, Clock: h.clk, Notifier: h.notifier,
		NodeID: testNode, TenantID: testTenant,
		VoidWindow: 12 * time.Hour,
	})
	require.NoError(t, err)
	return h
}

func (h *harness) seedStock(t *testing.T, sku string, qty int64) {
	t.Helper()
	err := h.inv.Append(context.Background(), inventory.Movement{
		MovementID:   uuid.New(),
		SKU:          sku,
		StoreID:      testStore,
		Delta:        qty,
		Reason:       inventory.ReasonReceive,
		RefType:      "receive",
		RefID:        "seed",
		OccurredAt:   time.Now().UTC(),
		Lamport:      0,
		OriginNodeID: "seed",
	})
	require.NoError(t, err)
}

// makeSaleAt finalizes a 2x SKU-A @ $5.00 cash sale at the given time and
// returns the resulting FinalizeResponse so tests have the SaleID, the
// originating payment id, and the invoice on hand.
func (h *harness) makeSaleAt(t *testing.T, at time.Time, sku string, qty int64, unitUnits int64) (sales.FinalizeResponse, sales.FinalizeRequest) {
	t.Helper()
	unitPrice := payments.Money{CurrencyCode: "USD", Units: unitUnits}
	lineTotal, _ := unitPrice.Mul(qty)
	req := sales.FinalizeRequest{
		SaleID:    uuid.New(),
		StoreID:   testStore,
		CounterID: "counter-1",
		Lines: []sales.SaleLine{{
			LineID:    uuid.New(),
			SKU:       sku,
			Quantity:  qty,
			UnitPrice: unitPrice,
			LineTotal: lineTotal,
		}},
		Tenders: []sales.Tender{{
			PaymentID: uuid.New(),
			Method:    payments.MethodCash,
			Amount:    lineTotal,
		}},
		OccurredAt: at,
	}
	resp, err := h.sales.Finalize(context.Background(), req)
	require.NoError(t, err)
	return resp, req
}

// --- Void --------------------------------------------------------------

func TestVoid_HappyPath_RestoresInventoryAndReversesPayment(t *testing.T) {
	h := newHarness(t)
	h.seedStock(t, "SKU-A", 10)

	now := time.Now().UTC()
	sale, _ := h.makeSaleAt(t, now, "SKU-A", 2, 5)
	// After sale: stock = 10 - 2 = 8.
	stock, err := h.inv.StockOnHand(context.Background(), testStore, "SKU-A")
	require.NoError(t, err)
	require.Equal(t, int64(8), stock)

	voidResp, err := h.svc.Void(context.Background(), refunds.VoidRequest{
		VoidID:     uuid.New(),
		SaleID:     sale.SaleID,
		StoreID:    testStore,
		CounterID:  "counter-1",
		Reason:     "wrong sale",
		OccurredAt: now.Add(5 * time.Minute),
	})
	require.NoError(t, err)
	require.False(t, voidResp.Idempotent)
	require.NotEqual(t, uuid.Nil, voidResp.BatchID)

	// Stock should be back to 10.
	stock, err = h.inv.StockOnHand(context.Background(), testStore, "SKU-A")
	require.NoError(t, err)
	require.Equal(t, int64(10), stock)

	// Net payment balance for the sale should be zero (paid + reversed).
	bal, err := h.pays.Balance(context.Background(), sale.SaleID)
	require.NoError(t, err)
	require.True(t, bal.IsZero(), "expected zero net payment balance after void, got %v", bal)

	// Notifier fired.
	require.Equal(t, 1, h.notifier.Count())
}

func TestVoid_OutsideWindow_Rejected(t *testing.T) {
	h := newHarness(t)
	h.seedStock(t, "SKU-A", 10)

	// Sale finalized 24h ago; window is 12h.
	old := time.Now().UTC().Add(-24 * time.Hour)
	sale, _ := h.makeSaleAt(t, old, "SKU-A", 1, 5)

	_, err := h.svc.Void(context.Background(), refunds.VoidRequest{
		VoidID:     uuid.New(),
		SaleID:     sale.SaleID,
		StoreID:    testStore,
		OccurredAt: time.Now().UTC(),
	})
	require.ErrorIs(t, err, refunds.ErrVoidWindowClosed)
}

func TestVoid_AfterRefund_Rejected(t *testing.T) {
	h := newHarness(t)
	h.seedStock(t, "SKU-A", 10)

	now := time.Now().UTC()
	sale, saleReq := h.makeSaleAt(t, now, "SKU-A", 2, 5)

	// Refund 1 unit.
	originalLine := saleReq.Lines[0]
	unitPrice := originalLine.UnitPrice
	lineTotal, _ := unitPrice.Mul(1)
	_, err := h.svc.Refund(context.Background(), refunds.RefundRequest{
		RefundID:   uuid.New(),
		SaleID:     sale.SaleID,
		StoreID:    testStore,
		OccurredAt: now.Add(1 * time.Hour),
		Lines: []refunds.RefundLineRequest{{
			SaleLineID: originalLine.LineID,
			SKU:        originalLine.SKU,
			Quantity:   1,
			Restock:    true,
			UnitPrice:  unitPrice,
			LineTotal:  lineTotal,
		}},
		Tenders: []refunds.RefundTenderRequest{{
			RefundPaymentID:   uuid.New(),
			OriginalPaymentID: saleReq.Tenders[0].PaymentID,
			Method:            payments.MethodCash,
			Amount:            lineTotal,
		}},
	})
	require.NoError(t, err)

	// Now try to void — must be rejected.
	_, err = h.svc.Void(context.Background(), refunds.VoidRequest{
		VoidID:     uuid.New(),
		SaleID:     sale.SaleID,
		StoreID:    testStore,
		OccurredAt: now.Add(2 * time.Hour),
	})
	require.ErrorIs(t, err, refunds.ErrCannotVoidRefunded)
}

func TestVoid_Idempotent_SameVoidID(t *testing.T) {
	h := newHarness(t)
	h.seedStock(t, "SKU-A", 10)

	now := time.Now().UTC()
	sale, _ := h.makeSaleAt(t, now, "SKU-A", 2, 5)

	voidID := uuid.New()
	req := refunds.VoidRequest{
		VoidID:     voidID,
		SaleID:     sale.SaleID,
		StoreID:    testStore,
		OccurredAt: now.Add(5 * time.Minute),
	}
	first, err := h.svc.Void(context.Background(), req)
	require.NoError(t, err)
	require.False(t, first.Idempotent)

	second, err := h.svc.Void(context.Background(), req)
	require.NoError(t, err)
	require.True(t, second.Idempotent)
	require.Equal(t, first.BatchID, second.BatchID)
	require.Equal(t, first.Lamport, second.Lamport)

	// Stock should only have been restored ONCE (== 10), not twice.
	stock, err := h.inv.StockOnHand(context.Background(), testStore, "SKU-A")
	require.NoError(t, err)
	require.Equal(t, int64(10), stock)
}

// --- Refund ------------------------------------------------------------

func TestRefund_PartialRefund_RestocksAndReversesProportionalPayment(t *testing.T) {
	h := newHarness(t)
	h.seedStock(t, "SKU-A", 10)

	now := time.Now().UTC()
	sale, saleReq := h.makeSaleAt(t, now, "SKU-A", 3, 5) // sold 3 @ $5 = $15
	// After: stock = 10 - 3 = 7.
	stock, err := h.inv.StockOnHand(context.Background(), testStore, "SKU-A")
	require.NoError(t, err)
	require.Equal(t, int64(7), stock)

	originalLine := saleReq.Lines[0]
	unitPrice := originalLine.UnitPrice
	refundQty := int64(1)
	lineTotal, _ := unitPrice.Mul(refundQty)

	resp, err := h.svc.Refund(context.Background(), refunds.RefundRequest{
		RefundID:   uuid.New(),
		SaleID:     sale.SaleID,
		StoreID:    testStore,
		CounterID:  "counter-1",
		OccurredAt: now.Add(2 * time.Hour),
		Lines: []refunds.RefundLineRequest{{
			SaleLineID: originalLine.LineID,
			SKU:        originalLine.SKU,
			Quantity:   refundQty,
			Restock:    true,
			UnitPrice:  unitPrice,
			LineTotal:  lineTotal,
		}},
		Tenders: []refunds.RefundTenderRequest{{
			RefundPaymentID:   uuid.New(),
			OriginalPaymentID: saleReq.Tenders[0].PaymentID,
			Method:            payments.MethodCash,
			Amount:            lineTotal,
		}},
	})
	require.NoError(t, err)
	require.False(t, resp.Idempotent)
	require.Contains(t, resp.Refund.CreditNoteNumber, "CN-")

	// Restock=true → stock back to 8 (10 - 3 sold + 1 refunded).
	stock, err = h.inv.StockOnHand(context.Background(), testStore, "SKU-A")
	require.NoError(t, err)
	require.Equal(t, int64(8), stock)

	// Net payment balance = $15 sold - $5 refunded = $10.
	bal, err := h.pays.Balance(context.Background(), sale.SaleID)
	require.NoError(t, err)
	expected := payments.Money{CurrencyCode: "USD", Units: 10}
	require.True(t, bal.Equal(expected), "expected $10 net, got %v", bal)
}

func TestRefund_NoRestockFlag_KeepsItemOffShelf(t *testing.T) {
	h := newHarness(t)
	h.seedStock(t, "SKU-A", 5)

	now := time.Now().UTC()
	sale, saleReq := h.makeSaleAt(t, now, "SKU-A", 2, 4)
	originalLine := saleReq.Lines[0]
	unitPrice := originalLine.UnitPrice
	lineTotal, _ := unitPrice.Mul(1)

	_, err := h.svc.Refund(context.Background(), refunds.RefundRequest{
		RefundID:   uuid.New(),
		SaleID:     sale.SaleID,
		StoreID:    testStore,
		OccurredAt: now.Add(1 * time.Hour),
		Lines: []refunds.RefundLineRequest{{
			SaleLineID: originalLine.LineID,
			SKU:        originalLine.SKU,
			Quantity:   1,
			Restock:    false, // damaged return
			UnitPrice:  unitPrice,
			LineTotal:  lineTotal,
		}},
		Tenders: []refunds.RefundTenderRequest{{
			RefundPaymentID:   uuid.New(),
			OriginalPaymentID: saleReq.Tenders[0].PaymentID,
			Method:            payments.MethodCash,
			Amount:            lineTotal,
		}},
	})
	require.NoError(t, err)

	// Stock should remain at (5 - 2) = 3; the refunded item did NOT re-shelve.
	stock, err := h.inv.StockOnHand(context.Background(), testStore, "SKU-A")
	require.NoError(t, err)
	require.Equal(t, int64(3), stock)
}

func TestRefund_OverRefund_Rejected(t *testing.T) {
	h := newHarness(t)
	h.seedStock(t, "SKU-A", 10)

	now := time.Now().UTC()
	sale, saleReq := h.makeSaleAt(t, now, "SKU-A", 2, 5)
	originalLine := saleReq.Lines[0]
	unitPrice := originalLine.UnitPrice
	lineTotalThree, _ := unitPrice.Mul(3) // refund 3 of qty=2

	_, err := h.svc.Refund(context.Background(), refunds.RefundRequest{
		RefundID:   uuid.New(),
		SaleID:     sale.SaleID,
		StoreID:    testStore,
		OccurredAt: now.Add(1 * time.Hour),
		Lines: []refunds.RefundLineRequest{{
			SaleLineID: originalLine.LineID,
			SKU:        originalLine.SKU,
			Quantity:   3,
			Restock:    true,
			UnitPrice:  unitPrice,
			LineTotal:  lineTotalThree,
		}},
		Tenders: []refunds.RefundTenderRequest{{
			RefundPaymentID:   uuid.New(),
			OriginalPaymentID: saleReq.Tenders[0].PaymentID,
			Method:            payments.MethodCash,
			Amount:            lineTotalThree,
		}},
	})
	var over *refunds.ErrOverRefund
	require.ErrorAs(t, err, &over)
	require.Equal(t, int64(2), over.SoldQuantity)
	require.Equal(t, int64(3), over.RequestedQty)
}

func TestRefund_CumulativeOverRefund_Rejected(t *testing.T) {
	h := newHarness(t)
	h.seedStock(t, "SKU-A", 10)

	now := time.Now().UTC()
	sale, saleReq := h.makeSaleAt(t, now, "SKU-A", 3, 5)
	originalLine := saleReq.Lines[0]
	unitPrice := originalLine.UnitPrice

	// First refund of 2 — fine (3 sold, 2 refunded).
	lineTotal2, _ := unitPrice.Mul(2)
	_, err := h.svc.Refund(context.Background(), refunds.RefundRequest{
		RefundID:   uuid.New(),
		SaleID:     sale.SaleID,
		StoreID:    testStore,
		OccurredAt: now.Add(1 * time.Hour),
		Lines: []refunds.RefundLineRequest{{
			SaleLineID: originalLine.LineID, SKU: originalLine.SKU,
			Quantity: 2, Restock: true, UnitPrice: unitPrice, LineTotal: lineTotal2,
		}},
		Tenders: []refunds.RefundTenderRequest{{
			RefundPaymentID:   uuid.New(),
			OriginalPaymentID: saleReq.Tenders[0].PaymentID,
			Method:            payments.MethodCash,
			Amount:            lineTotal2,
		}},
	})
	require.NoError(t, err)

	// Second refund of 2 — sold 3, already 2, requested 2 → over by 1.
	_, err = h.svc.Refund(context.Background(), refunds.RefundRequest{
		RefundID:   uuid.New(),
		SaleID:     sale.SaleID,
		StoreID:    testStore,
		OccurredAt: now.Add(2 * time.Hour),
		Lines: []refunds.RefundLineRequest{{
			SaleLineID: originalLine.LineID, SKU: originalLine.SKU,
			Quantity: 2, Restock: true, UnitPrice: unitPrice, LineTotal: lineTotal2,
		}},
		Tenders: []refunds.RefundTenderRequest{{
			RefundPaymentID:   uuid.New(),
			OriginalPaymentID: saleReq.Tenders[0].PaymentID,
			Method:            payments.MethodCash,
			Amount:            lineTotal2,
		}},
	})
	var over *refunds.ErrOverRefund
	require.ErrorAs(t, err, &over)
	require.Equal(t, int64(2), over.AlreadyQty)
}

func TestRefund_TenderMethodMismatch_Rejected(t *testing.T) {
	h := newHarness(t)
	h.seedStock(t, "SKU-A", 10)

	now := time.Now().UTC()
	sale, saleReq := h.makeSaleAt(t, now, "SKU-A", 2, 5)
	originalLine := saleReq.Lines[0]
	unitPrice := originalLine.UnitPrice
	lineTotal, _ := unitPrice.Mul(1)

	_, err := h.svc.Refund(context.Background(), refunds.RefundRequest{
		RefundID:   uuid.New(),
		SaleID:     sale.SaleID,
		StoreID:    testStore,
		OccurredAt: now.Add(1 * time.Hour),
		Lines: []refunds.RefundLineRequest{{
			SaleLineID: originalLine.LineID, SKU: originalLine.SKU,
			Quantity: 1, Restock: true, UnitPrice: unitPrice, LineTotal: lineTotal,
		}},
		Tenders: []refunds.RefundTenderRequest{{
			RefundPaymentID:   uuid.New(),
			OriginalPaymentID: saleReq.Tenders[0].PaymentID,
			Method:            payments.MethodCard, // original was cash
			Amount:            lineTotal,
		}},
	})
	require.ErrorIs(t, err, refunds.ErrTenderMismatch)
}

func TestRefund_TenderSumMismatch_Rejected(t *testing.T) {
	h := newHarness(t)
	h.seedStock(t, "SKU-A", 10)

	now := time.Now().UTC()
	sale, saleReq := h.makeSaleAt(t, now, "SKU-A", 2, 5)
	originalLine := saleReq.Lines[0]
	unitPrice := originalLine.UnitPrice
	lineTotal, _ := unitPrice.Mul(1)
	wrongTenderAmt := payments.Money{CurrencyCode: "USD", Units: 99}

	_, err := h.svc.Refund(context.Background(), refunds.RefundRequest{
		RefundID:   uuid.New(),
		SaleID:     sale.SaleID,
		StoreID:    testStore,
		OccurredAt: now.Add(1 * time.Hour),
		Lines: []refunds.RefundLineRequest{{
			SaleLineID: originalLine.LineID, SKU: originalLine.SKU,
			Quantity: 1, Restock: true, UnitPrice: unitPrice, LineTotal: lineTotal,
		}},
		Tenders: []refunds.RefundTenderRequest{{
			RefundPaymentID:   uuid.New(),
			OriginalPaymentID: saleReq.Tenders[0].PaymentID,
			Method:            payments.MethodCash,
			Amount:            wrongTenderAmt,
		}},
	})
	require.ErrorIs(t, err, refunds.ErrTenderSumMismatch)
}

func TestRefund_OnVoidedSale_Rejected(t *testing.T) {
	h := newHarness(t)
	h.seedStock(t, "SKU-A", 10)

	now := time.Now().UTC()
	sale, saleReq := h.makeSaleAt(t, now, "SKU-A", 2, 5)

	// Void first.
	_, err := h.svc.Void(context.Background(), refunds.VoidRequest{
		VoidID:     uuid.New(),
		SaleID:     sale.SaleID,
		StoreID:    testStore,
		OccurredAt: now.Add(5 * time.Minute),
	})
	require.NoError(t, err)

	// Refund on voided sale must reject.
	originalLine := saleReq.Lines[0]
	unitPrice := originalLine.UnitPrice
	lineTotal, _ := unitPrice.Mul(1)
	_, err = h.svc.Refund(context.Background(), refunds.RefundRequest{
		RefundID:   uuid.New(),
		SaleID:     sale.SaleID,
		StoreID:    testStore,
		OccurredAt: now.Add(10 * time.Minute),
		Lines: []refunds.RefundLineRequest{{
			SaleLineID: originalLine.LineID, SKU: originalLine.SKU,
			Quantity: 1, Restock: true, UnitPrice: unitPrice, LineTotal: lineTotal,
		}},
		Tenders: []refunds.RefundTenderRequest{{
			RefundPaymentID:   uuid.New(),
			OriginalPaymentID: saleReq.Tenders[0].PaymentID,
			Method:            payments.MethodCash,
			Amount:            lineTotal,
		}},
	})
	require.ErrorIs(t, err, refunds.ErrCannotRefundVoided)
}

func TestRefund_CreditNoteSequence_GaplessPerStorePerYear(t *testing.T) {
	h := newHarness(t)
	h.seedStock(t, "SKU-A", 10)

	now := time.Now().UTC()
	sale, saleReq := h.makeSaleAt(t, now, "SKU-A", 3, 5)
	originalLine := saleReq.Lines[0]
	unitPrice := originalLine.UnitPrice
	lineTotal, _ := unitPrice.Mul(1)

	// Three separate refunds — each one CN.
	var cnNumbers []string
	for i := 0; i < 3; i++ {
		resp, err := h.svc.Refund(context.Background(), refunds.RefundRequest{
			RefundID:   uuid.New(),
			SaleID:     sale.SaleID,
			StoreID:    testStore,
			OccurredAt: now.Add(time.Duration(i+1) * time.Hour),
			Lines: []refunds.RefundLineRequest{{
				SaleLineID: originalLine.LineID, SKU: originalLine.SKU,
				Quantity: 1, Restock: true, UnitPrice: unitPrice, LineTotal: lineTotal,
			}},
			Tenders: []refunds.RefundTenderRequest{{
				RefundPaymentID:   uuid.New(),
				OriginalPaymentID: saleReq.Tenders[0].PaymentID,
				Method:            payments.MethodCash,
				Amount:            lineTotal,
			}},
		})
		require.NoError(t, err)
		cnNumbers = append(cnNumbers, resp.Refund.CreditNoteNumber)
	}
	year := now.Year()
	require.Equal(t, []string{
		formatCN(year, 1),
		formatCN(year, 2),
		formatCN(year, 3),
	}, cnNumbers)
}

func TestRefund_Idempotent_SameRefundID(t *testing.T) {
	h := newHarness(t)
	h.seedStock(t, "SKU-A", 10)

	now := time.Now().UTC()
	sale, saleReq := h.makeSaleAt(t, now, "SKU-A", 2, 5)
	originalLine := saleReq.Lines[0]
	unitPrice := originalLine.UnitPrice
	lineTotal, _ := unitPrice.Mul(1)

	refundID := uuid.New()
	req := refunds.RefundRequest{
		RefundID:   refundID,
		SaleID:     sale.SaleID,
		StoreID:    testStore,
		OccurredAt: now.Add(1 * time.Hour),
		Lines: []refunds.RefundLineRequest{{
			SaleLineID: originalLine.LineID, SKU: originalLine.SKU,
			Quantity: 1, Restock: true, UnitPrice: unitPrice, LineTotal: lineTotal,
		}},
		Tenders: []refunds.RefundTenderRequest{{
			RefundPaymentID:   uuid.New(),
			OriginalPaymentID: saleReq.Tenders[0].PaymentID,
			Method:            payments.MethodCash,
			Amount:            lineTotal,
		}},
	}
	first, err := h.svc.Refund(context.Background(), req)
	require.NoError(t, err)
	require.False(t, first.Idempotent)

	second, err := h.svc.Refund(context.Background(), req)
	require.NoError(t, err)
	require.True(t, second.Idempotent)
	require.Equal(t, first.Refund.CreditNoteNumber, second.Refund.CreditNoteNumber)
}

func TestRefund_UnknownSKU_Rejected(t *testing.T) {
	h := newHarness(t)
	h.seedStock(t, "SKU-A", 10)

	now := time.Now().UTC()
	sale, saleReq := h.makeSaleAt(t, now, "SKU-A", 2, 5)
	originalLine := saleReq.Lines[0]
	unitPrice := originalLine.UnitPrice
	lineTotal, _ := unitPrice.Mul(1)

	_, err := h.svc.Refund(context.Background(), refunds.RefundRequest{
		RefundID:   uuid.New(),
		SaleID:     sale.SaleID,
		StoreID:    testStore,
		OccurredAt: now.Add(1 * time.Hour),
		Lines: []refunds.RefundLineRequest{{
			SaleLineID: uuid.New(),
			SKU:        "SKU-NONEXISTENT", // not in original sale
			Quantity:   1,
			Restock:    true,
			UnitPrice:  unitPrice,
			LineTotal:  lineTotal,
		}},
		Tenders: []refunds.RefundTenderRequest{{
			RefundPaymentID:   uuid.New(),
			OriginalPaymentID: saleReq.Tenders[0].PaymentID,
			Method:            payments.MethodCash,
			Amount:            lineTotal,
		}},
	})
	var unknown *refunds.ErrUnknownSaleLine
	require.True(t, errors.As(err, &unknown), "expected ErrUnknownSaleLine, got %v", err)
}

// --- helpers ----------------------------------------------------------

func formatCN(year int, seq int) string {
	return formatYYYYNNN("CN", year, seq)
}

func formatYYYYNNN(prefix string, year, seq int) string {
	return prefix + "-" + pad4(year) + "-" + pad6(seq)
}

func pad4(n int) string {
	s := []byte("0000")
	for i := 3; i >= 0 && n > 0; i-- {
		s[i] = byte('0' + n%10)
		n /= 10
	}
	return string(s)
}

func pad6(n int) string {
	s := []byte("000000")
	for i := 5; i >= 0 && n > 0; i-- {
		s[i] = byte('0' + n%10)
		n /= 10
	}
	return string(s)
}
