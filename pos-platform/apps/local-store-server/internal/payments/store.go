package payments

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"

	"github.com/mibjas/pos-platform/apps/local-store-server/internal/txn"
)

// Store is the data-access layer for the payments table. Idempotent on
// PaymentID — duplicate inserts are not an error (sync retries are the
// expected happy path; see docs/sync-rules.md).
type Store struct {
	db *sql.DB
}

func NewStore(sqlDB *sql.DB) *Store {
	return &Store{db: sqlDB}
}

// Insert appends a payment in its own transaction. Idempotent on PaymentID.
//
// For sale finalization (opslog + inventory + payments must commit together),
// use InsertTx inside a txn.Apply block.
func (s *Store) Insert(ctx context.Context, p Payment) (saved Payment, idempotent bool, err error) {
	err = txn.Apply(ctx, s.db, func(tx *sql.Tx) error {
		var ierr error
		saved, idempotent, ierr = s.InsertTx(ctx, tx, p)
		return ierr
	})
	if err != nil {
		return Payment{}, false, err
	}
	return saved, idempotent, nil
}

// InsertTx is the *sql.Tx variant. Refund linkage is validated against the
// same tx — so a parent payment inserted earlier in this same batch is
// visible. On a duplicate PaymentID, the existing row is returned with
// idempotent=true and no error.
func (s *Store) InsertTx(ctx context.Context, tx *sql.Tx, p Payment) (saved Payment, idempotent bool, err error) {
	if err := p.validate(); err != nil {
		return Payment{}, false, err
	}

	// If this is a refund linked to a parent, the parent must exist locally.
	if p.ParentPaymentID != uuid.Nil {
		var dummy string
		err := tx.QueryRowContext(ctx,
			`SELECT payment_id FROM payments WHERE payment_id = ?`,
			p.ParentPaymentID.String()).Scan(&dummy)
		if errors.Is(err, sql.ErrNoRows) {
			return Payment{}, false, fmt.Errorf("%w: %s", ErrParentNotFound, p.ParentPaymentID)
		}
		if err != nil {
			return Payment{}, false, fmt.Errorf("payments: parent lookup: %w", err)
		}
	}

	const insertSQL = `
		INSERT OR IGNORE INTO payments (
			payment_id, sale_id, method, currency_code, amount_units, amount_nanos,
			reference, parent_payment_id, created_at
		) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
	`
	res, err := tx.ExecContext(ctx, insertSQL,
		p.PaymentID.String(),
		p.SaleID.String(),
		string(p.Method),
		p.Amount.CurrencyCode,
		p.Amount.Units,
		p.Amount.Nanos,
		p.Reference,
		nullableUUID(p.ParentPaymentID),
		p.CreatedAt.UnixNano(),
	)
	if err != nil {
		return Payment{}, false, fmt.Errorf("payments: insert: %w", err)
	}
	affected, err := res.RowsAffected()
	if err != nil {
		return Payment{}, false, fmt.Errorf("payments: rows affected: %w", err)
	}
	idempotent = affected == 0

	saved, err = s.getTx(ctx, tx, p.PaymentID)
	if err != nil {
		return Payment{}, false, fmt.Errorf("payments: post-insert get: %w", err)
	}
	return saved, idempotent, nil
}

// Get fetches a payment by id. Returns sql.ErrNoRows-wrapped error if missing.
func (s *Store) Get(ctx context.Context, paymentID uuid.UUID) (Payment, error) {
	return scanPayment(s.db.QueryRowContext(ctx, selectByID, paymentID.String()))
}

func (s *Store) getTx(ctx context.Context, tx *sql.Tx, paymentID uuid.UUID) (Payment, error) {
	return scanPayment(tx.QueryRowContext(ctx, selectByID, paymentID.String()))
}

// ListForSale returns all payments for a sale, oldest first. Useful for
// receipt rendering, refund flows, and balance derivation.
func (s *Store) ListForSale(ctx context.Context, saleID uuid.UUID) ([]Payment, error) {
	const q = `
		SELECT payment_id, sale_id, method, currency_code, amount_units, amount_nanos,
		       reference, parent_payment_id, created_at
		FROM payments
		WHERE sale_id = ?
		ORDER BY created_at ASC, payment_id ASC
	`
	rows, err := s.db.QueryContext(ctx, q, saleID.String())
	if err != nil {
		return nil, fmt.Errorf("payments: list for sale: %w", err)
	}
	defer rows.Close()
	var out []Payment
	for rows.Next() {
		p, err := scanPayment(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, p)
	}
	return out, rows.Err()
}

// Balance returns the net amount paid for a sale = sum of payment amounts
// (refunds are negative). All payments must share a currency — if a sale has
// payments in multiple currencies that's a bug; we return an error.
//
// Convention: a positive balance means money received net of refunds. A
// zero balance means refunded in full. Negative means over-refunded.
func (s *Store) Balance(ctx context.Context, saleID uuid.UUID) (Money, error) {
	rows, err := s.ListForSale(ctx, saleID)
	if err != nil {
		return Money{}, err
	}
	if len(rows) == 0 {
		return Money{}, nil
	}
	currency := rows[0].Amount.CurrencyCode
	sum := Money{CurrencyCode: currency}
	for _, p := range rows {
		if p.Amount.CurrencyCode != currency {
			return Money{}, fmt.Errorf("payments: mixed currencies on sale %s: %q vs %q",
				saleID, currency, p.Amount.CurrencyCode)
		}
		sum, err = sum.Add(p.Amount)
		if err != nil {
			return Money{}, err
		}
	}
	return sum, nil
}

// --- internal ---

const selectByID = `
	SELECT payment_id, sale_id, method, currency_code, amount_units, amount_nanos,
	       reference, parent_payment_id, created_at
	FROM payments
	WHERE payment_id = ?
`

type rowScanner interface {
	Scan(dest ...any) error
}

func scanPayment(row rowScanner) (Payment, error) {
	var (
		p              Payment
		idStr, saleStr string
		methodStr      string
		parentStr      sql.NullString
		createdAtNs    int64
	)
	err := row.Scan(&idStr, &saleStr, &methodStr,
		&p.Amount.CurrencyCode, &p.Amount.Units, &p.Amount.Nanos,
		&p.Reference, &parentStr, &createdAtNs)
	if err != nil {
		return Payment{}, err
	}
	if p.PaymentID, err = uuid.Parse(idStr); err != nil {
		return Payment{}, fmt.Errorf("payments: parse payment_id %q: %w", idStr, err)
	}
	if p.SaleID, err = uuid.Parse(saleStr); err != nil {
		return Payment{}, fmt.Errorf("payments: parse sale_id %q: %w", saleStr, err)
	}
	p.Method = Method(methodStr)
	if parentStr.Valid && parentStr.String != "" {
		if p.ParentPaymentID, err = uuid.Parse(parentStr.String); err != nil {
			return Payment{}, fmt.Errorf("payments: parse parent_payment_id %q: %w", parentStr.String, err)
		}
	}
	p.CreatedAt = time.Unix(0, createdAtNs).UTC()
	return p, nil
}

func nullableUUID(u uuid.UUID) any {
	if u == uuid.Nil {
		return nil
	}
	return u.String()
}
