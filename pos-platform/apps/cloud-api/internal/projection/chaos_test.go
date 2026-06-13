// Phase 5 Slice 5.6: projection chaos tests.
//
// Lock in the two invariants the GL projection already satisfies by
// construction, so future refactors can't quietly break either:
//
//   1. Determinism — same event log → byte-identical (journal_entries,
//      journal_lines) regardless of how many worker ticks chunked the
//      work or how many times we re-ran.
//   2. Reorder safety — events landing in the events table in non-causal
//      order (payment-before-sale) still converge to the same final
//      state once everything's drained.
//
// Entirely test-only — no production code change should be needed.
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

	"github.com/mibjas/pos-platform/apps/cloud-api/internal/db"
	"github.com/mibjas/pos-platform/apps/cloud-api/internal/ingest"
	"github.com/mibjas/pos-platform/apps/cloud-api/internal/projection"
	posv1 "github.com/mibjas/pos-platform/packages/sdk-go/gen/pos/v1"
)

// --- snapshot helpers -------------------------------------------------

// glRow is one journal_line + its parent journal_entry, projected onto
// the columns that matter for invariant comparison. Excludes je_id (a
// content-derived sha1 — included implicitly via operation_id + je_seq)
// and posted_at (driven by event occurred_at, identical across runs).
type glRow struct {
	OperationID string
	JESeq       int
	StoreID     string
	SaleID      string
	PaymentID   string
	SourceType  string
	Account     string
	Side        string
	Currency    string
	Units       int64
	Nanos       int32
}

func snapshotGL(t *testing.T, sqlDB *sql.DB) []glRow {
	t.Helper()
	const q = `
		SELECT
		    je.operation_id, je.je_seq, je.store_id, je.sale_id, je.payment_id,
		    je.source_event_type,
		    jl.account_code, jl.side, jl.currency_code, jl.units, jl.nanos
		  FROM journal_lines jl
		  JOIN journal_entries je ON je.je_id = jl.je_id
		 ORDER BY je.operation_id ASC, je.je_seq ASC, jl.account_code ASC, jl.side ASC
	`
	rows, err := sqlDB.QueryContext(context.Background(), q)
	require.NoError(t, err)
	defer rows.Close()

	out := []glRow{}
	for rows.Next() {
		var r glRow
		var nanos int64
		require.NoError(t, rows.Scan(
			&r.OperationID, &r.JESeq, &r.StoreID, &r.SaleID, &r.PaymentID,
			&r.SourceType, &r.Account, &r.Side, &r.Currency, &r.Units, &nanos,
		))
		r.Nanos = int32(nanos)
		out = append(out, r)
	}
	require.NoError(t, rows.Err())
	return out
}

// wipeProjection clears the GL tables and resets the cursor — used to
// prove that a fresh replay reproduces the prior snapshot. Order matters:
// journal_lines first (FK to journal_entries ON DELETE RESTRICT).
func wipeProjection(t *testing.T, sqlDB *sql.DB) {
	t.Helper()
	ctx := context.Background()
	for _, stmt := range []string{
		`DELETE FROM journal_lines`,
		`DELETE FROM journal_entries`,
		`UPDATE projection_cursor SET last_event_id = 0 WHERE name = 'gl'`,
	} {
		_, err := sqlDB.ExecContext(ctx, stmt)
		require.NoError(t, err, "wipe: %s", stmt)
	}
}

// drainToIdle calls RunOnce until it reports processed=0 or a safety
// bound trips. The bound is loud-failing on purpose — if convergence
// stops working, we want a noisy test, not an infinite loop.
func drainToIdle(t *testing.T, h *harness) {
	t.Helper()
	const maxTicks = 50
	for i := 0; i < maxTicks; i++ {
		n, err := h.worker.RunOnce(context.Background())
		require.NoError(t, err)
		if n == 0 {
			return
		}
	}
	t.Fatalf("drainToIdle: did not converge within %d ticks", maxTicks)
}

// --- envelope fixtures ------------------------------------------------

// scenario builds a deterministic, balanced bundle of envelopes that
// exercises every Map() branch the chaos tests care about: two stores,
// two tax categories, a sale+payment pair, and a sale+payment+refund
// triple.
type scenario struct {
	saleA, payA              string
	saleB, payB, refB, refPB string // refPB = the refund's NEW payment id (tender)
}

func newScenario() scenario {
	return scenario{
		saleA: uuid.NewString(),
		payA:  uuid.NewString(),
		saleB: uuid.NewString(),
		payB:  uuid.NewString(),
		refB:  uuid.NewString(),
		refPB: uuid.NewString(),
	}
}

