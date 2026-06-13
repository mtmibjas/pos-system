// Package users is the file-backed credential store for local UAT and
// internal-developer cloud-api deployments. Loads a YAML file at boot
// (no hot reload — restart the process to pick up changes) and answers
// Authenticate(username, password) in constant time per user.
//
// What this package does NOT do:
//   - Hot reload (intentional: keep the boot footprint obvious).
//   - Password resets / change-password flows (the file is hand-edited).
//   - Lockout / rate-limit on failed attempts (a reverse proxy concern).
//   - Multi-tenant routing beyond the tenant_id on each user record.
//
// When a real users table lands (post-UAT), this package goes away —
// the handler in internal/api/auth_login.go talks to an Authenticator
// interface, so the swap is one file.
package users

import (
	"errors"
	"fmt"
	"os"

	"golang.org/x/crypto/bcrypt"
	"gopkg.in/yaml.v3"
)

// ErrInvalidCredentials is the only error the login handler surfaces to
// the client. We deliberately do NOT differentiate "unknown username"
// from "wrong password" — that would leak which usernames exist.
var ErrInvalidCredentials = errors.New("users: invalid credentials")

// User is one entry from the YAML file. BcryptHash is the $2a$ string
// produced by bcrypt.GenerateFromPassword; the plaintext password is
// never seen by this package.
type User struct {
	Username   string   `yaml:"username"`
	TenantID   string   `yaml:"tenant_id"`
	Roles      []string `yaml:"roles"`
	BcryptHash string   `yaml:"bcrypt"`
}

// fileShape mirrors the YAML root for unmarshal. Kept separate from
// the public surface so a future field rename in the file doesn't leak
// into callers.
type fileShape struct {
	Users []User `yaml:"users"`
}

// Store is an in-memory index of users by username. Safe for concurrent
// reads (Authenticate); not safe for mutation after Load returns.
type Store struct {
	byName map[string]User
}

// Load parses path. Returns a populated Store or a descriptive error.
// Empty file / missing `users:` key → an empty store (every login 401s).
// Duplicate usernames are a hard error — silently last-wins would hide
// a real misconfiguration.
func Load(path string) (*Store, error) {
	body, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("users: read %s: %w", path, err)
	}
	var f fileShape
	if err := yaml.Unmarshal(body, &f); err != nil {
		return nil, fmt.Errorf("users: parse %s: %w", path, err)
	}

	byName := make(map[string]User, len(f.Users))
	for i, u := range f.Users {
		switch {
		case u.Username == "":
			return nil, fmt.Errorf("users: entry %d has empty username", i)
		case u.TenantID == "":
			return nil, fmt.Errorf("users: user %q has empty tenant_id", u.Username)
		case u.BcryptHash == "":
			return nil, fmt.Errorf("users: user %q has empty bcrypt hash", u.Username)
		}
		if _, dup := byName[u.Username]; dup {
			return nil, fmt.Errorf("users: duplicate username %q", u.Username)
		}
		byName[u.Username] = u
	}
	return &Store{byName: byName}, nil
}

// Authenticate compares password against the stored bcrypt hash for
// username. Returns ErrInvalidCredentials on any failure (unknown user,
// wrong password, malformed hash) — never leaks which.
//
// bcrypt.CompareHashAndPassword runs in time proportional to the cost
// factor of the *stored* hash, so per-user cost is constant. We pay the
// hash cost even on unknown-username so timing doesn't leak existence —
// see the dummy-hash branch.
func (s *Store) Authenticate(username, password string) (User, error) {
	u, ok := s.byName[username]
	if !ok {
		// Burn a hash compare so unknown-user and wrong-password look the
		// same to a timing-based attacker. The cost is a few ms once per
		// failed attempt.
		_ = bcrypt.CompareHashAndPassword(dummyHash, []byte(password))
		return User{}, ErrInvalidCredentials
	}
	if err := bcrypt.CompareHashAndPassword([]byte(u.BcryptHash), []byte(password)); err != nil {
		return User{}, ErrInvalidCredentials
	}
	return u, nil
}

// Count is exposed so the operator log on boot can show how many users
// were loaded — a 0 here is almost always a misconfigured file path.
func (s *Store) Count() int { return len(s.byName) }

// dummyHash is a precomputed bcrypt of the literal string "dummy" at
// cost 10. Used by Authenticate to keep unknown-username and wrong-
// password indistinguishable in wall-clock time. The value here will
// never match any sensible real password.
var dummyHash = []byte("$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy")
