// Package db opens the local SQLite database with the mandatory PRAGMAs
// (WAL mode + friends) and applies migrations.
//
// All apps/local-store-server data lives in a single SQLite file. The choice
// of driver is modernc.org/sqlite — pure Go, no CGO — so the binary stays
// statically linkable per Development Guide §24.
package db

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"net/url"

	_ "modernc.org/sqlite" // registers "sqlite" driver
)

// Config configures the local SQLite database.
type Config struct {
	// Path is the on-disk file path. Required.
	// For in-memory testing use ":memory:" — but note WAL mode disables itself
	// for in-memory DBs, so prefer t.TempDir() in tests.
	Path string
}

// Open opens the SQLite database, applies mandatory PRAGMAs on every connection,
// verifies WAL is active, and returns the *sql.DB. Callers must Close() it.
//
// Mandatory PRAGMAs (see Development Guide §3 + docs/sync-rules.md):
//   - journal_mode=WAL       — readers don't block writers
//   - foreign_keys=ON        — SQLite defaults FK off; we want it on
//   - synchronous=NORMAL     — WAL sweet spot; FULL is overkill, OFF risks data
//   - busy_timeout=5000      — wait up to 5s for a write lock instead of erroring
//   - cache_size=-20000      — 20 MB page cache per connection
//   - temp_store=MEMORY      — temp tables in RAM
func Open(ctx context.Context, cfg Config) (*sql.DB, error) {
	if cfg.Path == "" {
		return nil, errors.New("db: Config.Path is required")
	}

	// _pragma= URL params are applied per connection by modernc.org/sqlite,
	// so they take effect for every pooled connection (including ones
	// reopened after idle eviction).
	q := url.Values{}
	q.Add("_pragma", "journal_mode(WAL)")
	q.Add("_pragma", "foreign_keys(ON)")
	q.Add("_pragma", "synchronous(NORMAL)")
	q.Add("_pragma", "busy_timeout(5000)")
	q.Add("_pragma", "cache_size(-20000)")
	q.Add("_pragma", "temp_store(MEMORY)")
	// BEGIN IMMEDIATE on every transaction — write lock acquired up front.
	// Avoids the SQLITE_BUSY upgrade-deadlock that bites DEFERRED txns when a
	// transaction starts as a read and tries to escalate to a write while
	// another writer holds the lock.
	q.Set("_txlock", "immediate")

	dsn := fmt.Sprintf("file:%s?%s", cfg.Path, q.Encode())

	sqlDB, err := sql.Open("sqlite", dsn)
	if err != nil {
		return nil, fmt.Errorf("db: open: %w", err)
	}

	// SQLite serializes writes (WAL allows concurrent reads + one writer).
	// Capping at 1 connection makes write contention deterministic and avoids
	// surprise SQLITE_BUSY for the busy_timeout window. We'll revisit if/when
	// we add a separate read pool.
	sqlDB.SetMaxOpenConns(1)

	if err := sqlDB.PingContext(ctx); err != nil {
		_ = sqlDB.Close()
		return nil, fmt.Errorf("db: ping: %w", err)
	}

	// Sanity-check that WAL actually engaged. If a PRAGMA silently failed
	// (e.g. a typo in the DSN), we want to fail loudly here, not weeks later
	// when a crash corrupts a non-WAL DB.
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
