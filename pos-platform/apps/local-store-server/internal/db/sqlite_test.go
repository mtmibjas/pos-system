package db_test

import (
	"context"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/require"

	"github.com/mibjas/pos-platform/apps/local-store-server/internal/db"
)

func TestOpen_AppliesMandatoryPragmas(t *testing.T) {
	ctx := context.Background()
	path := filepath.Join(t.TempDir(), "test.db")

	sqlDB, err := db.Open(ctx, db.Config{Path: path})
	require.NoError(t, err)
	t.Cleanup(func() { _ = sqlDB.Close() })

	checks := []struct {
		pragma string
		want   string
	}{
		{"journal_mode", "wal"},
		{"foreign_keys", "1"},
		{"synchronous", "1"}, // NORMAL = 1
	}
	for _, c := range checks {
		var got string
		require.NoError(t, sqlDB.QueryRowContext(ctx, "PRAGMA "+c.pragma).Scan(&got))
		require.Equal(t, c.want, got, "pragma %s", c.pragma)
	}

	var busyMs int
	require.NoError(t, sqlDB.QueryRowContext(ctx, "PRAGMA busy_timeout").Scan(&busyMs))
	require.Equal(t, 5000, busyMs)
}

func TestOpen_MissingPathIsError(t *testing.T) {
	_, err := db.Open(context.Background(), db.Config{})
	require.Error(t, err)
}

func TestRunMigrations_AppliesCleanly(t *testing.T) {
	ctx := context.Background()
	path := filepath.Join(t.TempDir(), "test.db")
	sqlDB, err := db.Open(ctx, db.Config{Path: path})
	require.NoError(t, err)
	t.Cleanup(func() { _ = sqlDB.Close() })

	require.NoError(t, db.RunMigrations(sqlDB))

	// operations_log table exists with the expected columns.
	rows, err := sqlDB.QueryContext(ctx, "PRAGMA table_info(operations_log)")
	require.NoError(t, err)
	defer rows.Close()

	cols := map[string]bool{}
	for rows.Next() {
		var (
			cid     int
			name    string
			ctype   string
			notnull int
			dflt    any
			pk      int
		)
		require.NoError(t, rows.Scan(&cid, &name, &ctype, &notnull, &dflt, &pk))
		cols[name] = true
	}
	require.NoError(t, rows.Err())

	want := []string{
		"id", "operation_id", "operation_type", "entity_type", "entity_id",
		"payload", "created_at", "lamport", "origin_node_id", "sync_status",
		"retry_count", "last_error", "batch_id",
	}
	for _, c := range want {
		require.True(t, cols[c], "missing column %s", c)
	}
}

func TestRunMigrations_Idempotent(t *testing.T) {
	ctx := context.Background()
	path := filepath.Join(t.TempDir(), "test.db")
	sqlDB, err := db.Open(ctx, db.Config{Path: path})
	require.NoError(t, err)
	t.Cleanup(func() { _ = sqlDB.Close() })

	require.NoError(t, db.RunMigrations(sqlDB))
	// Running again must be a no-op, not an error.
	require.NoError(t, db.RunMigrations(sqlDB))
}
