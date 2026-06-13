// Package reservations implements soft inventory holds — Phase 4 slice
// 4.3. A reservation says "counter X has Y units of SKU Z in-cart" and
// participates in inventory.Available so a second counter cannot oversell
// the same physical unit.
//
// Reservations are intra-store coordination only:
//
//   - never reach the cloud / opslog / EventEnvelope
//   - never produce inventory_movements
//   - have a hard TTL (default 5min); expired ones are dropped lazily on
//     the next Available read (slice 4.3 ships without a background
//     sweeper; can land later if operationally needed)
//   - are consumed atomically by SaleService.Finalize via
//     ReservationIDs, in the same txn.Apply as the sale, so the 5-min
//     false-depletion window after the sale commits does not happen.
//
// Realtime: every status transition emits an inventory_available_changed
// JSON frame over the hub so other counters' live tiles refresh.
package reservations

import (
	"errors"
	"time"

	"github.com/google/uuid"
)

// Status is the reservation lifecycle.
type Status string

const (
	StatusActive    Status = "active"
	StatusReleased  Status = "released"  // counter cancelled the cart
	StatusFinalized Status = "finalized" // consumed by a sale
	StatusExpired   Status = "expired"   // TTL elapsed
)

// DefaultTTL is the per-reservation hold window. See Phase 4 design notes.
const DefaultTTL = 5 * time.Minute

// Reservation is one row of inventory_reservations.
type Reservation struct {
	ID        uuid.UUID
	SKU       string
	StoreID   string
	CounterID string
	Quantity  int64
	CreatedAt time.Time
	ExpiresAt time.Time
	Status    Status
}

// ErrNotFound is returned by lookups that hit no row.
var ErrNotFound = errors.New("reservations: not found")

// ErrNotActive is returned when a transition requires status=active but
// the row is already terminal (released/finalized/expired).
var ErrNotActive = errors.New("reservations: not active")

// ErrInsufficientAvailable is returned when Reserve would push available
// stock below zero. Carries the same shape as inventory.OversellError so
// callers can render a consistent "out of stock" message.
type ErrInsufficientAvailable struct {
	SKU       string
	StoreID   string
	Available int64 // current available (on_hand - active reservations)
	Requested int64
}

func (e *ErrInsufficientAvailable) Error() string {
	return "reservations: insufficient available: sku=" + e.SKU +
		" store=" + e.StoreID
}
