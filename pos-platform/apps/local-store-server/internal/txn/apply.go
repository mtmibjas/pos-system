// Package txn provides the atomic batch helper used everywhere a write
// touches multiple tables.
//
// Per Development Guide §16 ("local completed sales are never rejected" +
// "inventory ledger is append-only") and docs/sync-rules.md ("Batching —
// atomic groups"), a sale finalization must persist:
//
//	1. operations_log row(s) for the SaleCreated, PaymentAdded, InventoryAdjusted events
//	2. inventory_movements row(s) for the stock decrement
//	3. payments row(s) for the tender(s)
//
// Either all of those persist or none do. txn.Apply wraps that requirement
// in a single function call.
package txn

import (
	"context"
	"database/sql"
	"fmt"
)

// Apply runs fn inside a single SQL transaction. If fn returns an error, the
// transaction is rolled back. If fn panics, the transaction is rolled back
// and the panic is rethrown. Otherwise the transaction is committed.
//
// The underlying DB is configured with _txlock=immediate (see db/sqlite.go),
// so the write lock is acquired at BEGIN — concurrent writers serialize
// cleanly with the configured busy_timeout instead of deadlocking on upgrade.
func Apply(ctx context.Context, db *sql.DB, fn func(*sql.Tx) error) (err error) {
	tx, err := db.BeginTx(ctx, nil)
	if err != nil {
		return fmt.Errorf("txn: begin: %w", err)
	}

	defer func() {
		if p := recover(); p != nil {
			_ = tx.Rollback()
			panic(p)
		}
		if err != nil {
			_ = tx.Rollback()
		}
	}()

	if err = fn(tx); err != nil {
		return err
	}
	if err = tx.Commit(); err != nil {
		return fmt.Errorf("txn: commit: %w", err)
	}
	return nil
}