func (s scenario) saleAOp(lamport uint64) *posv1.Operation {
	return op(s.saleA, "sale_created", "sale", s.saleA, lamport,
		&posv1.SaleCreated{
			SaleId:     s.saleA,
			StoreId:    &posv1.StoreId{Value: "store-A"},
			Lines:      []*posv1.SaleLine{{TaxCategoryId: "std", LineTax: usd(1, 0)}},
			Subtotal:   usd(10, 0),
			TaxTotal:   usd(1, 0),
			GrandTotal: usd(11, 0),
		})
}

func (s scenario) payAOp(lamport uint64) *posv1.Operation {
	return op(s.payA, "payment_added", "payment", s.payA, lamport,
		&posv1.PaymentAdded{PaymentId: s.payA, SaleId: s.saleA, Method: "cash", Amount: usd(11, 0)})
}

func (s scenario) saleBOp(lamport uint64) *posv1.Operation {
	return op(s.saleB, "sale_created", "sale", s.saleB, lamport,
		&posv1.SaleCreated{
			SaleId:     s.saleB,
			StoreId:    &posv1.StoreId{Value: "store-B"},
			Lines:      []*posv1.SaleLine{{TaxCategoryId: "food", LineTax: usd(2, 0)}},
			Subtotal:   usd(20, 0),
			TaxTotal:   usd(2, 0),
			GrandTotal: usd(22, 0),
		})
}

func (s scenario) payBOp(lamport uint64) *posv1.Operation {
	return op(s.payB, "payment_added", "payment", s.payB, lamport,
		&posv1.PaymentAdded{PaymentId: s.payB, SaleId: s.saleB, Method: "card", Amount: usd(22, 0)})
}

func (s scenario) refBOp(lamport uint64) *posv1.Operation {
	return op(s.refB, "sale_refunded", "sale", s.saleB, lamport,
		&posv1.SaleRefunded{
			RefundId:   s.refB,
			SaleId:     s.saleB,
			StoreId:    &posv1.StoreId{Value: "store-B"},
			Lines:      []*posv1.RefundLine{{TaxCategoryId: "food", LineTax: usd(2, 0)}},
			Subtotal:   usd(20, 0),
			TaxTotal:   usd(2, 0),
			GrandTotal: usd(22, 0),
			Tenders: []*posv1.RefundTender{{
				RefundPaymentId:   s.refPB,
				OriginalPaymentId: s.payB,
				Method:            "card",
				Amount:            usd(22, 0),
			}},
		})
}

// --- chaos tests ------------------------------------------------------

// 1. Determinism: wipe the GL tables, replay the same events, get the
//    same snapshot down to the byte.
func TestChaos_WipeAndReplay_YieldsIdenticalSnapshot(t *testing.T) {
	h := setup(t)
	s := newScenario()

	h.apply(&posv1.SyncBatch{
		BatchId:  "b1",
		TenantId: &posv1.TenantId{Value: "tenant-A"},
		Operations: []*posv1.Operation{
			s.saleAOp(1), s.payAOp(2),
			s.saleBOp(3), s.payBOp(4), s.refBOp(5),
		},
	})

	drainToIdle(t, h)
	first := snapshotGL(t, h.db)
	require.NotEmpty(t, first, "fixture should produce some JEs")

	wipeProjection(t, h.db)
	require.Empty(t, snapshotGL(t, h.db), "wipe should clear GL tables")

	drainToIdle(t, h)
	second := snapshotGL(t, h.db)

	assert.Equal(t, first, second, "replay must reproduce GL state exactly")
}

