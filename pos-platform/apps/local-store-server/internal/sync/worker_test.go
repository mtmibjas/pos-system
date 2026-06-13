package sync_test

import (
	"bytes"
	"context"
	"database/sql"
	"errors"
	"io"
	"log/slog"
	"math/rand/v2"
	"path/filepath"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/require"
	"google.golang.org/protobuf/proto"

	"github.com/mibjas/pos-platform/apps/local-store-server/internal/db"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/events"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/opslog"
	syncpkg "github.com/mibjas/pos-platform/apps/local-store-server/internal/sync"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/syncstate"
	posv1 "github.com/mibjas/pos-platform/packages/sdk-go/gen/pos/v1"
)

const testTenant = "tenant-A"

// --- test scaffolding ---

func newTestStores(t *testing.T) (*opslog.Store, *syncstate.Store, *sql.DB) {
	t.Helper()
	ctx := context.Background()
	path := filepath.Join(t.TempDir(), "worker.db")
	sqlDB, err := db.Open(ctx, db.Config{Path: path})
	require.NoError(t, err)
	t.Cleanup(func() { _ = sqlDB.Close() })
	require.NoError(t, db.RunMigrations(sqlDB))
	return opslog.NewStore(sqlDB), syncstate.NewStore(sqlDB), sqlDB
}

// insertPending writes one ready-to-ship op (a minimal SaleCreated envelope
// in its payload) and returns its OperationID.
func insertPending(t *testing.T, ops *opslog.Store, lamport uint64) uuid.UUID {
	t.Helper()
	id := uuid.New()
	sale := &posv1.SaleCreated{
		SaleId:  id.String(),
		StoreId: &posv1.StoreId{Value: "store-1"},
	}
	_, payload, err := events.Pack(sale, events.Meta{
		OperationID: id.String(),
		TenantID:    testTenant,
		OriginNode:  &posv1.OriginNode{NodeId: "node-test"},
		Lamport:     lamport,
		OccurredAt:  time.Now().UTC(),
	})
	require.NoError(t, err)

	_, _, err = ops.Insert(context.Background(), opslog.Operation{
		OperationID:   id,
		OperationType: "sale_created",
		EntityType:    "sale",
		EntityID:      id.String(),
		Payload:       payload,
		CreatedAt:     time.Now().UTC(),
		Lamport:       lamport,
		OriginNodeID:  "node-test",
	})
	require.NoError(t, err)
	return id
}

// fakeTransport is a programmable Transport. Each Send pops the next reply
// from replies (or returns the lastReply forever once exhausted) and records
// the request batch.
type fakeTransport struct {
	mu      sync.Mutex
	replies []fakeReply
	idx     int
	seen    []*posv1.SyncBatch
}

type fakeReply struct {
	ack *posv1.SyncBatchAck
	err error
}

func (f *fakeTransport) Send(_ context.Context, batch *posv1.SyncBatch) (*posv1.SyncBatchAck, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.seen = append(f.seen, proto.Clone(batch).(*posv1.SyncBatch))
	var r fakeReply
	if f.idx < len(f.replies) {
		r = f.replies[f.idx]
		f.idx++
	} else if len(f.replies) > 0 {
		r = f.replies[len(f.replies)-1]
	}
	if r.err != nil {
		return nil, r.err
	}
	if r.ack != nil {
		// Echo the batch_id so the worker accepts the ack.
		out := proto.Clone(r.ack).(*posv1.SyncBatchAck)
		if out.BatchId == "" {
			out.BatchId = batch.BatchId
		}
		return out, nil
	}
	return &posv1.SyncBatchAck{BatchId: batch.BatchId, Status: posv1.SyncBatchAck_STATUS_APPLIED}, nil
}

func (f *fakeTransport) Calls() int {
	f.mu.Lock()
	defer f.mu.Unlock()
	return len(f.seen)
}

