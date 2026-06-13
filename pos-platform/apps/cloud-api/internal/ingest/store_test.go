package ingest_test

import (
	"context"
	"path/filepath"
	"strconv"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/require"
	"google.golang.org/protobuf/types/known/timestamppb"

	"github.com/mibjas/pos-platform/apps/cloud-api/internal/db"
	"github.com/mibjas/pos-platform/apps/cloud-api/internal/ingest"
	posv1 "github.com/mibjas/pos-platform/packages/sdk-go/gen/pos/v1"
)

func uuidStr(t *testing.T) string {
	t.Helper()
	return uuid.NewString()
}

func newStore(t *testing.T) *ingest.Store {
	t.Helper()
	ctx := context.Background()
	sqlDB, err := db.Open(ctx, db.Config{Path: filepath.Join(t.TempDir(), "cloud.db")})
	require.NoError(t, err)
	t.Cleanup(func() { _ = sqlDB.Close() })
	require.NoError(t, db.RunMigrations(sqlDB))
	frozen := time.Date(2026, 5, 31, 12, 0, 0, 0, time.UTC)
	return ingest.NewStore(sqlDB, func() time.Time { return frozen })
}

func newOp(opID, opType, entityType, entityID string, lamport uint64) *posv1.Operation {
	return &posv1.Operation{
		OperationId:   &posv1.OperationId{Value: opID},
		OperationType: opType,
		EntityType:    entityType,
		EntityId:      entityID,
		Envelope: &posv1.EventEnvelope{
			OperationId:   &posv1.OperationId{Value: opID},
			EventType:     opType,
			SchemaVersion: 1,
			TenantId:      &posv1.TenantId{Value: "tenant-A"},
			Origin:        &posv1.OriginNode{NodeId: "node-1"},
			Clock:         &posv1.LamportClock{Counter: lamport, NodeId: "node-1"},
			OccurredAt:    timestamppb.New(time.Date(2026, 5, 31, 11, 0, 0, 0, time.UTC)),
			Payload: &posv1.EventEnvelope_SaleCreated{
				SaleCreated: &posv1.SaleCreated{SaleId: entityID},
			},
		},
		Origin: &posv1.OriginNode{NodeId: "node-1"},
	}
}

func newBatch(batchID string, ops ...*posv1.Operation) *posv1.SyncBatch {
	return &posv1.SyncBatch{
		BatchId:    batchID,
		TenantId:   &posv1.TenantId{Value: "tenant-A"},
		Operations: ops,
	}
}

func TestApply_HappyPath_Applied(t *testing.T) {
	s := newStore(t)
	batch := newBatch("batch-1",
		newOp(uuidStr(t), "sale_created", "sale", "sale-1", 1),
		newOp(uuidStr(t), "payment_added", "payment", "pay-1", 2),
	)

	res, err := s.Apply(context.Background(), batch)
	require.NoError(t, err)
	require.Equal(t, posv1.SyncBatchAck_STATUS_APPLIED, res.Status)
}

func TestApply_SameBatchRetried_Duplicate(t *testing.T) {
	s := newStore(t)
	batch := newBatch("batch-1", newOp(uuidStr(t), "sale_created", "sale", "sale-1", 1))

	res, err := s.Apply(context.Background(), batch)
	require.NoError(t, err)
	require.Equal(t, posv1.SyncBatchAck_STATUS_APPLIED, res.Status)

	res2, err := s.Apply(context.Background(), batch)
	require.NoError(t, err)
	require.Equal(t, posv1.SyncBatchAck_STATUS_DUPLICATE, res2.Status,
		"re-presenting the same batch_id must be DUPLICATE without touching rows")
}

