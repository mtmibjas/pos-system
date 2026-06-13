package refunds

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/google/uuid"
	"google.golang.org/protobuf/encoding/protojson"
	"google.golang.org/protobuf/proto"

	"github.com/mibjas/pos-platform/apps/local-store-server/internal/payments"
)

// Store is the data-access layer for the voids + refunds projections.
//
// tz is the store's local timezone. Credit-note year is derived from
// RefundedAt.In(tz).Year() — CN-2026-* rolls at local midnight.
type Store struct {
	db *sql.DB
	tz *time.Location
}

// NewStore returns a Store. If tz is nil, UTC is used.
func NewStore(sqlDB *sql.DB, tz *time.Location) *Store {
	if tz == nil {
		tz = time.UTC
	}
	return &Store{db: sqlDB, tz: tz}
}

// IssueVoidRequest is the input to IssueVoidTx.
//
// Snapshot is the canonical pos.v1.SaleVoided proto; the store serializes
// it once for the BLOB column and renders a JSON preview for debug.
type IssueVoidRequest struct {
	VoidID    uuid.UUID
	SaleID    uuid.UUID
	InvoiceID uuid.UUID
	StoreID   string
	CounterID string
	CashierID string
	Reason    string
	Snapshot  proto.Message
	VoidedAt  time.Time
}

// IssueVoidTx writes one void row inside an open transaction. Returns
// ErrAlreadyVoided on UNIQUE(sale_id) collision so the caller can decide
// whether that constitutes idempotent replay or a programming bug.
func (s *Store) IssueVoidTx(ctx context.Context, tx *sql.Tx, req IssueVoidRequest) (Void, error) {
	if err := s.validateVoid(req); err != nil {
		return Void{}, err
	}

	snapBytes, err := proto.Marshal(req.Snapshot)
	if err != nil {
		return Void{}, fmt.Errorf("refunds: marshal void snapshot: %w", err)
	}
	snapJSON, err := protojson.MarshalOptions{
		UseProtoNames:   true,
		EmitUnpopulated: true,
	}.Marshal(req.Snapshot)
	if err != nil {
		return Void{}, fmt.Errorf("refunds: marshal void snapshot json: %w", err)
	}
	createdAt := time.Now().UTC()

	const insertSQL = `
		INSERT INTO sale_voids (
			void_id, sale_id, invoice_id, store_id, counter_id, cashier_id,
			reason, snapshot, snapshot_json, voided_at_unix_ns, created_at_unix_ns
		) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
	`
	_, err = tx.ExecContext(ctx, insertSQL,
		req.VoidID.String(),
		req.SaleID.String(),
		req.InvoiceID.String(),
		req.StoreID,
		req.CounterID,
		req.CashierID,
		req.Reason,
		snapBytes,
		string(snapJSON),
		req.VoidedAt.UnixNano(),
		createdAt.UnixNano(),
	)
	if err != nil {
		if isUniqueSaleViolation(err, "sale_voids.sale_id") {
			return Void{}, ErrAlreadyVoided
		}
		return Void{}, fmt.Errorf("refunds: insert void: %w", err)
	}

	return Void{
		VoidID:       req.VoidID,
		SaleID:       req.SaleID,
		InvoiceID:    req.InvoiceID,
		StoreID:      req.StoreID,
		CounterID:    req.CounterID,
		CashierID:    req.CashierID,
		Reason:       req.Reason,
		Snapshot:     snapBytes,
		SnapshotJSON: string(snapJSON),
		VoidedAt:     req.VoidedAt,
		CreatedAt:    createdAt,
	}, nil
}

// IssueRefundRequest is the input to IssueRefundTx.
type IssueRefundRequest struct {
	RefundID   uuid.UUID
	SaleID     uuid.UUID
	InvoiceID  uuid.UUID
	StoreID    string
	CounterID  string
	CashierID  string
	Reason     string

	Subtotal   payments.Money
	TaxTotal   payments.Money
	GrandTotal payments.Money

	Lines      []RefundLine

	Snapshot   proto.Message
	RefundedAt time.Time
}

