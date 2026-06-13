// Slice 3.6 — end-to-end chaos test.
//
// Boots the real cloud-api handler stack (auth + ingest + read-side)
// via cloudapitest.Boot and drives it from the real local worker
// (opslog + Worker + HTTPTransport), with a programmable ChaosTransport
// decorator that injects faults between the worker and the cloud.
//
// Two invariants are checked:
//
//  1. NO LOSS — every op the local store marked acked exists exactly
//     once in the cloud's events table.
//  2. NO DOUBLE-APPLY — even when the cloud commits a batch but the
//     client never sees the ack (and therefore retries), the cloud
//     ends up with exactly one row per operation_id, not two.
//
// Auth is left ON (the cloud is wired with a verifier and the local
// transport mints a real JWT) so the chaos run exercises the same
// crypto path as production. Tenant isolation is tested explicitly.
package integration_test

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"sort"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/require"
	"google.golang.org/protobuf/proto"

	"github.com/mibjas/pos-platform/apps/cloud-api/cloudapitest"

	"github.com/mibjas/pos-platform/apps/local-store-server/internal/events"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/opslog"
	syncpkg "github.com/mibjas/pos-platform/apps/local-store-server/internal/sync"

	posv1 "github.com/mibjas/pos-platform/packages/sdk-go/gen/pos/v1"
)

// --- cloud read-side helpers ---

// listCloudEvents pulls every event for tenant across the cursor stream.
// Used as the read-side oracle: whatever the cloud returns here is what
// is actually durably committed.
func listCloudEvents(t *testing.T, cloud *cloudapitest.Fixture, tenant string) []cloudEvent {
	t.Helper()
	ts, err := syncpkg.NewTokenSource(syncpkg.TokenSourceOpts{
		Secret:  cloud.Secret,
		Tenant:  tenant,
		Issuer:  "chaos-test",
		Subject: "chaos-client",
		TTL:     5 * time.Minute,
	})
	require.NoError(t, err)

	var all []cloudEvent
	cursor := ""
	for {
		req, _ := http.NewRequest(http.MethodGet,
			cloud.URL+cloud.EventsPath+"?limit=500&cursor="+cursor, nil)
		bearer, err := ts.AuthHeader(context.Background())
		require.NoError(t, err)
		req.Header.Set("Authorization", bearer)
		resp, err := http.DefaultClient.Do(req)
		require.NoError(t, err)
		body, _ := io.ReadAll(resp.Body)
		_ = resp.Body.Close()
		require.Equal(t, http.StatusOK, resp.StatusCode, "events fetch: %s", body)

		var page eventsPage
		require.NoError(t, json.Unmarshal(body, &page))
		all = append(all, page.Events...)
		if page.NextCursor == "" {
			break
		}
		cursor = page.NextCursor
	}
	return all
}

type eventsPage struct {
	Events     []cloudEvent `json:"events"`
	NextCursor string       `json:"next_cursor"`
}

type cloudEvent struct {
	ID            int64  `json:"id"`
	OperationID   string `json:"operation_id"`
	BatchID       string `json:"batch_id"`
	TenantID      string `json:"tenant_id"`
	OperationType string `json:"operation_type"`
	PayloadB64    string `json:"payload_b64"`
	Lamport       int64  `json:"lamport"`
}

// --- chaos transport ---

// ChaosOp gets the call index, the outgoing batch, and a handle to the
// real transport. It returns whatever ack/error the worker should see.
// The op may freely call inner.Send(...) zero or more times (e.g.
// "commit on the cloud but tell the worker it failed").
type ChaosOp func(t *testing.T, call int, batch *posv1.SyncBatch, inner syncpkg.Transport) (*posv1.SyncBatchAck, error)

// ChaosTransport wraps a real Transport and replaces the response for
// the first len(plan) calls per the plan. Subsequent calls fall through.
type ChaosTransport struct {
	t     *testing.T
	inner syncpkg.Transport
	mu    sync.Mutex
	plan  []ChaosOp
	calls int
}

func newChaosTransport(t *testing.T, inner syncpkg.Transport, plan ...ChaosOp) *ChaosTransport {
	return &ChaosTransport{t: t, inner: inner, plan: plan}
}

