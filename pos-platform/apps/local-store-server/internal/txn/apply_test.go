package txn_test

import (
	"context"
	"database/sql"
	"errors"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/require"

	"github.com/mibjas/pos-platform/apps/local-store-server/internal/db"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/txn"
)

func newDB(t *testing.T) *sql.DB {
	t.Helper()
	ctx := context.Background()
	path := filepath.Join(t.TempDir(), "txn.db")
	sqlDB, err := db.Open(ctx, db.Config{Path: path})
	require.NoError(t, err)
	t.Cleanup(func() { _ = sqlDB.Close() })
	require.NoError(t, db.RunMigrations(sqlDB))
	// scratch table for these tests; we don't want to depend on the domain
	// migrations' specifics — just on Apply's commit/rollback contract.
	_, err = sqlDB.ExecContext(ctx, `CREATE TABLE scratch (k TEXT PRIMARY KEY, v TEXT NOT NULL)`)
	require.NoError(t, err)
	return sqlDB
}

func countScratch(t *testing.T, db *sql.DB) int {
	t.Helper()
	var n int
	require.NoError(t, db.QueryRow(`SELECT COUNT(*) FROM scratch`).Scan(&n))
	return n
}

func TestApply_CommitsOnSuccess(t *testing.T) {
	d := newDB(t)
	ctx := context.Background()
	err := txn.Apply(ctx, d, func(tx *sql.Tx) error {
		_, err := tx.ExecContext(ctx, `INSERT INTO scratch VALUES (?, ?)`, "a", "1")
		return err
	})
	require.NoError(t, err)
	require.Equal(t, 1, countScratch(t, d))
}

func TestApply_RollsBackOnError(t *testing.T) {
	d := newDB(t)
	ctx := context.Background()
	boom := errors.New("boom")
	err := txn.Apply(ctx, d, func(tx *sql.Tx) error {
		if _, err := tx.ExecContext(ctx, `INSERT INTO scratch VALUES (?, ?)`, "a", "1"); err != nil {
			return err
		}
		return boom
	})
	require.ErrorIs(t, err, boom)
	require.Equal(t, 0, countScratch(t, d), "writes inside the failed tx must roll back")
}

func TestApply_RollsBackOnPanic(t *testing.T) {
	d := newDB(t)
	ctx := context.Background()

	require.Panics(t, func() {
		_ = txn.Apply(ctx, d, func(tx *sql.Tx) error {
			_, _ = tx.ExecContext(ctx, `INSERT INTO scratch VALUES (?, ?)`, "a", "1")
			panic("kaboom")
		})
	})
	require.Equal(t, 0, countScratch(t, d), "panics must roll back, not commit")
}

func TestApply_MultipleStatementsAtomicity(t *testing.T) {
	d := newDB(t)
	ctx := context.Background()

	// Two inserts: first succeeds, second hits PK conflict → both must roll back.
	err := txn.Apply(ctx, d, func(tx *sql.Tx) error {
		if _, err := tx.ExecContext(ctx, `INSERT INTO scratch VALUES (?, ?)`, "k", "1"); err != nil {
			return err
		}
		_, err := tx.ExecContext(ctx, `INSERT INTO scratch VALUES (?, ?)`, "k", "2") // PK conflict
		return err
	})
	require.Error(t, err)
	require.Equal(t, 0, countScratch(t, d))
}
