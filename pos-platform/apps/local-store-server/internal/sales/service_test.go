package sales_test

import (
	"context"
	"database/sql"
	"errors"
	"path/filepath"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/require"
	"google.golang.org/protobuf/proto"

	"github.com/mibjas/pos-platform/apps/local-store-server/internal/clock"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/db"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/events"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/inventory"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/invoices"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/opslog"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/payments"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/reservations"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/sales"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/syncstate"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/tax"

	posv1 "github.com/mibjas/pos-platform/packages/sdk-go/gen/pos/v1"
)

const (
	testNode   = "node-sales-test"
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
	taxStore *tax.Store
	taxEng   *tax.Engine
	clk      *clock.Lamport
	notifier *fakeNotifier
	pub      *fakePublisher // nil unless built by newHarnessWithPublisher
	svc      *sales.Service
}

func newHarness(t *testing.T) *harness {
	t.Helper()
	ctx := context.Background()
	path := filepath.Join(t.TempDir(), "sales.db")
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
		taxStore: taxStore,
		taxEng:   tax.NewEngine(taxStore),
		clk:      clk,
		notifier: &fakeNotifier{},
	}
	h.svc, err = sales.NewService(sales.Config{
		DB:       h.db,
		Ops:      h.ops,
		Inv:      h.inv,
		Pays:     h.pays,
		Invoices: h.invs,
		Tax:      h.taxEng,
		Clock:    h.clk,
		Notifier: h.notifier,
		NodeID:   testNode,
		TenantID: testTenant,
	})
	require.NoError(t, err)
	return h
}

// seedCategoryExclusive creates a single-component exclusive tax category
// for use in this harness's tenant. Returns nothing — the category id is
// the one the caller passes in.
func (h *harness) seedCategoryExclusive(t *testing.T, categoryID string, rateBP int32) {
	t.Helper()
	ctx := context.Background()
	require.NoError(t, h.taxStore.UpsertCategory(ctx, tax.Category{
		ID: categoryID, Name: categoryID, TenantID: testTenant, PriceIncludesTax: false,
	}))
	require.NoError(t, h.taxStore.UpsertComponent(ctx, tax.Component{
		ID: categoryID + "-COMP", TaxCategoryID: categoryID, Name: categoryID, RateBP: rateBP,
	}))
}

// seedStock writes a positive 'receive' movement so subsequent sales succeed.
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

// mkSale builds a FinalizeRequest for one SKU at qty units of $unitPrice each,
// paid by a single tender. No tax.
func mkSale(sku string, qty int64, unitUnits int64, unitNanos int32) sales.FinalizeRequest {
	unitPrice := payments.Money{CurrencyCode: "USD", Units: unitUnits, Nanos: unitNanos}
	lineTotal, _ := unitPrice.Mul(qty)
	return sales.FinalizeRequest{
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
		Subtotal:   lineTotal,
		TaxTotal:   payments.Money{CurrencyCode: "USD"},
		GrandTotal: lineTotal,
		OccurredAt: time.Now().UTC(),
	}
}

// --- tests ---

// fakePublisher records every envelope it sees. Concurrency-safe so
// test bodies can read it after Finalize returns.
type fakePublisher struct {
	mu     sync.Mutex
	events []*posv1.EventEnvelope
}

func (p *fakePublisher) Publish(env *posv1.EventEnvelope) {
	p.mu.Lock()
	defer p.mu.Unlock()
	p.events = append(p.events, env)
}

func (p *fakePublisher) snapshot() []*posv1.EventEnvelope {
	p.mu.Lock()
	defer p.mu.Unlock()
	out := make([]*posv1.EventEnvelope, len(p.events))
	copy(out, p.events)
	return out
}

