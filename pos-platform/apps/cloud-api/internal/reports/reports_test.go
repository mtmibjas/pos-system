package reports_test

import (
	"context"
	"io"
	"log/slog"
	"path/filepath"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"google.golang.org/protobuf/types/known/timestamppb"

	"github.com/mibjas/pos-platform/apps/cloud-api/internal/db"
	"github.com/mibjas/pos-platform/apps/cloud-api/internal/ingest"
	"github.com/mibjas/pos-platform/apps/cloud-api/internal/projection"
	"github.com/mibjas/pos-platform/apps/cloud-api/internal/reports"
	posv1 "github.com/mibjas/pos-platform/packages/sdk-go/gen/pos/v1"
)

// --- harness (mirrors projection/replay_test.go on purpose so the
//     reports tests exercise the full ingest → project → report stack) ---

type fix struct {
	t       *testing.T
	ingest  *ingest.Store
	worker  *projection.Worker
	reports *reports.Store
}

func setup(t *testing.T) *fix {
	t.Helper()
	ctx := context.Background()
	sqlDB, err := db.Open(ctx, db.Config{Path: filepath.Join(t.TempDir(), "cloud.db")})
	require.NoError(t, err)
	t.Cleanup(func() { _ = sqlDB.Close() })
	require.NoError(t, db.RunMigrations(sqlDB))

	frozen := time.Date(2026, 5, 31, 12, 0, 0, 0, time.UTC)
	return &fix{
		t:       t,
		ingest:  ingest.NewStore(sqlDB, func() time.Time { return frozen }),
		worker:  projection.New(sqlDB, projection.NewStore(sqlDB), slog.New(slog.NewTextHandler(io.Discard, nil)), projection.WithBatch(500)),
		reports: reports.NewStore(sqlDB),
	}
}

func (f *fix) apply(batchID string, ops ...*posv1.Operation) {
	f.t.Helper()
	res, err := f.ingest.Apply(context.Background(), &posv1.SyncBatch{
		BatchId:    batchID,
		TenantId:   &posv1.TenantId{Value: "tenant-A"},
		Operations: ops,
	})
	require.NoError(f.t, err)
	require.Equal(f.t, posv1.SyncBatchAck_STATUS_APPLIED, res.Status)
}

func (f *fix) drain() {
	f.t.Helper()
	_, err := f.worker.RunOnce(context.Background())
	require.NoError(f.t, err)
}

func usd(units int64, nanos int32) *posv1.Money {
	return &posv1.Money{CurrencyCode: "USD", Units: units, Nanos: nanos}
}

// op builds an Operation whose envelope OccurredAt is `occurredAt`.
// Buckets depend on this so each test pins it explicitly.
func op(opID, opType, entityID, storeID string, lamport uint64, occurredAt time.Time, payload any) *posv1.Operation {
	env := &posv1.EventEnvelope{
		OperationId:   &posv1.OperationId{Value: opID},
		EventType:     opType,
		SchemaVersion: 1,
		TenantId:      &posv1.TenantId{Value: "tenant-A"},
		Origin:        &posv1.OriginNode{NodeId: "node-1"},
		Clock:         &posv1.LamportClock{Counter: lamport, NodeId: "node-1"},
		OccurredAt:    timestamppb.New(occurredAt),
	}
	switch p := payload.(type) {
	case *posv1.SaleCreated:
		p.StoreId = &posv1.StoreId{Value: storeID}
		env.Payload = &posv1.EventEnvelope_SaleCreated{SaleCreated: p}
	case *posv1.PaymentAdded:
		env.Payload = &posv1.EventEnvelope_PaymentAdded{PaymentAdded: p}
	case *posv1.SaleRefunded:
		p.StoreId = &posv1.StoreId{Value: storeID}
		env.Payload = &posv1.EventEnvelope_SaleRefunded{SaleRefunded: p}
	}
	return &posv1.Operation{
		OperationId:   &posv1.OperationId{Value: opID},
		OperationType: opType,
		EntityType:    "sale",
		EntityId:      entityID,
		Envelope:      env,
		Origin:        &posv1.OriginNode{NodeId: "node-1"},
	}
}

// --- ParseDateRange / ParsePeriod ---

func TestParseDateRange_DefaultsToFromPlusOne(t *testing.T) {
	r, err := reports.ParseDateRange("2026-05-31", "")
	require.NoError(t, err)
	assert.Equal(t, "2026-05-31", r.From.Format("2006-01-02"))
	assert.Equal(t, "2026-06-01", r.To.Format("2006-01-02"))
}

