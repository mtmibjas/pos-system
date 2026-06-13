package api

import (
	"bytes"
	"context"
	"encoding/json"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"testing"

	"github.com/mibjas/pos-platform/apps/cloud-api/internal/auth"
	"github.com/mibjas/pos-platform/apps/cloud-api/internal/db"
	"github.com/mibjas/pos-platform/apps/cloud-api/internal/users"
)

func newAdminFixture(t *testing.T) (*AdminUsersHandler, *users.DBStore) {
	t.Helper()
	sqlDB, err := db.Open(context.Background(), db.Config{Path: filepath.Join(t.TempDir(), "t.db")})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = sqlDB.Close() })
	if err := db.RunMigrations(sqlDB); err != nil {
		t.Fatal(err)
	}
	store := users.NewDBStore(sqlDB)
	return NewAdminUsersHandler(store, slog.New(slog.DiscardHandler)), store
}

// do issues a request with owner claims for tenant-A (caller = boss).
func do(t *testing.T, h http.Handler, method, path string, body any, claims *auth.Claims) *httptest.ResponseRecorder {
	t.Helper()
	var buf bytes.Buffer
	if body != nil {
		if err := json.NewEncoder(&buf).Encode(body); err != nil {
			t.Fatal(err)
		}
	}
	req := httptest.NewRequest(method, path, &buf)
	if claims != nil {
		req = req.WithContext(auth.ContextWithClaimsForTest(req.Context(), claims))
	}
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)
	return rec
}

func ownerClaims(username, tenant string) *auth.Claims {
	return &auth.Claims{TenantID: tenant, Subject: username, Roles: []string{"owner"}}
}

