// DB-backed user store — slice 6.1. Supersedes the YAML file store for
// serving traffic; the YAML file remains as a one-time seed source
// (ImportFromFile) so existing local setups migrate on first boot.
//
// Same security posture as the file store: Authenticate burns a dummy
// bcrypt compare on unknown usernames, and disabled users fail with the
// same ErrInvalidCredentials as everything else.
package users

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"time"

	"golang.org/x/crypto/bcrypt"
)

// ErrUsernameTaken is returned by Create when the username exists
// (including disabled users — usernames are never recycled).
var ErrUsernameTaken = errors.New("users: username already taken")

// ErrNotFound is returned by Update/Get for an unknown username.
var ErrNotFound = errors.New("users: not found")

// Record is the DB shape of a user. Distinct from the YAML User struct
// so file-format and DB-format can evolve independently.
type Record struct {
	Username   string    `json:"username"`
	TenantID   string    `json:"tenant_id"`
	Roles      []string  `json:"roles"`
	BcryptHash string    `json:"-"` // never serialized to API responses
	Disabled   bool      `json:"disabled"`
	CreatedAt  time.Time `json:"created_at"`
	UpdatedAt  time.Time `json:"updated_at"`
}

// DBStore reads/writes the users table. Safe for concurrent use (the
// *sql.DB pool handles locking; SQLite serializes writers).
type DBStore struct {
	db  *sql.DB
	now func() time.Time
}

// NewDBStore wires a store over an already-migrated database handle.
func NewDBStore(db *sql.DB) *DBStore {
	return &DBStore{db: db, now: time.Now}
}

// Authenticate mirrors Store.Authenticate: ErrInvalidCredentials on
// unknown user, wrong password, or disabled account — never says which.
func (s *DBStore) Authenticate(username, password string) (User, error) {
	row := s.db.QueryRow(
		`SELECT tenant_id, roles, bcrypt_hash, disabled FROM users WHERE username = ?`, username)
	var (
		tenant, rolesJSON, hash string
		disabled                bool
	)
	if err := row.Scan(&tenant, &rolesJSON, &hash, &disabled); err != nil {
		_ = bcrypt.CompareHashAndPassword(dummyHash, []byte(password))
		return User{}, ErrInvalidCredentials
	}
	if err := bcrypt.CompareHashAndPassword([]byte(hash), []byte(password)); err != nil {
		return User{}, ErrInvalidCredentials
	}
	if disabled {
		// Checked AFTER the hash compare so a disabled account costs the
		// same wall-clock as a wrong password.
		return User{}, ErrInvalidCredentials
	}
	var roles []string
	if err := json.Unmarshal([]byte(rolesJSON), &roles); err != nil {
		return User{}, ErrInvalidCredentials
	}
	return User{Username: username, TenantID: tenant, Roles: roles, BcryptHash: hash}, nil
}

// Count returns the total user count (enabled + disabled), for the boot
// log line.
func (s *DBStore) Count() int {
	var n int
	_ = s.db.QueryRow(`SELECT COUNT(*) FROM users`).Scan(&n)
	return n
}

// List returns all users of one tenant, ordered by username. Hashes are
// populated on the Record but excluded from JSON by the struct tag.
func (s *DBStore) List(ctx context.Context, tenantID string) ([]Record, error) {
	rows, err := s.db.QueryContext(ctx,
		`SELECT username, tenant_id, roles, bcrypt_hash, disabled, created_at, updated_at
		 FROM users WHERE tenant_id = ? ORDER BY username`, tenantID)
	if err != nil {
		return nil, fmt.Errorf("users: list: %w", err)
	}
	defer rows.Close()

	var out []Record
	for rows.Next() {
		r, err := scanRecord(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, r)
	}
	return out, rows.Err()
}

// Get fetches one user by username, tenant-scoped. ErrNotFound covers
// both "no such user" and "user belongs to another tenant" so handlers
// can't be used as a cross-tenant existence oracle.
func (s *DBStore) Get(ctx context.Context, tenantID, username string) (Record, error) {
	row := s.db.QueryRowContext(ctx,
		`SELECT username, tenant_id, roles, bcrypt_hash, disabled, created_at, updated_at
		 FROM users WHERE username = ? AND tenant_id = ?`, username, tenantID)
	r, err := scanRecord(row)
	if errors.Is(err, sql.ErrNoRows) {
		return Record{}, ErrNotFound
	}
	return r, err
}

// Create inserts a new user with a bcrypt-hashed password.
func (s *DBStore) Create(ctx context.Context, tenantID, username, password string, roles []string) (Record, error) {
	hash, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		return Record{}, fmt.Errorf("users: hash: %w", err)
	}
	rolesJSON, err := json.Marshal(nonEmpty(roles))
	if err != nil {
		return Record{}, fmt.Errorf("users: roles: %w", err)
	}
	now := s.now().UTC()
	_, err = s.db.ExecContext(ctx,
		`INSERT INTO users (username, tenant_id, roles, bcrypt_hash, disabled, created_at, updated_at)
		 VALUES (?, ?, ?, ?, 0, ?, ?)`,
		username, tenantID, string(rolesJSON), string(hash), now.Unix(), now.Unix())
	if err != nil {
		if isUniqueViolation(err) {
			return Record{}, ErrUsernameTaken
		}
		return Record{}, fmt.Errorf("users: create: %w", err)
	}
	return Record{
		Username: username, TenantID: tenantID, Roles: nonEmpty(roles),
		BcryptHash: string(hash), CreatedAt: now, UpdatedAt: now,
	}, nil
}

