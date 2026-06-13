package ingest

import (
	"fmt"
	"strings"

	"github.com/google/uuid"

	posv1 "github.com/mibjas/pos-platform/packages/sdk-go/gen/pos/v1"
)

// validateBatch runs validateOperation against every op in the batch
// and returns one OperationAck per failed op. An empty result means
// the batch is clean and may proceed to insertion.
func validateBatch(batch *posv1.SyncBatch) []*posv1.OperationAck {
	tenant := batch.GetTenantId().GetValue()
	var acks []*posv1.OperationAck
	for i, op := range batch.GetOperations() {
		if err := validateOperation(op, tenant); err != nil {
			ack := &posv1.OperationAck{
				Status: posv1.SyncBatchAck_STATUS_REJECTED,
				Error:  fmt.Sprintf("operation[%d]: %s", i, err.Error()),
			}
			if op != nil {
				ack.OperationId = op.GetOperationId()
			}
			acks = append(acks, ack)
		}
	}
	return acks
}

// validateOperation runs all per-operation contract checks the DB
// cannot enforce. Returns nil on a clean op; otherwise a human-readable
// reason joining every fault found (callers surface this to the sender
// via OperationAck.Error so a single round trip fixes everything).
//
// Checks run against the batch tenant — the envelope's tenant_id must
// match exactly. This is the cross-tenant-smuggling defence; without
// it a holder of one tenant's auth could attach events for another.
//
// What we do NOT check here:
//   - payload semantics (the inner SaleCreated/PaymentAdded shape).
//     The local-store-server is the producer of truth — re-validating
//     payload structure on the cloud would couple the schemas twice.
//   - signatures (SignedEnvelope is Phase 5+; auth is slice 3.5).
//   - replay across batches (handled by operation_id UNIQUE constraint
//     + ErrOperationConflict in store.go).
func validateOperation(op *posv1.Operation, batchTenant string) error {
	if op == nil {
		return fmt.Errorf("operation is nil")
	}

	var faults []string
	add := func(s string) { faults = append(faults, s) }

	opID := op.GetOperationId().GetValue()
	if opID == "" {
		add("operation_id is empty")
	} else if _, err := uuid.Parse(opID); err != nil {
		add(fmt.Sprintf("operation_id %q is not a UUID", opID))
	}

	if op.GetOperationType() == "" {
		add("operation_type is empty")
	}
	if op.GetEntityType() == "" {
		add("entity_type is empty")
	}
	if op.GetEntityId() == "" {
		add("entity_id is empty")
	}

	env := op.GetEnvelope()
	if env == nil {
		add("envelope is nil")
		return joinFaults(faults)
	}

	envOpID := env.GetOperationId().GetValue()
	if envOpID == "" {
		add("envelope.operation_id is empty")
	} else if opID != "" && envOpID != opID {
		add(fmt.Sprintf("envelope.operation_id %q != operation.operation_id %q",
			envOpID, opID))
	}

	if env.GetEventType() == "" {
		add("envelope.event_type is empty")
	} else if op.GetOperationType() != "" && env.GetEventType() != op.GetOperationType() {
		add(fmt.Sprintf("envelope.event_type %q != operation.operation_type %q",
			env.GetEventType(), op.GetOperationType()))
	}

	if env.GetSchemaVersion() == 0 {
		add("envelope.schema_version is zero")
	}

	envTenant := env.GetTenantId().GetValue()
	if envTenant == "" {
		add("envelope.tenant_id is empty")
	} else if envTenant != batchTenant {
		add(fmt.Sprintf("envelope.tenant_id %q != batch.tenant_id %q",
			envTenant, batchTenant))
	}

	if env.GetOrigin().GetNodeId() == "" {
		add("envelope.origin.node_id is empty")
	}
	if env.GetClock() == nil {
		add("envelope.clock is nil")
	}
	if env.GetOccurredAt() == nil {
		add("envelope.occurred_at is nil")
	}
	if env.GetPayload() == nil {
		add("envelope.payload oneof is unset")
	}

	return joinFaults(faults)
}

func joinFaults(faults []string) error {
	if len(faults) == 0 {
		return nil
	}
	return fmt.Errorf("%s", strings.Join(faults, "; "))
}
