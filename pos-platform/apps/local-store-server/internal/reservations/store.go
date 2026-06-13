package reservations

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
)

// Store is the data-access layer for inventory_reservations.
type Store struct {
	db *sql.DB
}

// NewStore returns a Store backed by sqlDB.
func NewStore(sqlDB *sql.DB) *Store {
	return &Store{db: sqlDB}
}

// Insert writes a fresh active reservation. Caller is expected to be
// holding inventory.WithSKULock + an Available check inside the same
// txn.Apply.
func (s *Store) Insert(ctx context.Context, tx *sql.Tx, r Reservation) error {
	if err := validateInsert(r); err != nil {
		return err
	}
	_, err := tx.ExecContext(ctx, `
		INSERT INTO inventory_reservations (
			reservation_id, sku, store_id, counter_id, quantity,
			created_at, expires_at, status
		) VALUES (?, ?, ?, ?, ?, ?, ?, 'active')
	`,
		r.ID.String(), r.SKU, r.StoreID, r.CounterID, r.Quantity,
		r.CreatedAt.UnixNano(), r.ExpiresAt.UnixNano(),
	)
	if err != nil {
		return fmt.Errorf("reservations: insert: %w", err)
	}
	return nil
}

// GetTx loads a reservation by id under tx. Returns ErrNotFound if absent.
func (s *Store) GetTx(ctx context.Context, tx *sql.Tx, id uuid.UUID) (Reservation, error) {
	return scanReservation(tx.QueryRowContext(ctx, selectByID, id.String()))
}

// Get loads a reservation by id outside a transaction. Returns
// ErrNotFound if absent.
func (s *Store) Get(ctx context.Context, id uuid.UUID) (Reservation, error) {
	return scanReservation(s.db.QueryRowContext(ctx, selectByID, id.String()))
}

// TransitionTx flips an active reservation to a terminal status. Returns
// ErrNotActive if the row exists but isn't active; ErrNotFound if missing.
// Caller drives the publish on success.
func (s *Store) TransitionTx(ctx context.Context, tx *sql.Tx, id uuid.UUID, to Status) error {
	switch to {
	case StatusReleased, StatusFinalized, StatusExpired:
	default:
		return fmt.Errorf("reservations: invalid transition target %q", to)
	}
	res, err := tx.ExecContext(ctx, `
		UPDATE inventory_reservations
		SET status = ?
		WHERE reservation_id = ? AND status = 'active'
	`, string(to), id.String())
	if err != nil {
		return fmt.Errorf("reservations: transition: %w", err)
	}
	n, _ := res.RowsAffected()
	if n == 1 {
		return nil
	}
	// Either missing or not active — distinguish for clearer errors.
	if _, err := s.GetTx(ctx, tx, id); err != nil {
		return err
	}
	return ErrNotActive
}

// ExpireDueTx marks every active reservation with expires_at <= now as
// 'expired'. Returns the list of (store_id, sku) pairs that changed so
// the caller can re-publish their Available counts. Lazy: called from
// Available read paths and from Reserve so we don't need a sweeper for
// slice 4.3.
func (s *Store) ExpireDueTx(ctx context.Context, tx *sql.Tx, nowUnixNano int64) ([]StoreSKU, error) {
	rows, err := tx.QueryContext(ctx, `
		SELECT DISTINCT store_id, sku
		FROM inventory_reservations
		WHERE status = 'active' AND expires_at <= ?
	`, nowUnixNano)
	if err != nil {
		return nil, fmt.Errorf("reservations: expire scan: %w", err)
	}
	var keys []StoreSKU
	for rows.Next() {
		var k StoreSKU
		if err := rows.Scan(&k.StoreID, &k.SKU); err != nil {
			_ = rows.Close()
			return nil, fmt.Errorf("reservations: expire scan row: %w", err)
		}
		keys = append(keys, k)
	}
	if err := rows.Close(); err != nil {
		return nil, err
	}
	if len(keys) == 0 {
		return nil, nil
	}
	_, err = tx.ExecContext(ctx, `
		UPDATE inventory_reservations
		SET status = 'expired'
		WHERE status = 'active' AND expires_at <= ?
	`, nowUnixNano)
	if err != nil {
		return nil, fmt.Errorf("reservations: expire update: %w", err)
	}
	return keys, nil
}

// StoreSKU keys an inventory location for "available changed" notifications.
type StoreSKU struct {
	StoreID string
	SKU     string
}

const selectByID = `
	SELECT reservation_id, sku, store_id, counter_id, quantity,
	       created_at, expires_at, status
	FROM inventory_reservations
	WHERE reservation_id = ?
`

func scanReservation(row *sql.Row) (Reservation, error) {
	var (
		r          Reservation
		idStr      string
		createdNs  int64
		expiresNs  int64
		statusStr  string
	)
	err := row.Scan(&idStr, &r.SKU, &r.StoreID, &r.CounterID, &r.Quantity,
		&createdNs, &expiresNs, &statusStr)
	if errors.Is(err, sql.ErrNoRows) {
		return Reservation{}, ErrNotFound
	}
	if err != nil {
		return Reservation{}, fmt.Errorf("reservations: scan: %w", err)
	}
	if r.ID, err = uuid.Parse(idStr); err != nil {
		return Reservation{}, fmt.Errorf("reservations: parse id %q: %w", idStr, err)
	}
	r.CreatedAt = time.Unix(0, createdNs).UTC()
	r.ExpiresAt = time.Unix(0, expiresNs).UTC()
	r.Status = Status(statusStr)
	return r, nil
}

func validateInsert(r Reservation) error {
	if r.ID == uuid.Nil {
		return errors.New("reservations: ID is required")
	}
	if r.SKU == "" {
		return errors.New("reservations: SKU is required")
	}
	if r.StoreID == "" {
		return errors.New("reservations: StoreID is required")
	}
	if r.CounterID == "" {
		return errors.New("reservations: CounterID is required")
	}
	if r.Quantity <= 0 {
		return errors.New("reservations: Quantity must be positive")
	}
	if r.CreatedAt.IsZero() || r.ExpiresAt.IsZero() {
		return errors.New("reservations: CreatedAt and ExpiresAt are required")
	}
	if !r.ExpiresAt.After(r.CreatedAt) {
		return errors.New("reservations: ExpiresAt must be after CreatedAt")
	}
	return nil
}
