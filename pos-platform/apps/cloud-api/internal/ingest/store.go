// Package ingest is the cloud's batch-acceptance core.
//
// Apply is the single entry point: it takes a decoded SyncBatch and
// commits the batch row + its operations in one transaction. Idempotent
// on batch_id — a retried POST returns STATUS_DUPLICATE without
// re-writing anything.
//
// What this package does NOT do:
//   - HTTP / proto wire framing (cloudhttp handler wraps it)
//   - per-operation validation beyond what the DB enforces (slice 3.2
//     adds payload + tenant validation)
//   - authentication (slice 3.5 adds JWT middleware in front)
//
// The intent is for Apply to stay synchronous, deterministic, and easy
// to fuzz from tests. Failure modes:
//   - context cancelled → returns ctx.Err()
//   - missing/empty batch_id → ErrEmptyBatchID (caller maps to HTTP 400)
//   - operation_id conflict against an existing batch → ErrOperationConflict
//   - any other DB error → wrapped with context for the slog line
package ingest

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"strings"
	"time"

	"google.golang.org/protobuf/proto"

	posv1 "github.com/mibjas/pos-platform/packages/sdk-go/gen/pos/v1"
)

// Sentinel errors. Callers (HTTP handler, tests) match these with
// errors.Is to choose the right ack status / HTTP code.
var (
	// ErrEmptyBatchID — the SyncBatch arrived with batch_id == "".
	// HTTP layer maps this to 400 Bad Request.
	ErrEmptyBatchID = errors.New("ingest: batch_id is required")

	// ErrEmptyTenant — tenant_id missing on the wire. We require it
	// even before JWT auth lands (slice 3.5) because the batch is
	// tenant-scoped and unscoped writes would corrupt the read-side.
	ErrEmptyTenant = errors.New("ingest: tenant_id is required")

	// ErrOperationConflict — a freshly-presented operation_id is
	// already attached to a *different* batch. This is a contract
	// violation by the sender (operation_ids should be unique forever)
	// and surfaces as STATUS_REJECTED. We choose REJECTED rather than
	// silently merging because the cloud is the source of truth on
	// what's already accepted.
	ErrOperationConflict = errors.New("ingest: operation_id belongs to a different batch")
)

// Result is what Apply returns to the HTTP layer. Status follows the
// SyncBatchAck.Status enum semantics (Applied | Duplicate | Rejected).
// Per-operation acks are populated on the rejected path so the client
// can isolate the failing row instead of stalling the whole queue.
type Result struct {
	Status        posv1.SyncBatchAck_Status
	Message       string
	OperationAcks []*posv1.OperationAck
}

// Store wraps the cloud's *sql.DB and a clock for testable timestamps.
type Store struct {
	db  *sql.DB
	now func() time.Time
}

// NewStore wires a Store around an already-migrated *sql.DB. now may
// be nil — falls back to time.Now in UTC.
func NewStore(sqlDB *sql.DB, now func() time.Time) *Store {
	if sqlDB == nil {
		panic("ingest: NewStore requires a non-nil *sql.DB")
	}
	if now == nil {
		now = func() time.Time { return time.Now().UTC() }
	}
	return &Store{db: sqlDB, now: now}
}