func TestFinalize_BroadcastsEveryCommittedEventToPublisher(t *testing.T) {
	// Build a harness with a fakePublisher injected. Verifies slice 4.2:
	// after Finalize commits, the hub sees one envelope per opslog row.
	h := newHarnessWithPublisher(t)
	h.seedStock(t, "SKU-A", 10)

	req := mkSale("SKU-A", 2, 3, 0) // qty=2 → 1 sale_created + 1 inventory_adjusted + 1 payment_added
	_, err := h.svc.Finalize(context.Background(), req)
	require.NoError(t, err)

	got := h.pub.snapshot()
	require.Len(t, got, 3, "Finalize must publish one envelope per opslog row")

	types := []string{got[0].EventType, got[1].EventType, got[2].EventType}
	require.Contains(t, types, "sale_created")
	require.Contains(t, types, "inventory_adjusted")
	require.Contains(t, types, "payment_added")

	// Every envelope must carry the tenant id and a non-empty operation id.
	for _, env := range got {
		require.Equal(t, testTenant, env.TenantId.Value)
		require.NotEmpty(t, env.OperationId.Value)
		require.NotZero(t, env.Clock.Counter)
	}
}

func TestFinalize_IdempotentReplay_DoesNotRePublish(t *testing.T) {
	// The idempotent short-circuit must NOT re-broadcast. Re-broadcasting
	// would surface as a phantom "another sale just happened" to UI clients.
	// Stale-replay clients catch up via 4.4 reconnect-with-last-seen.
	h := newHarnessWithPublisher(t)
	h.seedStock(t, "SKU-A", 10)

	req := mkSale("SKU-A", 1, 5, 0)
	_, err := h.svc.Finalize(context.Background(), req)
	require.NoError(t, err)
	require.Len(t, h.pub.snapshot(), 3, "first finalize broadcasts trio")

	_, err = h.svc.Finalize(context.Background(), req) // same SaleID → idempotent
	require.NoError(t, err)
	require.Len(t, h.pub.snapshot(), 3, "idempotent replay must NOT re-broadcast")
}

// newHarnessWithPublisher mirrors newHarness but injects a fakePublisher
// so tests can assert the realtime fan-out behavior.
func newHarnessWithPublisher(t *testing.T) *harness {
	t.Helper()
	h := newHarness(t)
	h.pub = &fakePublisher{}
	// Rebuild the service with the publisher wired in.
	svc, err := sales.NewService(sales.Config{
		DB:        h.db,
		Ops:       h.ops,
		Inv:       h.inv,
		Pays:      h.pays,
		Invoices:  h.invs,
		Tax:       h.taxEng,
		Clock:     h.clk,
		Notifier:  h.notifier,
		Publisher: h.pub,
		NodeID:    testNode,
		TenantID:  testTenant,
	})
	require.NoError(t, err)
	h.svc = svc
	return h
}

// TestFinalize_ConsumesReservation_FlipsStatusInSameTxn proves slice 4.3
// integration: a sale supplied with ReservationIDs flips each hold to
// 'finalized' atomically with the sale, and a stale id rolls everything
// back (no movements written).
func TestFinalize_ConsumesReservation_FlipsStatusInSameTxn(t *testing.T) {
	h := newHarness(t)
	h.seedStock(t, "SKU-RES", 5)

	// Bolt a reservations service onto the harness's existing inventory.
	rStore := reservations.NewStore(h.db)
	rSvc, err := reservations.NewService(reservations.Config{
		DB: h.db, Store: rStore, Inv: h.inv,
	})
	require.NoError(t, err)

	// Rebuild sale service with reservations wired in.
	svc, err := sales.NewService(sales.Config{
		DB: h.db, Ops: h.ops, Inv: h.inv, Pays: h.pays, Invoices: h.invs,
		Tax: h.taxEng, Clock: h.clk, Notifier: h.notifier,
		Reservations: rSvc,
		NodeID:       testNode, TenantID: testTenant,
	})
	require.NoError(t, err)

	// Counter holds 2 units.
	resv, err := rSvc.Reserve(context.Background(), reservations.ReserveRequest{
		SKU: "SKU-RES", StoreID: testStore, CounterID: "counter-1", Quantity: 2,
	})
	require.NoError(t, err)
	require.Equal(t, reservations.StatusActive, resv.Reservation.Status)

	// Sale finalizes those 2 units AND consumes the reservation.
	req := mkSale("SKU-RES", 2, 1, 0)
	req.ReservationIDs = []uuid.UUID{resv.Reservation.ID}
	_, err = svc.Finalize(context.Background(), req)
	require.NoError(t, err)

	r, err := rSvc.Get(context.Background(), resv.Reservation.ID)
	require.NoError(t, err)
	require.Equal(t, reservations.StatusFinalized, r.Status,
		"reservation must be flipped to finalized atomically with the sale")

	stock, err := h.inv.StockOnHand(context.Background(), testStore, "SKU-RES")
	require.NoError(t, err)
	require.Equal(t, int64(3), stock)
}

