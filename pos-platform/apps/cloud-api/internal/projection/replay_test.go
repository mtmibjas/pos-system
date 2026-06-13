package projection_test

import (
	"context"
	"database/sql"
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
	posv1 "github.com/mibjas/pos-platform/packages/sdk-go/gen/pos/v1"
)

// --- harness ---

type harness struct {
	t      *testing.T
	db     *sql.DB
	ingest *ingest.Store
	gl     *projection.Store
	worker *projection.Worker
}

func setup(t *testing.T) *harness {
	t.Helper()
	ctx := context.Background()
	sqlDB, err := db.Open(ctx, db.Config{Path: filepath.Join(t.TempDir(), "cloud.db")})
	require.NoError(t, err)
	t.Cleanup(func() { _ = sqlDB.Close() })
	require.NoError(t, db.RunMigrations(sqlDB))

	frozen := time.Date(2026, 5, 31, 12, 0, 0, 0, time.UTC)
	ing := ingest.NewStore(sqlDB, func() time.Time { return frozen })
	gl := projection.NewStore(sqlDB)
	worker := projection.New(
		sqlDB, gl,
		slog.New(slog.NewTextHandler(io.Discard, nil)),
		projection.WithBatch(100),
		projection.WithNow(func() time.Time { return frozen }),
	)
	return &harness{t: t, db: sqlDB, ingest: ing, gl: gl, worker: worker}
}

func (h *harness) apply(batch *posv1.SyncBatch) {
	h.t.Helper()
	res, err := h.ingest.Apply(context.Background(), batch)
	require.NoError(h.t, err)
	require.Equal(h.t, posv1.SyncBatchAck_STATUS_APPLIED, res.Status,
		"ingest must accept batch %q (got %q: %s)", batch.GetBatchId(), res.Status, res.Message)
}

func (h *harness) drain() int {
	h.t.Helper()
	n, err := h.worker.RunOnce(context.Background())
	require.NoError(h.t, err)
	return n
}

func usd(units int64, nanos int32) *posv1.Money {
	return &posv1.Money{CurrencyCode: "USD", Units: units, Nanos: nanos}
}

func op(opID, opType, entityType, entityID string, lamport uint64, payload any) *posv1.Operation {
	occ := time.Date(2026, 5, 31, 11, 0, 0, 0, time.UTC)
	env := &posv1.EventEnvelope{
		OperationId:   &posv1.OperationId{Value: opID},
		EventType:     opType,
		SchemaVersion: 1,
		TenantId:      &posv1.TenantId{Value: "tenant-A"},
		Origin:        &posv1.OriginNode{NodeId: "node-1"},
		Clock:         &posv1.LamportClock{Counter: lamport, NodeId: "node-1"},
		OccurredAt:    timestamppb.New(occ),
	}
	switch p := payload.(type) {
	case *posv1.SaleCreated:
		env.Payload = &posv1.EventEnvelope_SaleCreated{SaleCreated: p}
	case *posv1.PaymentAdded:
		env.Payload = &posv1.EventEnvelope_PaymentAdded{PaymentAdded: p}
	case *posv1.PaymentRefunded:
		env.Payload = &posv1.EventEnvelope_PaymentRefunded{PaymentRefunded: p}
	case *posv1.SaleRefunded:
		env.Payload = &posv1.EventEnvelope_SaleRefunded{SaleRefunded: p}
	case *posv1.SaleVoided:
		env.Payload = &posv1.EventEnvelope_SaleVoided{SaleVoided: p}
	}
	return &posv1.Operation{
		OperationId:   &posv1.OperationId{Value: opID},
		OperationType: opType,
		EntityType:    entityType,
		EntityId:      entityID,
		Envelope:      env,
		Origin:        &posv1.OriginNode{NodeId: "node-1"},
	}
}

// queryJEsForSale is a tiny test-only assertion helper.
func (h *harness) queryJECountForSale(saleID string) int {
	h.t.Helper()
	var n int
	require.NoError(h.t, h.db.QueryRowContext(context.Background(),
		`SELECT COUNT(*) FROM journal_entries WHERE sale_id = ?`, saleID).Scan(&n))
	return n
}

func (h *harness) queryLineCount() int {
	h.t.Helper()
	var n int
	require.NoError(h.t, h.db.QueryRowContext(context.Background(),
		`SELECT COUNT(*) FROM journal_lines`).Scan(&n))
	return n
}