func (c *ChaosTransport) Send(ctx context.Context, batch *posv1.SyncBatch) (*posv1.SyncBatchAck, error) {
	c.mu.Lock()
	n := c.calls
	c.calls++
	c.mu.Unlock()

	if n < len(c.plan) {
		return c.plan[n](c.t, n, batch, c.inner)
	}
	return c.inner.Send(ctx, batch)
}

func (c *ChaosTransport) CallCount() int {
	c.mu.Lock()
	defer c.mu.Unlock()
	return c.calls
}

// --- chaos op helpers ---

// opPass forwards to the real transport unchanged.
func opPass() ChaosOp {
	return func(_ *testing.T, _ int, batch *posv1.SyncBatch, inner syncpkg.Transport) (*posv1.SyncBatchAck, error) {
		return inner.Send(context.Background(), batch)
	}
}

// opDropResponseAfterCommit calls inner so the cloud actually commits,
// then discards the ack and returns a transient network error to the
// worker. This is the canonical "cloud OK, network dropped" case that
// idempotency on batch_id has to survive.
func opDropResponseAfterCommit() ChaosOp {
	return func(t *testing.T, _ int, batch *posv1.SyncBatch, inner syncpkg.Transport) (*posv1.SyncBatchAck, error) {
		ack, err := inner.Send(context.Background(), batch)
		// We expect the inner Send to succeed; if it didn't, the test
		// setup is buggy — fail loudly instead of masking it.
		require.NoError(t, err, "inner cloud must accept the batch before we drop the response")
		require.NotNil(t, ack)
		return nil, &syncpkg.TransientError{Err: fmt.Errorf("chaos: response dropped (cloud already committed batch %s)", batch.BatchId)}
	}
}

// opForce503RetryAfter returns a server-hinted retry-after error WITHOUT
// touching the cloud. Used to test that the worker honors the server's
// schedule.
func opForce503RetryAfter(d time.Duration) ChaosOp {
	return func(_ *testing.T, _ int, batch *posv1.SyncBatch, _ syncpkg.Transport) (*posv1.SyncBatchAck, error) {
		return nil, &syncpkg.RetryAfterError{
			TransientError: syncpkg.TransientError{Err: fmt.Errorf("chaos: forced 503 on batch %s", batch.BatchId)},
			RetryAfter:     d,
		}
	}
}

// --- invariants ---

// assertCloudHasOpsExactlyOnce verifies the no-loss + no-double-apply
// invariants in one shot: the multiset of operation_ids on the cloud
// for `tenant` equals the set passed in, with no duplicates.
func assertCloudHasOpsExactlyOnce(t *testing.T, evts []cloudEvent, tenant string, want []uuid.UUID) {
	t.Helper()

	cloudIDs := map[string]int{}
	for _, e := range evts {
		require.Equal(t, tenant, e.TenantID,
			"cloud event %d carries tenant %s but assertion is scoped to %s — cross-tenant leak",
			e.ID, e.TenantID, tenant)
		cloudIDs[e.OperationID]++
		_, err := base64.StdEncoding.DecodeString(e.PayloadB64)
		require.NoError(t, err, "event %d payload not base64", e.ID)
	}

	for opID, n := range cloudIDs {
		require.Equal(t, 1, n,
			"operation_id %s appears %d times on the cloud — idempotency broken under chaos",
			opID, n)
	}

	wantStrs := make([]string, len(want))
	for i, id := range want {
		wantStrs[i] = id.String()
	}
	sort.Strings(wantStrs)

	gotStrs := make([]string, 0, len(cloudIDs))
	for k := range cloudIDs {
		gotStrs = append(gotStrs, k)
	}
	sort.Strings(gotStrs)

	require.Equal(t, wantStrs, gotStrs,
		"cloud ops do not equal local ops — at least one op was lost or fabricated")
}

// --- driving helpers ---

func drivenWorker(t *testing.T, s *stores, tenant string, chaos *ChaosTransport) *syncpkg.Worker {
	t.Helper()
	logger := slog.New(slog.NewTextHandler(io.Discard, nil))
	return syncpkg.NewWorker(s.ops, s.state, chaos, tenant, syncpkg.WorkerOpts{
		Tick:          20 * time.Millisecond,
		MaxRetries:    20,
		Logger:        logger,
		ShutdownGrace: 20 * time.Millisecond,
		Backoff: syncpkg.NewBackoff(syncpkg.BackoffOpts{
			Base: 2 * time.Millisecond,
			Cap:  15 * time.Millisecond,
		}),
	})
}