func TestFinalize_StaleReservationID_RollsBackEverything(t *testing.T) {
	h := newHarness(t)
	h.seedStock(t, "SKU-STALE", 5)

	rStore := reservations.NewStore(h.db)
	rSvc, err := reservations.NewService(reservations.Config{
		DB: h.db, Store: rStore, Inv: h.inv,
	})
	require.NoError(t, err)

	svc, err := sales.NewService(sales.Config{
		DB: h.db, Ops: h.ops, Inv: h.inv, Pays: h.pays, Invoices: h.invs,
		Tax: h.taxEng, Clock: h.clk, Notifier: h.notifier,
		Reservations: rSvc,
		NodeID:       testNode, TenantID: testTenant,
	})
	require.NoError(t, err)

	// Reserve then immediately release — so the id is known but no longer active.
	resv, err := rSvc.Reserve(context.Background(), reservations.ReserveRequest{
		SKU: "SKU-STALE", StoreID: testStore, CounterID: "counter-1", Quantity: 1,
	})
	require.NoError(t, err)
	require.NoError(t, rSvc.Release(context.Background(), resv.Reservation.ID))

	req := mkSale("SKU-STALE", 1, 1, 0)
	req.ReservationIDs = []uuid.UUID{resv.Reservation.ID}
	_, err = svc.Finalize(context.Background(), req)
	require.Error(t, err)
	require.ErrorIs(t, err, reservations.ErrNotActive)

	// Rollback: zero opslog rows, stock unchanged.
	var count int
	require.NoError(t, h.db.QueryRow(`SELECT COUNT(*) FROM operations_log`).Scan(&count))
	require.Equal(t, 0, count)
	stock, err := h.inv.StockOnHand(context.Background(), testStore, "SKU-STALE")
	require.NoError(t, err)
	require.Equal(t, int64(5), stock)
}

