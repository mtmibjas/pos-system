// Package opslog is the data layer for the append-only operations_log.
//
// Every state-changing thing the local-store-server does is first written here
// as an Operation, then later shipped to the cloud by the sync engine. This is
// the heart of the system (Development Guide §1 rule 10).
//
// See docs/sync-rules.md for the canonical schema + idempotency contract.
package opslog

import (
	"errors"
	"time"

	"github.com/google/uuid"
)

// SyncStatus is the lifecycle of an Operation as far as the cloud is concerned.
type SyncStatus string

const (
	StatusPending  SyncStatus = "pending"   // queued, not yet sent
	StatusInFlight SyncStatus = "in_flight" // included in an in-progress batch
	StatusAcked    SyncStatus = "acked"     // cloud confirmed (APPLIED or DUPLICATE)
	StatusFailed   SyncStatus = "failed"    // terminal — gave up after max retries or permanent error
)

// Valid reports whether s is one of the known statuses.
func (s SyncStatus) Valid() bool {
	switch s {
	case StatusPending, StatusInFlight, StatusAcked, StatusFailed:
		return true
	}
	return false
}

// Operation is one row of operations_log.
//
// Schema is locked in docs/sync-rules.md — do not change without updating
// that doc and the migration.
type Operation struct {
	// ID is the local autoincrement PK. Zero on inputs; populated on reads.
	// Used only for local ordering; never sent to the cloud.
	ID int64

	// OperationID is the UUID used for idempotency. REQUIRED on Insert.
	OperationID uuid.UUID

	// OperationType mirrors event_type (e.g. "sale_created").
	OperationType string

	// EntityType is the category of thing being mutated ("sale", "payment",
	// "inventory", …). EntityID identifies the specific instance — a UUID
	// for sales/payments, a SKU for inventory.
	EntityType string
	EntityID   string

	// Payload is the serialized EventEnvelope (Protobuf bytes). Opaque to
	// this layer — we never parse it here.
	Payload []byte

	// CreatedAt is the wall-clock at origin. Lamport is what we order by;
	// CreatedAt is for human diagnostics only (see docs/sync-rules.md clock drift).
	CreatedAt time.Time
	Lamport   uint64

	// OriginNodeID is the stable per-device install id (UUID-ish string).
	OriginNodeID string

	// SyncStatus is set to StatusPending on Insert. Subsequent state changes
	// go through MarkInFlight / MarkAcked / MarkFailed.
	SyncStatus SyncStatus

	// RetryCount bumps on each failed attempt; LastError records the most
	// recent failure for diagnostics.
	RetryCount int
	LastError  string

	// BatchID is uuid.Nil until the operation is included in a sync batch.
	BatchID uuid.UUID
}

// validate runs cheap input checks before we hit the DB.
func (o Operation) validate() error {
	if o.OperationID == uuid.Nil {
		return errors.New("opslog: OperationID is required")
	}
	if o.OperationType == "" {
		return errors.New("opslog: OperationType is required")
	}
	if o.EntityType == "" {
		return errors.New("opslog: EntityType is required")
	}
	if o.EntityID == "" {
		return errors.New("opslog: EntityID is required")
	}
	if len(o.Payload) == 0 {
		return errors.New("opslog: Payload is required")
	}
	if o.OriginNodeID == "" {
		return errors.New("opslog: OriginNodeID is required")
	}
	if o.CreatedAt.IsZero() {
		return errors.New("opslog: CreatedAt is required")
	}
	return nil
}