func newWorker(t *testing.T, ops *opslog.Store, state *syncstate.Store, tr syncpkg.Transport, opts syncpkg.WorkerOpts) *syncpkg.Worker {
	t.Helper()
	if opts.Logger == nil {
		opts.Logger = slog.New(slog.NewTextHandler(io.Discard, nil))
	}
	if opts.Tick == 0 {
		opts.Tick = 50 * time.Millisecond
	}
	if opts.Backoff == nil {
		opts.Backoff = syncpkg.NewBackoff(syncpkg.BackoffOpts{
			Base: 5 * time.Millisecond,
			Cap:  20 * time.Millisecond,
		})
	}
	if opts.ShutdownGrace == 0 {
		opts.ShutdownGrace = 10 * time.Millisecond
	}
	return syncpkg.NewWorker(ops, state, tr, testTenant, opts)
}

// runUntilDrained spins the worker in a goroutine, waits until every op is
// out of pending/in_flight or until timeout, then cancels.
func runUntilDrained(t *testing.T, w *syncpkg.Worker, ops *opslog.Store, expectedIDs []uuid.UUID, timeout time.Duration) {
	t.Helper()
	ctx, cancel := context.WithCancel(context.Background())
	done := make(chan struct{})
	go func() {
		_ = w.Run(ctx)
		close(done)
	}()
	defer func() {
		cancel()
		<-done
	}()

	deadline := time.Now().Add(timeout)
	for time.Now().Before(deadline) {
		settled := true
		for _, id := range expectedIDs {
			op, err := ops.Get(context.Background(), id)
			if err != nil {
				settled = false
				break
			}
			if op.SyncStatus == opslog.StatusPending || op.SyncStatus == opslog.StatusInFlight {
				settled = false
				break
			}
		}
		if settled {
			return
		}
		time.Sleep(5 * time.Millisecond)
	}
	t.Fatalf("worker did not drain within %s", timeout)
}

// --- tests ---

func TestWorker_HappyPath_MarksAckedAndRecordsState(t *testing.T) {
	ops, state, _ := newTestStores(t)
	id := insertPending(t, ops, 1)

	tr := &fakeTransport{
		replies: []fakeReply{{ack: &posv1.SyncBatchAck{Status: posv1.SyncBatchAck_STATUS_APPLIED}}},
	}
	w := newWorker(t, ops, state, tr, syncpkg.WorkerOpts{})

	runUntilDrained(t, w, ops, []uuid.UUID{id}, 2*time.Second)

	op, err := ops.Get(context.Background(), id)
	require.NoError(t, err)
	require.Equal(t, opslog.StatusAcked, op.SyncStatus)

	// last_sync_at + last_sync_batch_id are stamped.
	_, err = state.GetTime(context.Background(), syncstate.KeyLastSyncAt)
	require.NoError(t, err)
	_, err = state.GetUUID(context.Background(), syncstate.KeyLastSyncBatchID)
	require.NoError(t, err)
}

func TestWorker_DuplicateAck_AlsoAcks(t *testing.T) {
	ops, state, _ := newTestStores(t)
	id := insertPending(t, ops, 1)

	tr := &fakeTransport{
		replies: []fakeReply{{ack: &posv1.SyncBatchAck{Status: posv1.SyncBatchAck_STATUS_DUPLICATE}}},
	}
	w := newWorker(t, ops, state, tr, syncpkg.WorkerOpts{})

	runUntilDrained(t, w, ops, []uuid.UUID{id}, 2*time.Second)

	op, err := ops.Get(context.Background(), id)
	require.NoError(t, err)
	require.Equal(t, opslog.StatusAcked, op.SyncStatus,
		"DUPLICATE must be treated as success — peer already applied it")
}

