package invoices

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
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/txn"
)

// Store is the data-access layer for invoices.
//
// tz is the store's local timezone. Year for invoice numbering is derived
// from FinalizedAt.In(tz).Year(), so an INV-2026-* series rolls over at
// local midnight rather than UTC midnight.
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

// IssueRequest is the input to IssueTx.
//
// Snapshot is the canonical pos.v1.SaleCreated proto; IssueTx serializes
// it once for the BLOB column and renders a JSON preview for the debug
// column. The caller does not pre-serialize.
type IssueRequest struct {
	InvoiceID uuid.UUID
	SaleID    uuid.UUID
	StoreID   string
	CounterID string
	CashierID string

	Subtotal   payments.Money
	TaxTotal   payments.Money
	GrandTotal payments.Money

	Snapshot    proto.Message
	FinalizedAt time.Time
}

// IssueTx writes one invoice row inside an open transaction. It allocates
// the next per-store-per-year sequence atomically with the row insert.
//
// On UNIQUE(sale_id) collision returns ErrAlreadyIssued — callers that need
// idempotent replay should call GetBySale separately before invoking IssueTx.
func (s *Store) IssueTx(ctx context.Context, tx *sql.Tx, req IssueRequest) (Invoice, error) {
	if err := s.validate(req); err != nil {
		return Invoice{}, err
	}

	year := req.FinalizedAt.In(s.tz).Year()

	seq, err := s.nextSeq(ctx, tx, req.StoreID, year)
	if err != nil {
		return Invoice{}, fmt.Errorf("invoices: allocate sequence: %w", err)
	}
	invoiceNumber := fmt.Sprintf("INV-%04d-%06d", year, seq)

	snapBytes, err := proto.Marshal(req.Snapshot)
	if err != nil {
		return Invoice{}, fmt.Errorf("invoices: marshal snapshot: %w", err)
	}
	// Use a stable JSON form for the preview column. Read-only; safe to
	// regenerate if the schema ever changes.
	snapJSON, err := protojson.MarshalOptions{
		UseProtoNames:   true,
		EmitUnpopulated: true,
	}.Marshal(req.Snapshot)
	if err != nil {
		return Invoice{}, fmt.Errorf("invoices: marshal snapshot json: %w", err)
	}

	createdAt := time.Now().UTC()

	const insertSQL = `
		INSERT INTO invoices (
			invoice_id, sale_id, invoice_number, store_id, counter_id, cashier_id,
			currency_code, subtotal_units, subtotal_nanos,
			tax_total_units, tax_total_nanos,
			grand_total_units, grand_total_nanos,
			snapshot, snapshot_json,
			finalized_at_unix_ns, created_at_unix_ns
		) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
	`
	_, err = tx.ExecContext(ctx, insertSQL,
		req.InvoiceID.String(),
		req.SaleID.String(),
		invoiceNumber,
		req.StoreID,
		req.CounterID,
		req.CashierID,
		req.Subtotal.CurrencyCode,
		req.Subtotal.Units, req.Subtotal.Nanos,
		req.TaxTotal.Units, req.TaxTotal.Nanos,
		req.GrandTotal.Units, req.GrandTotal.Nanos,
		snapBytes,
		string(snapJSON),
		req.FinalizedAt.UnixNano(),
		createdAt.UnixNano(),
	)
	if err != nil {
		if isUniqueSaleViolation(err) {
			return Invoice{}, ErrAlreadyIssued
		}
		return Invoice{}, fmt.Errorf("invoices: insert: %w", err)
	}

	return Invoice{
		InvoiceID:     req.InvoiceID,
		SaleID:        req.SaleID,
		InvoiceNumber: invoiceNumber,
		StoreID:       req.StoreID,
		CounterID:     req.CounterID,
		CashierID:     req.CashierID,
		Subtotal:      req.Subtotal,
		TaxTotal:      req.TaxTotal,
		GrandTotal:    req.GrandTotal,
		Snapshot:      snapBytes,
		SnapshotJSON:  string(snapJSON),
		FinalizedAt:   req.FinalizedAt,
		CreatedAt:     createdAt,
	}, nil
}

