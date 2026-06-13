// Package refunds owns the local projection for voids and refunds.
//
// A void is a same-shift, full reversal of a finalized sale. A refund is a
// post-finalization partial-or-full return of money to the customer that
// issues a credit-note. Both are layered on top of append-only events
// (SaleVoided / SaleRefunded) in operations_log; the rows in this package
// are local read projections used by receipts, reports, and the Service
// layer to enforce "cannot refund more than was sold" without re-reading
// the proto BLOB on every line.
//
// Issuance always happens inside the refunds.Service transactional batch
// — never standalone — so the opslog event, payment ledger row(s),
// inventory restoration row(s), and these projection rows commit together
// or not at all.
package refunds

import (
	"time"

	"github.com/google/uuid"

	"github.com/mibjas/pos-platform/apps/local-store-server/internal/payments"
)

// Void is one row of sale_voids. Snapshot holds canonical serialized
// pos.v1.SaleVoided bytes; SnapshotJSON is debug-only.
type Void struct {
	VoidID       uuid.UUID
	SaleID       uuid.UUID
	InvoiceID    uuid.UUID
	StoreID      string
	CounterID    string
	CashierID    string
	Reason       string
	Snapshot     []byte
	SnapshotJSON string
	VoidedAt     time.Time
	CreatedAt    time.Time
}

// Refund is one row of refunds. Subtotal/TaxTotal/GrandTotal are stored as
// non-negative magnitudes — the sign is implicit (a refund is always money
// out). Snapshot holds canonical serialized pos.v1.SaleRefunded bytes.
type Refund struct {
	RefundID         uuid.UUID
	SaleID           uuid.UUID
	InvoiceID        uuid.UUID
	CreditNoteNumber string // CN-YYYY-NNNNNN
	StoreID          string
	CounterID        string
	CashierID        string
	Reason           string

	Subtotal   payments.Money
	TaxTotal   payments.Money
	GrandTotal payments.Money

	Lines []RefundLine

	Snapshot     []byte
	SnapshotJSON string

	RefundedAt time.Time
	CreatedAt  time.Time
}

// RefundLine is one row of refund_lines. SaleLineID references the
// original SaleLine.LineID being (partially) refunded; Quantity is a
// positive magnitude.
type RefundLine struct {
	RefundID    uuid.UUID
	SaleLineID  uuid.UUID
	SKU         string
	Quantity    int64
	Restock     bool
	UnitPrice   payments.Money
	LineTotal   payments.Money
}
