// Package devices is the store-server's registered-terminal store, backing
// AuthService.RegisterDevice + the device half of AuthService.Login. See
// docs/store-server-auth-contract.md §3–§5.
//
// A device is tier-1 of the two-tier auth model: an opaque secret minted
// once at registration, stored here only as a bcrypt hash, and checked at
// every Login. Storing the hash (not a long-lived JWT) is what makes a
// lost/retired terminal revocable.
package devices

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"strings"
	"time"

	"golang.org/x/crypto/bcrypt"
)

// ErrInvalidDevice is the generic failure for a bad device credential at
// Login — unknown device_id, wrong secret, or revoked device all collapse
// to this so the surface can't be used to enumerate devices.
var ErrInvalidDevice = errors.New("devices: invalid device credential")

// ErrCounterNotFound is returned by Register when replace_counter_id names
// a counter with no active device to replace.
var ErrCounterNotFound = errors.New("devices: no active device on counter")

// Device is a registered terminal. SecretBcryptHash is never exposed.
type Device struct {
	DeviceID     string
	TenantID     string
	StoreID      string
	CounterID    string
	DeviceName   string
	RegisteredBy string
	Disabled     bool
	CreatedAt    time.Time
	LastSeenAt   time.Time // zero when never logged in
}

// RegisterParams is the input to Register. The caller (AuthService) mints
// DeviceID + the plaintext secret, bcrypt-hashes the secret into
// SecretBcryptHash, and verifies the manager before calling here — this
// store is pure data access.
type RegisterParams struct {
	DeviceID         string
	TenantID         string
	StoreID          string
	DeviceName       string
	SecretBcryptHash string
	RegisteredBy     string // manager username, audit only
	ReplaceCounterID string // optional: re-provision this counter (till swap)
}

// Store reads/writes the devices table. Safe for concurrent use.
type Store struct {
	db  *sql.DB
	now func() time.Time
}

// NewStore wires a store over an already-migrated database handle.
func NewStore(db *sql.DB) *Store {
	return &Store{db: db, now: time.Now}
}

// Register provisions a terminal. With ReplaceCounterID empty it assigns the
// next sequential counter for the store and inserts a new row. With
// ReplaceCounterID set it revokes the active device on that counter and
// reuses the counter_id, so shift reports/audit stay continuous across a
// till swap. Both paths run in one transaction.
func (s *Store) Register(ctx context.Context, p RegisterParams) (Device, error) {
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return Device{}, fmt.Errorf("devices: begin: %w", err)
	}
	defer func() { _ = tx.Rollback() }() // no-op after Commit

	counterID := p.ReplaceCounterID
	if counterID != "" {
		res, err := tx.ExecContext(ctx,
			`UPDATE devices SET disabled = 1
			 WHERE store_id = ? AND counter_id = ? AND disabled = 0`,
			p.StoreID, counterID)
		if err != nil {
			return Device{}, fmt.Errorf("devices: revoke old: %w", err)
		}
		n, err := res.RowsAffected()
		if err != nil {
			return Device{}, fmt.Errorf("devices: revoke rows: %w", err)
		}
		if n == 0 {
			return Device{}, ErrCounterNotFound
		}
	} else {
		counterID, err = nextCounterID(ctx, tx, p.StoreID)
		if err != nil {
			return Device{}, err
		}
	}

	now := s.now().UTC()
	_, err = tx.ExecContext(ctx,
		`INSERT INTO devices
		   (device_id, tenant_id, store_id, counter_id, device_name,
		    secret_bcrypt_hash, disabled, registered_by, created_at, last_seen_at)
		 VALUES (?, ?, ?, ?, ?, ?, 0, ?, ?, NULL)`,
		p.DeviceID, p.TenantID, p.StoreID, counterID, p.DeviceName,
		p.SecretBcryptHash, p.RegisteredBy, now.Unix())
	if err != nil {
		// The partial unique index backstops a rare race where two
		// concurrent new registrations compute the same counter number.
		if isUniqueViolation(err) {
			return Device{}, fmt.Errorf("devices: counter %q already active (retry): %w", counterID, err)
		}
		return Device{}, fmt.Errorf("devices: insert: %w", err)
	}

	if err := tx.Commit(); err != nil {
		return Device{}, fmt.Errorf("devices: commit: %w", err)
	}
	return Device{
		DeviceID:     p.DeviceID,
		TenantID:     p.TenantID,
		StoreID:      p.StoreID,
		CounterID:    counterID,
		DeviceName:   p.DeviceName,
		RegisteredBy: p.RegisteredBy,
		CreatedAt:    now,
	}, nil
}

// Authenticate validates a device credential at Login: the device must
// exist, be enabled, and its secret must match. On success it stamps
// last_seen_at (best-effort) and returns the Device. Any failure →
// ErrInvalidDevice (no enumeration).
func (s *Store) Authenticate(ctx context.Context, deviceID, secret string) (Device, error) {
	row := s.db.QueryRowContext(ctx,
		`SELECT tenant_id, store_id, counter_id, device_name, secret_bcrypt_hash,
		        disabled, registered_by, created_at
		 FROM devices WHERE device_id = ?`, deviceID)
	var (
		d         Device
		hash      string
		disabled  int
		createdAt int64
	)
	if err := row.Scan(&d.TenantID, &d.StoreID, &d.CounterID, &d.DeviceName,
		&hash, &disabled, &d.RegisteredBy, &createdAt); err != nil {
		// Burn a compare so an unknown device_id costs the same wall-clock
		// as a known device with a wrong secret.
		_ = bcrypt.CompareHashAndPassword(dummyHash, []byte(secret))
		return Device{}, ErrInvalidDevice
	}
	if err := bcrypt.CompareHashAndPassword([]byte(hash), []byte(secret)); err != nil {
		return Device{}, ErrInvalidDevice
	}
	if disabled != 0 {
		return Device{}, ErrInvalidDevice
	}
	d.DeviceID = deviceID
	d.CreatedAt = time.Unix(createdAt, 0).UTC()

	now := s.now().UTC()
	if _, err := s.db.ExecContext(ctx,
		`UPDATE devices SET last_seen_at = ? WHERE device_id = ?`, now.Unix(), deviceID); err == nil {
		d.LastSeenAt = now
	}
	return d, nil
}

// nextCounterID derives the next per-store counter as "counter-<N>" where N
// is one past the count of DISTINCT counter_ids ever assigned for the store.
// Revoked rows still count, so numbers are never recycled — a replacement
// reuses an existing counter_id and does NOT call this.
func nextCounterID(ctx context.Context, tx *sql.Tx, storeID string) (string, error) {
	var distinct int
	err := tx.QueryRowContext(ctx,
		`SELECT COUNT(DISTINCT counter_id) FROM devices WHERE store_id = ?`, storeID).Scan(&distinct)
	if err != nil {
		return "", fmt.Errorf("devices: next counter: %w", err)
	}
	return fmt.Sprintf("counter-%d", distinct+1), nil
}

// dummyHash equalizes Authenticate's timing for unknown device_ids.
var dummyHash, _ = bcrypt.GenerateFromPassword([]byte("dummy-timing-secret"), bcrypt.DefaultCost)

// isUniqueViolation sniffs SQLite's unique-constraint error without
// importing the driver package.
func isUniqueViolation(err error) bool {
	return err != nil && (strings.Contains(err.Error(), "UNIQUE constraint failed") ||
		strings.Contains(err.Error(), "duplicate key"))
}
