package api

import (
	"context"
	"encoding/json"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"strings"
	"testing"

	"github.com/mibjas/pos-platform/apps/cloud-api/internal/auth"
	"github.com/mibjas/pos-platform/apps/cloud-api/internal/db"
	"github.com/mibjas/pos-platform/apps/cloud-api/internal/tenants"
	"github.com/mibjas/pos-platform/apps/cloud-api/internal/users"
)

func newPlatformFixture(t *testing.T) (*PlatformTenantsHandler, *tenants.Store, *users.DBStore) {
	t.Helper()
	sqlDB, err := db.Open(context.Background(), db.Config{Path: filepath.Join(t.TempDir(), "t.db")})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = sqlDB.Close() })
	if err := db.RunMigrations(sqlDB); err != nil {
		t.Fatal(err)
	}
	ts := tenants.NewStore(sqlDB)
	us := users.NewDBStore(sqlDB)
	return NewPlatformTenantsHandler(ts, us, slog.New(slog.DiscardHandler)), ts, us
}

func platformDo(t *testing.T, h http.Handler, method, path, body string) *httptest.ResponseRecorder {
	t.Helper()
	var rdr *strings.Reader
	if body == "" {
		rdr = strings.NewReader("")
	} else {
		rdr = strings.NewReader(body)
	}
	req := httptest.NewRequest(method, path, rdr)
	req = req.WithContext(auth.ContextWithClaimsForTest(req.Context(),
		&auth.Claims{TenantID: "platform", Subject: "staff", Roles: []string{auth.RolePlatformAdmin}}))
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)
	return rec
}

func TestPlatform_TenantLifecycle(t *testing.T) {
	h, ts, us := newPlatformFixture(t)
	ctx := context.Background()

	// Create.
	rec := platformDo(t, h, http.MethodPost, "/v1/platform/tenants",
		`{"tenant_id":"tenant-NEW","name":"New Retail Co"}`)
	if rec.Code != http.StatusCreated {
		t.Fatalf("create: %d %s", rec.Code, rec.Body)
	}

	// Duplicate → 409.
	rec = platformDo(t, h, http.MethodPost, "/v1/platform/tenants",
		`{"tenant_id":"tenant-NEW"}`)
	if rec.Code != http.StatusConflict {
		t.Fatalf("dup: %d", rec.Code)
	}

	// List includes it, with usage zeros + user count after adding one.
	if _, err := us.Create(ctx, "tenant-NEW", "owner@new", "longenough", []string{"owner"}); err != nil {
		t.Fatal(err)
	}
	rec = platformDo(t, h, http.MethodGet, "/v1/platform/tenants", "")
	var listed struct {
		Tenants []tenants.TenantWithUsage `json:"tenants"`
	}
	_ = json.Unmarshal(rec.Body.Bytes(), &listed)
	var found *tenants.TenantWithUsage
	for i := range listed.Tenants {
		if listed.Tenants[i].TenantID == "tenant-NEW" {
			found = &listed.Tenants[i]
		}
	}
	if found == nil || found.Usage.UserCount != 1 {
		t.Fatalf("listed = %+v", listed.Tenants)
	}

	// Suspend → CheckActive errors.
	rec = platformDo(t, h, http.MethodPatch, "/v1/platform/tenants/tenant-NEW",
		`{"status":"suspended"}`)
	if rec.Code != http.StatusOK {
		t.Fatalf("suspend: %d %s", rec.Code, rec.Body)
	}
	if err := ts.CheckActive(ctx, "tenant-NEW"); err == nil {
		t.Fatal("CheckActive passed for suspended tenant")
	}
	// Unknown tenant stays implicitly active.
	if err := ts.CheckActive(ctx, "tenant-NEVER-SEEN"); err != nil {
		t.Fatalf("implicit tenant: %v", err)
	}

	// Reactivate.
	rec = platformDo(t, h, http.MethodPatch, "/v1/platform/tenants/tenant-NEW",
		`{"status":"active"}`)
	if rec.Code != http.StatusOK {
		t.Fatalf("reactivate: %d", rec.Code)
	}
	if err := ts.CheckActive(ctx, "tenant-NEW"); err != nil {
		t.Fatalf("CheckActive after reactivate: %v", err)
	}

	// Per-tenant users subroute.
	rec = platformDo(t, h, http.MethodGet, "/v1/platform/tenants/tenant-NEW/users", "")
	if rec.Code != http.StatusOK || !strings.Contains(rec.Body.String(), "owner@new") {
		t.Fatalf("users: %d %s", rec.Code, rec.Body)
	}

	// Bad status / unknown tenant / no delete.
	if rec := platformDo(t, h, http.MethodPatch, "/v1/platform/tenants/tenant-NEW", `{"status":"obliterated"}`); rec.Code != http.StatusBadRequest {
		t.Fatalf("bad status: %d", rec.Code)
	}
	if rec := platformDo(t, h, http.MethodPatch, "/v1/platform/tenants/ghost", `{"status":"suspended"}`); rec.Code != http.StatusNotFound {
		t.Fatalf("unknown tenant: %d", rec.Code)
	}
	if rec := platformDo(t, h, http.MethodDelete, "/v1/platform/tenants/tenant-NEW", ""); rec.Code != http.StatusMethodNotAllowed {
		t.Fatalf("delete: %d", rec.Code)
	}
}

func TestPlatform_SuspendedTenantCannotLogin(t *testing.T) {
	_, ts, us := newPlatformFixture(t)
	ctx := context.Background()

	if _, err := us.Create(ctx, "tenant-S", "bob@s", "longenough", []string{"owner"}); err != nil {
		t.Fatal(err)
	}
	if _, err := ts.Create(ctx, "tenant-S", "Suspended Co"); err != nil {
		t.Fatal(err)
	}
	issuer, err := auth.NewIssuer("test-secret", 0)
	if err != nil {
		t.Fatal(err)
	}
	login := NewLoginHandler(us, issuer, slog.New(slog.DiscardHandler))
	login.TenantGate = ts.CheckActive

	doLogin := func() *httptest.ResponseRecorder {
		req := httptest.NewRequest(http.MethodPost, "/v1/auth/login",
			strings.NewReader(`{"username":"bob@s","password":"longenough"}`))
		rec := httptest.NewRecorder()
		login.ServeHTTP(rec, req)
		return rec
	}

	if rec := doLogin(); rec.Code != http.StatusOK {
		t.Fatalf("active tenant login: %d %s", rec.Code, rec.Body)
	}
	if _, err := ts.SetStatus(ctx, "tenant-S", tenants.StatusSuspended); err != nil {
		t.Fatal(err)
	}
	rec := doLogin()
	if rec.Code != http.StatusForbidden {
		t.Fatalf("suspended tenant login: %d %s", rec.Code, rec.Body)
	}
	if !strings.Contains(rec.Body.String(), "suspended") {
		t.Fatalf("body = %s", rec.Body)
	}
}