func realTransport(t *testing.T, cloud *cloudapitest.Fixture, tenant string) syncpkg.Transport {
	t.Helper()
	ts, err := syncpkg.NewTokenSource(syncpkg.TokenSourceOpts{
		Secret:  cloud.Secret,
		Tenant:  tenant,
		Issuer:  "chaos-test",
		Subject: "chaos-client",
		TTL:     5 * time.Minute,
	})
	require.NoError(t, err)
	tr := syncpkg.NewHTTPTransport(cloud.URL)
	tr.AuthHeaderFunc = ts.AuthHeader
	return tr
}

func runUntilAcked(t *testing.T, w *syncpkg.Worker, ops *opslog.Store, ids []uuid.UUID, timeout time.Duration) {
	t.Helper()
	ctx, cancel := context.WithCancel(context.Background())
	done := make(chan struct{})
	go func() { _ = w.Run(ctx); close(done) }()
	defer func() { cancel(); <-done }()

	deadline := time.Now().Add(timeout)
	for time.Now().Before(deadline) {
		all := true
		for _, id := range ids {
			op, err := ops.Get(context.Background(), id)
			if err != nil || op.SyncStatus != opslog.StatusAcked {
				all = false
				break
			}
		}
		if all {
			return
		}
		time.Sleep(5 * time.Millisecond)
	}
	t.Fatalf("worker did not ack all %d ops within %s", len(ids), timeout)
}

func seedOpsForTenant(t *testing.T, s *stores, tenant string, n int) []uuid.UUID {
	t.Helper()
	ctx := context.Background()
	ids := make([]uuid.UUID, n)
	for i := 0; i < n; i++ {
		id := uuid.New()
		lamport := uint64(i + 1)
		sale := &posv1.SaleCreated{
			SaleId:  id.String(),
			StoreId: &posv1.StoreId{Value: "store-" + tenant},
		}
		_, payload, err := events.Pack(sale, events.Meta{
			OperationID: id.String(),
			TenantID:    tenant,
			OriginNode:  &posv1.OriginNode{NodeId: nodeID},
			Lamport:     lamport,
			OccurredAt:  time.Now().UTC(),
		})
		require.NoError(t, err)
		_, _, err = s.ops.Insert(ctx, opslog.Operation{
			OperationID:   id,
			OperationType: "sale_created",
			EntityType:    "sale",
			EntityID:      id.String(),
			Payload:       payload,
			CreatedAt:     time.Now().UTC(),
			Lamport:       lamport,
			OriginNodeID:  nodeID,
		})
		require.NoError(t, err)
		ids[i] = id
	}
	return ids
}

// --- scenarios ---

// TestChaos_DroppedResponses_IdempotentApply is the headline test.
// The first few sends "drop" their response after the cloud has already
// committed. The worker treats the dropped response as transient and
// retries with the SAME batch_id (MarkRetry preserves it); the cloud
// responds STATUS_DUPLICATE; nothing gets written twice. Final cloud
// state is exactly one event per op_id.
func TestChaos_DroppedResponses_IdempotentApply(t *testing.T) {
	s := newStores(t)
	cloud := cloudapitest.Boot(t)
	ids := seedOpsForTenant(t, s, "tenant-A", 6)

	// Drop the first 3 sends after the cloud commits, then let traffic
	// through. The worker bundles all pending ops into one batch, so each
	// drop forces a same-batch retry that the cloud must classify as
	// DUPLICATE.
	chaos := newChaosTransport(t, realTransport(t, cloud, "tenant-A"),
		opDropResponseAfterCommit(),
		opDropResponseAfterCommit(),
		opDropResponseAfterCommit(),
	)

	w := drivenWorker(t, s, "tenant-A", chaos)
	runUntilAcked(t, w, s.ops, ids, 5*time.Second)

	evts := listCloudEvents(t, cloud, "tenant-A")
	assertCloudHasOpsExactlyOnce(t, evts, "tenant-A", ids)

	require.GreaterOrEqual(t, chaos.CallCount(), 4,
		"chaos plan dropped 3 responses — worker should have made at least 4 sends total")
}