// 2. Reorder safety: events whose physical order in the events table
//    differs from the "natural" causal order still converge to the same
//    GL snapshot, provided the projection's ordering constraint is
//    respected (a refund's referenced PaymentAdded must precede it in
//    the events table — the worker's cursor model gives up when it
//    can't satisfy that lookup at the head of the cursor).
//
//    The interesting reorders this test exercises:
//      • payments arrive before their sales (PaymentAdded has no causal
//        dep on SaleCreated in the GL map — it's pure A/R structure).
//      • the two sales' streams are fully interleaved across batches.
//
//    What we lock in: the GL projection is order-agnostic up to the
//    refund-after-payment constraint.
func TestChaos_OutOfOrder_ConvergesToSameState(t *testing.T) {
	// Causal run: sale → payment, sale → payment → refund, single batch.
	hA := setup(t)
	sA := newScenario()
	hA.apply(&posv1.SyncBatch{
		BatchId:  "causal",
		TenantId: &posv1.TenantId{Value: "tenant-A"},
		Operations: []*posv1.Operation{
			sA.saleAOp(1), sA.payAOp(2),
			sA.saleBOp(3), sA.payBOp(4), sA.refBOp(5),
		},
	})
	drainToIdle(t, hA)
	causal := snapshotGL(t, hA.db)

	// Reordered run: identical operation_ids (so JE rows compare equal),
	// but split across batches with physically reordered operations:
	//   batch 1: payB, saleB         (payment before its sale)
	//   batch 2: payA                 (sale A's payment, sale not yet there)
	//   batch 3: saleA, refB          (sale A finally arrives; refB lands
	//                                  after payB, satisfying the lookup)
	hB := setup(t)
	sB := sA
	hB.apply(&posv1.SyncBatch{
		BatchId:  "reorder-1",
		TenantId: &posv1.TenantId{Value: "tenant-A"},
		Operations: []*posv1.Operation{
			sB.payBOp(1), sB.saleBOp(2),
		},
	})
	hB.apply(&posv1.SyncBatch{
		BatchId:  "reorder-2",
		TenantId: &posv1.TenantId{Value: "tenant-A"},
		Operations: []*posv1.Operation{sB.payAOp(3)},
	})
	hB.apply(&posv1.SyncBatch{
		BatchId:  "reorder-3",
		TenantId: &posv1.TenantId{Value: "tenant-A"},
		Operations: []*posv1.Operation{
			sB.saleAOp(4), sB.refBOp(5),
		},
	})
	drainToIdle(t, hB)

	reordered := snapshotGL(t, hB.db)
	assert.Equal(t, causal, reordered,
		"reordered events must converge to the same GL state")
}

// 3. Chunked drain: same workload split across many tiny ticks must
//    yield the same snapshot as one big tick.
func TestChaos_ChunkedDrain_MatchesSinglePassDrain(t *testing.T) {
	// Scenario A — default batch size, drains in one tick.
	hA := setup(t)
	sA := newScenario()
	hA.apply(&posv1.SyncBatch{
		BatchId:  "bA",
		TenantId: &posv1.TenantId{Value: "tenant-A"},
		Operations: []*posv1.Operation{
			sA.saleAOp(1), sA.payAOp(2),
			sA.saleBOp(3), sA.payBOp(4), sA.refBOp(5),
		},
	})
	drainToIdle(t, hA)
	single := snapshotGL(t, hA.db)

	// Scenario B — fresh DB, same events, batch=1 worker so each tick
	// processes exactly one event.
	hB := setupWithBatch(t, 1)
	sB := sA // full copy — includes refPB so JE rows compare equal
	hB.apply(&posv1.SyncBatch{
		BatchId:  "bB",
		TenantId: &posv1.TenantId{Value: "tenant-A"},
		Operations: []*posv1.Operation{
			sB.saleAOp(1), sB.payAOp(2),
			sB.saleBOp(3), sB.payBOp(4), sB.refBOp(5),
		},
	})
	drainToIdle(t, hB)
	chunked := snapshotGL(t, hB.db)

	assert.Equal(t, single, chunked,
		"chunk size must not affect final GL state")
}

// 4. Idle ticks are no-ops: replaying RunOnce on a fully-drained log
//    must report processed=0 and leave the snapshot unchanged.
func TestChaos_IdleTick_IsNoop(t *testing.T) {
	h := setup(t)
	s := newScenario()
	h.apply(&posv1.SyncBatch{
		BatchId:  "b",
		TenantId: &posv1.TenantId{Value: "tenant-A"},
		Operations: []*posv1.Operation{
			s.saleAOp(1), s.payAOp(2),
		},
	})
	drainToIdle(t, h)
	before := snapshotGL(t, h.db)

	for i := 0; i < 5; i++ {
		n, err := h.worker.RunOnce(context.Background())
		require.NoError(t, err)
		assert.Equal(t, 0, n, "idle RunOnce #%d must process zero events", i)
	}

	after := snapshotGL(t, h.db)
	assert.Equal(t, before, after, "idle ticks must not mutate the GL state")
}

// --- support: a batch-tuned harness ----------------------------------

// setupWithBatch mirrors setup() but lets the chunked-drain test pin a
// tiny worker batch size. Kept local to chaos_test.go because no other
// test needs it.
func setupWithBatch(t *testing.T, batch int) *harness {
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
		projection.WithBatch(batch),
		projection.WithNow(func() time.Time { return frozen }),
	)
	return &harness{t: t, db: sqlDB, ingest: ing, gl: gl, worker: worker}
}
