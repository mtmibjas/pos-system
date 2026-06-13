package opslog_test

import (
	"context"
	"database/sql"
	"path/filepath"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/require"

	"github.com/mibjas/pos-platform/apps/local-store-server/internal/db"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/opslog"
)

// newTestStore opens a fresh SQLite file in t.TempDir(), runs migrations,
// and returns the store + raw DB handle. The DB is closed in t.Cleanup.
func newTestStore(t *testing.T) (*opslog.Store, *sql.DB) {
	t.Helper()
	ctx := context.Background()
	path := filepath.Join(t.TempDir(), "ops.db")

	sqlDB, err := db.Open(ctx, db.Config{Path: path})
	require.NoError(t, err)
	t.Cleanup(func() { _ = sqlDB.Close() })

	require.NoError(t, db.RunMigrations(sqlDB))
	return opslog.NewStore(sqlDB), sqlDB
}

func newOp() opslog.Operation {
	return opslog.Operation{
		OperationID:   uuid.New(),
		OperationType: "sale_created",
		EntityType:    "sale",
		EntityID:      uuid.NewString(),
		Payload:       []byte("test-payload-bytes"),
		CreatedAt:     time.Now().UTC(),
		Lamport:       42,
		OriginNodeID:  "node-test",
	}
}

func TestStore_Insert_RoundTrip(t *testing.T) {
	s, _ := newTestStore(t)
	op := newOp()

	saved, idempotent, err := s.Insert(context.Background(), op)
	require.NoError(t, err)
	require.False(t, idempotent, "first insert is not idempotent")

	require.NotZero(t, saved.ID, "id is autoincrement-populated")
	require.Equal(t, op.OperationID, saved.OperationID)
	require.Equal(t, op.OperationType, saved.OperationType)
	require.Equal(t, op.EntityType, saved.EntityType)
	require.Equal(t, op.EntityID, saved.EntityID)
	require.Equal(t, op.Payload, saved.Payload)
	require.Equal(t, op.CreatedAt.UnixNano(), saved.CreatedAt.UnixNano())
	require.Equal(t, op.Lamport, saved.Lamport)
	require.Equal(t, op.OriginNodeID, saved.OriginNodeID)

	// Defaults on insert:
	require.Equal(t, opslog.StatusPending, saved.SyncStatus)
	require.Equal(t, 0, saved.RetryCount)
	require.Equal(t, "", saved.LastError)
	require.Equal(t, uuid.Nil, saved.BatchID)
}

func TestStore_Insert_Idempotent(t *testing.T) {
	s, sqlDB := newTestStore(t)
	op := newOp()

	first, idemp1, err := s.Insert(context.Background(), op)
	require.NoError(t, err)
	require.False(t, idemp1)

	// Mutate the in-memory op to confirm Insert does NOT re-apply changes.
	op.Payload = []byte("DIFFERENT-PAYLOAD")
	op.Lamport = 9999

	second, idemp2, err := s.Insert(context.Background(), op)
	require.NoError(t, err)
	require.True(t, idemp2, "second insert with same OperationID is idempotent")

	// The returned row is the original one — not the new attempted values.
	require.Equal(t, first.ID, second.ID)
	require.Equal(t, []byte("test-payload-bytes"), second.Payload)
	require.Equal(t, uint64(42), second.Lamport)

	// And exactly one row exists.
	var count int
	require.NoError(t, sqlDB.QueryRow("SELECT COUNT(*) FROM operations_log").Scan(&count))
	require.Equal(t, 1, count)
}