func TestFinalize_HappyPath_AtomicTrioUnderOneBatchID(t *testing.T) {
	h := newHarness(t)
	h.seedStock(t, "SKU-A", 10)
	h.seedStock(t, "SKU-B", 5)

	pricedA := payments.Money{CurrencyCode: "USD", Units: 2, Nanos: 500_000_000} // $2.50
	pricedB := payments.Money{CurrencyCode: "USD", Units: 1, Nanos: 0}           // $1.00

	totalA, _ := pricedA.Mul(3)        // $7.50
	totalB, _ := pricedB.Mul(2)        // $2.00
	subtotal, _ := totalA.Add(totalB)  // $9.50

	tender1 := payments.Money{CurrencyCode: "USD", Units: 5, Nanos: 0}
	tender2 := payments.Money{CurrencyCode: "USD", Units: 4, Nanos: 500_000_000}

	req := sales.FinalizeRequest{
		SaleID:    uuid.New(),
		StoreID:   testStore,
		CounterID: "counter-1",
		Lines: []sales.SaleLine{
			{LineID: uuid.New(), SKU: "SKU-A", Quantity: 3, UnitPrice: pricedA, LineTotal: totalA},
			{LineID: uuid.New(), SKU: "SKU-B", Quantity: 2, UnitPrice: pricedB, LineTotal: totalB},
		},
		Tenders: []sales.Tender{
			{PaymentID: uuid.New(), Method: payments.MethodCash, Amount: tender1},
			{PaymentID: uuid.New(), Method: payments.MethodCard, Amount: tender2},
		},
		Subtotal:   subtotal,
		TaxTotal:   payments.Money{CurrencyCode: "USD"},
		GrandTotal: subtotal,
		OccurredAt: time.Now().UTC(),
	}

	resp, err := h.svc.Finalize(context.Background(), req)
	require.NoError(t, err)
	require.False(t, resp.Idempotent)
	require.NotEqual(t, uuid.Nil, resp.BatchID)
	require.Equal(t, req.SaleID, resp.SaleID)
	require.NotZero(t, resp.Lamport)

	// opslog: 1 sale + 2 inventory + 2 payment = 5 ops, all sharing BatchID.
	rows, err := h.db.Query(`SELECT operation_type, batch_id FROM operations_log ORDER BY id`)
	require.NoError(t, err)
	defer rows.Close()
	var (
		types     []string
		batchIDs  = map[string]struct{}{}
	)
	for rows.Next() {
		var (
			ot string
			b  sql.NullString
		)
		require.NoError(t, rows.Scan(&ot, &b))
		types = append(types, ot)
		require.True(t, b.Valid, "batch_id must be set on every op")
		batchIDs[b.String] = struct{}{}
	}
	require.NoError(t, rows.Err())
	require.Equal(t, []string{
		"sale_created", "inventory_adjusted", "inventory_adjusted", "payment_added", "payment_added",
	}, types)
	require.Equal(t, 1, len(batchIDs), "all 5 ops must share one batch_id")
	for b := range batchIDs {
		require.Equal(t, resp.BatchID.String(), b)
	}

	// Inventory ledger reflects decrements.
	stockA, err := h.inv.StockOnHand(context.Background(), testStore, "SKU-A")
	require.NoError(t, err)
	require.EqualValues(t, 10-3, stockA)
	stockB, err := h.inv.StockOnHand(context.Background(), testStore, "SKU-B")
	require.NoError(t, err)
	require.EqualValues(t, 5-2, stockB)

	// Payments ledger net = grand total (Balance returns net received, not owed).
	balance, err := h.pays.Balance(context.Background(), req.SaleID)
	require.NoError(t, err)
	require.True(t, balance.Equal(subtotal), "expected balance == grand total %v, got %v", subtotal, balance)

	// Notifier called exactly once.
	require.Equal(t, 1, h.notifier.Count())

	// Sanity: the persisted opslog payload round-trips back to a typed SaleCreated.
	op, err := h.ops.Get(context.Background(), req.SaleID)
	require.NoError(t, err)
	env, inner, err := events.Unpack(op.Payload)
	require.NoError(t, err)
	require.Equal(t, "sale_created", env.EventType)
	sale, ok := inner.(*posv1.SaleCreated)
	require.True(t, ok)
	require.Equal(t, req.SaleID.String(), sale.SaleId)
	require.Len(t, sale.Lines, 2)
	// proto.Equal because Money pointers won't be ==.
	require.True(t, proto.Equal(sale.Subtotal, &posv1.Money{CurrencyCode: "USD", Units: 9, Nanos: 500_000_000}))

	// Invoice projection: present on response, retrievable by sale id,
	// number-prefixed for the year, and snapshot round-trips to the same
	// payload as the opslog op.
	require.NotEqual(t, uuid.Nil, resp.Invoice.InvoiceID)
	require.Equal(t, req.SaleID, resp.Invoice.SaleID)
	require.Contains(t, resp.Invoice.InvoiceNumber, "INV-")
	require.True(t, resp.Invoice.GrandTotal.Equal(subtotal))

	persisted, err := h.invs.GetBySale(context.Background(), req.SaleID)
	require.NoError(t, err)
	require.Equal(t, resp.Invoice.InvoiceID, persisted.InvoiceID)

	var snapSale posv1.SaleCreated
	require.NoError(t, proto.Unmarshal(persisted.Snapshot, &snapSale))
	require.True(t, proto.Equal(&snapSale, sale),
		"invoice snapshot must equal opslog payload byte-for-byte semantically")
}

func TestFinalize_Idempotent_SameSaleIDReturnsSameOutcome(t *testing.T) {
	h := newHarness(t)
	h.seedStock(t, "SKU-X", 10)

	req := mkSale("SKU-X", 1, 1, 0)

	first, err := h.svc.Finalize(context.Background(), req)
	require.NoError(t, err)
	require.False(t, first.Idempotent)

	// Same SaleID — must return the same response and add no new rows.
	second, err := h.svc.Finalize(context.Background(), req)
	require.NoError(t, err)
	require.True(t, second.Idempotent)
	require.Equal(t, first.BatchID, second.BatchID)
	require.Equal(t, first.Lamport, second.Lamport)
	require.Equal(t, first.Invoice.InvoiceID, second.Invoice.InvoiceID,
		"idempotent replay must return the same invoice, not allocate a new number")
	require.Equal(t, first.Invoice.InvoiceNumber, second.Invoice.InvoiceNumber)

	// Only 3 ops total (1 sale + 1 inv + 1 pay); no duplicates.
	var count int
	require.NoError(t, h.db.QueryRow(`SELECT COUNT(*) FROM operations_log`).Scan(&count))
	require.Equal(t, 3, count, "second call must not write new rows")

	// And exactly one invoice exists for this sale.
	var invCount int
	require.NoError(t, h.db.QueryRow(`SELECT COUNT(*) FROM invoices WHERE sale_id = ?`, req.SaleID.String()).Scan(&invCount))
	require.Equal(t, 1, invCount)

	// Notifier called once on the original success; not on the idempotent replay.
	require.Equal(t, 1, h.notifier.Count())
}

