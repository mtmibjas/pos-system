package sync

import (
	"context"
	"errors"
	"fmt"

	"github.com/google/uuid"
	"google.golang.org/protobuf/proto"
	"google.golang.org/protobuf/types/known/timestamppb"

	"github.com/mibjas/pos-platform/apps/local-store-server/internal/opslog"
	posv1 "github.com/mibjas/pos-platform/packages/sdk-go/gen/pos/v1"
)

// Batcher pulls pending operations from the opslog and assembles them into
// a SyncBatch ready for the transport. Grouping rules (docs/sync-rules.md
// "Batching — atomic groups"):
//
//   - Ops that already share a non-nil batch_id (e.g. a sale's three ops
//     written by the future SaleService) ship together — that grouping is
//     load-bearing for atomicity at the cloud, and we never split it.
//   - Ungrouped ops (batch_id NULL) ship together as one fresh batch.
//
// Batcher itself is stateless — the worker owns the loop.
type Batcher struct {
	ops      *opslog.Store
	tenantID string
	maxOps   int
}

// NewBatcher creates a Batcher. maxOps <= 0 defaults to 100.
func NewBatcher(ops *opslog.Store, tenantID string, maxOps int) *Batcher {
	if maxOps <= 0 {
		maxOps = 100
	}
	return &Batcher{ops: ops, tenantID: tenantID, maxOps: maxOps}
}

// ErrNothingPending is returned by Next when no operations are pending.
var ErrNothingPending = errors.New("sync: nothing pending")

// Next pulls the next batch's worth of pending ops, marks them in_flight
// under a single batch_id (preserving any pre-existing batch_id grouping),
// and returns the wire-ready SyncBatch.
//
// Returns ErrNothingPending when the queue is empty so the worker can
// distinguish "no work" from "real error".
func (b *Batcher) Next(ctx context.Context) (*posv1.SyncBatch, []uuid.UUID, error) {
	pending, err := b.ops.ListPending(ctx, b.maxOps)
	if err != nil {
		return nil, nil, fmt.Errorf("sync: list pending: %w", err)
	}
	if len(pending) == 0 {
		return nil, nil, ErrNothingPending
	}

	// If the head op has a non-nil batch_id (post-crash resume), ship only
	// that group; otherwise grab the whole pending window.
	headBatch := pending[0].BatchID
	var (
		picked []opslog.Operation
		ids    []uuid.UUID
	)
	if headBatch != uuid.Nil {
		for _, op := range pending {
			if op.BatchID == headBatch {
				picked = append(picked, op)
				ids = append(ids, op.OperationID)
			}
		}
	} else {
		for _, op := range pending {
			// Stop the moment we hit a pre-grouped op — it must ship in its
			// own next call to preserve grouping order.
			if op.BatchID != uuid.Nil {
				break
			}
			picked = append(picked, op)
			ids = append(ids, op.OperationID)
		}
	}

	batchID := headBatch
	if batchID == uuid.Nil {
		batchID = uuid.New()
	}

	if _, err := b.ops.MarkInFlight(ctx, ids, batchID); err != nil {
		return nil, nil, fmt.Errorf("sync: mark in_flight: %w", err)
	}

	batch, err := assembleBatch(b.tenantID, batchID, picked)
	if err != nil {
		return nil, nil, err
	}
	return batch, ids, nil
}

// assembleBatch wraps the picked ops into a SyncBatch. Each opslog payload
// is already the marshaled EventEnvelope (see internal/events.Pack); we
// unmarshal it back into the typed envelope so the wire shape carries
// structured data, not opaque bytes.
func assembleBatch(tenantID string, batchID uuid.UUID, ops []opslog.Operation) (*posv1.SyncBatch, error) {
	wire := &posv1.SyncBatch{
		BatchId:      batchID.String(),
		TenantId:     &posv1.TenantId{Value: tenantID},
		ClientSentAt: timestamppb.Now(),
		Operations:   make([]*posv1.Operation, 0, len(ops)),
	}
	for _, op := range ops {
		env := &posv1.EventEnvelope{}
		if err := proto.Unmarshal(op.Payload, env); err != nil {
			return nil, fmt.Errorf("sync: unmarshal payload for op %s: %w", op.OperationID, err)
		}
		wire.Operations = append(wire.Operations, &posv1.Operation{
			OperationId:   &posv1.OperationId{Value: op.OperationID.String()},
			OperationType: op.OperationType,
			EntityType:    op.EntityType,
			EntityId:      op.EntityID,
			Envelope:      env,
			CreatedAt:     timestamppb.New(op.CreatedAt),
			Origin:        &posv1.OriginNode{NodeId: op.OriginNodeID},
			RetryCount:    uint32(op.RetryCount),
		})
	}
	return wire, nil
}