func TestWorker_TransientThenSuccess_RetriesAndAcks(t *testing.T) {
	ops, state, _ := newTestStores(t)
	id := insertPending(t, ops, 1)

	tr := &fakeTransport{
		replies: []fakeReply{
			{err: &syncpkg.TransientError{Err: errors.New("flaky network")}},
			{err: &syncpkg.TransientError{Err: errors.New("flaky network")}},
			{ack: &posv1.SyncBatchAck{Status: posv1.SyncBatchAck_STATUS_APPLIED}},
		},
	}
	w := newWorker(t, ops, state, tr, syncpkg.WorkerOpts{MaxRetries: 5})

	runUntilDrained(t, w, ops, []uuid.UUID{id}, 3*time.Second)

	op, err := ops.Get(context.Background(), id)
	require.NoError(t, err)
	require.Equal(t, opslog.StatusAcked, op.SyncStatus)
	require.GreaterOrEqual(t, op.RetryCount, 2,
		"retry_count must reflect the transient attempts (got %d)", op.RetryCount)
	require.Equal(t, 3, tr.Calls(), "should have called transport exactly 3 times")
}

func TestWorker_TransientRetriesExhausted_MarksFailed(t *testing.T) {
	ops, state, _ := newTestStores(t)
	id := insertPending(t, ops, 1)

	tr := &fakeTransport{
		replies: []fakeReply{{err: &syncpkg.TransientError{Err: errors.New("down forever")}}},
	}
	w := newWorker(t, ops, state, tr, syncpkg.WorkerOpts{MaxRetries: 2})

	runUntilDrained(t, w, ops, []uuid.UUID{id}, 3*time.Second)

	op, err := ops.Get(context.Background(), id)
	require.NoError(t, err)
	require.Equal(t, opslog.StatusFailed, op.SyncStatus)
	require.Contains(t, op.LastError, "retries exhausted")

	// bumpFailedCount runs strictly after MarkFailed, so poll briefly.
	deadline := time.Now().Add(500 * time.Millisecond)
	for time.Now().Before(deadline) {
		failed, gerr := state.GetUint64(context.Background(), syncstate.KeyFailedOpsCount)
		if gerr == nil && failed == 1 {
			return
		}
		time.Sleep(5 * time.Millisecond)
	}
	t.Fatal("failed_ops_count never reached 1")
}

func TestWorker_PermanentTransportError_MarksFailedImmediately(t *testing.T) {
	ops, state, _ := newTestStores(t)
	id := insertPending(t, ops, 1)

	tr := &fakeTransport{
		replies: []fakeReply{{err: errors.New("HTTP 400 malformed")}},
	}
	w := newWorker(t, ops, state, tr, syncpkg.WorkerOpts{MaxRetries: 5})

	runUntilDrained(t, w, ops, []uuid.UUID{id}, 2*time.Second)

	op, err := ops.Get(context.Background(), id)
	require.NoError(t, err)
	require.Equal(t, opslog.StatusFailed, op.SyncStatus)
	require.Equal(t, 1, tr.Calls(),
		"permanent error must not be retried (got %d calls)", tr.Calls())
}

func TestWorker_AckRejected_MarksFailed(t *testing.T) {
	ops, state, _ := newTestStores(t)
	id := insertPending(t, ops, 1)

	tr := &fakeTransport{
		replies: []fakeReply{{ack: &posv1.SyncBatchAck{
			Status:  posv1.SyncBatchAck_STATUS_REJECTED,
			Message: "schema mismatch",
		}}},
	}
	w := newWorker(t, ops, state, tr, syncpkg.WorkerOpts{})

	runUntilDrained(t, w, ops, []uuid.UUID{id}, 2*time.Second)

	op, err := ops.Get(context.Background(), id)
	require.NoError(t, err)
	require.Equal(t, opslog.StatusFailed, op.SyncStatus)
	require.Contains(t, op.LastError, "schema mismatch")
}

func TestWorker_AckRetryLater_RequeuesAsPending(t *testing.T) {
	ops, state, _ := newTestStores(t)
	id := insertPending(t, ops, 1)

	tr := &fakeTransport{
		replies: []fakeReply{
			{ack: &posv1.SyncBatchAck{Status: posv1.SyncBatchAck_STATUS_RETRY_LATER, Message: "shard rebalancing"}},
			{ack: &posv1.SyncBatchAck{Status: posv1.SyncBatchAck_STATUS_APPLIED}},
		},
	}
	w := newWorker(t, ops, state, tr, syncpkg.WorkerOpts{})

	runUntilDrained(t, w, ops, []uuid.UUID{id}, 2*time.Second)

	op, err := ops.Get(context.Background(), id)
	require.NoError(t, err)
	require.Equal(t, opslog.StatusAcked, op.SyncStatus,
		"RETRY_LATER then APPLIED must end in acked")
	require.GreaterOrEqual(t, tr.Calls(), 2)
}

