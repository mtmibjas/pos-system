// Package inventory is the data layer for the append-only inventory ledger
// (inventory_movements).
//
// Stock-on-hand is DERIVED from the ledger, never stored directly. See
// docs/inventory-rules.md for the canonical rules.
package inventory

import (
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
)

// Reason identifies why a movement happened. Mirrors the CHECK in the migration.
type Reason string

const (
	ReasonSale        Reason = "sale"
	ReasonReceive     Reason = "receive"
	ReasonTransferIn  Reason = "transfer_in"
	ReasonTransferOut Reason = "transfer_out"
	ReasonStockTake   Reason = "stock_take"
	ReasonShrinkage   Reason = "shrinkage"
	ReasonRefund      Reason = "refund"
	ReasonVoid        Reason = "void"
)

func (r Reason) Valid() bool {
	switch r {
	case ReasonSale, ReasonReceive, ReasonTransferIn, ReasonTransferOut,
		ReasonStockTake, ReasonShrinkage, ReasonRefund, ReasonVoid:
		return true
	}
	return false
}

// Movement is one row of inventory_movements. Schema is locked in
// docs/inventory-rules.md and the 000002 migration.
type Movement struct {
	ID           int64     // local autoincrement; zero on input
	MovementID   uuid.UUID // UUID; UNIQUE; required
	SKU          string
	StoreID      string
	CounterID    string    // optional (empty = store-level event)
	Delta        int64     // never zero; negative for sales, positive for receives
	Reason       Reason
	RefType      string    // 'sale' | 'transfer' | 'stock_take' | 'refund' | 'void'
	RefID        string
	OccurredAt   time.Time
	Lamport      uint64
	OriginNodeID string

	// Voiding fields — set by VoidMovement on the original row when a
	// reversal is appended. Untouched on a fresh movement.
	VoidedAt   time.Time // zero unless voided
	VoidedByID uuid.UUID // uuid.Nil unless voided
}

func (m Movement) validate() error {
	if m.MovementID == uuid.Nil {
		return errors.New("inventory: MovementID is required")
	}
	if m.SKU == "" {
		return errors.New("inventory: SKU is required")
	}
	if m.StoreID == "" {
		return errors.New("inventory: StoreID is required")
	}
	if m.Delta == 0 {
		return errors.New("inventory: Delta must be non-zero")
	}
	if !m.Reason.Valid() {
		return fmt.Errorf("inventory: invalid Reason %q", m.Reason)
	}
	if m.RefType == "" {
		return errors.New("inventory: RefType is required")
	}
	if m.RefID == "" {
		return errors.New("inventory: RefID is required")
	}
	if m.OccurredAt.IsZero() {
		return errors.New("inventory: OccurredAt is required")
	}
	if m.OriginNodeID == "" {
		return errors.New("inventory: OriginNodeID is required")
	}
	return nil
}

// OversellError is returned when a negative-delta movement would drive
// stock-on-hand below zero and the store has not opted into allow_oversell.
type OversellError struct {
	SKU     string
	StoreID string
	Have    int64 // current stock-on-hand
	Want    int64 // absolute value of the requested decrement
}

func (e *OversellError) Error() string {
	return fmt.Sprintf("inventory: oversell rejected: sku=%s store=%s have=%d want=%d",
		e.SKU, e.StoreID, e.Have, e.Want)
}
