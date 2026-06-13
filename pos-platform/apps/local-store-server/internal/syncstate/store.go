// Package syncstate is a thin K/V wrapper over the sync_state table.
//
// Why a K/V layer (and not typed columns per datum): the set of metadata we
// care about will grow as sync evolves (checkpoints, feature flags, op-counts
// for the dashboard). A migration per new datum is friction we don't need —
// see 000004_sync_state.up.sql for the canonical list of well-known keys.
package syncstate

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"strconv"
	"time"

	"github.com/google/uuid"
)

// Well-known keys. Documented in 000004_sync_state.up.sql.
const (
	KeyLastSyncAt       = "last_sync_at"        // unix-nanos as decimal string
	KeyLastSyncBatchID  = "last_sync_batch_id"  // UUID string
	KeyNextLamport      = "next_lamport"        // uint64 as decimal string
	KeyFailedOpsCount   = "failed_ops_count"    // int64 as decimal string
)

// ErrNotFound is returned by Get/GetX when a key has never been written.
var ErrNotFound = errors.New("syncstate: key not found")

type Store struct {
	db *sql.DB
}

func NewStore(sqlDB *sql.DB) *Store {
	return &Store{db: sqlDB}
}

// Set writes (or replaces) a key. updated_at is stamped to now (UTC).
func (s *Store) Set(ctx context.Context, key, value string) error {
	if key == "" {
		return errors.New("syncstate: key is required")
	}
	_, err := s.db.ExecContext(ctx, `
		INSERT INTO sync_state (key, value, updated_at) VALUES (?, ?, ?)
		ON CONFLICT(key) DO UPDATE SET value = excluded.value, updated_at = excluded.updated_at
	`, key, value, time.Now().UTC().UnixNano())
	if err != nil {
		return fmt.Errorf("syncstate: set %q: %w", key, err)
	}
	return nil
}

// Get reads a key. Returns ErrNotFound if the key has never been written.
func (s *Store) Get(ctx context.Context, key string) (string, error) {
	var v string
	err := s.db.QueryRowContext(ctx,
		`SELECT value FROM sync_state WHERE key = ?`, key).Scan(&v)
	if errors.Is(err, sql.ErrNoRows) {
		return "", ErrNotFound
	}
	if err != nil {
		return "", fmt.Errorf("syncstate: get %q: %w", key, err)
	}
	return v, nil
}

// SetTime is a typed setter for unix-nanos timestamps.
func (s *Store) SetTime(ctx context.Context, key string, t time.Time) error {
	return s.Set(ctx, key, strconv.FormatInt(t.UTC().UnixNano(), 10))
}

// GetTime parses the value as unix-nanos.
func (s *Store) GetTime(ctx context.Context, key string) (time.Time, error) {
	raw, err := s.Get(ctx, key)
	if err != nil {
		return time.Time{}, err
	}
	ns, err := strconv.ParseInt(raw, 10, 64)
	if err != nil {
		return time.Time{}, fmt.Errorf("syncstate: parse time at %q: %w", key, err)
	}
	return time.Unix(0, ns).UTC(), nil
}

// SetUint64 / GetUint64 — used for next_lamport.
func (s *Store) SetUint64(ctx context.Context, key string, v uint64) error {
	return s.Set(ctx, key, strconv.FormatUint(v, 10))
}

func (s *Store) GetUint64(ctx context.Context, key string) (uint64, error) {
	raw, err := s.Get(ctx, key)
	if err != nil {
		return 0, err
	}
	v, err := strconv.ParseUint(raw, 10, 64)
	if err != nil {
		return 0, fmt.Errorf("syncstate: parse uint64 at %q: %w", key, err)
	}
	return v, nil
}

// SetUUID / GetUUID — used for last_sync_batch_id.
func (s *Store) SetUUID(ctx context.Context, key string, u uuid.UUID) error {
	return s.Set(ctx, key, u.String())
}

func (s *Store) GetUUID(ctx context.Context, key string) (uuid.UUID, error) {
	raw, err := s.Get(ctx, key)
	if err != nil {
		return uuid.Nil, err
	}
	u, err := uuid.Parse(raw)
	if err != nil {
		return uuid.Nil, fmt.Errorf("syncstate: parse uuid at %q: %w", key, err)
	}
	return u, nil
}
