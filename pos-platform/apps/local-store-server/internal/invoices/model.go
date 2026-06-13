// Package invoices owns the local invoice projection.
//
// An invoice is a denormalized, immutable read model of a finalized sale.
// It is NOT a synced entity — the cloud reconstructs its own invoices from
// the SaleCreated operations in operations_log. We keep one here so the
// local server can render receipts, look up sales by human-facing
// invoice_number, and provide a stable reference target for refunds
// (Slice 2.4).
//
// Issuance is always done inside a SaleService.Finalize transaction via
// Store.IssueTx — never in isolation. The sale, the ops, the ledger rows,
// and the invoice all commit together or not at all.
package invoices

import (
	"time"

	"github.com/google/uuid"

	"github.com/mibjas/pos-platform/apps/local-store-server/internal/payments"
)

// Invoice is one row of the invoices table.
//
// Snapshot holds the canonical serialized pos.v1.SaleCreated proto bytes;
// SnapshotJSON is a debug-only preview written alongside the bytes and is
// never read by code. The application reads Snapshot when it needs the
// detail and uses the indexed top-level columns for queries.
type Invoice struct {
	InvoiceID     uuid.UUID
	SaleID        uuid.UUID
	InvoiceNumber string // INV-YYYY-NNNNNN
	StoreID       string
	CounterID     string
	CashierID     string

	Subtotal   payments.Money
	TaxTotal   payments.Money
	GrandTotal payments.Money

	Snapshot     []byte // canonical proto bytes
	SnapshotJSON string // debug-only preview

	FinalizedAt time.Time // from SaleCreated.occurred_at
	CreatedAt   time.Time // when this row was written
}