func TestFinalize_OutOfStock_RollsBackEverything(t *testing.T) {
	h := newHarness(t)
	h.seedStock(t, "SKU-OOS", 1) // only 1 in stock; sale asks for 5

	req := mkSale("SKU-OOS", 5, 1, 0)

	_, err := h.svc.Finalize(context.Background(), req)
	require.Error(t, err)
	var oversell *inventory.OversellError
	require.True(t, errors.As(err, &oversell), "expected OversellError, got %v", err)

	// Zero new ops should have been persisted.
	var count int
	require.NoError(t, h.db.QueryRow(`SELECT COUNT(*) FROM operations_log`).Scan(&count))
	require.Equal(t, 0, count, "rollback must leave opslog empty")

	// Inventory still has the original 1 unit.
	stock, err := h.inv.StockOnHand(context.Background(), testStore, "SKU-OOS")
	require.NoError(t, err)
	require.EqualValues(t, 1, stock)

	// No payment row, no notification.
	require.Equal(t, 0, h.notifier.Count())

	// And no invoice — the projection rolls back with the txn, and the
	// per-store invoice sequence is NOT consumed.
	var invCount int
	require.NoError(t, h.db.QueryRow(`SELECT COUNT(*) FROM invoices`).Scan(&invCount))
	require.Equal(t, 0, invCount, "rollback must leave invoices empty")
	var seqRows int
	require.NoError(t, h.db.QueryRow(`SELECT COUNT(*) FROM invoice_sequences`).Scan(&seqRows))
	require.Equal(t, 0, seqRows, "rollback must leave invoice_sequences untouched")
}

func TestFinalize_LineTotalMismatch_Rejects(t *testing.T) {
	h := newHarness(t)
	h.seedStock(t, "SKU-Y", 10)

	req := mkSale("SKU-Y", 2, 5, 0)
	req.Lines[0].LineTotal = payments.Money{CurrencyCode: "USD", Units: 9, Nanos: 0} // wrong: should be $10
	req.Subtotal = req.Lines[0].LineTotal
	req.GrandTotal = req.Lines[0].LineTotal
	req.Tenders[0].Amount = req.Lines[0].LineTotal

	_, err := h.svc.Finalize(context.Background(), req)
	require.Error(t, err)
	var lineErr *sales.ErrLineTotalMismatch
	require.True(t, errors.As(err, &lineErr), "expected ErrLineTotalMismatch, got %v", err)
}

func TestFinalize_GrandTotalMismatch_Rejects(t *testing.T) {
	h := newHarness(t)
	h.seedStock(t, "SKU-Z", 10)

	req := mkSale("SKU-Z", 1, 5, 0) // $5 sale
	req.Tenders[0].Amount = payments.Money{CurrencyCode: "USD", Units: 4, Nanos: 0} // pays only $4

	_, err := h.svc.Finalize(context.Background(), req)
	require.Error(t, err)
	var gtErr *sales.ErrGrandTotalMismatch
	require.True(t, errors.As(err, &gtErr), "expected ErrGrandTotalMismatch, got %v", err)
}

func TestFinalize_ConcurrentSalesSameSKU_LastItemRace(t *testing.T) {
	h := newHarness(t)
	h.seedStock(t, "SKU-LAST", 1) // only one unit available

	results := make(chan error, 2)
	start := make(chan struct{})
	var wg sync.WaitGroup
	for i := 0; i < 2; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			<-start
			req := mkSale("SKU-LAST", 1, 1, 0)
			_, err := h.svc.Finalize(context.Background(), req)
			results <- err
		}()
	}
	close(start)
	wg.Wait()
	close(results)

	var wins, losses int
	for err := range results {
		if err == nil {
			wins++
			continue
		}
		var oversell *inventory.OversellError
		require.True(t, errors.As(err, &oversell), "loser must lose with OversellError, got %v", err)
		losses++
	}
	require.Equal(t, 1, wins, "exactly one sale must succeed")
	require.Equal(t, 1, losses, "the other sale must be rejected")

	stock, err := h.inv.StockOnHand(context.Background(), testStore, "SKU-LAST")
	require.NoError(t, err)
	require.EqualValues(t, 0, stock)
}