// Patch carries optional field updates for Update. Nil pointer = leave
// unchanged.
type Patch struct {
	Password *string
	Disabled *bool
	Roles    *[]string
}

// Update applies a partial update, tenant-scoped. Returns the updated
// record. Username is immutable by design (it's the PK and appears in
// JWT subjects).
func (s *DBStore) Update(ctx context.Context, tenantID, username string, p Patch) (Record, error) {
	cur, err := s.Get(ctx, tenantID, username)
	if err != nil {
		return Record{}, err
	}
	if p.Password != nil {
		hash, err := bcrypt.GenerateFromPassword([]byte(*p.Password), bcrypt.DefaultCost)
		if err != nil {
			return Record{}, fmt.Errorf("users: hash: %w", err)
		}
		cur.BcryptHash = string(hash)
	}
	if p.Disabled != nil {
		cur.Disabled = *p.Disabled
	}
	if p.Roles != nil {
		cur.Roles = nonEmpty(*p.Roles)
	}
	rolesJSON, err := json.Marshal(cur.Roles)
	if err != nil {
		return Record{}, fmt.Errorf("users: roles: %w", err)
	}
	cur.UpdatedAt = s.now().UTC()
	_, err = s.db.ExecContext(ctx,
		`UPDATE users SET roles = ?, bcrypt_hash = ?, disabled = ?, updated_at = ?
		 WHERE username = ? AND tenant_id = ?`,
		string(rolesJSON), cur.BcryptHash, cur.Disabled, cur.UpdatedAt.Unix(), username, tenantID)
	if err != nil {
		return Record{}, fmt.Errorf("users: update: %w", err)
	}
	return cur, nil
}

// ImportFromFile seeds the users table from a YAML file store, but ONLY
// when the table is empty — re-running on every boot is a no-op once
// any user exists, so DB edits are never clobbered by a stale file.
// Returns the number of users imported (0 = table wasn't empty or the
// file had none).
func (s *DBStore) ImportFromFile(ctx context.Context, fileStore *Store) (int, error) {
	if s.Count() > 0 {
		return 0, nil
	}
	now := s.now().UTC().Unix()
	n := 0
	for _, u := range fileStore.byName {
		rolesJSON, err := json.Marshal(nonEmpty(u.Roles))
		if err != nil {
			return n, fmt.Errorf("users: import %q: %w", u.Username, err)
		}
		_, err = s.db.ExecContext(ctx,
			`INSERT INTO users (username, tenant_id, roles, bcrypt_hash, disabled, created_at, updated_at)
			 VALUES (?, ?, ?, ?, 0, ?, ?)`,
			u.Username, u.TenantID, string(rolesJSON), u.BcryptHash, now, now)
		if err != nil {
			return n, fmt.Errorf("users: import %q: %w", u.Username, err)
		}
		n++
	}
	return n, nil
}

// scanner abstracts *sql.Row / *sql.Rows for scanRecord.
type scanner interface{ Scan(dest ...any) error }

func scanRecord(sc scanner) (Record, error) {
	var (
		r          Record
		rolesJSON  string
		disabled   int
		cAt, uAt   int64
	)
	if err := sc.Scan(&r.Username, &r.TenantID, &rolesJSON, &r.BcryptHash, &disabled, &cAt, &uAt); err != nil {
		return Record{}, err
	}
	if err := json.Unmarshal([]byte(rolesJSON), &r.Roles); err != nil {
		return Record{}, fmt.Errorf("users: bad roles for %q: %w", r.Username, err)
	}
	r.Disabled = disabled != 0
	r.CreatedAt = time.Unix(cAt, 0).UTC()
	r.UpdatedAt = time.Unix(uAt, 0).UTC()
	return r, nil
}

// nonEmpty drops empty-string roles (mirrors auth.Issuer's filtering)
// and normalizes nil → empty slice so JSON marshals as [] not null.
func nonEmpty(roles []string) []string {
	out := make([]string, 0, len(roles))
	for _, r := range roles {
		if r != "" {
			out = append(out, r)
		}
	}
	return out
}

// isUniqueViolation sniffs SQLite's unique-constraint error without
// importing the driver package (keeps this file driver-agnostic for
// the Postgres future; revisit the match strings then).
func isUniqueViolation(err error) bool {
	return err != nil && (strings.Contains(err.Error(), "UNIQUE constraint failed") ||
		strings.Contains(err.Error(), "duplicate key"))
}
