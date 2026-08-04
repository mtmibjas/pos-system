package expenses

import (
	"context"
	"database/sql"
	"fmt"
	"time"

	"github.com/google/uuid"
)

// Store is the data-access layer for the expenses table.
//
// It exposes the minimum surface ExpenseService needs (Create / List by
// store). Unlike the items store there is no FK dependency to
// pre-validate, so it is constructed from the *sql.DB alone.
type Store struct {
	db *sql.DB
}

// NewStore wires the expenses store.
func NewStore(sqlDB *sql.DB) *Store {
	return &Store{db: sqlDB}
}

// Create inserts a new expense. tenant_id / store_id are taken from the
// passed Expense — callers (the api handler) pin them from server config
// before calling this method.
//
// The ID is server-assigned (a fresh UUID) unless the caller already set
// one (the seeder uses stable IDs so re-runs are idempotent). CreatedAt
// is set to now on write.
//
// Validation:
//   - TenantID, StoreID, Date, Category all required
//   - Amount.CurrencyCode required
//
// Returns the canonical row after write.
func (s *Store) Create(ctx context.Context, in Expense) (Expense, error) {
	if err := validateForCreate(in); err != nil {
		return Expense{}, err
	}

	if in.ID == "" {
		in.ID = uuid.NewString()
	}
	now := time.Now().UTC()
	in.CreatedAt = now
	// VAT defaults to the amount's currency when unset so the stored
	// zero-VAT row round-trips with a sensible currency code.
	if in.VAT.CurrencyCode == "" {
		in.VAT.CurrencyCode = in.Amount.CurrencyCode
	}

	_, err := s.db.ExecContext(ctx, `
		INSERT INTO expenses (
			id, tenant_id, store_id, date, category, description, payment_mode,
			amount_currency, amount_units, amount_nanos,
			vat_currency, vat_units, vat_nanos,
			created_at
		) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
		ON CONFLICT(id) DO UPDATE SET
			tenant_id       = excluded.tenant_id,
			store_id        = excluded.store_id,
			date            = excluded.date,
			category        = excluded.category,
			description     = excluded.description,
			payment_mode    = excluded.payment_mode,
			amount_currency = excluded.amount_currency,
			amount_units    = excluded.amount_units,
			amount_nanos    = excluded.amount_nanos,
			vat_currency    = excluded.vat_currency,
			vat_units       = excluded.vat_units,
			vat_nanos       = excluded.vat_nanos,
			created_at      = excluded.created_at
	`,
		in.ID, in.TenantID, in.StoreID, in.Date, in.Category, in.Description, in.PaymentMode,
		in.Amount.CurrencyCode, in.Amount.Units, in.Amount.Nanos,
		in.VAT.CurrencyCode, in.VAT.Units, in.VAT.Nanos,
		now.UnixNano(),
	)
	if err != nil {
		return Expense{}, fmt.Errorf("expenses: create: %w", err)
	}
	return in, nil
}

// List returns expenses for the (tenant, store), most-recent first
// (created_at DESC, then id for a stable tiebreak). An empty result is
// not an error.
func (s *Store) List(ctx context.Context, tenantID, storeID string) ([]Expense, error) {
	if tenantID == "" {
		return nil, fmt.Errorf("expenses: List requires tenantID")
	}
	if storeID == "" {
		return nil, fmt.Errorf("expenses: List requires storeID")
	}
	rows, err := s.db.QueryContext(ctx, `
		SELECT id, tenant_id, store_id, date, category, description, payment_mode,
		       amount_currency, amount_units, amount_nanos,
		       vat_currency, vat_units, vat_nanos,
		       created_at
		FROM expenses
		WHERE tenant_id = ? AND store_id = ?
		ORDER BY created_at DESC, id ASC
	`, tenantID, storeID)
	if err != nil {
		return nil, fmt.Errorf("expenses: list: %w", err)
	}
	defer rows.Close()
	var out []Expense
	for rows.Next() {
		e, err := scanExpense(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, e)
	}
	return out, rows.Err()
}

// scanExpense reads one row in the SELECT column order above.
type scanner interface {
	Scan(dest ...any) error
}

func scanExpense(s scanner) (Expense, error) {
	var (
		e         Expense
		createdNS int64
	)
	if err := s.Scan(
		&e.ID, &e.TenantID, &e.StoreID, &e.Date, &e.Category, &e.Description, &e.PaymentMode,
		&e.Amount.CurrencyCode, &e.Amount.Units, &e.Amount.Nanos,
		&e.VAT.CurrencyCode, &e.VAT.Units, &e.VAT.Nanos,
		&createdNS,
	); err != nil {
		return Expense{}, err
	}
	e.CreatedAt = time.Unix(0, createdNS).UTC()
	return e, nil
}

func validateForCreate(in Expense) error {
	switch {
	case in.TenantID == "":
		return fmt.Errorf("%w: TenantID is required", ErrInvalidExpense)
	case in.StoreID == "":
		return fmt.Errorf("%w: StoreID is required", ErrInvalidExpense)
	case in.Date == "":
		return fmt.Errorf("%w: Date is required", ErrInvalidExpense)
	case in.Category == "":
		return fmt.Errorf("%w: Category is required", ErrInvalidExpense)
	case in.Amount.CurrencyCode == "":
		return fmt.Errorf("%w: Amount.CurrencyCode is required", ErrInvalidExpense)
	}
	return nil
}