// Issue is the standalone variant — opens its own transaction. Tests and
// administrative tools use it; SaleService.Finalize uses IssueTx.
func (s *Store) Issue(ctx context.Context, req IssueRequest) (inv Invoice, err error) {
	err = txn.Apply(ctx, s.db, func(tx *sql.Tx) error {
		var ierr error
		inv, ierr = s.IssueTx(ctx, tx, req)
		return ierr
	})
	if err != nil {
		return Invoice{}, err
	}
	return inv, nil
}

// Get fetches an invoice by InvoiceID. Returns ErrNotFound if missing.
func (s *Store) Get(ctx context.Context, invoiceID uuid.UUID) (Invoice, error) {
	return scanInvoice(s.db.QueryRowContext(ctx, selectByInvoiceID, invoiceID.String()))
}

// GetBySale fetches an invoice by SaleID. Returns ErrNotFound if missing.
func (s *Store) GetBySale(ctx context.Context, saleID uuid.UUID) (Invoice, error) {
	return scanInvoice(s.db.QueryRowContext(ctx, selectBySaleID, saleID.String()))
}

// GetByInvoiceNumber fetches an invoice by its INV-YYYY-NNNNNN number.
// Returns ErrNotFound if missing. invoice_number has a UNIQUE index per
// store-year so this is a single-row lookup.
func (s *Store) GetByInvoiceNumber(ctx context.Context, invoiceNumber string) (Invoice, error) {
	return scanInvoice(s.db.QueryRowContext(ctx, selectByInvoiceNumber, invoiceNumber))
}

// ListFilter narrows List output. Zero-value fields are ignored.
type ListFilter struct {
	StoreID string
	Since   time.Time
	Until   time.Time
	Limit   int // <=0 means no limit
}

// List returns invoices most-recent-first.
func (s *Store) List(ctx context.Context, f ListFilter) ([]Invoice, error) {
	var (
		clauses []string
		args    []any
	)
	if f.StoreID != "" {
		clauses = append(clauses, "store_id = ?")
		args = append(args, f.StoreID)
	}
	if !f.Since.IsZero() {
		clauses = append(clauses, "finalized_at_unix_ns >= ?")
		args = append(args, f.Since.UnixNano())
	}
	if !f.Until.IsZero() {
		clauses = append(clauses, "finalized_at_unix_ns < ?")
		args = append(args, f.Until.UnixNano())
	}
	q := selectAllCols + " FROM invoices"
	if len(clauses) > 0 {
		q += " WHERE " + strings.Join(clauses, " AND ")
	}
	q += " ORDER BY finalized_at_unix_ns DESC, invoice_id ASC"
	if f.Limit > 0 {
		q += fmt.Sprintf(" LIMIT %d", f.Limit)
	}

	rows, err := s.db.QueryContext(ctx, q, args...)
	if err != nil {
		return nil, fmt.Errorf("invoices: list: %w", err)
	}
	defer rows.Close()
	var out []Invoice
	for rows.Next() {
		inv, err := scanInvoice(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, inv)
	}
	return out, rows.Err()
}

// --- internals ---

func (s *Store) validate(req IssueRequest) error {
	if req.InvoiceID == uuid.Nil {
		return errors.New("invoices: InvoiceID is required")
	}
	if req.SaleID == uuid.Nil {
		return errors.New("invoices: SaleID is required")
	}
	if req.StoreID == "" {
		return errors.New("invoices: StoreID is required")
	}
	if req.FinalizedAt.IsZero() {
		return errors.New("invoices: FinalizedAt is required")
	}
	if req.Snapshot == nil {
		return errors.New("invoices: Snapshot is required")
	}
	cur := req.GrandTotal.CurrencyCode
	if cur == "" {
		return errors.New("invoices: GrandTotal.CurrencyCode is required")
	}
	if req.Subtotal.CurrencyCode != cur || req.TaxTotal.CurrencyCode != cur {
		return errors.New("invoices: mixed currencies across totals")
	}
	return nil
}