// Apply persists a batch atomically. Re-presenting the same batch_id
// short-circuits to {Status: DUPLICATE}; no rows are touched.
func (s *Store) Apply(ctx context.Context, batch *posv1.SyncBatch) (Result, error) {
	if batch == nil {
		return Result{}, errors.New("ingest: batch is nil")
	}
	if batch.GetBatchId() == "" {
		return Result{}, ErrEmptyBatchID
	}
	tenant := batch.GetTenantId().GetValue()
	if tenant == "" {
		return Result{}, ErrEmptyTenant
	}

	// Fast-path duplicate check — saves opening a write txn for retries
	// that are already on disk.
	if seen, err := s.exists(ctx, batch.GetBatchId()); err != nil {
		return Result{}, err
	} else if seen {
		return Result{Status: posv1.SyncBatchAck_STATUS_DUPLICATE}, nil
	}

	// Per-operation validation (slice 3.2). Runs before BeginTx so an
	// invalid batch doesn't burn a write transaction. All faults across
	// all ops are collected so the sender fixes them in one round trip
	// instead of N rejections in a row.
	if acks := validateBatch(batch); len(acks) > 0 {
		return Result{
			Status:        posv1.SyncBatchAck_STATUS_REJECTED,
			Message:       fmt.Sprintf("%d operation(s) failed validation", len(acks)),
			OperationAcks: acks,
		}, nil
	}

	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return Result{}, fmt.Errorf("ingest: begin: %w", err)
	}
	defer func() { _ = tx.Rollback() }() // no-op after Commit

	receivedAt := s.now().UnixNano()

	// Lose the race? Some other concurrent POST landed the same
	// batch_id between our exists() check and BeginTx. The INSERT
	// below will hit the PK constraint and we'll classify it as
	// duplicate without rolling forward.
	_, err = tx.ExecContext(ctx, `
		INSERT INTO applied_batches (batch_id, tenant_id, operation_count, applied_at_unix_ns)
		VALUES (?, ?, ?, ?)
	`, batch.GetBatchId(), tenant, len(batch.GetOperations()), receivedAt)
	if err != nil {
		if isUniqueBatchViolation(err) {
			return Result{Status: posv1.SyncBatchAck_STATUS_DUPLICATE}, nil
		}
		return Result{}, fmt.Errorf("ingest: insert batch: %w", err)
	}

	for i, op := range batch.GetOperations() {
		if err := s.insertOperation(ctx, tx, batch.GetBatchId(), tenant, op, receivedAt); err != nil {
			if errors.Is(err, ErrOperationConflict) {
				return Result{
					Status:  posv1.SyncBatchAck_STATUS_REJECTED,
					Message: fmt.Sprintf("operation[%d]: %s", i, err.Error()),
					OperationAcks: []*posv1.OperationAck{{
						OperationId: op.GetOperationId(),
						Status:      posv1.SyncBatchAck_STATUS_REJECTED,
						Error:       err.Error(),
					}},
				}, nil
			}
			return Result{}, fmt.Errorf("ingest: insert operation[%d]: %w", i, err)
		}
	}

	if err := tx.Commit(); err != nil {
		return Result{}, fmt.Errorf("ingest: commit: %w", err)
	}
	return Result{Status: posv1.SyncBatchAck_STATUS_APPLIED}, nil
}

func (s *Store) exists(ctx context.Context, batchID string) (bool, error) {
	var dummy string
	err := s.db.QueryRowContext(ctx,
		`SELECT batch_id FROM applied_batches WHERE batch_id = ?`,
		batchID,
	).Scan(&dummy)
	if errors.Is(err, sql.ErrNoRows) {
		return false, nil
	}
	if err != nil {
		return false, fmt.Errorf("ingest: exists: %w", err)
	}
	return true, nil
}

func (s *Store) insertOperation(
	ctx context.Context,
	tx *sql.Tx,
	batchID, tenant string,
	op *posv1.Operation,
	receivedAt int64,
) error {
	if op == nil {
		return errors.New("operation: nil")
	}
	opID := op.GetOperationId().GetValue()
	if opID == "" {
		return errors.New("operation: operation_id is empty")
	}
	payload, err := proto.Marshal(op.GetEnvelope())
	if err != nil {
		return fmt.Errorf("marshal envelope: %w", err)
	}

	occurredAt := int64(0)
	if env := op.GetEnvelope(); env != nil && env.GetOccurredAt() != nil {
		occurredAt = env.GetOccurredAt().AsTime().UnixNano()
	}
	lamport := int64(0)
	if env := op.GetEnvelope(); env != nil && env.GetClock() != nil {
		lamport = int64(env.GetClock().GetCounter())
	}
	originNode := ""
	if op.GetOrigin() != nil {
		originNode = op.GetOrigin().GetNodeId()
	}

	_, err = tx.ExecContext(ctx, `
		INSERT INTO events (
			operation_id, batch_id, tenant_id,
			operation_type, entity_type, entity_id,
			payload, lamport, origin_node_id,
			occurred_at_unix_ns, received_at_unix_ns
		) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
	`,
		opID, batchID, tenant,
		op.GetOperationType(), op.GetEntityType(), op.GetEntityId(),
		payload, lamport, originNode,
		occurredAt, receivedAt,
	)
	if err != nil {
		if isUniqueOperationViolation(err) {
			// Was this operation_id ever attached to a different batch?
			var existingBatch string
			lookupErr := tx.QueryRowContext(ctx,
				`SELECT batch_id FROM events WHERE operation_id = ?`,
				opID,
			).Scan(&existingBatch)
			if lookupErr == nil && existingBatch != batchID {
				return ErrOperationConflict
			}
			// Same batch_id already wrote this op — shouldn't happen given the
			// batch-level dedupe above, but treat it as benign.
			return nil
		}
		return fmt.Errorf("insert event: %w", err)
	}
	return nil
}

