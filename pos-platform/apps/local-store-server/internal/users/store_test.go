package users_test

import (
	"context"
	"database/sql"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/require"

	"github.com/mibjas/pos-platform/apps/local-store-server/internal/db"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/users"
)

const testTenant = "tenant-A"

func newStore(t *testing.T) (*users.Store, *sql.DB) {
	t.Helper()
	ctx := context.Background()
	path := filepath.Join(t.TempDir(), "users.db")
	sqlDB, err := db.Open(ctx, db.Config{Path: path})
	require.NoError(t, err)
	t.Cleanup(func() { _ = sqlDB.Close() })
	require.NoError(t, db.RunMigrations(sqlDB))
	return users.NewStore(sqlDB), sqlDB
}

func TestAuthenticate_Success(t *testing.T) {
	ctx := context.Background()
	store, _ := newStore(t)

	require.NoError(t, store.Create(ctx, "owner@a", testTenant, "s3cret",
		[]string{"owner"}, "Shop Owner"))

	u, err := store.Authenticate(ctx, "owner@a", "s3cret")
	require.NoError(t, err)
	require.Equal(t, "owner@a", u.Username)
	require.Equal(t, testTenant, u.TenantID)
	require.Equal(t, []string{"owner"}, u.Roles)
	require.Equal(t, "Shop Owner", u.DisplayName)
}

func TestAuthenticate_WrongPassword(t *testing.T) {
	ctx := context.Background()
	store, _ := newStore(t)
	require.NoError(t, store.Create(ctx, "owner@a", testTenant, "s3cret", []string{"owner"}, ""))

	_, err := store.Authenticate(ctx, "owner@a", "wrong")
	require.ErrorIs(t, err, users.ErrInvalidCredentials)
}

func TestAuthenticate_UnknownUser(t *testing.T) {
	ctx := context.Background()
	store, _ := newStore(t)

	_, err := store.Authenticate(ctx, "ghost@a", "whatever")
	require.ErrorIs(t, err, users.ErrInvalidCredentials)
}

func TestAuthenticate_DisabledUser(t *testing.T) {
	ctx := context.Background()
	store, sqlDB := newStore(t)
	require.NoError(t, store.Create(ctx, "fired@a", testTenant, "s3cret", []string{"cashier"}, ""))

	// No Disable method on the store yet (disabled arrives via cloud sync
	// later); flip the flag directly to exercise the auth path.
	_, err := sqlDB.ExecContext(ctx, `UPDATE users SET disabled = 1 WHERE username = ?`, "fired@a")
	require.NoError(t, err)

	_, err = store.Authenticate(ctx, "fired@a", "s3cret")
	require.ErrorIs(t, err, users.ErrInvalidCredentials,
		"a disabled user must fail with the same generic error as a wrong password")
}

func TestAuthenticate_EmptyDisplayNameStaysEmpty(t *testing.T) {
	ctx := context.Background()
	store, _ := newStore(t)
	require.NoError(t, store.Create(ctx, "cashier@a", testTenant, "pw", []string{"cashier"}, ""))

	u, err := store.Authenticate(ctx, "cashier@a", "pw")
	require.NoError(t, err)
	// Fallback to username is the service layer's job; the store reports
	// the stored value verbatim.
	require.Equal(t, "", u.DisplayName)
}

func TestCreate_DuplicateUsername(t *testing.T) {
	ctx := context.Background()
	store, _ := newStore(t)
	require.NoError(t, store.Create(ctx, "dup@a", testTenant, "pw", nil, ""))

	err := store.Create(ctx, "dup@a", testTenant, "pw2", nil, "")
	require.ErrorIs(t, err, users.ErrUsernameTaken)
}

func TestCount(t *testing.T) {
	ctx := context.Background()
	store, _ := newStore(t)

	n, err := store.Count(ctx)
	require.NoError(t, err)
	require.Equal(t, 0, n)

	require.NoError(t, store.Create(ctx, "a@a", testTenant, "pw", nil, ""))
	require.NoError(t, store.Create(ctx, "b@a", testTenant, "pw", nil, ""))

	n, err = store.Count(ctx)
	require.NoError(t, err)
	require.Equal(t, 2, n)
}
