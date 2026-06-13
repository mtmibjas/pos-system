package users

import (
	"context"
	"database/sql"
	"errors"
	"os"
	"path/filepath"
	"testing"

	"github.com/mibjas/pos-platform/apps/cloud-api/internal/db"
)

func newTestDB(t *testing.T) *sql.DB {
	t.Helper()
	sqlDB, err := db.Open(context.Background(), db.Config{Path: filepath.Join(t.TempDir(), "test.db")})
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	t.Cleanup(func() { _ = sqlDB.Close() })
	if err := db.RunMigrations(sqlDB); err != nil {
		t.Fatalf("migrate: %v", err)
	}
	return sqlDB
}

func TestDBStore_CreateAuthenticate(t *testing.T) {
	s := NewDBStore(newTestDB(t))
	ctx := context.Background()

	rec, err := s.Create(ctx, "tenant-A", "alice", "hunter2-long", []string{"owner", ""})
	if err != nil {
		t.Fatalf("create: %v", err)
	}
	if len(rec.Roles) != 1 || rec.Roles[0] != "owner" {
		t.Fatalf("empty role not filtered: %v", rec.Roles)
	}

	u, err := s.Authenticate("alice", "hunter2-long")
	if err != nil {
		t.Fatalf("authenticate: %v", err)
	}
	if u.TenantID != "tenant-A" {
		t.Fatalf("tenant = %q", u.TenantID)
	}

	if _, err := s.Authenticate("alice", "WRONG"); !errors.Is(err, ErrInvalidCredentials) {
		t.Fatalf("wrong password: got %v", err)
	}
	if _, err := s.Authenticate("nobody", "x"); !errors.Is(err, ErrInvalidCredentials) {
		t.Fatalf("unknown user: got %v", err)
	}
}

func TestDBStore_DuplicateUsername(t *testing.T) {
	s := NewDBStore(newTestDB(t))
	ctx := context.Background()
	if _, err := s.Create(ctx, "tenant-A", "alice", "password1", nil); err != nil {
		t.Fatalf("create: %v", err)
	}
	// Same username, even different tenant → taken. Usernames are global.
	if _, err := s.Create(ctx, "tenant-B", "alice", "password2", nil); !errors.Is(err, ErrUsernameTaken) {
		t.Fatalf("want ErrUsernameTaken, got %v", err)
	}
}

func TestDBStore_DisabledUserCannotLogin(t *testing.T) {
	s := NewDBStore(newTestDB(t))
	ctx := context.Background()
	if _, err := s.Create(ctx, "tenant-A", "bob", "password1", []string{"cashier"}); err != nil {
		t.Fatalf("create: %v", err)
	}
	on := true
	if _, err := s.Update(ctx, "tenant-A", "bob", Patch{Disabled: &on}); err != nil {
		t.Fatalf("disable: %v", err)
	}
	if _, err := s.Authenticate("bob", "password1"); !errors.Is(err, ErrInvalidCredentials) {
		t.Fatalf("disabled user authenticated: %v", err)
	}
	// Re-enable → works again.
	off := false
	if _, err := s.Update(ctx, "tenant-A", "bob", Patch{Disabled: &off}); err != nil {
		t.Fatalf("enable: %v", err)
	}
	if _, err := s.Authenticate("bob", "password1"); err != nil {
		t.Fatalf("re-enabled user rejected: %v", err)
	}
}

func TestDBStore_UpdatePasswordAndRoles(t *testing.T) {
	s := NewDBStore(newTestDB(t))
	ctx := context.Background()
	if _, err := s.Create(ctx, "tenant-A", "carol", "oldpassword", []string{"cashier"}); err != nil {
		t.Fatalf("create: %v", err)
	}
	newPw := "newpassword"
	roles := []string{"owner"}
	rec, err := s.Update(ctx, "tenant-A", "carol", Patch{Password: &newPw, Roles: &roles})
	if err != nil {
		t.Fatalf("update: %v", err)
	}
	if len(rec.Roles) != 1 || rec.Roles[0] != "owner" {
		t.Fatalf("roles = %v", rec.Roles)
	}
	if _, err := s.Authenticate("carol", "oldpassword"); !errors.Is(err, ErrInvalidCredentials) {
		t.Fatal("old password still works")
	}
	if _, err := s.Authenticate("carol", "newpassword"); err != nil {
		t.Fatalf("new password rejected: %v", err)
	}
}

func TestDBStore_TenantScoping(t *testing.T) {
	s := NewDBStore(newTestDB(t))
	ctx := context.Background()
	_, _ = s.Create(ctx, "tenant-A", "a1", "password1", nil)
	_, _ = s.Create(ctx, "tenant-A", "a2", "password1", nil)
	_, _ = s.Create(ctx, "tenant-B", "b1", "password1", nil)

	listA, err := s.List(ctx, "tenant-A")
	if err != nil || len(listA) != 2 {
		t.Fatalf("list A: %v, n=%d", err, len(listA))
	}
	// Cross-tenant Get/Update must 404, not leak.
	if _, err := s.Get(ctx, "tenant-A", "b1"); !errors.Is(err, ErrNotFound) {
		t.Fatalf("cross-tenant get: %v", err)
	}
	on := true
	if _, err := s.Update(ctx, "tenant-A", "b1", Patch{Disabled: &on}); !errors.Is(err, ErrNotFound) {
		t.Fatalf("cross-tenant update: %v", err)
	}
}

func TestDBStore_ImportFromFile(t *testing.T) {
	s := NewDBStore(newTestDB(t))
	ctx := context.Background()

	yaml := `users:
  - username: owner@tenant-a
    tenant_id: tenant-A
    roles: [owner]
    bcrypt: $2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy
`
	path := filepath.Join(t.TempDir(), "users.yaml")
	if err := os.WriteFile(path, []byte(yaml), 0o600); err != nil {
		t.Fatal(err)
	}
	fs, err := Load(path)
	if err != nil {
		t.Fatalf("load yaml: %v", err)
	}

	n, err := s.ImportFromFile(ctx, fs)
	if err != nil || n != 1 {
		t.Fatalf("import: n=%d err=%v", n, err)
	}
	// Second import is a no-op — table not empty.
	n, err = s.ImportFromFile(ctx, fs)
	if err != nil || n != 0 {
		t.Fatalf("re-import: n=%d err=%v", n, err)
	}
	if s.Count() != 1 {
		t.Fatalf("count = %d", s.Count())
	}
}