func TestAdmin_CreateListPatch(t *testing.T) {
	h, _ := newAdminFixture(t)
	boss := ownerClaims("boss", "tenant-A")

	// Create.
	rec := do(t, h, http.MethodPost, "/v1/admin/users",
		map[string]any{"username": "cashier1", "password": "longenough", "roles": []string{"cashier"}}, boss)
	if rec.Code != http.StatusCreated {
		t.Fatalf("create: %d %s", rec.Code, rec.Body)
	}
	// Response must not leak the hash.
	if bytes.Contains(rec.Body.Bytes(), []byte("$2a$")) {
		t.Fatal("bcrypt hash leaked in create response")
	}

	// List shows it.
	rec = do(t, h, http.MethodGet, "/v1/admin/users", nil, boss)
	if rec.Code != http.StatusOK {
		t.Fatalf("list: %d", rec.Code)
	}
	var listResp struct {
		Users []users.Record `json:"users"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &listResp); err != nil {
		t.Fatal(err)
	}
	if len(listResp.Users) != 1 || listResp.Users[0].Username != "cashier1" {
		t.Fatalf("list = %+v", listResp.Users)
	}

	// Patch: disable.
	rec = do(t, h, http.MethodPatch, "/v1/admin/users/cashier1",
		map[string]any{"disabled": true}, boss)
	if rec.Code != http.StatusOK {
		t.Fatalf("patch: %d %s", rec.Code, rec.Body)
	}
	var patched users.Record
	_ = json.Unmarshal(rec.Body.Bytes(), &patched)
	if !patched.Disabled {
		t.Fatal("disabled flag not applied")
	}
}

func TestAdmin_TenantIsolation(t *testing.T) {
	h, store := newAdminFixture(t)
	// User exists in tenant-B.
	if _, err := store.Create(context.Background(), "tenant-B", "bobby", "longenough", nil); err != nil {
		t.Fatal(err)
	}
	boss := ownerClaims("boss", "tenant-A")

	// tenant-A owner cannot see tenant-B's user...
	rec := do(t, h, http.MethodGet, "/v1/admin/users", nil, boss)
	if bytes.Contains(rec.Body.Bytes(), []byte("bobby")) {
		t.Fatal("cross-tenant user visible in list")
	}
	// ...nor patch them (404, not 403 — no existence oracle).
	rec = do(t, h, http.MethodPatch, "/v1/admin/users/bobby",
		map[string]any{"disabled": true}, boss)
	if rec.Code != http.StatusNotFound {
		t.Fatalf("cross-tenant patch: %d", rec.Code)
	}
}

func TestAdmin_SelfLockoutGuards(t *testing.T) {
	h, store := newAdminFixture(t)
	if _, err := store.Create(context.Background(), "tenant-A", "boss", "longenough", []string{"owner"}); err != nil {
		t.Fatal(err)
	}
	boss := ownerClaims("boss", "tenant-A")

	// Cannot disable self.
	rec := do(t, h, http.MethodPatch, "/v1/admin/users/boss",
		map[string]any{"disabled": true}, boss)
	if rec.Code != http.StatusUnprocessableEntity {
		t.Fatalf("self-disable: %d %s", rec.Code, rec.Body)
	}
	// Cannot drop own owner role.
	rec = do(t, h, http.MethodPatch, "/v1/admin/users/boss",
		map[string]any{"roles": []string{"cashier"}}, boss)
	if rec.Code != http.StatusUnprocessableEntity {
		t.Fatalf("self-demote: %d %s", rec.Code, rec.Body)
	}
	// Changing own password IS allowed.
	rec = do(t, h, http.MethodPatch, "/v1/admin/users/boss",
		map[string]any{"password": "evenlongerpw"}, boss)
	if rec.Code != http.StatusOK {
		t.Fatalf("self password change: %d %s", rec.Code, rec.Body)
	}
}

func TestAdmin_Validation(t *testing.T) {
	h, _ := newAdminFixture(t)
	boss := ownerClaims("boss", "tenant-A")

	cases := []struct {
		name string
		body map[string]any
		want int
	}{
		{"missing username", map[string]any{"password": "longenough"}, http.StatusBadRequest},
		{"missing password", map[string]any{"username": "x"}, http.StatusBadRequest},
		{"short password", map[string]any{"username": "x", "password": "short"}, http.StatusBadRequest},
	}
	for _, tc := range cases {
		rec := do(t, h, http.MethodPost, "/v1/admin/users", tc.body, boss)
		if rec.Code != tc.want {
			t.Errorf("%s: %d want %d", tc.name, rec.Code, tc.want)
		}
	}

	// Duplicate → 409.
	body := map[string]any{"username": "dup", "password": "longenough"}
	_ = do(t, h, http.MethodPost, "/v1/admin/users", body, boss)
	rec := do(t, h, http.MethodPost, "/v1/admin/users", body, boss)
	if rec.Code != http.StatusConflict {
		t.Fatalf("duplicate: %d", rec.Code)
	}

	// Empty patch → 400.
	rec = do(t, h, http.MethodPatch, "/v1/admin/users/dup", map[string]any{}, boss)
	if rec.Code != http.StatusBadRequest {
		t.Fatalf("empty patch: %d", rec.Code)
	}

	// No claims at all → 401 (fail closed on wiring bug).
	rec = do(t, h, http.MethodGet, "/v1/admin/users", nil, nil)
	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("no claims: %d", rec.Code)
	}

	// DELETE not supported.
	rec = do(t, h, http.MethodDelete, "/v1/admin/users/dup", nil, boss)
	if rec.Code != http.StatusMethodNotAllowed {
		t.Fatalf("delete: %d", rec.Code)
	}
}

func TestAdmin_CannotAssignPlatformAdmin(t *testing.T) {
	h, _ := newAdminFixture(t)
	boss := ownerClaims("boss", "tenant-A")

	// Create with platform_admin → 403.
	rec := do(t, h, http.MethodPost, "/v1/admin/users",
		map[string]any{"username": "sneaky", "password": "longenough",
			"roles": []string{"owner", "platform_admin"}}, boss)
	if rec.Code != http.StatusForbidden {
		t.Fatalf("create with platform_admin: %d", rec.Code)
	}

	// Patch an existing user up to platform_admin → 403.
	rec = do(t, h, http.MethodPost, "/v1/admin/users",
		map[string]any{"username": "normal", "password": "longenough", "roles": []string{"cashier"}}, boss)
	if rec.Code != http.StatusCreated {
		t.Fatal(rec.Code)
	}
	rec = do(t, h, http.MethodPatch, "/v1/admin/users/normal",
		map[string]any{"roles": []string{"platform_admin"}}, boss)
	if rec.Code != http.StatusForbidden {
		t.Fatalf("patch to platform_admin: %d", rec.Code)
	}
}