func TestFinalize_NotifierNotCalledOnError(t *testing.T) {
	h := newHarness(t)
	// No stock at all — sale will OOS.
	req := mkSale("SKU-NONE", 1, 1, 0)
	_, err := h.svc.Finalize(context.Background(), req)
	require.Error(t, err)
	require.Equal(t, 0, h.notifier.Count())
}

func TestFinalize_LamportMonotonic_AcrossSales(t *testing.T) {
	h := newHarness(t)
	h.seedStock(t, "SKU-L", 10)

	var last uint64
	for i := 0; i < 5; i++ {
		req := mkSale("SKU-L", 1, 1, 0)
		resp, err := h.svc.Finalize(context.Background(), req)
		require.NoError(t, err)
		require.Greater(t, resp.Lamport, last, "lamport must strictly increase: %d vs %d", resp.Lamport, last)
		last = resp.Lamport
	}
}

func TestFinalize_WithTax_GrandTotalIncludesIt(t *testing.T) {
	h := newHarness(t)
	h.seedStock(t, "SKU-TAX", 10)
	h.seedCategoryExclusive(t, "VAT-10", 1000) // 10% exclusive single component

	netLine := payments.Money{CurrencyCode: "USD", Units: 10, Nanos: 0}
	expectedTax := payments.Money{CurrencyCode: "USD", Units: 1, Nanos: 0}
	expectedGrand, _ := netLine.Add(expectedTax)

	req := sales.FinalizeRequest{
		SaleID:    uuid.New(),
		StoreID:   testStore,
		CounterID: "counter-1",
		Lines: []sales.SaleLine{{
			LineID:        uuid.New(),
			SKU:           "SKU-TAX",
			Quantity:      1,
			UnitPrice:     netLine,
			LineTotal:     netLine,
			TaxCategoryID: "VAT-10",
		}},
		Tenders: []sales.Tender{{
			PaymentID: uuid.New(),
			Method:    payments.MethodCard,
			Amount:    expectedGrand,
		}},
		// Totals left zero — engine fills them in.
		OccurredAt: time.Now().UTC(),
	}

	resp, err := h.svc.Finalize(context.Background(), req)
	require.NoError(t, err)
	require.False(t, resp.Idempotent)
	require.True(t, resp.Invoice.GrandTotal.Equal(expectedGrand))
	require.True(t, resp.Invoice.TaxTotal.Equal(expectedTax))

	balance, err := h.pays.Balance(context.Background(), req.SaleID)
	require.NoError(t, err)
	require.True(t, balance.Equal(expectedGrand), "expected balance == grand total %v, got %v", expectedGrand, balance)
}

// seedCategoryInclusive helper used by the inclusive-pricing tests below.
func (h *harness) seedCategoryInclusive(t *testing.T, categoryID string, components map[string]int32) {
	t.Helper()
	ctx := context.Background()
	require.NoError(t, h.taxStore.UpsertCategory(context.Background(), tax.Category{
		ID: categoryID, Name: categoryID, TenantID: testTenant, PriceIncludesTax: true,
	}))
	for name, bp := range components {
		require.NoError(t, h.taxStore.UpsertComponent(ctx, tax.Component{
			ID:            categoryID + "-" + name,
			TaxCategoryID: categoryID,
			Name:          name,
			RateBP:        bp,
		}))
	}
}

