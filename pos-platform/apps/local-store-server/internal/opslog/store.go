package opslog

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/google/uuid"
)

// Sentinel errors.
var (
	ErrNotFound     = errors.New("opslog: operation not found")
	ErrAlreadyAcked = errors.New("opslog: operation already acked")
)

// Store is the data-access layer for operations_log. It is safe for concurrent
// use — concurrent Inserts of the same OperationID are resolved atomically by
// the underlying UNIQUE constraint.
type Store struct {
	db *sql.DB
}

// NewStore wraps an *sql.DB that has had migrations applied (see db.RunMigrations).
func NewStore(sqlDB *sql.DB) *Store {
	return &Store{db: sqlDB}
}

// Insert appends an operation. It is idempotent: if op.OperationID already
// exists, Insert returns the existing row and idempotent=true. It never
// returns a duplicate-key error to the caller — duplicates are the expected
// happy path on sync retry (see docs/sync-rules.md).
//
// The inserted row always starts in StatusPending with retry_count=0 and
// batch_id=NULL, regardless of what the input op has for those fields.
func (s *Store) Insert(ctx context.Context, op Operation) (saved Operation, idempotent bool, err error) {
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return Operation{}, false, fmt.Errorf("opslog: begin: %w", err)
	}
	defer func() { _ = tx.Rollback() }()

	saved, idempotent, err = s.InsertTx(ctx, tx, op)
	if err != nil {
		return Operation{}, false, err
	}
	if err = tx.Commit(); err != nil {
		return Operation{}, false, fmt.Errorf("opslog: commit: %w", err)
	}
	return saved, idempotent, nil
}

// InsertTx is the *sql.Tx variant of Insert. Use it inside txn.Apply when
// the operation must persist atomically with rows in other tables (the
// common case for sale finalization — see docs/sync-rules.md "Batching").
func (s *Store) InsertTx(ctx context.Context, tx *sql.Tx, op Operation) (saved Operation, idempotent bool, err error) {
	if err := op.validate(); err != nil {
		return Operation{}, false, err
	}

	// BatchID is set at insert time when a caller wants to mark a group of
	// operations as one atomic batch (the SaleService does this for the
	// SaleCreated + InventoryAdjusted + PaymentAdded trio so they ship together).
	// uuid.Nil → leave batch_id NULL; the sync worker will assign one later.
	const insertSQL = `
		INSERT OR IGNORE INTO operations_log (
			operation_id, operation_type, entity_type, entity_id, payload,
			created_at, lamport, origin_node_id, sync_status, retry_count, last_error, batch_id
		) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'pending', 0, '', ?)
	`
	res, err := tx.ExecContext(ctx, insertSQL,
		op.OperationID.String(),
		op.OperationType,
		op.EntityType,
		op.EntityID,
		op.Payload,
		op.CreatedAt.UnixNano(),
		op.Lamport,
		op.OriginNodeID,
		nullableBatchID(op.BatchID),
	)
	if err != nil {
		return Operation{}, false, fmt.Errorf("opslog: insert: %w", err)
	}

	affected, err := res.RowsAffected()
	if err != nil {
		return Operation{}, false, fmt.Errorf("opslog: rows affected: %w", err)
	}
	idempotent = affected == 0

	// Fetch the canonical row inside the same tx (either the one we just
	// inserted, or the pre-existing one if this was a duplicate).
	saved, err = s.getTx(ctx, tx, op.OperationID)
	if err != nil {
		return Operation{}, false, fmt.Errorf("opslog: post-insert get: %w", err)
	}
	return saved, idempotent, nil
}

func (s *Store) getTx(ctx context.Context, tx *sql.Tx, operationID uuid.UUID) (Operation, error) {
	const q = `
		SELECT id, operation_id, operation_type, entity_type, entity_id, payload,
		       created_at, lamport, origin_node_id, sync_status, retry_count, last_error, batch_id
		FROM operations_log
		WHERE operation_id = ?
	`
	return scanOperation(tx.QueryRowContext(ctx, q, operationID.String()))
}

// Get fetches an operation by its OperationID. Returns ErrNotFound if missing.
func (s *Store) Get(ctx context.Context, operationID uuid.UUID) (Operation, error) {
	const q = `
		SELECT id, operation_id, operation_type, entity_type, entity_id, payload,
		       created_at, lamport, origin_node_id, sync_status, retry_count, last_error, batch_id
		FROM operations_log
		WHERE operation_id = ?
	`
	row := s.db.QueryRowContext(ctx, q, operationID.String())
	return scanOperation(row)
}