func TestStore_Insert_ConcurrentSameID(t *testing.T) {
	s, sqlDB := newTestStore(t)
	op := newOp()

	const N = 20
	var (
		wg      sync.WaitGroup
		results = make([]opslog.Operation, N)
		idemps  = make([]bool, N)
		errs    = make([]error, N)
		start   = make(chan struct{})
	)

	for i := 0; i < N; i++ {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			<-start
			results[i], idemps[i], errs[i] = s.Insert(context.Background(), op)
		}(i)
	}
	close(start)
	wg.Wait()

	for i, e := range errs {
		require.NoError(t, e, "goroutine %d", i)
	}

	// Exactly one inserter sees idempotent=false; the rest see true.
	fresh := 0
	for _, b := range idemps {
		if !b {
			fresh++
		}
	}
	require.Equal(t, 1, fresh, "exactly one fresh insert across %d concurrent attempts", N)

	// All callers see the same canonical row.
	for i := 1; i < N; i++ {
		require.Equal(t, results[0].ID, results[i].ID)
		require.Equal(t, results[0].OperationID, results[i].OperationID)
	}

	// Only one row in the DB.
	var count int
	require.NoError(t, sqlDB.QueryRow("SELECT COUNT(*) FROM operations_log").Scan(&count))
	require.Equal(t, 1, count)
}

func TestStore_Insert_ValidationErrors(t *testing.T) {
	s, _ := newTestStore(t)

	cases := []struct {
		name string
		mut  func(*opslog.Operation)
	}{
		{"missing operation_id", func(o *opslog.Operation) { o.OperationID = uuid.Nil }},
		{"missing operation_type", func(o *opslog.Operation) { o.OperationType = "" }},
		{"missing entity_type", func(o *opslog.Operation) { o.EntityType = "" }},
		{"missing entity_id", func(o *opslog.Operation) { o.EntityID = "" }},
		{"missing payload", func(o *opslog.Operation) { o.Payload = nil }},
		{"missing origin_node_id", func(o *opslog.Operation) { o.OriginNodeID = "" }},
		{"missing created_at", func(o *opslog.Operation) { o.CreatedAt = time.Time{} }},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			op := newOp()
			c.mut(&op)
			_, _, err := s.Insert(context.Background(), op)
			require.Error(t, err)
		})
	}
}

func TestStore_Get_NotFound(t *testing.T) {
	s, _ := newTestStore(t)
	_, err := s.Get(context.Background(), uuid.New())
	require.ErrorIs(t, err, opslog.ErrNotFound)
}

func TestStore_ListPending_OldestFirstAndLimit(t *testing.T) {
	s, _ := newTestStore(t)
	ctx := context.Background()

	base := time.Now().UTC()
	for i := 0; i < 5; i++ {
		op := newOp()
		op.CreatedAt = base.Add(time.Duration(i) * time.Second)
		_, _, err := s.Insert(ctx, op)
		require.NoError(t, err)
	}

	got, err := s.ListPending(ctx, 3)
	require.NoError(t, err)
	require.Len(t, got, 3)
	for i := 1; i < len(got); i++ {
		require.True(t, got[i-1].CreatedAt.UnixNano() <= got[i].CreatedAt.UnixNano(),
			"oldest-first order broken at index %d", i)
	}
}

func TestStore_ListPending_DefaultsLimitTo100(t *testing.T) {
	s, _ := newTestStore(t)
	got, err := s.ListPending(context.Background(), 0)
	require.NoError(t, err)
	require.Empty(t, got) // no rows; just verifying the call doesn't error
}

func TestStore_MarkInFlight_OnlyPending(t *testing.T) {
	s, _ := newTestStore(t)
	ctx := context.Background()

	// 3 pending ops.
	ids := make([]uuid.UUID, 0, 3)
	for i := 0; i < 3; i++ {
		op := newOp()
		_, _, err := s.Insert(ctx, op)
		require.NoError(t, err)
		ids = append(ids, op.OperationID)
	}

	// Move id[0] to in_flight via a prior batch, then ack it.
	preBatch := uuid.New()
	n, err := s.MarkInFlight(ctx, ids[:1], preBatch)
	require.NoError(t, err)
	require.Equal(t, int64(1), n)
	n, err = s.MarkAcked(ctx, ids[:1])
	require.NoError(t, err)
	require.Equal(t, int64(1), n)

	// Now try to MarkInFlight all 3. Only ids[1] and ids[2] should transition.
	batch := uuid.New()
	n, err = s.MarkInFlight(ctx, ids, batch)
	require.NoError(t, err)
	require.Equal(t, int64(2), n)

	// Verify states.
	op0, err := s.Get(ctx, ids[0])
	require.NoError(t, err)
	require.Equal(t, opslog.StatusAcked, op0.SyncStatus)

	op1, err := s.Get(ctx, ids[1])
	require.NoError(t, err)
	require.Equal(t, opslog.StatusInFlight, op1.SyncStatus)
	require.Equal(t, batch, op1.BatchID)

	op2, err := s.Get(ctx, ids[2])
	require.NoError(t, err)
	require.Equal(t, opslog.StatusInFlight, op2.SyncStatus)
	require.Equal(t, batch, op2.BatchID)
}