func TestParseDateRange_RejectsBadInputs(t *testing.T) {
	_, err := reports.ParseDateRange("", "")
	assert.Error(t, err, "from required")
	_, err = reports.ParseDateRange("not-a-date", "")
	assert.Error(t, err)
	_, err = reports.ParseDateRange("2026-05-31", "2026-05-30")
	assert.Error(t, err, "to must be after from")
	_, err = reports.ParseDateRange("2026-05-31", "2026-05-31")
	assert.Error(t, err, "to must be strictly after from")
}

func TestParsePeriod_DefaultsToDay(t *testing.T) {
	p, err := reports.ParsePeriod("")
	require.NoError(t, err)
	assert.Equal(t, reports.PeriodDay, p)
	_, err = reports.ParsePeriod("year")
	assert.Error(t, err)
}

// --- Sales summary ---

func TestSalesSummary_NetsRefundsAndVoids(t *testing.T) {
	f := setup(t)
	may30 := time.Date(2026, 5, 30, 10, 0, 0, 0, time.UTC)
	may31 := time.Date(2026, 5, 31, 10, 0, 0, 0, time.UTC)

	// May-30: $10 sale + $1 tax (std), paid cash.
	saleA := uuid.NewString()
	payA := uuid.NewString()
	f.apply("b1",
		op(saleA, "sale_created", saleA, "store-A", 1, may30, &posv1.SaleCreated{
			SaleId:     saleA,
			Lines:      []*posv1.SaleLine{{TaxCategoryId: "std", LineTax: usd(1, 0)}},
			Subtotal:   usd(10, 0),
			TaxTotal:   usd(1, 0),
			GrandTotal: usd(11, 0),
		}),
		op(payA, "payment_added", payA, "store-A", 2, may30,
			&posv1.PaymentAdded{PaymentId: payA, SaleId: saleA, Method: "cash", Amount: usd(11, 0)}),
	)
	// May-31: $20 sale + $2 tax (std), then full refund same day.
	saleB := uuid.NewString()
	payB := uuid.NewString()
	refB := uuid.NewString()
	f.apply("b2",
		op(saleB, "sale_created", saleB, "store-A", 3, may31, &posv1.SaleCreated{
			SaleId:     saleB,
			Lines:      []*posv1.SaleLine{{TaxCategoryId: "std", LineTax: usd(2, 0)}},
			Subtotal:   usd(20, 0),
			TaxTotal:   usd(2, 0),
			GrandTotal: usd(22, 0),
		}),
		op(payB, "payment_added", payB, "store-A", 4, may31,
			&posv1.PaymentAdded{PaymentId: payB, SaleId: saleB, Method: "card", Amount: usd(22, 0)}),
		op(refB, "sale_refunded", saleB, "store-A", 5, may31, &posv1.SaleRefunded{
			RefundId:   refB,
			SaleId:     saleB,
			Lines:      []*posv1.RefundLine{{TaxCategoryId: "std", LineTax: usd(2, 0)}},
			Subtotal:   usd(20, 0),
			TaxTotal:   usd(2, 0),
			GrandTotal: usd(22, 0),
			Tenders: []*posv1.RefundTender{{
				RefundPaymentId: uuid.NewString(), OriginalPaymentId: payB,
				Method: "card", Amount: usd(22, 0),
			}},
		}),
	)
	f.drain()

	r, err := reports.ParseDateRange("2026-05-30", "2026-06-01")
	require.NoError(t, err)
	buckets, err := f.reports.SalesSummary(context.Background(), "tenant-A", r, "", reports.PeriodDay)
	require.NoError(t, err)
	require.Len(t, buckets, 2)

	// May-30: $10 / $1
	assert.Equal(t, "2026-05-30", buckets[0].PeriodStart)
	assert.Equal(t, int64(10), buckets[0].Revenue.Units)
	assert.Equal(t, int64(1), buckets[0].Tax.Units)
	assert.Equal(t, int64(11), buckets[0].GrandTotal.Units)

	// May-31: sale + refund net to zero.
	assert.Equal(t, "2026-05-31", buckets[1].PeriodStart)
	assert.Equal(t, int64(0), buckets[1].Revenue.Units)
	assert.Equal(t, int64(0), buckets[1].Tax.Units)
	assert.Equal(t, int64(0), buckets[1].GrandTotal.Units)
}