// ListByBatch returns every operation tagged with batchID, ordered by
// insertion id so consumers see them in the same sequence the producer
// wrote them. Returns an empty slice (not an error) when no rows match.
//
// Used by the realtime publisher (Phase 4 slice 4.2) after a successful
// txn.Apply commit: the service tags every event in one logical commit
// with the same batchID, then reads them back here and fans them out via
// the hub. Index-backed via idx_operations_log_batch.
func (s *Store) ListByBatch(ctx context.Context, batchID uuid.UUID) ([]Operation, error) {
	if batchID == uuid.Nil {
		return nil, errors.New("opslog: ListByBatch requires a non-nil batchID")
	}
	const q = `
		SELECT id, operation_id, operation_type, entity_type, entity_id, payload,
		       created_at, lamport, origin_node_id, sync_status, retry_count, last_error, batch_id
		FROM operations_log
		WHERE batch_id = ?
		ORDER BY id ASC
	`
	rows, err := s.db.QueryContext(ctx, q, batchID.String())
	if err != nil {
		return nil, fmt.Errorf("opslog: list by batch: %w", err)
	}
	defer rows.Close()

	var ops []Operation
	for rows.Next() {
		op, err := scanOperation(rows)
		if err != nil {
			return nil, err
		}
		ops = append(ops, op)
	}
	return ops, rows.Err()
}

// ListSince returns operations with lamport > sinceLamport, ordered by
// (lamport ASC, id ASC) so ties are broken deterministically. Capped at
// limit rows; limit <= 0 defaults to 100.
//
// Used by the WS reconnect catch-up path (slice 4.4): the client passes
// its last-seen Lamport, the server replays anything that landed after.
// No batch_id / sync_status filter — replay is about durable history,
// not the sync pipeline state.
func (s *Store) ListSince(ctx context.Context, sinceLamport uint64, limit int) ([]Operation, error) {
	if limit <= 0 {
		limit = 100
	}
	const q = `
		SELECT id, operation_id, operation_type, entity_type, entity_id, payload,
		       created_at, lamport, origin_node_id, sync_status, retry_count, last_error, batch_id
		FROM operations_log
		WHERE lamport > ?
		ORDER BY lamport ASC, id ASC
		LIMIT ?
	`
	rows, err := s.db.QueryContext(ctx, q, sinceLamport, limit)
	if err != nil {
		return nil, fmt.Errorf("opslog: list since: %w", err)
	}
	defer rows.Close()

	var ops []Operation
	for rows.Next() {
		op, err := scanOperation(rows)
		if err != nil {
			return nil, err
		}
		ops = append(ops, op)
	}
	return ops, rows.Err()
}

// ListPending returns up to limit operations in StatusPending, oldest first
// (by created_at, then id for ties). limit <= 0 defaults to 100.
//
// This is the hot path for the sync worker. It is index-backed via
// idx_operations_log_status_created.
func (s *Store) ListPending(ctx context.Context, limit int) ([]Operation, error) {
	if limit <= 0 {
		limit = 100
	}
	const q = `
		SELECT id, operation_id, operation_type, entity_type, entity_id, payload,
		       created_at, lamport, origin_node_id, sync_status, retry_count, last_error, batch_id
		FROM operations_log
		WHERE sync_status = 'pending'
		ORDER BY created_at ASC, id ASC
		LIMIT ?
	`
	rows, err := s.db.QueryContext(ctx, q, limit)
	if err != nil {
		return nil, fmt.Errorf("opslog: list pending: %w", err)
	}
	defer rows.Close()

	var ops []Operation
	for rows.Next() {
		op, err := scanOperation(rows)
		if err != nil {
			return nil, err
		}
		ops = append(ops, op)
	}
	return ops, rows.Err()
}

// MarkInFlight transitions the listed operations from pending to in_flight
// and stamps them with batchID. Operations not currently in 'pending' are
// silently skipped (already in-flight, acked, or failed). Returns the number
// of operations that actually transitioned.
//
// Partial transitions are intentional: the sync worker may pass a mix of
// pending + already-shipped ids and expects "do what you can".
func (s *Store) MarkInFlight(ctx context.Context, operationIDs []uuid.UUID, batchID uuid.UUID) (int64, error) {
	if len(operationIDs) == 0 {
		return 0, nil
	}
	if batchID == uuid.Nil {
		return 0, errors.New("opslog: MarkInFlight requires a non-nil batchID")
	}

	placeholders := strings.Repeat("?,", len(operationIDs))
	placeholders = placeholders[:len(placeholders)-1]

	args := make([]any, 0, len(operationIDs)+1)
	args = append(args, batchID.String())
	for _, id := range operationIDs {
		args = append(args, id.String())
	}

	q := fmt.Sprintf(`
		UPDATE operations_log
		SET sync_status = 'in_flight', batch_id = ?
		WHERE operation_id IN (%s) AND sync_status = 'pending'
	`, placeholders)

	res, err := s.db.ExecContext(ctx, q, args...)
	if err != nil {
		return 0, fmt.Errorf("opslog: mark in_flight: %w", err)
	}
	return res.RowsAffected()
}