func TestStore_MarkInFlight_RequiresBatchID(t *testing.T) {
	s, _ := newTestStore(t)
	_, err := s.MarkInFlight(context.Background(), []uuid.UUID{uuid.New()}, uuid.Nil)
	require.Error(t, err)
}

func TestStore_MarkAcked_OnlyInFlight(t *testing.T) {
	s, _ := newTestStore(t)
	ctx := context.Background()

	op := newOp()
	_, _, err := s.Insert(ctx, op)
	require.NoError(t, err)

	// MarkAcked on a pending op is a no-op.
	n, err := s.MarkAcked(ctx, []uuid.UUID{op.OperationID})
	require.NoError(t, err)
	require.Equal(t, int64(0), n)

	got, err := s.Get(ctx, op.OperationID)
	require.NoError(t, err)
	require.Equal(t, opslog.StatusPending, got.SyncStatus)

	// Move to in_flight, then ack succeeds.
	_, err = s.MarkInFlight(ctx, []uuid.UUID{op.OperationID}, uuid.New())
	require.NoError(t, err)
	n, err = s.MarkAcked(ctx, []uuid.UUID{op.OperationID})
	require.NoError(t, err)
	require.Equal(t, int64(1), n)

	got, err = s.Get(ctx, op.OperationID)
	require.NoError(t, err)
	require.Equal(t, opslog.StatusAcked, got.SyncStatus)
}

func TestStore_MarkFailed_IncrementsRetryAndRecordsError(t *testing.T) {
	s, _ := newTestStore(t)
	ctx := context.Background()

	op := newOp()
	_, _, err := s.Insert(ctx, op)
	require.NoError(t, err)

	require.NoError(t, s.MarkFailed(ctx, op.OperationID, "boom #1"))
	got, err := s.Get(ctx, op.OperationID)
	require.NoError(t, err)
	require.Equal(t, opslog.StatusFailed, got.SyncStatus)
	require.Equal(t, 1, got.RetryCount)
	require.Equal(t, "boom #1", got.LastError)

	// A second MarkFailed bumps retry_count again.
	require.NoError(t, s.MarkFailed(ctx, op.OperationID, "boom #2"))
	got, err = s.Get(ctx, op.OperationID)
	require.NoError(t, err)
	require.Equal(t, 2, got.RetryCount)
	require.Equal(t, "boom #2", got.LastError)
}

func TestStore_MarkFailed_RefusesAcked(t *testing.T) {
	s, _ := newTestStore(t)
	ctx := context.Background()

	op := newOp()
	_, _, err := s.Insert(ctx, op)
	require.NoError(t, err)

	_, err = s.MarkInFlight(ctx, []uuid.UUID{op.OperationID}, uuid.New())
	require.NoError(t, err)
	_, err = s.MarkAcked(ctx, []uuid.UUID{op.OperationID})
	require.NoError(t, err)

	err = s.MarkFailed(ctx, op.OperationID, "shouldn't apply")
	require.ErrorIs(t, err, opslog.ErrAlreadyAcked)

	// Status is unchanged.
	got, err := s.Get(ctx, op.OperationID)
	require.NoError(t, err)
	require.Equal(t, opslog.StatusAcked, got.SyncStatus)
	require.Equal(t, 0, got.RetryCount)
	require.Equal(t, "", got.LastError)
}

func TestStore_MarkFailed_NotFound(t *testing.T) {
	s, _ := newTestStore(t)
	err := s.MarkFailed(context.Background(), uuid.New(), "x")
	require.ErrorIs(t, err, opslog.ErrNotFound)
}