// TestFinalize_InclusiveGST — gross price on the line, engine extracts net+tax.
// India-style CGST+SGST split on a ₹118 line at 18% inclusive.
func TestFinalize_InclusiveGST_ExtractsNetAndSplits(t *testing.T) {
	h := newHarness(t)
	h.seedStock(t, "SKU-IN", 10)
	h.seedCategoryInclusive(t, "GST-18", map[string]int32{"CGST": 900, "SGST": 900})

	grossLine := payments.Money{CurrencyCode: "INR", Units: 118, Nanos: 0}
	expectedNet := payments.Money{CurrencyCode: "INR", Units: 100, Nanos: 0}
	expectedTax := payments.Money{CurrencyCode: "INR", Units: 18, Nanos: 0}

	req := sales.FinalizeRequest{
		SaleID:    uuid.New(),
		StoreID:   testStore,
		CounterID: "counter-1",
		Lines: []sales.SaleLine{{
			LineID:        uuid.New(),
			SKU:           "SKU-IN",
			Quantity:      1,
			UnitPrice:     grossLine,
			LineTotal:     grossLine, // gross because category is inclusive
			TaxCategoryID: "GST-18",
		}},
		Tenders: []sales.Tender{{
			PaymentID: uuid.New(),
			Method:    payments.MethodCash,
			Amount:    grossLine, // customer pays ₹118
		}},
		OccurredAt: time.Now().UTC(),
	}

	resp, err := h.svc.Finalize(context.Background(), req)
	require.NoError(t, err)
	require.True(t, resp.Invoice.Subtotal.Equal(expectedNet), "net %v vs %v", expectedNet, resp.Invoice.Subtotal)
	require.True(t, resp.Invoice.TaxTotal.Equal(expectedTax), "tax %v vs %v", expectedTax, resp.Invoice.TaxTotal)
	require.True(t, resp.Invoice.GrandTotal.Equal(grossLine))
}

// TestFinalize_TaxCallerSuppliedMismatch_Rejects — caller passes a wrong
// TaxTotal; engine recompute disagrees → ErrTotalsMismatch.
func TestFinalize_CallerSuppliedTotalsMismatch_Rejects(t *testing.T) {
	h := newHarness(t)
	h.seedStock(t, "SKU-MM", 10)
	h.seedCategoryExclusive(t, "VAT-10", 1000)

	netLine := payments.Money{CurrencyCode: "USD", Units: 10, Nanos: 0}
	correctTax := payments.Money{CurrencyCode: "USD", Units: 1, Nanos: 0}
	wrongTax := payments.Money{CurrencyCode: "USD", Units: 2, Nanos: 0} // caller cheats
	wrongGrand, _ := netLine.Add(wrongTax)

	req := sales.FinalizeRequest{
		SaleID:    uuid.New(),
		StoreID:   testStore,
		CounterID: "counter-1",
		Lines: []sales.SaleLine{{
			LineID: uuid.New(), SKU: "SKU-MM", Quantity: 1,
			UnitPrice: netLine, LineTotal: netLine, TaxCategoryID: "VAT-10",
		}},
		Tenders:    []sales.Tender{{PaymentID: uuid.New(), Method: payments.MethodCash, Amount: wrongGrand}},
		Subtotal:   netLine,
		TaxTotal:   wrongTax,
		GrandTotal: wrongGrand,
		OccurredAt: time.Now().UTC(),
	}

	_, err := h.svc.Finalize(context.Background(), req)
	require.Error(t, err)
	var mm *sales.ErrTotalsMismatch
	require.True(t, errors.As(err, &mm), "expected ErrTotalsMismatch, got %v", err)
	require.Equal(t, "TaxTotal", mm.Field)

	// Make sure the wrong totals didn't somehow get persisted.
	_ = correctTax
	var count int
	require.NoError(t, h.db.QueryRow(`SELECT COUNT(*) FROM operations_log`).Scan(&count))
	require.Equal(t, 0, count)
}

// TestFinalize_UnknownTaxCategory_Errors — line references a nonexistent
// category, engine surfaces ErrCategoryNotFound which Finalize wraps.
func TestFinalize_UnknownTaxCategory_Errors(t *testing.T) {
	h := newHarness(t)
	h.seedStock(t, "SKU-U", 5)
	req := mkSale("SKU-U", 1, 1, 0)
	req.Lines[0].TaxCategoryID = "DOES-NOT-EXIST"
	_, err := h.svc.Finalize(context.Background(), req)
	require.Error(t, err)
	require.True(t, errors.Is(err, tax.ErrCategoryNotFound),
		"expected tax.ErrCategoryNotFound somewhere in chain, got %v", err)
}
