package inventory

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"sync"
	"time"

	"github.com/google/uuid"

	"github.com/mibjas/pos-platform/apps/local-store-server/internal/txn"
)

// AllowOversell is a per-store policy hook. Return true to permit negative
// stock for that store. Default (nil) is "never allow oversell" — the safest
// posture for a POS at retail.
type AllowOversell func(storeID string) bool

// Store is the data-access layer for inventory_movements. It serializes
// writes-per-(store,sku) via in-process mutexes so that "last-item races"
// across counters can be resolved deterministically.
type Store struct {
	db            *sql.DB
	locks         sync.Map // key = storeID + "\x00" + sku, value = *sync.Mutex
	allowOversell AllowOversell
}

// NewStore returns a Store. allowOversell may be nil (= never allow oversell).
func NewStore(sqlDB *sql.DB, allowOversell AllowOversell) *Store {
	return &Store{db: sqlDB, allowOversell: allowOversell}
}

// skuLock returns (and lazily creates) the mutex for (storeID, sku).
func (s *Store) skuLock(storeID, sku string) *sync.Mutex {
	key := storeID + "\x00" + sku
	v, _ := s.locks.LoadOrStore(key, &sync.Mutex{})
	return v.(*sync.Mutex)
}

// WithSKULock acquires the per-(store,sku) lock, runs fn, releases.
//
// Use this when composing a multi-step operation that must be linearised
// against other operations on the same SKU (e.g. "check stock then write
// movement then publish over websocket"). The SQL transaction itself does
// NOT need this lock — SQLite serializes writes already — but the
// **read-then-write** check for oversell does.
func (s *Store) WithSKULock(storeID, sku string, fn func() error) error {
	if storeID == "" || sku == "" {
		return errors.New("inventory: WithSKULock requires non-empty storeID and sku")
	}
	mu := s.skuLock(storeID, sku)
	mu.Lock()
	defer mu.Unlock()
	return fn()
}

// Append writes a single movement in its own transaction, holding the
// per-SKU lock for the duration. Convenience for one-off inventory edits
// (receives, stock takes) that aren't part of a larger sale batch.
//
// For sales (where opslog + inventory + payments must commit atomically),
// use AppendTx inside a txn.Apply block — and hold WithSKULock yourself
// across the verify-and-write window.
func (s *Store) Append(ctx context.Context, m Movement) error {
	return s.WithSKULock(m.StoreID, m.SKU, func() error {
		return txn.Apply(ctx, s.db, func(tx *sql.Tx) error {
			return s.AppendTx(ctx, tx, m)
		})
	})
}

// AppendTx is the *sql.Tx variant. The caller is responsible for holding
// WithSKULock around the verify-then-write window (this method does the
// oversell check + insert inside tx).
func (s *Store) AppendTx(ctx context.Context, tx *sql.Tx, m Movement) error {
	if err := m.validate(); err != nil {
		return err
	}

	if m.Delta < 0 {
		current, err := s.stockOnHandWith(ctx, txQuerier{tx}, m.StoreID, m.SKU)
		if err != nil {
			return err
		}
		if current+m.Delta < 0 {
			if s.allowOversell == nil || !s.allowOversell(m.StoreID) {
				return &OversellError{
					SKU:     m.SKU,
					StoreID: m.StoreID,
					Have:    current,
					Want:    -m.Delta,
				}
			}
		}
	}

	_, err := tx.ExecContext(ctx, `
		INSERT INTO inventory_movements (
			movement_id, sku, store_id, counter_id, delta, reason,
			ref_type, ref_id, occurred_at, lamport, origin_node_id
		) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
	`,
		m.MovementID.String(), m.SKU, m.StoreID, nullableString(m.CounterID),
		m.Delta, string(m.Reason), m.RefType, m.RefID,
		m.OccurredAt.UnixNano(), m.Lamport, m.OriginNodeID,
	)
	if err != nil {
		return fmt.Errorf("inventory: insert movement: %w", err)
	}
	return nil
}

// Available returns on-hand minus the sum of active-not-expired
// reservations for (storeID, sku). It's the "buyable right now" number
// the multi-counter live tile renders.
//
// nowUnixNano is the cutoff used to drop expired reservations from the
// sum — the caller passes time.Now().UTC().UnixNano() in production;
// tests can pin it for determinism.
//
// Reservations live in inventory_reservations (slice 4.3) and are NOT
// synced to the cloud — they're intra-store coordination only, so we
// query them directly here rather than going through a separate package
// (avoiding an import cycle inventory → reservations → inventory).
func (s *Store) Available(ctx context.Context, storeID, sku string, nowUnixNano int64) (int64, error) {
	return s.availableWith(ctx, dbQuerier{s.db}, storeID, sku, nowUnixNano)
}

// AvailableTx is the *sql.Tx variant for read-then-write callers that
// need the value computed inside the same transaction as a subsequent
// write (e.g. the reservations service's Reserve path).
func (s *Store) AvailableTx(ctx context.Context, tx *sql.Tx, storeID, sku string, nowUnixNano int64) (int64, error) {
	return s.availableWith(ctx, txQuerier{tx}, storeID, sku, nowUnixNano)
}

func (s *Store) availableWith(ctx context.Context, q querier, storeID, sku string, nowUnixNano int64) (int64, error) {
	onHand, err := s.stockOnHandWith(ctx, q, storeID, sku)
	if err != nil {
		return 0, err
	}
	var held sql.NullInt64
	err = q.QueryRowContext(ctx, `
		SELECT COALESCE(SUM(quantity), 0)
		FROM inventory_reservations
		WHERE store_id = ? AND sku = ? AND status = 'active' AND expires_at > ?
	`, storeID, sku, nowUnixNano).Scan(&held)
	if err != nil {
		return 0, fmt.Errorf("inventory: held qty: %w", err)
	}
	if held.Valid {
		return onHand - held.Int64, nil
	}
	return onHand, nil
}