func TestWorker_NothingPending_NoCalls(t *testing.T) {
	ops, state, _ := newTestStores(t)

	tr := &fakeTransport{}
	w := newWorker(t, ops, state, tr, syncpkg.WorkerOpts{})

	ctx, cancel := context.WithTimeout(context.Background(), 150*time.Millisecond)
	defer cancel()
	_ = w.Run(ctx)

	require.Equal(t, 0, tr.Calls(),
		"empty queue must not invoke transport")
}

func TestWorker_Notify_WakesImmediately(t *testing.T) {
	ops, state, _ := newTestStores(t)
	id := insertPending(t, ops, 1)

	tr := &fakeTransport{
		replies: []fakeReply{{ack: &posv1.SyncBatchAck{Status: posv1.SyncBatchAck_STATUS_APPLIED}}},
	}
	// Long tick — if Notify works, we don't wait for it.
	w := newWorker(t, ops, state, tr, syncpkg.WorkerOpts{Tick: 10 * time.Second})

	ctx, cancel := context.WithCancel(context.Background())
	done := make(chan struct{})
	go func() { _ = w.Run(ctx); close(done) }()
	defer func() { cancel(); <-done }()

	// The initial drain at Run start should already pick this up — Notify
	// is exercised after a follow-up insert.
	deadline := time.Now().Add(2 * time.Second)
	for time.Now().Before(deadline) {
		op, err := ops.Get(context.Background(), id)
		require.NoError(t, err)
		if op.SyncStatus == opslog.StatusAcked {
			break
		}
		time.Sleep(5 * time.Millisecond)
	}

	// Now insert a second op AFTER startup drain has settled, call Notify,
	// and assert the worker picks it up well inside the 10s tick window.
	id2 := insertPending(t, ops, 2)
	w.Notify()

	deadline = time.Now().Add(1 * time.Second)
	for time.Now().Before(deadline) {
		op, err := ops.Get(context.Background(), id2)
		require.NoError(t, err)
		if op.SyncStatus == opslog.StatusAcked {
			return
		}
		time.Sleep(5 * time.Millisecond)
	}
	t.Fatal("Notify did not wake the worker within 1s (tick is 10s)")
}

func TestWorker_RetryAfterError_HonorsServerHintAndDoesNotBumpBackoff(t *testing.T) {
	ops, state, _ := newTestStores(t)
	id := insertPending(t, ops, 1)

	hint := 30 * time.Millisecond
	tr := &fakeTransport{
		replies: []fakeReply{
			{err: &syncpkg.RetryAfterError{
				TransientError: syncpkg.TransientError{Err: errors.New("429 backoff")},
				RetryAfter:     hint,
			}},
			{ack: &posv1.SyncBatchAck{Status: posv1.SyncBatchAck_STATUS_APPLIED}},
		},
	}
	// Backoff with a deliberately *large* Base so it would dominate if the
	// worker fell back to it. With Retry-After honored we should still settle
	// inside the runUntilDrained timeout because actual wait is 30ms.
	bo := syncpkg.NewBackoff(syncpkg.BackoffOpts{
		Base: 30 * time.Second,
		Cap:  60 * time.Second,
		Rng:  rand.New(rand.NewPCG(1, 1)),
	})
	w := newWorker(t, ops, state, tr, syncpkg.WorkerOpts{MaxRetries: 5, Backoff: bo})

	runUntilDrained(t, w, ops, []uuid.UUID{id}, 1*time.Second)

	op, err := ops.Get(context.Background(), id)
	require.NoError(t, err)
	require.Equal(t, opslog.StatusAcked, op.SyncStatus,
		"worker should have honored the 30ms Retry-After, not the 30s backoff base")
}

