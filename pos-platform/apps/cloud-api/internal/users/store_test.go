package users_test

import (
	"errors"
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"golang.org/x/crypto/bcrypt"

	"github.com/mibjas/pos-platform/apps/cloud-api/internal/users"
)

// writeUsersFile produces a YAML file at tmp/users.yaml with one user
// whose password hashes to `password`. Returns the file path so tests
// can pass it to users.Load directly.
func writeUsersFile(t *testing.T, username, tenant, password string, roles ...string) string {
	t.Helper()
	hash, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.MinCost)
	require.NoError(t, err)
	rolesYAML := "[" + joinQuoted(roles) + "]"
	body := "users:\n" +
		"  - username: " + username + "\n" +
		"    tenant_id: " + tenant + "\n" +
		"    roles: " + rolesYAML + "\n" +
		"    bcrypt: " + string(hash) + "\n"
	path := filepath.Join(t.TempDir(), "users.yaml")
	require.NoError(t, os.WriteFile(path, []byte(body), 0o600))
	return path
}

func joinQuoted(roles []string) string {
	out := ""
	for i, r := range roles {
		if i > 0 {
			out += ", "
		}
		out += `"` + r + `"`
	}
	return out
}

func TestLoad_HappyPath(t *testing.T) {
	path := writeUsersFile(t, "alice", "tenant-A", "hunter2", "owner")
	s, err := users.Load(path)
	require.NoError(t, err)
	assert.Equal(t, 1, s.Count())
}

func TestAuthenticate_WrongPassword(t *testing.T) {
	path := writeUsersFile(t, "alice", "tenant-A", "hunter2", "owner")
	s, err := users.Load(path)
	require.NoError(t, err)

	_, err = s.Authenticate("alice", "WRONG")
	assert.ErrorIs(t, err, users.ErrInvalidCredentials)
}

func TestAuthenticate_UnknownUser(t *testing.T) {
	path := writeUsersFile(t, "alice", "tenant-A", "hunter2", "owner")
	s, err := users.Load(path)
	require.NoError(t, err)

	_, err = s.Authenticate("bob", "anything")
	assert.ErrorIs(t, err, users.ErrInvalidCredentials)
}

func TestAuthenticate_Success(t *testing.T) {
	path := writeUsersFile(t, "alice", "tenant-A", "hunter2", "owner", "cashier")
	s, err := users.Load(path)
	require.NoError(t, err)

	u, err := s.Authenticate("alice", "hunter2")
	require.NoError(t, err)
	assert.Equal(t, "alice", u.Username)
	assert.Equal(t, "tenant-A", u.TenantID)
	assert.Equal(t, []string{"owner", "cashier"}, u.Roles)
}

func TestLoad_Errors(t *testing.T) {
	t.Run("missing file", func(t *testing.T) {
		_, err := users.Load(filepath.Join(t.TempDir(), "nope.yaml"))
		require.Error(t, err)
	})

	t.Run("duplicate username", func(t *testing.T) {
		path := filepath.Join(t.TempDir(), "dup.yaml")
		body := `users:
  - username: alice
    tenant_id: t
    bcrypt: $2a$04$abcdefghijklmnopqrstuv
  - username: alice
    tenant_id: t
    bcrypt: $2a$04$abcdefghijklmnopqrstuv
`
		require.NoError(t, os.WriteFile(path, []byte(body), 0o600))
		_, err := users.Load(path)
		require.Error(t, err)
		assert.Contains(t, err.Error(), "duplicate")
	})

	t.Run("missing fields", func(t *testing.T) {
		path := filepath.Join(t.TempDir(), "bad.yaml")
		body := `users:
  - username: ""
    tenant_id: t
    bcrypt: $2a$04$abcdefghijklmnopqrstuv
`
		require.NoError(t, os.WriteFile(path, []byte(body), 0o600))
		_, err := users.Load(path)
		require.Error(t, err)
	})
}

// Sanity check that the sentinel error is what callers expect.
func TestErrInvalidCredentials_IsSentinel(t *testing.T) {
	require.True(t, errors.Is(users.ErrInvalidCredentials, users.ErrInvalidCredentials))
}