// StockOnHand returns the current derived stock-on-hand for (sku, store).
// It is eventually consistent — a concurrent write may land between the
// read and any subsequent decision. For "check then write" patterns, do
// the check inside the same transaction (StockOnHandTx) under WithSKULock.
func (s *Store) StockOnHand(ctx context.Context, storeID, sku string) (int64, error) {
	return s.stockOnHandWith(ctx, dbQuerier{s.db}, storeID, sku)
}

// StockOnHandTx is the *sql.Tx variant.
func (s *Store) StockOnHandTx(ctx context.Context, tx *sql.Tx, storeID, sku string) (int64, error) {
	return s.stockOnHandWith(ctx, txQuerier{tx}, storeID, sku)
}

// OnHandRow is one per-SKU stock-on-hand row.
type OnHandRow struct {
	SKU    string
	OnHand int64
}

// ListOnHand returns the live derived on-hand for every SKU that has at
// least one non-voided movement at storeID. Sorted by SKU. Callers that
// want catalog metadata (name, price) should join externally against
// items.Store.List — this method intentionally stays inventory-only.
func (s *Store) ListOnHand(ctx context.Context, storeID string) ([]OnHandRow, error) {
	if storeID == "" {
		return nil, errors.New("inventory: ListOnHand requires storeID")
	}
	rows, err := s.db.QueryContext(ctx, `
		SELECT sku, COALESCE(SUM(delta), 0) AS on_hand
		FROM inventory_movements
		WHERE store_id = ? AND voided_at IS NULL
		GROUP BY sku
		ORDER BY sku ASC
	`, storeID)
	if err != nil {
		return nil, fmt.Errorf("inventory: list on-hand: %w", err)
	}
	defer rows.Close()
	var out []OnHandRow
	for rows.Next() {
		var r OnHandRow
		if err := rows.Scan(&r.SKU, &r.OnHand); err != nil {
			return nil, fmt.Errorf("inventory: scan on-hand: %w", err)
		}
		out = append(out, r)
	}
	return out, rows.Err()
}

// ListMovements returns all non-voided movements for (sku, store), ordered
// oldest-first. Useful for audit + ledger views.
func (s *Store) ListMovements(ctx context.Context, storeID, sku string) ([]Movement, error) {
	const q = `
		SELECT id, movement_id, sku, store_id, counter_id, delta, reason,
		       ref_type, ref_id, occurred_at, lamport, origin_node_id,
		       voided_at, voided_by_id
		FROM inventory_movements
		WHERE sku = ? AND store_id = ?
		ORDER BY occurred_at ASC, id ASC
	`
	rows, err := s.db.QueryContext(ctx, q, sku, storeID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []Movement
	for rows.Next() {
		m, err := scanMovement(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, m)
	}
	return out, rows.Err()
}

// --- internal helpers ---

type querier interface {
	QueryRowContext(ctx context.Context, query string, args ...any) *sql.Row
}

type dbQuerier struct{ db *sql.DB }

func (d dbQuerier) QueryRowContext(ctx context.Context, q string, args ...any) *sql.Row {
	return d.db.QueryRowContext(ctx, q, args...)
}

type txQuerier struct{ tx *sql.Tx }

func (t txQuerier) QueryRowContext(ctx context.Context, q string, args ...any) *sql.Row {
	return t.tx.QueryRowContext(ctx, q, args...)
}

func (s *Store) stockOnHandWith(ctx context.Context, q querier, storeID, sku string) (int64, error) {
	var sum sql.NullInt64
	err := q.QueryRowContext(ctx, `
		SELECT COALESCE(SUM(delta), 0)
		FROM inventory_movements
		WHERE sku = ? AND store_id = ? AND voided_at IS NULL
	`, sku, storeID).Scan(&sum)
	if err != nil {
		return 0, fmt.Errorf("inventory: stock on hand: %w", err)
	}
	if !sum.Valid {
		return 0, nil
	}
	return sum.Int64, nil
}

func nullableString(s string) any {
	if s == "" {
		return nil
	}
	return s
}

type rowScanner interface {
	Scan(dest ...any) error
}

func scanMovement(row rowScanner) (Movement, error) {
	var (
		m              Movement
		idStr          string
		counterID      sql.NullString
		reasonStr      string
		occurredAtNs   int64
		voidedAtNs     sql.NullInt64
		voidedByIDStr  sql.NullString
	)
	err := row.Scan(&m.ID, &idStr, &m.SKU, &m.StoreID, &counterID, &m.Delta, &reasonStr,
		&m.RefType, &m.RefID, &occurredAtNs, &m.Lamport, &m.OriginNodeID,
		&voidedAtNs, &voidedByIDStr)
	if err != nil {
		return Movement{}, err
	}
	if m.MovementID, err = uuid.Parse(idStr); err != nil {
		return Movement{}, fmt.Errorf("inventory: parse movement_id %q: %w", idStr, err)
	}
	if counterID.Valid {
		m.CounterID = counterID.String
	}
	m.Reason = Reason(reasonStr)
	m.OccurredAt = time.Unix(0, occurredAtNs).UTC()
	if voidedAtNs.Valid {
		m.VoidedAt = time.Unix(0, voidedAtNs.Int64).UTC()
	}
	if voidedByIDStr.Valid && voidedByIDStr.String != "" {
		if m.VoidedByID, err = uuid.Parse(voidedByIDStr.String); err != nil {
			return Movement{}, fmt.Errorf("inventory: parse voided_by_id %q: %w", voidedByIDStr.String, err)
		}
	}
	return m, nil
}