func (h *harness) queryAccountExists(code string) bool {
	h.t.Helper()
	var dummy string
	err := h.db.QueryRowContext(context.Background(),
		`SELECT code FROM accounts WHERE code = ?`, code).Scan(&dummy)
	return err == nil
}

// --- end-to-end scenarios ---

func TestWorker_SaleThenPayment_PostsBalancedJEs(t *testing.T) {
	h := setup(t)
	saleID := uuid.NewString()
	payID := uuid.NewString()

	sale := &posv1.SaleCreated{
		SaleId:  saleID,
		StoreId: &posv1.StoreId{Value: "store-A"},
		Lines: []*posv1.SaleLine{
			{TaxCategoryId: "std", LineTax: usd(1, 0)},
		},
		Subtotal:   usd(10, 0),
		TaxTotal:   usd(1, 0),
		GrandTotal: usd(11, 0),
	}
	pay := &posv1.PaymentAdded{
		PaymentId: payID,
		SaleId:    saleID,
		Method:    "cash",
		Amount:    usd(11, 0),
	}
	h.apply(&posv1.SyncBatch{
		BatchId:  "b1",
		TenantId: &posv1.TenantId{Value: "tenant-A"},
		Operations: []*posv1.Operation{
			op(saleID, "sale_created", "sale", saleID, 1, sale),
			op(payID, "payment_added", "payment", payID, 2, pay),
		},
	})

	n := h.drain()
	assert.Equal(t, 2, n, "should process both events")
	// One JE for sale, one for payment.
	assert.Equal(t, 2, h.queryJECountForSale(saleID))
	// Tax sub-account 2100.std created on demand.
	assert.True(t, h.queryAccountExists("2100.std"))

	// Cursor advances to event id 2.
	cur, err := h.gl.Cursor(context.Background())
	require.NoError(t, err)
	assert.Equal(t, int64(2), cur)
}

func TestWorker_IdempotentReplay_NoDuplicates(t *testing.T) {
	h := setup(t)
	saleID := uuid.NewString()
	sale := &posv1.SaleCreated{
		SaleId:     saleID,
		StoreId:    &posv1.StoreId{Value: "store-A"},
		Subtotal:   usd(5, 0),
		TaxTotal:   usd(0, 0),
		GrandTotal: usd(5, 0),
	}
	h.apply(&posv1.SyncBatch{
		BatchId:    "b1",
		TenantId:   &posv1.TenantId{Value: "tenant-A"},
		Operations: []*posv1.Operation{op(saleID, "sale_created", "sale", saleID, 1, sale)},
	})

	h.drain()
	jeBefore := h.queryJECountForSale(saleID)
	lineBefore := h.queryLineCount()

	// Force the cursor backwards and re-drain. INSERT OR IGNORE on
	// (operation_id, je_seq) must collapse the replay to a no-op.
	require.NoError(t, h.gl.AdvanceCursor(context.Background(), 0, 0))
	h.drain()

	assert.Equal(t, jeBefore, h.queryJECountForSale(saleID),
		"replay must not create duplicate JEs")
	assert.Equal(t, lineBefore, h.queryLineCount(),
		"replay must not create duplicate lines")
}