// MarkAcked transitions the listed operations from in_flight to acked.
// Operations not currently in 'in_flight' are silently skipped.
func (s *Store) MarkAcked(ctx context.Context, operationIDs []uuid.UUID) (int64, error) {
	if len(operationIDs) == 0 {
		return 0, nil
	}

	placeholders := strings.Repeat("?,", len(operationIDs))
	placeholders = placeholders[:len(placeholders)-1]

	args := make([]any, 0, len(operationIDs))
	for _, id := range operationIDs {
		args = append(args, id.String())
	}

	q := fmt.Sprintf(`
		UPDATE operations_log
		SET sync_status = 'acked'
		WHERE operation_id IN (%s) AND sync_status = 'in_flight'
	`, placeholders)

	res, err := s.db.ExecContext(ctx, q, args...)
	if err != nil {
		return 0, fmt.Errorf("opslog: mark acked: %w", err)
	}
	return res.RowsAffected()
}

// MarkRetry transitions the listed operations from 'in_flight' back to
// 'pending', increments their retry_count, PRESERVES their batch_id,
// and records lastError. Use this after a transient transport failure —
// the next sync pass will pick them up and re-ship them under the SAME
// batch_id so the cloud's idempotency dedup (slice 3.1) fires correctly.
//
// Why preserve batch_id: the cloud applies a batch atomically and dedups
// on batch_id. A dropped response means the cloud may have committed
// while we never saw the ack; retrying under the SAME batch_id lets the
// cloud reply STATUS_DUPLICATE (success). Re-batching the same op_ids
// under a fresh batch_id would instead trigger an op_id-conflict
// rejection — the chaos test (slice 3.6) caught this case.
//
// Operations not currently in 'in_flight' are silently skipped (same
// "do what you can" posture as MarkInFlight / MarkAcked).
func (s *Store) MarkRetry(ctx context.Context, operationIDs []uuid.UUID, lastError string) (int64, error) {
	if len(operationIDs) == 0 {
		return 0, nil
	}
	placeholders := strings.Repeat("?,", len(operationIDs))
	placeholders = placeholders[:len(placeholders)-1]

	args := make([]any, 0, len(operationIDs)+1)
	args = append(args, lastError)
	for _, id := range operationIDs {
		args = append(args, id.String())
	}

	q := fmt.Sprintf(`
		UPDATE operations_log
		SET sync_status = 'pending',
		    retry_count = retry_count + 1,
		    last_error  = ?
		WHERE operation_id IN (%s) AND sync_status = 'in_flight'
	`, placeholders)

	res, err := s.db.ExecContext(ctx, q, args...)
	if err != nil {
		return 0, fmt.Errorf("opslog: mark retry: %w", err)
	}
	return res.RowsAffected()
}

// MarkFailed moves an operation to the terminal 'failed' state, increments
// retry_count, and records lastError. Refuses to overwrite an already-acked
// operation — that would silently undo a confirmed sync.
//
// This is the terminal failure marker (max retries exceeded or permanent
// error). For transient failures the sync engine uses MarkRetry instead.
func (s *Store) MarkFailed(ctx context.Context, operationID uuid.UUID, lastError string) error {
	res, err := s.db.ExecContext(ctx, `
		UPDATE operations_log
		SET sync_status = 'failed',
		    retry_count = retry_count + 1,
		    last_error  = ?
		WHERE operation_id = ? AND sync_status != 'acked'
	`, lastError, operationID.String())
	if err != nil {
		return fmt.Errorf("opslog: mark failed: %w", err)
	}
	affected, err := res.RowsAffected()
	if err != nil {
		return fmt.Errorf("opslog: rows affected: %w", err)
	}
	if affected == 0 {
		// Either the op doesn't exist or it's already acked. Distinguish.
		if _, getErr := s.Get(ctx, operationID); errors.Is(getErr, ErrNotFound) {
			return ErrNotFound
		}
		return ErrAlreadyAcked
	}
	return nil
}

// --- internal ---

func nullableBatchID(u uuid.UUID) any {
	if u == uuid.Nil {
		return nil
	}
	return u.String()
}

type rowScanner interface {
	Scan(dest ...any) error
}

func scanOperation(row rowScanner) (Operation, error) {
	var (
		op          Operation
		opIDStr     string
		createdAtNs int64
		statusStr   string
		batchIDStr  sql.NullString
	)
	err := row.Scan(
		&op.ID,
		&opIDStr,
		&op.OperationType,
		&op.EntityType,
		&op.EntityID,
		&op.Payload,
		&createdAtNs,
		&op.Lamport,
		&op.OriginNodeID,
		&statusStr,
		&op.RetryCount,
		&op.LastError,
		&batchIDStr,
	)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return Operation{}, ErrNotFound
		}
		return Operation{}, fmt.Errorf("opslog: scan: %w", err)
	}

	op.OperationID, err = uuid.Parse(opIDStr)
	if err != nil {
		return Operation{}, fmt.Errorf("opslog: parse operation_id %q: %w", opIDStr, err)
	}
	op.CreatedAt = time.Unix(0, createdAtNs).UTC()
	op.SyncStatus = SyncStatus(statusStr)
	if batchIDStr.Valid && batchIDStr.String != "" {
		op.BatchID, err = uuid.Parse(batchIDStr.String)
		if err != nil {
			return Operation{}, fmt.Errorf("opslog: parse batch_id %q: %w", batchIDStr.String, err)
		}
	}
	return op, nil
}