func TestApply_OperationIDInDifferentBatch_Rejected(t *testing.T) {
	s := newStore(t)
	opID := uuidStr(t)
	first := newBatch("batch-1", newOp(opID, "sale_created", "sale", "sale-1", 1))
	res, err := s.Apply(context.Background(), first)
	require.NoError(t, err)
	require.Equal(t, posv1.SyncBatchAck_STATUS_APPLIED, res.Status)

	// Same operation_id re-used inside a different batch — contract violation.
	second := newBatch("batch-2", newOp(opID, "sale_created", "sale", "sale-1", 1))
	res2, err := s.Apply(context.Background(), second)
	require.NoError(t, err)
	require.Equal(t, posv1.SyncBatchAck_STATUS_REJECTED, res2.Status)
	require.Len(t, res2.OperationAcks, 1)
	require.Equal(t, opID, res2.OperationAcks[0].OperationId.Value)
	require.Equal(t, posv1.SyncBatchAck_STATUS_REJECTED, res2.OperationAcks[0].Status)
}

func TestApply_MissingBatchID_ReturnsSentinel(t *testing.T) {
	s := newStore(t)
	_, err := s.Apply(context.Background(), newBatch(""))
	require.ErrorIs(t, err, ingest.ErrEmptyBatchID)
}

func TestApply_MissingTenant_ReturnsSentinel(t *testing.T) {
	s := newStore(t)
	batch := &posv1.SyncBatch{BatchId: "batch-x"}
	_, err := s.Apply(context.Background(), batch)
	require.ErrorIs(t, err, ingest.ErrEmptyTenant)
}

func TestApply_NilBatch_Errors(t *testing.T) {
	s := newStore(t)
	_, err := s.Apply(context.Background(), nil)
	require.Error(t, err)
}

func TestApply_OpMissingOperationID_Rejected(t *testing.T) {
	s := newStore(t)
	batch := newBatch("batch-1", &posv1.Operation{
		// no OperationId — caught by slice-3.2 validation
		OperationType: "sale_created",
		EntityType:    "sale",
		EntityId:      "sale-1",
	})
	res, err := s.Apply(context.Background(), batch)
	require.NoError(t, err)
	require.Equal(t, posv1.SyncBatchAck_STATUS_REJECTED, res.Status)
	require.Len(t, res.OperationAcks, 1)
	require.Contains(t, res.OperationAcks[0].Error, "operation_id is empty")
}

// --- Slice 3.4: List / read-side ---

func mustApply(t *testing.T, s *ingest.Store, batchID string, ops ...*posv1.Operation) {
	t.Helper()
	res, err := s.Apply(context.Background(), newBatch(batchID, ops...))
	require.NoError(t, err)
	require.Equal(t, posv1.SyncBatchAck_STATUS_APPLIED, res.Status)
}

func TestList_RejectsEmptyTenant(t *testing.T) {
	s := newStore(t)
	_, _, err := s.List(context.Background(), "", ingest.Cursor{}, 10)
	require.Error(t, err)
}

func TestList_EmptyTable_ReturnsZeroCursor(t *testing.T) {
	s := newStore(t)
	events, next, err := s.List(context.Background(), "tenant-A", ingest.Cursor{}, 10)
	require.NoError(t, err)
	require.Empty(t, events)
	require.Equal(t, ingest.Cursor{}, next, "empty result → no next cursor")
}

func TestList_OrdersByLamportThenID(t *testing.T) {
	s := newStore(t)
	mustApply(t, s, "b-1",
		newOp(uuidStr(t), "sale_created", "sale", "s-1", 3),
		newOp(uuidStr(t), "sale_created", "sale", "s-2", 1),
	)
	mustApply(t, s, "b-2", newOp(uuidStr(t), "sale_created", "sale", "s-3", 2))

	events, _, err := s.List(context.Background(), "tenant-A", ingest.Cursor{}, 10)
	require.NoError(t, err)
	require.Len(t, events, 3)

	// Strictly ascending by lamport (ties broken by id).
	for i := 1; i < len(events); i++ {
		prev, cur := events[i-1], events[i]
		ok := cur.Lamport > prev.Lamport || (cur.Lamport == prev.Lamport && cur.ID > prev.ID)
		require.True(t, ok, "rows must be ascending: %+v then %+v", prev, cur)
	}
}