func TestStore_ListPending_UsesIndex(t *testing.T) {
	// EXPLAIN QUERY PLAN must mention the (sync_status, created_at) index.
	// If this fails, an index was dropped or the query was rewritten in a
	// way that no longer hits it — fix one or the other, don't relax the test.
	_, sqlDB := newTestStore(t)
	rows, err := sqlDB.Query(`
		EXPLAIN QUERY PLAN
		SELECT id FROM operations_log
		WHERE sync_status = 'pending'
		ORDER BY created_at ASC, id ASC
		LIMIT 100
	`)
	require.NoError(t, err)
	defer rows.Close()

	var planLines []string
	for rows.Next() {
		var id, parent, notused int
		var detail string
		require.NoError(t, rows.Scan(&id, &parent, &notused, &detail))
		planLines = append(planLines, detail)
	}
	plan := strings.Join(planLines, "\n")
	require.Contains(t, plan, "idx_operations_log_status_created", "plan was: %s", plan)
}

func TestInsert_WithBatchID_PersistedFromInsert(t *testing.T) {
	s, _ := newTestStore(t)
	ctx := context.Background()

	bid := uuid.New()
	op := newOp()
	op.BatchID = bid
	saved, _, err := s.Insert(ctx, op)
	require.NoError(t, err)
	require.Equal(t, bid, saved.BatchID,
		"BatchID provided at insert time must be persisted (sale atomic-batch grouping)")
}

func TestListByBatch_ReturnsOnlyMatchingRowsInInsertOrder(t *testing.T) {
	s, _ := newTestStore(t)
	ctx := context.Background()

	bid := uuid.New()
	other := uuid.New()

	// Insert: A,B,C all under bid; D,E under other. We expect ListByBatch(bid)
	// to return A,B,C in their insertion order.
	insert := func(batch uuid.UUID, opType string) opslog.Operation {
		op := newOp()
		op.OperationType = opType
		op.BatchID = batch
		saved, _, err := s.Insert(ctx, op)
		require.NoError(t, err)
		return saved
	}
	a := insert(bid, "sale_created")
	b := insert(bid, "inventory_adjusted")
	c := insert(bid, "payment_added")
	insert(other, "sale_created")
	insert(other, "inventory_adjusted")

	got, err := s.ListByBatch(ctx, bid)
	require.NoError(t, err)
	require.Len(t, got, 3)
	require.Equal(t, a.OperationID, got[0].OperationID)
	require.Equal(t, b.OperationID, got[1].OperationID)
	require.Equal(t, c.OperationID, got[2].OperationID)
}

func TestListByBatch_RejectsNilBatchID(t *testing.T) {
	s, _ := newTestStore(t)
	_, err := s.ListByBatch(context.Background(), uuid.Nil)
	require.Error(t, err)
}

func TestListByBatch_EmptyForUnknownBatch(t *testing.T) {
	s, _ := newTestStore(t)
	got, err := s.ListByBatch(context.Background(), uuid.New())
	require.NoError(t, err)
	require.Empty(t, got)
}

func TestInsert_NoBatchID_StoredAsNull(t *testing.T) {
	s, _ := newTestStore(t)
	ctx := context.Background()

	saved, _, err := s.Insert(ctx, newOp())
	require.NoError(t, err)
	require.Equal(t, uuid.Nil, saved.BatchID,
		"uuid.Nil at insert must store NULL (sync worker will assign batch_id later)")
}

func TestMarkRetry_InFlightBackToPending(t *testing.T) {
	s, _ := newTestStore(t)
	ctx := context.Background()

	op := newOp()
	_, _, err := s.Insert(ctx, op)
	require.NoError(t, err)

	bid := uuid.New()
	n, err := s.MarkInFlight(ctx, []uuid.UUID{op.OperationID}, bid)
	require.NoError(t, err)
	require.Equal(t, int64(1), n)

	n, err = s.MarkRetry(ctx, []uuid.UUID{op.OperationID}, "network blip")
	require.NoError(t, err)
	require.Equal(t, int64(1), n)

	got, err := s.Get(ctx, op.OperationID)
	require.NoError(t, err)
	require.Equal(t, opslog.StatusPending, got.SyncStatus)
	require.Equal(t, bid, got.BatchID,
		"MarkRetry must PRESERVE batch_id — retries reuse the same id so the cloud's "+
			"batch-level dedup (slice 3.1) classifies the retry as DUPLICATE on commit-then-drop")
	require.Equal(t, "network blip", got.LastError)
	require.Equal(t, 1, got.RetryCount)
}