// IssueRefundTx writes one refund row + its refund_lines inside an open
// transaction. Allocates the next per-store-per-year credit-note sequence.
func (s *Store) IssueRefundTx(ctx context.Context, tx *sql.Tx, req IssueRefundRequest) (Refund, error) {
	if err := s.validateRefund(req); err != nil {
		return Refund{}, err
	}

	year := req.RefundedAt.In(s.tz).Year()
	seq, err := s.nextCNSeq(ctx, tx, req.StoreID, year)
	if err != nil {
		return Refund{}, fmt.Errorf("refunds: allocate cn sequence: %w", err)
	}
	creditNoteNumber := fmt.Sprintf("CN-%04d-%06d", year, seq)

	snapBytes, err := proto.Marshal(req.Snapshot)
	if err != nil {
		return Refund{}, fmt.Errorf("refunds: marshal refund snapshot: %w", err)
	}
	snapJSON, err := protojson.MarshalOptions{
		UseProtoNames:   true,
		EmitUnpopulated: true,
	}.Marshal(req.Snapshot)
	if err != nil {
		return Refund{}, fmt.Errorf("refunds: marshal refund snapshot json: %w", err)
	}
	createdAt := time.Now().UTC()

	const insertRefund = `
		INSERT INTO refunds (
			refund_id, sale_id, invoice_id, credit_note_number, store_id, counter_id, cashier_id,
			reason, currency_code,
			subtotal_units, subtotal_nanos,
			tax_total_units, tax_total_nanos,
			grand_total_units, grand_total_nanos,
			snapshot, snapshot_json,
			refunded_at_unix_ns, created_at_unix_ns
		) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
	`
	_, err = tx.ExecContext(ctx, insertRefund,
		req.RefundID.String(),
		req.SaleID.String(),
		req.InvoiceID.String(),
		creditNoteNumber,
		req.StoreID,
		req.CounterID,
		req.CashierID,
		req.Reason,
		req.GrandTotal.CurrencyCode,
		req.Subtotal.Units, req.Subtotal.Nanos,
		req.TaxTotal.Units, req.TaxTotal.Nanos,
		req.GrandTotal.Units, req.GrandTotal.Nanos,
		snapBytes,
		string(snapJSON),
		req.RefundedAt.UnixNano(),
		createdAt.UnixNano(),
	)
	if err != nil {
		return Refund{}, fmt.Errorf("refunds: insert refund: %w", err)
	}

	const insertLine = `
		INSERT INTO refund_lines (
			refund_id, sale_line_id, sku, quantity, restock,
			unit_price_units, unit_price_nanos,
			line_total_units, line_total_nanos,
			currency_code
		) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
	`
	outLines := make([]RefundLine, 0, len(req.Lines))
	for _, ln := range req.Lines {
		restock := 0
		if ln.Restock {
			restock = 1
		}
		_, err := tx.ExecContext(ctx, insertLine,
			req.RefundID.String(),
			ln.SaleLineID.String(),
			ln.SKU,
			ln.Quantity,
			restock,
			ln.UnitPrice.Units, ln.UnitPrice.Nanos,
			ln.LineTotal.Units, ln.LineTotal.Nanos,
			ln.LineTotal.CurrencyCode,
		)
		if err != nil {
			return Refund{}, fmt.Errorf("refunds: insert refund_line %s: %w", ln.SaleLineID, err)
		}
		ln.RefundID = req.RefundID
		outLines = append(outLines, ln)
	}

	return Refund{
		RefundID:         req.RefundID,
		SaleID:           req.SaleID,
		InvoiceID:        req.InvoiceID,
		CreditNoteNumber: creditNoteNumber,
		StoreID:          req.StoreID,
		CounterID:        req.CounterID,
		CashierID:        req.CashierID,
		Reason:           req.Reason,
		Subtotal:         req.Subtotal,
		TaxTotal:         req.TaxTotal,
		GrandTotal:       req.GrandTotal,
		Lines:            outLines,
		Snapshot:         snapBytes,
		SnapshotJSON:     string(snapJSON),
		RefundedAt:       req.RefundedAt,
		CreatedAt:        createdAt,
	}, nil
}