func TestList_PaginatesViaCursor(t *testing.T) {
	s := newStore(t)
	// 5 ops with strictly increasing lamports for predictability.
	for i := uint64(1); i <= 5; i++ {
		mustApply(t, s, "b-"+strconv.FormatUint(i, 10),
			newOp(uuidStr(t), "sale_created", "sale", "s-x", i))
	}

	// Page 1 (limit 2) → 2 rows + next cursor.
	page1, next1, err := s.List(context.Background(), "tenant-A", ingest.Cursor{}, 2)
	require.NoError(t, err)
	require.Len(t, page1, 2)
	require.NotEqual(t, ingest.Cursor{}, next1, "more rows remain — next cursor must be set")

	// Page 2 (limit 2) starting at next1.
	page2, next2, err := s.List(context.Background(), "tenant-A", next1, 2)
	require.NoError(t, err)
	require.Len(t, page2, 2)
	require.NotEqual(t, ingest.Cursor{}, next2)

	// Page 3: 1 remaining → short page → zero next cursor.
	page3, next3, err := s.List(context.Background(), "tenant-A", next2, 2)
	require.NoError(t, err)
	require.Len(t, page3, 1)
	require.Equal(t, ingest.Cursor{}, next3, "short page → end of stream")

	// All operation_ids distinct across pages.
	seen := map[string]bool{}
	for _, p := range [][]ingest.Event{page1, page2, page3} {
		for _, e := range p {
			require.False(t, seen[e.OperationID], "operation_id %s seen twice across pages", e.OperationID)
			seen[e.OperationID] = true
		}
	}
	require.Len(t, seen, 5)
}

func TestList_ClampsLimit(t *testing.T) {
	s := newStore(t)
	mustApply(t, s, "b-1", newOp(uuidStr(t), "sale_created", "sale", "s-1", 1))

	// Negative/zero limit defaults to DefaultListLimit; oversize clamps to Max.
	events, _, err := s.List(context.Background(), "tenant-A", ingest.Cursor{}, 0)
	require.NoError(t, err)
	require.Len(t, events, 1)

	events, _, err = s.List(context.Background(), "tenant-A", ingest.Cursor{}, ingest.MaxListLimit+1000)
	require.NoError(t, err)
	require.Len(t, events, 1, "single row regardless of how big limit is")
}

func TestList_TenantScoped(t *testing.T) {
	s := newStore(t)
	mustApply(t, s, "b-A", newOp(uuidStr(t), "sale_created", "sale", "s-A", 1))

	// Apply for tenant-B via a hand-built batch.
	res, err := s.Apply(context.Background(), &posv1.SyncBatch{
		BatchId:  "b-B",
		TenantId: &posv1.TenantId{Value: "tenant-B"},
		Operations: []*posv1.Operation{func() *posv1.Operation {
			o := newOp(uuidStr(t), "sale_created", "sale", "s-B", 1)
			o.Envelope.TenantId = &posv1.TenantId{Value: "tenant-B"}
			return o
		}()},
	})
	require.NoError(t, err)
	require.Equal(t, posv1.SyncBatchAck_STATUS_APPLIED, res.Status)

	a, _, err := s.List(context.Background(), "tenant-A", ingest.Cursor{}, 10)
	require.NoError(t, err)
	require.Len(t, a, 1)
	require.Equal(t, "tenant-A", a[0].TenantID)

	b, _, err := s.List(context.Background(), "tenant-B", ingest.Cursor{}, 10)
	require.NoError(t, err)
	require.Len(t, b, 1)
	require.Equal(t, "tenant-B", b[0].TenantID,
		"list must be strictly tenant-scoped — no leaks across tenants")
}

func TestApply_RejectedBatchDoesNotConsumeBatchID(t *testing.T) {
	s := newStore(t)
	bad := newBatch("batch-1", &posv1.Operation{OperationType: "x"})
	res, err := s.Apply(context.Background(), bad)
	require.NoError(t, err)
	require.Equal(t, posv1.SyncBatchAck_STATUS_REJECTED, res.Status)

	// Same batch_id with fixed ops must succeed (validation rejection
	// runs before the applied_batches INSERT, so the id is not burned).
	good := newBatch("batch-1", newOp(uuidStr(t), "sale_created", "sale", "sale-1", 1))
	res2, err := s.Apply(context.Background(), good)
	require.NoError(t, err)
	require.Equal(t, posv1.SyncBatchAck_STATUS_APPLIED, res2.Status)
}