func TestMarkRetry_SkipsNonInFlight(t *testing.T) {
	s, _ := newTestStore(t)
	ctx := context.Background()

	op := newOp()
	_, _, err := s.Insert(ctx, op)
	require.NoError(t, err)
	// Still 'pending' — MarkRetry must skip it.
	n, err := s.MarkRetry(ctx, []uuid.UUID{op.OperationID}, "shouldn't apply")
	require.NoError(t, err)
	require.Equal(t, int64(0), n)

	got, _ := s.Get(ctx, op.OperationID)
	require.Equal(t, 0, got.RetryCount, "retry_count must not bump when not in_flight")
	require.Equal(t, "", got.LastError)
}

func TestStore_ListSince_OrderingFilterAndLimit(t *testing.T) {
	// Replay support for WS reconnect (slice 4.4): return rows with
	// lamport > sinceLamport, in (lamport ASC, id ASC) order, capped at limit.
	s, _ := newTestStore(t)
	ctx := context.Background()

	insert := func(lamport uint64) uuid.UUID {
		op := newOp()
		op.Lamport = lamport
		_, _, err := s.Insert(ctx, op)
		require.NoError(t, err)
		return op.OperationID
	}
	insert(5)            // below threshold — excluded
	insert(10)           // at threshold — excluded (strictly greater)
	id11 := insert(11)
	id12 := insert(12)
	id20a := insert(20) // two rows with the same lamport — id breaks the tie
	id20b := insert(20)
	insert(30)

	got, err := s.ListSince(ctx, 10, 3)
	require.NoError(t, err)
	require.Len(t, got, 3, "limit caps the result")
	require.Equal(t, id11, got[0].OperationID)
	require.Equal(t, id12, got[1].OperationID)
	require.Equal(t, id20a, got[2].OperationID, "lower id wins on lamport tie")
	require.True(t, got[0].Lamport < got[1].Lamport)
	require.True(t, got[1].Lamport < got[2].Lamport ||
		(got[1].Lamport == got[2].Lamport && got[1].ID < got[2].ID))

	// Asking for more than exists returns all matching rows.
	got, err = s.ListSince(ctx, 10, 100)
	require.NoError(t, err)
	require.Len(t, got, 5)
	require.Equal(t, id20b, got[3].OperationID)
}

func TestStore_ListSince_ZeroReturnsAll(t *testing.T) {
	s, _ := newTestStore(t)
	ctx := context.Background()
	for i := uint64(1); i <= 3; i++ {
		op := newOp()
		op.Lamport = i
		_, _, err := s.Insert(ctx, op)
		require.NoError(t, err)
	}
	got, err := s.ListSince(ctx, 0, 100)
	require.NoError(t, err)
	require.Len(t, got, 3, "sinceLamport=0 admits every row (lamports are 1-based)")
}

func TestStore_ListSince_DefaultsLimitTo100(t *testing.T) {
	s, _ := newTestStore(t)
	got, err := s.ListSince(context.Background(), 0, 0)
	require.NoError(t, err)
	require.Empty(t, got)
}

func TestMarkRetry_BumpsRetryCountOnEachCall(t *testing.T) {
	s, _ := newTestStore(t)
	ctx := context.Background()
	op := newOp()
	_, _, err := s.Insert(ctx, op)
	require.NoError(t, err)

	for want := 1; want <= 3; want++ {
		_, err := s.MarkInFlight(ctx, []uuid.UUID{op.OperationID}, uuid.New())
		require.NoError(t, err)
		_, err = s.MarkRetry(ctx, []uuid.UUID{op.OperationID}, "transient")
		require.NoError(t, err)
		got, _ := s.Get(ctx, op.OperationID)
		require.Equal(t, want, got.RetryCount)
	}
}