// Event is the read-side projection of a row in `events`. Returned
// from List in lamport+id order, scoped to a single tenant. Payload
// is the serialized EventEnvelope (callers proto.Unmarshal it before
// inspecting business fields).
type Event struct {
	ID               int64
	OperationID      string
	BatchID          string
	TenantID         string
	OperationType    string
	EntityType       string
	EntityID         string
	Payload          []byte
	Lamport          int64
	OriginNodeID     string
	OccurredAtUnixNs int64
	ReceivedAtUnixNs int64
}

// Default and ceiling for List. The ceiling is enforced server-side
// so a misconfigured client can't pull the whole tenant history in
// one request.
const (
	DefaultListLimit = 100
	MaxListLimit     = 1000
)

// List returns up to limit events for tenant strictly after the
// cursor, ordered by (lamport, id). The returned next-cursor points
// at the last row of this page; when the page is short of limit the
// next cursor is the zero Cursor (caller encodes that as "" → end
// of stream).
//
// limit is clamped: <=0 → DefaultListLimit; > MaxListLimit → MaxListLimit.
func (s *Store) List(ctx context.Context, tenant string, after Cursor, limit int) ([]Event, Cursor, error) {
	if tenant == "" {
		return nil, Cursor{}, errors.New("ingest: list: tenant is empty")
	}
	if limit <= 0 {
		limit = DefaultListLimit
	}
	if limit > MaxListLimit {
		limit = MaxListLimit
	}

	// Row-value comparison ( (lamport, id) > (?, ?) ) is supported by
	// both SQLite (>= 3.15) and Postgres — keeps this query portable
	// for the eventual Postgres swap. Fetch limit+1 so we can tell
	// whether more rows exist without a second query.
	const q = `
		SELECT id, operation_id, batch_id, tenant_id,
		       operation_type, entity_type, entity_id,
		       payload, lamport, origin_node_id,
		       occurred_at_unix_ns, received_at_unix_ns
		  FROM events
		 WHERE tenant_id = ?
		   AND (lamport > ? OR (lamport = ? AND id > ?))
		 ORDER BY lamport ASC, id ASC
		 LIMIT ?
	`
	rows, err := s.db.QueryContext(ctx, q,
		tenant, after.Lamport, after.Lamport, after.ID, limit+1,
	)
	if err != nil {
		return nil, Cursor{}, fmt.Errorf("ingest: list query: %w", err)
	}
	defer rows.Close()

	out := make([]Event, 0, limit+1)
	for rows.Next() {
		var e Event
		if err := rows.Scan(
			&e.ID, &e.OperationID, &e.BatchID, &e.TenantID,
			&e.OperationType, &e.EntityType, &e.EntityID,
			&e.Payload, &e.Lamport, &e.OriginNodeID,
			&e.OccurredAtUnixNs, &e.ReceivedAtUnixNs,
		); err != nil {
			return nil, Cursor{}, fmt.Errorf("ingest: list scan: %w", err)
		}
		out = append(out, e)
	}
	if err := rows.Err(); err != nil {
		return nil, Cursor{}, fmt.Errorf("ingest: list iterate: %w", err)
	}

	// We fetched one extra row as an end-of-stream probe. If it's there,
	// trim it off and emit a next cursor pointing at the last kept row.
	// Otherwise the page is final → zero cursor.
	var next Cursor
	if len(out) > limit {
		out = out[:limit]
		last := out[len(out)-1]
		next = Cursor{Lamport: last.Lamport, ID: last.ID}
	}
	return out, next, nil
}

// SQLite reports UNIQUE constraint violations in the error message;
// we match by substring rather than depend on driver-specific extended
// codes (keeps this driver-agnostic per Postgres migration plan).

func isUniqueBatchViolation(err error) bool {
	if err == nil {
		return false
	}
	msg := err.Error()
	return strings.Contains(msg, "UNIQUE") && strings.Contains(msg, "applied_batches")
}

func isUniqueOperationViolation(err error) bool {
	if err == nil {
		return false
	}
	msg := err.Error()
	return strings.Contains(msg, "UNIQUE") && strings.Contains(msg, "events.operation_id")
}