// GetVoidBySale returns the void row for a sale_id, if any.
func (s *Store) GetVoidBySale(ctx context.Context, saleID uuid.UUID) (Void, error) {
	return s.scanVoid(s.db.QueryRowContext(ctx, selectVoidBySale, saleID.String()))
}

// ListRefundsBySale returns every refund issued against a given sale in
// chronological order. Used by Service to compute already-refunded
// quantities before approving a new refund.
func (s *Store) ListRefundsBySale(ctx context.Context, saleID uuid.UUID) ([]Refund, error) {
	rows, err := s.db.QueryContext(ctx, selectRefundsBySale, saleID.String())
	if err != nil {
		return nil, fmt.Errorf("refunds: list by sale: %w", err)
	}
	defer rows.Close()
	var out []Refund
	for rows.Next() {
		r, err := s.scanRefund(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, r)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	// Hydrate lines for each refund (small N — one sale's refund history).
	for i := range out {
		ls, err := s.linesFor(ctx, out[i].RefundID)
		if err != nil {
			return nil, err
		}
		out[i].Lines = ls
	}
	return out, nil
}

// SumRefundedQty returns the sum of refund_lines.quantity grouped by
// sale_line_id for a given sale_id. Used by Service to enforce the
// per-line over-refund check in O(1) DB roundtrips.
func (s *Store) SumRefundedQty(ctx context.Context, saleID uuid.UUID) (map[uuid.UUID]int64, error) {
	const q = `
		SELECT rl.sale_line_id, COALESCE(SUM(rl.quantity), 0)
		FROM refund_lines rl
		JOIN refunds r ON r.refund_id = rl.refund_id
		WHERE r.sale_id = ?
		GROUP BY rl.sale_line_id
	`
	rows, err := s.db.QueryContext(ctx, q, saleID.String())
	if err != nil {
		return nil, fmt.Errorf("refunds: sum refunded qty: %w", err)
	}
	defer rows.Close()
	out := map[uuid.UUID]int64{}
	for rows.Next() {
		var idStr string
		var qty int64
		if err := rows.Scan(&idStr, &qty); err != nil {
			return nil, err
		}
		id, err := uuid.Parse(idStr)
		if err != nil {
			return nil, fmt.Errorf("refunds: parse sale_line_id: %w", err)
		}
		out[id] = qty
	}
	return out, rows.Err()
}

// --- internals ---

func (s *Store) validateVoid(req IssueVoidRequest) error {
	switch {
	case req.VoidID == uuid.Nil:
		return errors.New("refunds: VoidID is required")
	case req.SaleID == uuid.Nil:
		return errors.New("refunds: SaleID is required")
	case req.InvoiceID == uuid.Nil:
		return errors.New("refunds: InvoiceID is required")
	case req.StoreID == "":
		return errors.New("refunds: StoreID is required")
	case req.VoidedAt.IsZero():
		return errors.New("refunds: VoidedAt is required")
	case req.Snapshot == nil:
		return errors.New("refunds: Snapshot is required")
	}
	return nil
}

func (s *Store) validateRefund(req IssueRefundRequest) error {
	switch {
	case req.RefundID == uuid.Nil:
		return errors.New("refunds: RefundID is required")
	case req.SaleID == uuid.Nil:
		return errors.New("refunds: SaleID is required")
	case req.InvoiceID == uuid.Nil:
		return errors.New("refunds: InvoiceID is required")
	case req.StoreID == "":
		return errors.New("refunds: StoreID is required")
	case req.RefundedAt.IsZero():
		return errors.New("refunds: RefundedAt is required")
	case req.Snapshot == nil:
		return errors.New("refunds: Snapshot is required")
	case len(req.Lines) == 0:
		return ErrEmptyLines
	}
	cur := req.GrandTotal.CurrencyCode
	if cur == "" {
		return errors.New("refunds: GrandTotal.CurrencyCode is required")
	}
	if req.Subtotal.CurrencyCode != cur || req.TaxTotal.CurrencyCode != cur {
		return errors.New("refunds: mixed currencies across totals")
	}
	for _, ln := range req.Lines {
		if ln.SaleLineID == uuid.Nil {
			return errors.New("refunds: line SaleLineID is required")
		}
		if ln.SKU == "" {
			return errors.New("refunds: line SKU is required")
		}
		if ln.Quantity <= 0 {
			return errors.New("refunds: line quantity must be positive")
		}
		if ln.LineTotal.CurrencyCode != cur {
			return errors.New("refunds: line currency does not match totals")
		}
	}
	return nil
}

// nextCNSeq performs an atomic per-(store, year) increment inside tx and
// returns the new last_seq. Gapless under concurrency for the same reason
// invoice_sequences is: INSERT OR IGNORE + UPDATE + SELECT in the same
// write transaction, which SQLite serializes.
func (s *Store) nextCNSeq(ctx context.Context, tx *sql.Tx, storeID string, year int) (int64, error) {
	if _, err := tx.ExecContext(ctx,
		`INSERT OR IGNORE INTO credit_note_sequences (store_id, year, last_seq) VALUES (?, ?, 0)`,
		storeID, year,
	); err != nil {
		return 0, fmt.Errorf("seed: %w", err)
	}
	if _, err := tx.ExecContext(ctx,
		`UPDATE credit_note_sequences SET last_seq = last_seq + 1 WHERE store_id = ? AND year = ?`,
		storeID, year,
	); err != nil {
		return 0, fmt.Errorf("increment: %w", err)
	}
	var seq int64
	if err := tx.QueryRowContext(ctx,
		`SELECT last_seq FROM credit_note_sequences WHERE store_id = ? AND year = ?`,
		storeID, year,
	).Scan(&seq); err != nil {
		return 0, fmt.Errorf("read: %w", err)
	}
	return seq, nil
}

func (s *Store) linesFor(ctx context.Context, refundID uuid.UUID) ([]RefundLine, error) {
	const q = `
		SELECT sale_line_id, sku, quantity, restock,
		       unit_price_units, unit_price_nanos,
		       line_total_units, line_total_nanos,
		       currency_code
		FROM refund_lines WHERE refund_id = ?
	`
	rows, err := s.db.QueryContext(ctx, q, refundID.String())
	if err != nil {
		return nil, fmt.Errorf("refunds: list lines: %w", err)
	}
	defer rows.Close()
	var out []RefundLine
	for rows.Next() {
		var (
			idStr               string
			sku                 string
			qty                 int64
			restockInt          int
			upU, ltU            int64
			upN, ltN            int32
			currency            string
		)
		if err := rows.Scan(&idStr, &sku, &qty, &restockInt,
			&upU, &upN, &ltU, &ltN, &currency); err != nil {
			return nil, err
		}
		id, err := uuid.Parse(idStr)
		if err != nil {
			return nil, fmt.Errorf("refunds: parse sale_line_id: %w", err)
		}
		out = append(out, RefundLine{
			RefundID:   refundID,
			SaleLineID: id,
			SKU:        sku,
			Quantity:   qty,
			Restock:    restockInt == 1,
			UnitPrice:  payments.Money{CurrencyCode: currency, Units: upU, Nanos: upN},
			LineTotal:  payments.Money{CurrencyCode: currency, Units: ltU, Nanos: ltN},
		})
	}
	return out, rows.Err()
}

const selectVoidAllCols = `
	SELECT void_id, sale_id, invoice_id, store_id, counter_id, cashier_id,
	       reason, snapshot, snapshot_json,
	       voided_at_unix_ns, created_at_unix_ns
	FROM sale_voids
`

const selectVoidBySale = selectVoidAllCols + ` WHERE sale_id = ?`

const selectRefundAllCols = `
	SELECT refund_id, sale_id, invoice_id, credit_note_number,
	       store_id, counter_id, cashier_id, reason, currency_code,
	       subtotal_units, subtotal_nanos,
	       tax_total_units, tax_total_nanos,
	       grand_total_units, grand_total_nanos,
	       snapshot, snapshot_json,
	       refunded_at_unix_ns, created_at_unix_ns
	FROM refunds
`

const selectRefundsBySale = selectRefundAllCols + ` WHERE sale_id = ? ORDER BY refunded_at_unix_ns ASC, refund_id ASC`

type rowScanner interface {
	Scan(dest ...any) error
}

func (s *Store) scanVoid(row rowScanner) (Void, error) {
	var (
		v                                         Void
		voidIDStr, saleIDStr, invIDStr            string
		voidedNs, createdNs                       int64
	)
	err := row.Scan(
		&voidIDStr, &saleIDStr, &invIDStr,
		&v.StoreID, &v.CounterID, &v.CashierID,
		&v.Reason, &v.Snapshot, &v.SnapshotJSON,
		&voidedNs, &createdNs,
	)
	if errors.Is(err, sql.ErrNoRows) {
		return Void{}, ErrNotFound
	}
	if err != nil {
		return Void{}, err
	}
	if v.VoidID, err = uuid.Parse(voidIDStr); err != nil {
		return Void{}, fmt.Errorf("refunds: parse void_id %q: %w", voidIDStr, err)
	}
	if v.SaleID, err = uuid.Parse(saleIDStr); err != nil {
		return Void{}, fmt.Errorf("refunds: parse sale_id %q: %w", saleIDStr, err)
	}
	if v.InvoiceID, err = uuid.Parse(invIDStr); err != nil {
		return Void{}, fmt.Errorf("refunds: parse invoice_id %q: %w", invIDStr, err)
	}
	v.VoidedAt = time.Unix(0, voidedNs).UTC()
	v.CreatedAt = time.Unix(0, createdNs).UTC()
	return v, nil
}

func (s *Store) scanRefund(row rowScanner) (Refund, error) {
	var (
		r                                                            Refund
		refundIDStr, saleIDStr, invIDStr, currency                   string
		refundedNs, createdNs                                        int64
		subU, taxU, grU                                              int64
		subN, taxN, grN                                              int32
	)
	err := row.Scan(
		&refundIDStr, &saleIDStr, &invIDStr, &r.CreditNoteNumber,
		&r.StoreID, &r.CounterID, &r.CashierID, &r.Reason, &currency,
		&subU, &subN, &taxU, &taxN, &grU, &grN,
		&r.Snapshot, &r.SnapshotJSON,
		&refundedNs, &createdNs,
	)
	if errors.Is(err, sql.ErrNoRows) {
		return Refund{}, ErrNotFound
	}
	if err != nil {
		return Refund{}, err
	}
	if r.RefundID, err = uuid.Parse(refundIDStr); err != nil {
		return Refund{}, fmt.Errorf("refunds: parse refund_id %q: %w", refundIDStr, err)
	}
	if r.SaleID, err = uuid.Parse(saleIDStr); err != nil {
		return Refund{}, fmt.Errorf("refunds: parse sale_id %q: %w", saleIDStr, err)
	}
	if r.InvoiceID, err = uuid.Parse(invIDStr); err != nil {
		return Refund{}, fmt.Errorf("refunds: parse invoice_id %q: %w", invIDStr, err)
	}
	r.Subtotal = payments.Money{CurrencyCode: currency, Units: subU, Nanos: subN}
	r.TaxTotal = payments.Money{CurrencyCode: currency, Units: taxU, Nanos: taxN}
	r.GrandTotal = payments.Money{CurrencyCode: currency, Units: grU, Nanos: grN}
	r.RefundedAt = time.Unix(0, refundedNs).UTC()
	r.CreatedAt = time.Unix(0, createdNs).UTC()
	return r, nil
}

// isUniqueSaleViolation matches a SQLite UNIQUE-constraint error on the
// given column. Matching by substring keeps the package driver-agnostic
// (no dependency on sqlite3.ExtendedCode constants).
func isUniqueSaleViolation(err error, qualifiedColumn string) bool {
	if err == nil {
		return false
	}
	msg := err.Error()
	return strings.Contains(msg, "UNIQUE") && strings.Contains(msg, qualifiedColumn)
}