func TestSalesSummary_FiltersByStore(t *testing.T) {
	f := setup(t)
	occ := time.Date(2026, 5, 31, 10, 0, 0, 0, time.UTC)

	for _, store := range []string{"store-A", "store-B"} {
		saleID := uuid.NewString()
		f.apply("b-"+store,
			op(saleID, "sale_created", saleID, store, 1, occ, &posv1.SaleCreated{
				SaleId:     saleID,
				Subtotal:   usd(10, 0),
				TaxTotal:   usd(0, 0),
				GrandTotal: usd(10, 0),
			}),
		)
	}
	f.drain()

	r, _ := reports.ParseDateRange("2026-05-31", "")
	all, err := f.reports.SalesSummary(context.Background(), "tenant-A", r, "", reports.PeriodDay)
	require.NoError(t, err)
	require.Len(t, all, 1)
	assert.Equal(t, int64(20), all[0].Revenue.Units, "no filter = both stores")

	storeA, err := f.reports.SalesSummary(context.Background(), "tenant-A", r, "store-A", reports.PeriodDay)
	require.NoError(t, err)
	require.Len(t, storeA, 1)
	assert.Equal(t, int64(10), storeA[0].Revenue.Units, "store filter narrows to one")
}

// --- Sales by method ---

func TestSalesByMethod_NetsPerClearingAccount(t *testing.T) {
	f := setup(t)
	may31 := time.Date(2026, 5, 31, 10, 0, 0, 0, time.UTC)

	// $11 cash + $22 card sale, both same day. Card sale then refunded
	// fully → card row should drop out (skip-empty).
	saleA := uuid.NewString()
	payCash := uuid.NewString()
	saleB := uuid.NewString()
	payCard := uuid.NewString()
	refB := uuid.NewString()

	f.apply("b1",
		op(saleA, "sale_created", saleA, "store-A", 1, may31, &posv1.SaleCreated{
			SaleId: saleA, Subtotal: usd(10, 0), TaxTotal: usd(1, 0), GrandTotal: usd(11, 0),
			Lines: []*posv1.SaleLine{{TaxCategoryId: "std", LineTax: usd(1, 0)}},
		}),
		op(payCash, "payment_added", payCash, "store-A", 2, may31,
			&posv1.PaymentAdded{PaymentId: payCash, SaleId: saleA, Method: "cash", Amount: usd(11, 0)}),
		op(saleB, "sale_created", saleB, "store-A", 3, may31, &posv1.SaleCreated{
			SaleId: saleB, Subtotal: usd(20, 0), TaxTotal: usd(2, 0), GrandTotal: usd(22, 0),
			Lines: []*posv1.SaleLine{{TaxCategoryId: "std", LineTax: usd(2, 0)}},
		}),
		op(payCard, "payment_added", payCard, "store-A", 4, may31,
			&posv1.PaymentAdded{PaymentId: payCard, SaleId: saleB, Method: "card", Amount: usd(22, 0)}),
		op(refB, "sale_refunded", saleB, "store-A", 5, may31, &posv1.SaleRefunded{
			RefundId: refB, SaleId: saleB,
			Lines:      []*posv1.RefundLine{{TaxCategoryId: "std", LineTax: usd(2, 0)}},
			Subtotal:   usd(20, 0), TaxTotal: usd(2, 0), GrandTotal: usd(22, 0),
			Tenders: []*posv1.RefundTender{{
				RefundPaymentId: uuid.NewString(), OriginalPaymentId: payCard,
				Method: "card", Amount: usd(22, 0),
			}},
		}),
	)
	f.drain()

	r, _ := reports.ParseDateRange("2026-05-31", "")
	out, err := f.reports.SalesByMethod(context.Background(), "tenant-A", r, "")
	require.NoError(t, err)
	// Only cash should appear (card netted to zero).
	require.Len(t, out, 1)
	assert.Equal(t, "cash", out[0].Method)
	assert.Equal(t, int64(11), out[0].Amount.Units)
}

// --- Tax summary ---