func TestWorker_DegradedRecoveredLogsFireOncePerOutage(t *testing.T) {
	ops, state, _ := newTestStores(t)
	id := insertPending(t, ops, 1)

	var buf bytes.Buffer
	logger := slog.New(slog.NewTextHandler(&buf, &slog.HandlerOptions{Level: slog.LevelInfo}))

	tr := &fakeTransport{
		replies: []fakeReply{
			{err: &syncpkg.TransientError{Err: errors.New("net")}},
			{err: &syncpkg.TransientError{Err: errors.New("net")}},
			{err: &syncpkg.TransientError{Err: errors.New("net")}},
			{ack: &posv1.SyncBatchAck{Status: posv1.SyncBatchAck_STATUS_APPLIED}},
		},
	}
	w := newWorker(t, ops, state, tr, syncpkg.WorkerOpts{MaxRetries: 5, Logger: logger})

	runUntilDrained(t, w, ops, []uuid.UUID{id}, 2*time.Second)

	out := buf.String()
	require.Equal(t, 1, strings.Count(out, "cloud connection degraded"),
		"degraded must log exactly once per outage, got:\n%s", out)
	require.Equal(t, 1, strings.Count(out, "cloud connection recovered"),
		"recovered must log exactly once when streak ends, got:\n%s", out)
}

func TestWorker_HappyPathDoesNotLogRecoveredOrDegraded(t *testing.T) {
	ops, state, _ := newTestStores(t)
	id := insertPending(t, ops, 1)

	var buf bytes.Buffer
	logger := slog.New(slog.NewTextHandler(&buf, &slog.HandlerOptions{Level: slog.LevelInfo}))

	tr := &fakeTransport{
		replies: []fakeReply{{ack: &posv1.SyncBatchAck{Status: posv1.SyncBatchAck_STATUS_APPLIED}}},
	}
	w := newWorker(t, ops, state, tr, syncpkg.WorkerOpts{Logger: logger})

	runUntilDrained(t, w, ops, []uuid.UUID{id}, 1*time.Second)

	out := buf.String()
	require.NotContains(t, out, "cloud connection degraded")
	require.NotContains(t, out, "cloud connection recovered")
}

func TestWorker_StartupJitter_BoundedByConfig(t *testing.T) {
	ops, state, _ := newTestStores(t)
	id := insertPending(t, ops, 1)

	tr := &fakeTransport{
		replies: []fakeReply{{ack: &posv1.SyncBatchAck{Status: posv1.SyncBatchAck_STATUS_APPLIED}}},
	}
	jitter := 50 * time.Millisecond
	w := newWorker(t, ops, state, tr, syncpkg.WorkerOpts{
		StartupJitter: jitter,
		JitterRng:     rand.New(rand.NewPCG(7, 7)),
	})

	start := time.Now()
	runUntilDrained(t, w, ops, []uuid.UUID{id}, 500*time.Millisecond)
	elapsed := time.Since(start)

	require.Less(t, elapsed, jitter+250*time.Millisecond,
		"startup jitter must be bounded by config (jitter=%s, elapsed=%s)", jitter, elapsed)
}

func TestWorker_ContextCancel_ShutsDown(t *testing.T) {
	ops, state, _ := newTestStores(t)
	tr := &fakeTransport{}
	w := newWorker(t, ops, state, tr, syncpkg.WorkerOpts{
		Tick:          1 * time.Second,
		ShutdownGrace: 20 * time.Millisecond,
	})

	ctx, cancel := context.WithCancel(context.Background())
	done := make(chan error, 1)
	go func() { done <- w.Run(ctx) }()

	cancel()
	select {
	case err := <-done:
		require.NoError(t, err)
	case <-time.After(200 * time.Millisecond):
		t.Fatal("worker did not honor context cancellation within grace+slack")
	}
}
