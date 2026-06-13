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
	"github.com/mibjas/pos-platform/apps/cloud-api/internal/catalog"
	"github.com/mibjas/pos-platform/apps/cloud-api/internal/db"
)

func newCatalogFixture(t *testing.T) (*CatalogUploadHandler, *AdminCatalogHandler) {
	t.Helper()
	sqlDB, err := db.Open(context.Background(), db.Config{Path: filepath.Join(t.TempDir(), "t.db")})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = sqlDB.Close() })
	if err := db.RunMigrations(sqlDB); err != nil {
		t.Fatal(err)
	}
	store := catalog.NewStore(sqlDB)
	logger := slog.New(slog.DiscardHandler)
	return NewCatalogUploadHandler(store, true, logger), NewAdminCatalogHandler(store, logger)
}

func storeClaims(tenant string) *auth.Claims {
	return &auth.Claims{TenantID: tenant, Subject: "local-store-server"}
}

func putSnapshot(t *testing.T, h http.Handler, body string, claims *auth.Claims) *httptest.ResponseRecorder {
	t.Helper()
	req := httptest.NewRequest(http.MethodPut, "/v1/sync/catalog", strings.NewReader(body))
	if claims != nil {
		req = req.WithContext(auth.ContextWithClaimsForTest(req.Context(), claims))
	}
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)
	return rec
}

func TestCatalog_UploadAndRead(t *testing.T) {
	upload, read := newCatalogFixture(t)

	body := `{"tenant_id":"tenant-A","node_id":"node-1","items":[{"sku":"X","name":"Widget"}]}`
	rec := putSnapshot(t, upload, body, storeClaims("tenant-A"))
	if rec.Code != http.StatusNoContent {
		t.Fatalf("upload: %d %s", rec.Code, rec.Body)
	}

	// Second upload replaces, not duplicates.
	body2 := `{"tenant_id":"tenant-A","node_id":"node-1","items":[]}`
	if rec := putSnapshot(t, upload, body2, storeClaims("tenant-A")); rec.Code != http.StatusNoContent {
		t.Fatalf("re-upload: %d", rec.Code)
	}

	req := httptest.NewRequest(http.MethodGet, "/v1/admin/catalog", nil)
	req = req.WithContext(auth.ContextWithClaimsForTest(req.Context(),
		&auth.Claims{TenantID: "tenant-A", Subject: "boss", Roles: []string{"owner"}}))
	rr := httptest.NewRecorder()
	read.ServeHTTP(rr, req)
	if rr.Code != http.StatusOK {
		t.Fatalf("read: %d", rr.Code)
	}
	var resp struct {
		Snapshots []struct {
			NodeID  string          `json:"node_id"`
			Payload json.RawMessage `json:"payload"`
		} `json:"snapshots"`
	}
	if err := json.Unmarshal(rr.Body.Bytes(), &resp); err != nil {
		t.Fatal(err)
	}
	if len(resp.Snapshots) != 1 || resp.Snapshots[0].NodeID != "node-1" {
		t.Fatalf("snapshots = %+v", resp.Snapshots)
	}
	if !strings.Contains(string(resp.Snapshots[0].Payload), `"items":[]`) {
		t.Fatalf("payload not replaced: %s", resp.Snapshots[0].Payload)
	}
}

func TestCatalog_TenantPinning(t *testing.T) {
	upload, read := newCatalogFixture(t)

	// Token for tenant-B uploading a tenant-A snapshot → 403.
	body := `{"tenant_id":"tenant-A","node_id":"node-1"}`
	rec := putSnapshot(t, upload, body, storeClaims("tenant-B"))
	if rec.Code != http.StatusForbidden {
		t.Fatalf("cross-tenant upload: %d", rec.Code)
	}

	// tenant-B owner reading sees nothing from tenant-A.
	if rec := putSnapshot(t, upload, body, storeClaims("tenant-A")); rec.Code != http.StatusNoContent {
		t.Fatalf("setup upload: %d", rec.Code)
	}
	req := httptest.NewRequest(http.MethodGet, "/v1/admin/catalog", nil)
	req = req.WithContext(auth.ContextWithClaimsForTest(req.Context(),
		&auth.Claims{TenantID: "tenant-B", Subject: "boss", Roles: []string{"owner"}}))
	rr := httptest.NewRecorder()
	read.ServeHTTP(rr, req)
	if strings.Contains(rr.Body.String(), "node-1") {
		t.Fatal("cross-tenant snapshot visible")
	}
}

func TestCatalog_Validation(t *testing.T) {
	upload, _ := newCatalogFixture(t)

	cases := []struct {
		name, body string
		want       int
	}{
		{"not json", "{", http.StatusBadRequest},
		{"missing node", `{"tenant_id":"tenant-A"}`, http.StatusBadRequest},
		{"missing tenant", `{"node_id":"n1"}`, http.StatusBadRequest},
	}
	for _, tc := range cases {
		if rec := putSnapshot(t, upload, tc.body, storeClaims("tenant-A")); rec.Code != tc.want {
			t.Errorf("%s: %d want %d", tc.name, rec.Code, tc.want)
		}
	}

	// Wrong method.
	req := httptest.NewRequest(http.MethodGet, "/v1/sync/catalog", nil)
	req = req.WithContext(auth.ContextWithClaimsForTest(req.Context(), storeClaims("tenant-A")))
	rr := httptest.NewRecorder()
	upload.ServeHTTP(rr, req)
	if rr.Code != http.StatusMethodNotAllowed {
		t.Fatalf("GET on upload: %d", rr.Code)
	}
}
