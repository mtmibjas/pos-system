// Package users is the store-server's local user store, backing
// AuthService.Login. See docs/store-server-auth-contract.md.
//
// Offline-first: users live LOCAL so a cashier can log in with the cloud
// unreachable. The schema is ported from cloud-api's 000003_users (plus a
// display_name column) so the future cloud->store user sync is a straight
// copy. Until that sync lands, seed with Create (see cmd/seed-* / tests).
//
// Security posture mirrors cloud-api: Authenticate burns a dummy bcrypt
// compare on unknown usernames so timing doesn't reveal which usernames
// exist, and a disabled account fails with the same ErrInvalidCredentials
// as a wrong password.
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

// ErrInvalidCredentials is the only failure AuthService surfaces for a bad
// login — never "no such user" vs "wrong password" vs "disabled", so the
// surface can't be used to enumerate usernames.
var ErrInvalidCredentials = errors.New("users: invalid credentials")

// ErrUsernameTaken is returned by Create when the username already exists
// (including disabled users — usernames are never recycled).
var ErrUsernameTaken = errors.New("users: username already taken")

// User is the authenticated identity AuthService needs to mint a session
// token + render the client. BcryptHash is deliberately not exposed.
type User struct {
	Username    string
	TenantID    string
	Roles       []string
	DisplayName string
}

// HasRole reports whether the user carries role r.
func (u User) HasRole(r string) bool {
	for _, have := range u.Roles {
		if have == r {
			return true
		}
	}
	return false
}

// Store reads/writes the users table. Safe for concurrent use (the *sql.DB
// pool handles locking; SQLite serializes writers).
type Store struct {
	db  *sql.DB
	now func() time.Time
}

// NewStore wires a store over an already-migrated database handle.
func NewStore(db *sql.DB) *Store {
	return &Store{db: db, now: time.Now}
}

// Authenticate verifies username+password against the bcrypt hash and
// returns the User. ErrInvalidCredentials on unknown user, wrong password,
// or disabled account — never says which.
func (s *Store) Authenticate(ctx context.Context, username, password string) (User, error) {
	row := s.db.QueryRowContext(ctx,
		`SELECT tenant_id, roles, bcrypt_hash, display_name, disabled
		 FROM users WHERE username = ?`, username)
	var (
		tenant, rolesJSON, hash, displayName string
		disabled                             int
	)
	if err := row.Scan(&tenant, &rolesJSON, &hash, &displayName, &disabled); err != nil {
		// Unknown user: burn a compare so wall-clock matches the
		// known-user-wrong-password path.
		_ = bcrypt.CompareHashAndPassword(dummyHash, []byte(password))
		return User{}, ErrInvalidCredentials
	}
	if err := bcrypt.CompareHashAndPassword([]byte(hash), []byte(password)); err != nil {
		return User{}, ErrInvalidCredentials
	}
	if disabled != 0 {
		// Checked AFTER the hash compare so a disabled account costs the
		// same wall-clock as a wrong password.
		return User{}, ErrInvalidCredentials
	}
	var roles []string
	if err := json.Unmarshal([]byte(rolesJSON), &roles); err != nil {
		return User{}, ErrInvalidCredentials
	}
	return User{
		Username:    username,
		TenantID:    tenant,
		Roles:       roles,
		DisplayName: displayName,
	}, nil
}

// Create inserts a new user with a bcrypt-hashed password. Used for UAT
// seeding (and tests) until the cloud->store user sync lands. displayName
// may be "" (login then falls back to the username).
func (s *Store) Create(ctx context.Context, username, tenantID, password string, roles []string, displayName string) error {
	hash, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		return fmt.Errorf("users: hash: %w", err)
	}
	rolesJSON, err := json.Marshal(nonEmpty(roles))
	if err != nil {
		return fmt.Errorf("users: roles: %w", err)
	}
	now := s.now().UTC().Unix()
	_, err = s.db.ExecContext(ctx,
		`INSERT INTO users (username, tenant_id, roles, bcrypt_hash, display_name, disabled, created_at, updated_at)
		 VALUES (?, ?, ?, ?, ?, 0, ?, ?)`,
		username, tenantID, string(rolesJSON), string(hash), displayName, now, now)
	if err != nil {
		if isUniqueViolation(err) {
			return ErrUsernameTaken
		}
		return fmt.Errorf("users: create: %w", err)
	}
	return nil
}

// Count returns the total user count (enabled + disabled), for the boot
// log line and seed guards.
func (s *Store) Count(ctx context.Context) (int, error) {
	var n int
	if err := s.db.QueryRowContext(ctx, `SELECT COUNT(*) FROM users`).Scan(&n); err != nil {
		return 0, fmt.Errorf("users: count: %w", err)
	}
	return n, nil
}

// dummyHash is a bcrypt hash used only to equalize Authenticate's timing on
// unknown usernames. Generated once at init (the plaintext is irrelevant).
var dummyHash, _ = bcrypt.GenerateFromPassword([]byte("dummy-timing-password"), bcrypt.DefaultCost)

// nonEmpty drops empty-string roles and normalizes nil → empty slice so
// JSON marshals as [] not null (mirrors cloud-api).
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
// importing the driver package (keeps this driver-agnostic for the
// Postgres future; revisit the match strings then).
func isUniqueViolation(err error) bool {
	return err != nil && (strings.Contains(err.Error(), "UNIQUE constraint failed") ||
		strings.Contains(err.Error(), "duplicate key"))
}
