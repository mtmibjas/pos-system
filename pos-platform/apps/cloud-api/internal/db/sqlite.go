// Package db opens the cloud-api's local SQLite database with the
// mandatory PRAGMAs and applies migrations.
//
// SQLite is used here as the dev/test storage — the schema is
// Postgres-portable (see migrations) so promoting to Postgres in a
// later phase is a driver swap + minor type-name edits.
package db

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"net/url"

	_ "modernc.org/sqlite" // registers "sqlite" driver
)

// Config configures the cloud-api SQLite database.
type Config struct {
	// Path is the on-disk file path. Required.
	// In-memory ":memory:" is fine for tests but doesn't get WAL — prefer
	// a t.TempDir() file when testing concurrent behaviour.
	Path string
}

// Open opens the SQLite database, applies mandatory PRAGMAs, verifies
// WAL is active, and returns the *sql.DB. Callers must Close() it.
//
// Mandatory PRAGMAs (mirror local-store-server's `internal/db.Open`):
//   - journal_mode=WAL       — readers don't block writers
//   - foreign_keys=ON        — referential integrity for events.batch_id
//   - synchronous=NORMAL     — WAL sweet spot
//   - busy_timeout=5000      — wait up to 5s for a write lock
//   - cache_size=-20000      — 20 MB page cache per connection
//   - temp_store=MEMORY      — temp tables in RAM
func Open(ctx context.Context, cfg Config) (*sql.DB, error) {
	if cfg.Path == "" {
		return nil, errors.New("db: Config.Path is required")
	}

	q := url.Values{}
	q.Add("_pragma", "journal_mode(WAL)")
	q.Add("_pragma", "foreign_keys(ON)")
	q.Add("_pragma", "synchronous(NORMAL)")
	q.Add("_pragma", "busy_timeout(5000)")
	q.Add("_pragma", "cache_size(-20000)")
	q.Add("_pragma", "temp_store(MEMORY)")
	// IMMEDIATE acquires the write lock up front; avoids SQLITE_BUSY
	// upgrade-deadlock when a read txn tries to escalate.
	q.Set("_txlock", "immediate")

	dsn := fmt.Sprintf("file:%s?%s", cfg.Path, q.Encode())

	sqlDB, err := sql.Open("sqlite", dsn)
	if err != nil {
		return nil, fmt.Errorf("db: open: %w", err)
	}

	// SQLite serializes writes; cap connections at 1 so write contention
	// is deterministic. Postgres swap-out lifts this naturally.
	sqlDB.SetMaxOpenConns(1)

	if err := sqlDB.PingContext(ctx); err != nil {
		_ = sqlDB.Close()
		return nil, fmt.Errorf("db: ping: %w", err)
	}

	var mode string
	if err := sqlDB.QueryRowContext(ctx, "PRAGMA journal_mode").Scan(&mode); err != nil {
		_ = sqlDB.Close()
		return nil, fmt.Errorf("db: verify journal_mode: %w", err)
	}
	if mode != "wal" {
		_ = sqlDB.Close()
		return nil, fmt.Errorf("db: expected journal_mode=wal, got %q", mode)
	}

	return sqlDB, nil
}