// nextSeq performs an atomic per-(store, year) increment inside tx and
// returns the new last_seq value. Gapless under concurrency because both
// the IGNORE-seed and the UPDATE happen within the same transaction; SQLite
// serializes write transactions (or our PRAGMA busy_timeout retries them).
func (s *Store) nextSeq(ctx context.Context, tx *sql.Tx, storeID string, year int) (int64, error) {
	if _, err := tx.ExecContext(ctx,
		`INSERT OR IGNORE INTO invoice_sequences (store_id, year, last_seq) VALUES (?, ?, 0)`,
		storeID, year,
	); err != nil {
		return 0, fmt.Errorf("seed: %w", err)
	}
	if _, err := tx.ExecContext(ctx,
		`UPDATE invoice_sequences SET last_seq = last_seq + 1 WHERE store_id = ? AND year = ?`,
		storeID, year,
	); err != nil {
		return 0, fmt.Errorf("increment: %w", err)
	}
	var seq int64
	if err := tx.QueryRowContext(ctx,
		`SELECT last_seq FROM invoice_sequences WHERE store_id = ? AND year = ?`,
		storeID, year,
	).Scan(&seq); err != nil {
		return 0, fmt.Errorf("read: %w", err)
	}
	return seq, nil
}

const selectAllCols = `
	SELECT invoice_id, sale_id, invoice_number, store_id, counter_id, cashier_id,
	       currency_code, subtotal_units, subtotal_nanos,
	       tax_total_units, tax_total_nanos,
	       grand_total_units, grand_total_nanos,
	       snapshot, snapshot_json,
	       finalized_at_unix_ns, created_at_unix_ns
`

const selectByInvoiceID = selectAllCols + ` FROM invoices WHERE invoice_id = ?`
const selectBySaleID = selectAllCols + ` FROM invoices WHERE sale_id = ?`
const selectByInvoiceNumber = selectAllCols + ` FROM invoices WHERE invoice_number = ?`

type rowScanner interface {
	Scan(dest ...any) error
}

func scanInvoice(row rowScanner) (Invoice, error) {
	var (
		inv             Invoice
		invIDStr        string
		saleIDStr       string
		currency        string
		finalizedNs     int64
		createdNs       int64
		subU, taxU, grU int64
		subN, taxN, grN int32
	)
	err := row.Scan(
		&invIDStr, &saleIDStr, &inv.InvoiceNumber, &inv.StoreID, &inv.CounterID, &inv.CashierID,
		&currency, &subU, &subN, &taxU, &taxN, &grU, &grN,
		&inv.Snapshot, &inv.SnapshotJSON,
		&finalizedNs, &createdNs,
	)
	if errors.Is(err, sql.ErrNoRows) {
		return Invoice{}, ErrNotFound
	}
	if err != nil {
		return Invoice{}, err
	}
	if inv.InvoiceID, err = uuid.Parse(invIDStr); err != nil {
		return Invoice{}, fmt.Errorf("invoices: parse invoice_id %q: %w", invIDStr, err)
	}
	if inv.SaleID, err = uuid.Parse(saleIDStr); err != nil {
		return Invoice{}, fmt.Errorf("invoices: parse sale_id %q: %w", saleIDStr, err)
	}
	inv.Subtotal = payments.Money{CurrencyCode: currency, Units: subU, Nanos: subN}
	inv.TaxTotal = payments.Money{CurrencyCode: currency, Units: taxU, Nanos: taxN}
	inv.GrandTotal = payments.Money{CurrencyCode: currency, Units: grU, Nanos: grN}
	inv.FinalizedAt = time.Unix(0, finalizedNs).UTC()
	inv.CreatedAt = time.Unix(0, createdNs).UTC()
	return inv, nil
}

// isUniqueSaleViolation matches SQLite's UNIQUE constraint error for
// sale_id. We deliberately match by substring rather than depending on the
// sqlite3 driver's ExtendedCode constants — keeps the package
// driver-agnostic.
func isUniqueSaleViolation(err error) bool {
	if err == nil {
		return false
	}
	msg := err.Error()
	return strings.Contains(msg, "UNIQUE") && strings.Contains(msg, "invoices.sale_id")
}
