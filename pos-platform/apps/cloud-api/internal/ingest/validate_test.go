package ingest

import (
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/require"
	"google.golang.org/protobuf/types/known/timestamppb"

	posv1 "github.com/mibjas/pos-platform/packages/sdk-go/gen/pos/v1"
)

// goodOp returns an operation that passes all validation rules.
// Tests mutate one field at a time to assert that rule's error.
func goodOp() *posv1.Operation {
	id := uuid.NewString()
	return &posv1.Operation{
		OperationId:   &posv1.OperationId{Value: id},
		OperationType: "sale_created",
		EntityType:    "sale",
		EntityId:      "sale-1",
		Envelope: &posv1.EventEnvelope{
			OperationId:   &posv1.OperationId{Value: id},
			EventType:     "sale_created",
			SchemaVersion: 1,
			TenantId:      &posv1.TenantId{Value: "tenant-A"},
			Origin:        &posv1.OriginNode{NodeId: "node-1"},
			Clock:         &posv1.LamportClock{Counter: 1, NodeId: "node-1"},
			OccurredAt:    timestamppb.New(time.Now()),
			Payload: &posv1.EventEnvelope_SaleCreated{
				SaleCreated: &posv1.SaleCreated{SaleId: "sale-1"},
			},
		},
	}
}

func TestValidateOperation_HappyPath(t *testing.T) {
	require.NoError(t, validateOperation(goodOp(), "tenant-A"))
}

func TestValidateOperation_Faults(t *testing.T) {
	cases := []struct {
		name      string
		mutate    func(*posv1.Operation)
		wantInErr string
	}{
		{"nil operation_id", func(o *posv1.Operation) { o.OperationId = nil }, "operation_id is empty"},
		{"non-uuid operation_id", func(o *posv1.Operation) { o.OperationId.Value = "not-a-uuid" }, "not a UUID"},
		{"empty operation_type", func(o *posv1.Operation) { o.OperationType = "" }, "operation_type is empty"},
		{"empty entity_type", func(o *posv1.Operation) { o.EntityType = "" }, "entity_type is empty"},
		{"empty entity_id", func(o *posv1.Operation) { o.EntityId = "" }, "entity_id is empty"},
		{"nil envelope", func(o *posv1.Operation) { o.Envelope = nil }, "envelope is nil"},
		{"envelope op_id mismatch", func(o *posv1.Operation) {
			o.Envelope.OperationId = &posv1.OperationId{Value: uuid.NewString()}
		}, "envelope.operation_id"},
		{"empty event_type", func(o *posv1.Operation) { o.Envelope.EventType = "" }, "envelope.event_type is empty"},
		{"event_type mismatch", func(o *posv1.Operation) { o.Envelope.EventType = "payment_added" }, "!= operation.operation_type"},
		{"zero schema_version", func(o *posv1.Operation) { o.Envelope.SchemaVersion = 0 }, "schema_version is zero"},
		{"empty envelope tenant", func(o *posv1.Operation) { o.Envelope.TenantId = nil }, "envelope.tenant_id is empty"},
		{"cross-tenant smuggling", func(o *posv1.Operation) {
			o.Envelope.TenantId = &posv1.TenantId{Value: "tenant-B"}
		}, "!= batch.tenant_id"},
		{"empty origin node", func(o *posv1.Operation) { o.Envelope.Origin = nil }, "origin.node_id is empty"},
		{"nil clock", func(o *posv1.Operation) { o.Envelope.Clock = nil }, "envelope.clock is nil"},
		{"nil occurred_at", func(o *posv1.Operation) { o.Envelope.OccurredAt = nil }, "occurred_at is nil"},
		{"unset payload", func(o *posv1.Operation) { o.Envelope.Payload = nil }, "payload oneof is unset"},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			op := goodOp()
			tc.mutate(op)
			err := validateOperation(op, "tenant-A")
			require.Error(t, err)
			require.Contains(t, err.Error(), tc.wantInErr)
		})
	}
}

func TestValidateOperation_NilOp(t *testing.T) {
	require.Error(t, validateOperation(nil, "tenant-A"))
}

func TestValidateOperation_MultipleFaults_JoinedInOneError(t *testing.T) {
	op := goodOp()
	op.EntityId = ""
	op.Envelope.SchemaVersion = 0
	err := validateOperation(op, "tenant-A")
	require.Error(t, err)
	msg := err.Error()
	require.Contains(t, msg, "entity_id is empty")
	require.Contains(t, msg, "schema_version is zero")
}

func TestValidateBatch_OneFault_OneAck(t *testing.T) {
	batch := &posv1.SyncBatch{
		BatchId:  "b-1",
		TenantId: &posv1.TenantId{Value: "tenant-A"},
		Operations: []*posv1.Operation{
			goodOp(),
			func() *posv1.Operation { o := goodOp(); o.EntityId = ""; return o }(),
			goodOp(),
		},
	}
	acks := validateBatch(batch)
	require.Len(t, acks, 1)
	require.Contains(t, acks[0].Error, "operation[1]")
	require.Contains(t, acks[0].Error, "entity_id is empty")
}

func TestValidateBatch_CleanBatch_NoAcks(t *testing.T) {
	batch := &posv1.SyncBatch{
		BatchId:    "b-1",
		TenantId:   &posv1.TenantId{Value: "tenant-A"},
		Operations: []*posv1.Operation{goodOp(), goodOp()},
	}
	require.Empty(t, validateBatch(batch))
}
