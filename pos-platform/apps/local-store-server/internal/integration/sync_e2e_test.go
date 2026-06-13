package integration_test

import (
	"context"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/require"
	"google.golang.org/protobuf/proto"

	"github.com/mibjas/pos-platform/apps/local-store-server/internal/events"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/opslog"
	syncpkg "github.com/mibjas/pos-platform/apps/local-store-server/internal/sync"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/syncstate"

	posv1 "github.com/mibjas/pos-platform/packages/sdk-go/gen/pos/v1"
)

// TestE2E_SyncWorker_DrainsPendingOpsAgainstRealHTTPServer wires the real
// HTTP transport, real worker, and a real httptest server (mimicking the
// cloud-api stub's contract) to prove the whole pipeline ships ops end-to-end.
func TestE2E_SyncWorker_DrainsPendingOpsAgainstRealHTTPServer(t *testing.T) {
	s := newStores(t)
	ctx := context.Background()

	// Seed two pending ops via the real Pack + opslog path.
	id1 := mustInsertSaleOp(t, s.ops, s.clk, ctx)
	id2 := mustInsertSaleOp(t, s.ops, s.clk, ctx)

	// In-process cloud stub: tracks applied batches, returns DUPLICATE on
	// repeat (idempotency contract — see docs/sync-rules.md).
	seen := newSeenSet()
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		require.Equal(t, "/v1/sync/batches", r.URL.Path)
		require.Equal(t, "application/x-protobuf", r.Header.Get("Content-Type"))
		body, err := io.ReadAll(r.Body)
		require.NoError(t, err)
		batch := &posv1.SyncBatch{}
		require.NoError(t, proto.Unmarshal(body, batch))
		require.NotEmpty(t, batch.BatchId)
		require.NotEmpty(t, batch.Operations, "batch must carry the ops we enqueued")

		status := posv1.SyncBatchAck_STATUS_APPLIED
		if !seen.add(batch.BatchId) {
			status = posv1.SyncBatchAck_STATUS_DUPLICATE
		}
		w.Header().Set("Content-Type", "application/x-protobuf")
		ack, _ := proto.Marshal(&posv1.SyncBatchAck{BatchId: batch.BatchId, Status: status})
		_, _ = w.Write(ack)
	}))
	defer srv.Close()

	transport := syncpkg.NewHTTPTransport(srv.URL)
	worker := syncpkg.NewWorker(s.ops, s.state, transport, "tenant-A", syncpkg.WorkerOpts{
		Tick:          50 * time.Millisecond,
		MaxRetries:    3,
		Logger:        slog.New(slog.NewTextHandler(io.Discard, nil)),
		ShutdownGrace: 20 * time.Millisecond,
		Backoff: syncpkg.NewBackoff(syncpkg.BackoffOpts{
			Base: 5 * time.Millisecond,
			Cap:  20 * time.Millisecond,
		}),
	})

	wctx, cancel := context.WithCancel(context.Background())
	done := make(chan struct{})
	go func() { _ = worker.Run(wctx); close(done) }()
	defer func() { cancel(); <-done }()

	waitForAcked(t, s.ops, []uuid.UUID{id1, id2}, 3*time.Second)

	// Verify the worker also recorded sync metadata.
	_, err := s.state.GetTime(ctx, syncstate.KeyLastSyncAt)
	require.NoError(t, err)
	_, err = s.state.GetUUID(ctx, syncstate.KeyLastSyncBatchID)
	require.NoError(t, err)
}

func TestE2E_SyncWorker_NetworkOutageThenRecovery(t *testing.T) {
	s := newStores(t)
	ctx := context.Background()
	id := mustInsertSaleOp(t, s.ops, s.clk, ctx)

	// First 3 hits → 503 (transient), then APPLIED.
	var mu sync.Mutex
	hits := 0
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		mu.Lock()
		hits++
		n := hits
		mu.Unlock()

		if n <= 3 {
			http.Error(w, "warming up", http.StatusServiceUnavailable)
			return
		}
		body, _ := io.ReadAll(r.Body)
		batch := &posv1.SyncBatch{}
		_ = proto.Unmarshal(body, batch)
		w.Header().Set("Content-Type", "application/x-protobuf")
		ack, _ := proto.Marshal(&posv1.SyncBatchAck{
			BatchId: batch.BatchId, Status: posv1.SyncBatchAck_STATUS_APPLIED,
		})
		_, _ = w.Write(ack)
	}))
	defer srv.Close()

	transport := syncpkg.NewHTTPTransport(srv.URL)
	worker := syncpkg.NewWorker(s.ops, s.state, transport, "tenant-A", syncpkg.WorkerOpts{
		Tick:          50 * time.Millisecond,
		MaxRetries:    10,
		Logger:        slog.New(slog.NewTextHandler(io.Discard, nil)),
		ShutdownGrace: 20 * time.Millisecond,
		Backoff: syncpkg.NewBackoff(syncpkg.BackoffOpts{
			Base: 5 * time.Millisecond,
			Cap:  20 * time.Millisecond,
		}),
	})

	wctx, cancel := context.WithCancel(context.Background())
	done := make(chan struct{})
	go func() { _ = worker.Run(wctx); close(done) }()
	defer func() { cancel(); <-done }()

	waitForAcked(t, s.ops, []uuid.UUID{id}, 3*time.Second)

	op, err := s.ops.Get(ctx, id)
	require.NoError(t, err)
	require.GreaterOrEqual(t, op.RetryCount, 3,
		"retry_count must reflect the three transient attempts before recovery")
}

// --- helpers ---

func mustInsertSaleOp(t *testing.T, ops *opslog.Store, _ interface{}, ctx context.Context) uuid.UUID {
	t.Helper()
	id := uuid.New()
	sale := &posv1.SaleCreated{
		SaleId:  id.String(),
		StoreId: &posv1.StoreId{Value: "store-e2e"},
	}
	_, payload, err := events.Pack(sale, events.Meta{
		OperationID: id.String(),
		TenantID:    "tenant-A",
		OriginNode:  &posv1.OriginNode{NodeId: nodeID},
		Lamport:     1,
		OccurredAt:  time.Now().UTC(),
	})
	require.NoError(t, err)

	_, _, err = ops.Insert(ctx, opslog.Operation{
		OperationID:   id,
		OperationType: "sale_created",
		EntityType:    "sale",
		EntityID:      id.String(),
		Payload:       payload,
		CreatedAt:     time.Now().UTC(),
		Lamport:       1,
		OriginNodeID:  nodeID,
	})
	require.NoError(t, err)
	return id
}

func waitForAcked(t *testing.T, ops *opslog.Store, ids []uuid.UUID, timeout time.Duration) {
	t.Helper()
	deadline := time.Now().Add(timeout)
	for time.Now().Before(deadline) {
		allAcked := true
		for _, id := range ids {
			op, err := ops.Get(context.Background(), id)
			require.NoError(t, err)
			if op.SyncStatus != opslog.StatusAcked {
				allAcked = false
				break
			}
		}
		if allAcked {
			return
		}
		time.Sleep(10 * time.Millisecond)
	}
	t.Fatalf("ops did not reach acked within %s", timeout)
}

type seenSet struct {
	mu  sync.Mutex
	ids map[string]struct{}
}

func newSeenSet() *seenSet { return &seenSet{ids: map[string]struct{}{}} }

// add returns true if id was new (i.e. caller should APPLY), false if it
// was already present (DUPLICATE).
func (s *seenSet) add(id string) bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	if _, ok := s.ids[id]; ok {
		return false
	}
	s.ids[id] = struct{}{}
	return true
}