func TestTaxSummary_SplitsByCategory(t *testing.T) {
	f := setup(t)
	may31 := time.Date(2026, 5, 31, 10, 0, 0, 0, time.UTC)

	saleID := uuid.NewString()
	f.apply("b1",
		op(saleID, "sale_created", saleID, "store-A", 1, may31, &posv1.SaleCreated{
			SaleId: saleID,
			Lines: []*posv1.SaleLine{
				{TaxCategoryId: "std", LineTax: usd(1, 500_000_000)},
				{TaxCategoryId: "food", LineTax: usd(0, 250_000_000)},
			},
			Subtotal:   usd(15, 0),
			TaxTotal:   usd(1, 750_000_000),
			GrandTotal: usd(16, 750_000_000),
		}),
	)
	f.drain()

	r, _ := reports.ParseDateRange("2026-05-31", "")
	out, err := f.reports.TaxSummary(context.Background(), "tenant-A", r, "", reports.PeriodDay)
	require.NoError(t, err)
	require.Len(t, out, 2)

	byCat := map[string]reports.MoneyAmount{}
	for _, b := range out {
		byCat[b.TaxCategory] = b.Amount
	}
	assert.Equal(t, int64(1), byCat["std"].Units)
	assert.Equal(t, int32(500_000_000), byCat["std"].Nanos)
	assert.Equal(t, int64(0), byCat["food"].Units)
	assert.Equal(t, int32(250_000_000), byCat["food"].Nanos)
}

// --- Period bucketing ---

func TestSalesSummary_MonthBucket(t *testing.T) {
	f := setup(t)
	// One sale in early May, another in late May → both bucket to
	// 2026-05-01 under month grouping.
	may3 := time.Date(2026, 5, 3, 10, 0, 0, 0, time.UTC)
	may28 := time.Date(2026, 5, 28, 10, 0, 0, 0, time.UTC)
	for i, occ := range []time.Time{may3, may28} {
		saleID := uuid.NewString()
		f.apply(uuid.NewString(),
			op(saleID, "sale_created", saleID, "store-A", uint64(i+1), occ, &posv1.SaleCreated{
				SaleId:     saleID,
				Subtotal:   usd(10, 0),
				TaxTotal:   usd(0, 0),
				GrandTotal: usd(10, 0),
			}),
		)
	}
	f.drain()

	r, _ := reports.ParseDateRange("2026-05-01", "2026-06-01")
	out, err := f.reports.SalesSummary(context.Background(), "tenant-A", r, "", reports.PeriodMonth)
	require.NoError(t, err)
	require.Len(t, out, 1, "both sales collapse into one month bucket")
	assert.Equal(t, "2026-05-01", out[0].PeriodStart)
	assert.Equal(t, int64(20), out[0].Revenue.Units)
}

// --- ListStores ---

func TestListStores_ReturnsDistinctStoresWithDates(t *testing.T) {
	f := setup(t)
	may10 := time.Date(2026, 5, 10, 10, 0, 0, 0, time.UTC)
	may20 := time.Date(2026, 5, 20, 10, 0, 0, 0, time.UTC)
	may31 := time.Date(2026, 5, 31, 10, 0, 0, 0, time.UTC)

	// Two sales in store-A (different days) and one in store-B.
	for _, c := range []struct {
		store string
		when  time.Time
		lam   uint64
	}{
		{"store-A", may10, 1},
		{"store-A", may31, 2},
		{"store-B", may20, 3},
	} {
		saleID := uuid.NewString()
		f.apply(uuid.NewString(),
			op(saleID, "sale_created", saleID, c.store, c.lam, c.when, &posv1.SaleCreated{
				SaleId:     saleID,
				Subtotal:   usd(10, 0),
				TaxTotal:   usd(0, 0),
				GrandTotal: usd(10, 0),
			}),
		)
	}
	f.drain()

	stores, err := f.reports.ListStores(context.Background(), "tenant-A")
	require.NoError(t, err)
	require.Len(t, stores, 2)

	assert.Equal(t, "store-A", stores[0].StoreID)
	assert.Equal(t, "2026-05-10", stores[0].FirstActivity)
	assert.Equal(t, "2026-05-31", stores[0].LastActivity)

	assert.Equal(t, "store-B", stores[1].StoreID)
	assert.Equal(t, "2026-05-20", stores[1].FirstActivity)
	assert.Equal(t, "2026-05-20", stores[1].LastActivity)
}

func TestListStores_FiltersByTenant(t *testing.T) {
	f := setup(t)
	// Only tenant-A activity exists; query for tenant-X should be empty.
	saleID := uuid.NewString()
	f.apply(uuid.NewString(),
		op(saleID, "sale_created", saleID, "store-A", 1,
			time.Date(2026, 5, 31, 10, 0, 0, 0, time.UTC),
			&posv1.SaleCreated{SaleId: saleID, Subtotal: usd(10, 0), TaxTotal: usd(0, 0), GrandTotal: usd(10, 0)}),
	)
	f.drain()

	stores, err := f.reports.ListStores(context.Background(), "tenant-X")
	require.NoError(t, err)
	assert.Empty(t, stores)
}