func TestWorker_SaleVoided_ReversesSaleAndPayment(t *testing.T) {
	h := setup(t)
	saleID := uuid.NewString()
	payID := uuid.NewString()
	voidID := uuid.NewString()

	sale := &posv1.SaleCreated{
		SaleId:     saleID,
		StoreId:    &posv1.StoreId{Value: "store-A"},
		Subtotal:   usd(10, 0),
		TaxTotal:   usd(1, 0),
		GrandTotal: usd(11, 0),
		Lines:      []*posv1.SaleLine{{TaxCategoryId: "std", LineTax: usd(1, 0)}},
	}
	pay := &posv1.PaymentAdded{
		PaymentId: payID, SaleId: saleID, Method: "card", Amount: usd(11, 0),
	}
	voided := &posv1.SaleVoided{
		VoidId: voidID, SaleId: saleID, StoreId: &posv1.StoreId{Value: "store-A"},
	}
	h.apply(&posv1.SyncBatch{
		BatchId:  "b1",
		TenantId: &posv1.TenantId{Value: "tenant-A"},
		Operations: []*posv1.Operation{
			op(saleID, "sale_created", "sale", saleID, 1, sale),
			op(payID, "payment_added", "payment", payID, 2, pay),
			op(voidID, "sale_voided", "sale", saleID, 3, voided),
		},
	})
	h.drain()

	// Sum balances per account: post-void everything must net to zero.
	rows, err := h.db.Query(`
		SELECT account_code, side, units, nanos
		  FROM journal_lines jl
		  JOIN journal_entries je ON je.je_id = jl.je_id
		 WHERE je.sale_id = ?
	`, saleID)
	require.NoError(t, err)
	defer rows.Close()
	balance := map[string]int64{} // signed nanos
	for rows.Next() {
		var acct, side string
		var units int64
		var nanos int64
		require.NoError(t, rows.Scan(&acct, &side, &units, &nanos))
		amt := units*1_000_000_000 + nanos
		if side == "credit" {
			amt = -amt
		}
		balance[acct] += amt
	}
	for acct, bal := range balance {
		assert.Equal(t, int64(0), bal,
			"account %s must net to zero after void; got %d", acct, bal)
	}
}

func TestWorker_SaleRefunded_PostsGoodsAndTender(t *testing.T) {
	h := setup(t)
	saleID := uuid.NewString()
	payID := uuid.NewString()
	refundID := uuid.NewString()

	sale := &posv1.SaleCreated{
		SaleId: saleID, StoreId: &posv1.StoreId{Value: "store-A"},
		Lines:      []*posv1.SaleLine{{LineId: "l1", TaxCategoryId: "std", LineTax: usd(1, 0)}},
		Subtotal:   usd(10, 0), TaxTotal: usd(1, 0), GrandTotal: usd(11, 0),
	}
	pay := &posv1.PaymentAdded{PaymentId: payID, SaleId: saleID, Method: "card", Amount: usd(11, 0)}
	refund := &posv1.SaleRefunded{
		RefundId: refundID, SaleId: saleID, StoreId: &posv1.StoreId{Value: "store-A"},
		Lines:      []*posv1.RefundLine{{SaleLineId: "l1", TaxCategoryId: "std", LineTax: usd(1, 0)}},
		Subtotal:   usd(10, 0), TaxTotal: usd(1, 0), GrandTotal: usd(11, 0),
		Tenders: []*posv1.RefundTender{{
			RefundPaymentId: uuid.NewString(), OriginalPaymentId: payID,
			Method: "card", Amount: usd(11, 0),
		}},
	}
	h.apply(&posv1.SyncBatch{
		BatchId:  "b1",
		TenantId: &posv1.TenantId{Value: "tenant-A"},
		Operations: []*posv1.Operation{
			op(saleID, "sale_created", "sale", saleID, 1, sale),
			op(payID, "payment_added", "payment", payID, 2, pay),
			op(refundID, "sale_refunded", "sale", saleID, 3, refund),
		},
	})
	h.drain()

	// SaleRefunded produces 2 JEs (goods + 1 tender). Plus 2 from sale +
	// payment. So 4 total entries for sale_id.
	assert.Equal(t, 4, h.queryJECountForSale(saleID))
}

func TestWorker_PaymentRefunded_OutOfOrder_DoesNotAdvanceCursor(t *testing.T) {
	h := setup(t)
	payID := uuid.NewString()
	refundID := uuid.NewString()

	// PaymentRefunded for a payment we've never seen. Worker should leave
	// the cursor put so a later pass (after the missing PaymentAdded is
	// ingested) can pick it up.
	refund := &posv1.PaymentRefunded{
		RefundId: refundID, OriginalPaymentId: payID, Amount: usd(5, 0),
	}
	h.apply(&posv1.SyncBatch{
		BatchId:    "b1",
		TenantId:   &posv1.TenantId{Value: "tenant-A"},
		Operations: []*posv1.Operation{op(refundID, "payment_refunded", "payment", refundID, 1, refund)},
	})
	processed := h.drain()
	assert.Equal(t, 0, processed, "missing predecessor must stop the worker")
	cur, err := h.gl.Cursor(context.Background())
	require.NoError(t, err)
	assert.Equal(t, int64(0), cur, "cursor must NOT advance past the failed row")
}