// TestChaos_RetryAfter503Storm_HonorsServerHint forces a stream of
// 503+Retry-After errors before any traffic reaches the cloud, then
// lets it through. The batch must eventually land exactly once.
func TestChaos_RetryAfter503Storm_HonorsServerHint(t *testing.T) {
	s := newStores(t)
	cloud := cloudapitest.Boot(t)
	ids := seedOpsForTenant(t, s, "tenant-A", 3)

	chaos := newChaosTransport(t, realTransport(t, cloud, "tenant-A"),
		opForce503RetryAfter(10*time.Millisecond),
		opForce503RetryAfter(10*time.Millisecond),
		opForce503RetryAfter(10*time.Millisecond),
		opForce503RetryAfter(10*time.Millisecond),
		opForce503RetryAfter(10*time.Millisecond),
	)

	w := drivenWorker(t, s, "tenant-A", chaos)
	runUntilAcked(t, w, s.ops, ids, 5*time.Second)

	evts := listCloudEvents(t, cloud, "tenant-A")
	assertCloudHasOpsExactlyOnce(t, evts, "tenant-A", ids)
}

// TestChaos_TenantIsolationUnderConcurrentChaos runs two workers
// against the same cloud with chaos on each. Each tenant's read-side
// must contain exactly its own ops — no cross-tenant leakage even
// when both workers are retrying through the same backend at once.
func TestChaos_TenantIsolationUnderConcurrentChaos(t *testing.T) {
	sA := newStores(t)
	sB := newStores(t)
	cloud := cloudapitest.Boot(t)

	idsA := seedOpsForTenant(t, sA, "tenant-A", 4)
	idsB := seedOpsForTenant(t, sB, "tenant-B", 4)

	chaosA := newChaosTransport(t, realTransport(t, cloud, "tenant-A"),
		opDropResponseAfterCommit(),
		opPass(),
		opDropResponseAfterCommit(),
	)
	chaosB := newChaosTransport(t, realTransport(t, cloud, "tenant-B"),
		opPass(),
		opDropResponseAfterCommit(),
		opPass(),
	)

	wA := drivenWorker(t, sA, "tenant-A", chaosA)
	wB := drivenWorker(t, sB, "tenant-B", chaosB)

	var wg sync.WaitGroup
	wg.Add(2)
	go func() { defer wg.Done(); runUntilAcked(t, wA, sA.ops, idsA, 5*time.Second) }()
	go func() { defer wg.Done(); runUntilAcked(t, wB, sB.ops, idsB, 5*time.Second) }()
	wg.Wait()

	assertCloudHasOpsExactlyOnce(t, listCloudEvents(t, cloud, "tenant-A"), "tenant-A", idsA)
	assertCloudHasOpsExactlyOnce(t, listCloudEvents(t, cloud, "tenant-B"), "tenant-B", idsB)
}

// TestChaos_ReadSideOrdersByLamport verifies that even when the
// chaos transport reshuffles delivery timing (drops + retries), the
// cloud read-side still returns events in lamport order — that's what
// downstream consumers rely on for replay.
func TestChaos_ReadSideOrdersByLamport(t *testing.T) {
	s := newStores(t)
	cloud := cloudapitest.Boot(t)

	ids := seedOpsForTenant(t, s, "tenant-A", 5)
	chaos := newChaosTransport(t, realTransport(t, cloud, "tenant-A"),
		opDropResponseAfterCommit(),
		opPass(),
		opDropResponseAfterCommit(),
	)
	w := drivenWorker(t, s, "tenant-A", chaos)
	runUntilAcked(t, w, s.ops, ids, 5*time.Second)

	evts := listCloudEvents(t, cloud, "tenant-A")
	require.Len(t, evts, len(ids))

	for i := 1; i < len(evts); i++ {
		require.Greater(t, evts[i].Lamport, evts[i-1].Lamport,
			"read-side must order by lamport regardless of received_at: %d then %d",
			evts[i-1].Lamport, evts[i].Lamport)
	}

	// Sanity: payloads proto-decode back to the original ops.
	seen := map[string]bool{}
	for _, e := range evts {
		raw, err := base64.StdEncoding.DecodeString(e.PayloadB64)
		require.NoError(t, err)
		env := &posv1.EventEnvelope{}
		require.NoError(t, proto.Unmarshal(raw, env))
		require.Equal(t, e.OperationID, env.OperationId.Value)
		seen[e.OperationID] = true
	}
	require.Len(t, seen, len(ids))
}
