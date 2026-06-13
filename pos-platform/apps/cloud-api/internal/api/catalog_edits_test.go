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

func newEditsFixture(t *testing.T) (*AdminCatalogEditsHandler, *SyncCatalogEditsHandler) {
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
	return NewAdminCatalogEditsHandler(store, logger), NewSyncCatalogEditsHandler(store, logger)
}

func withClaims(req *http.Request, c *auth.Claims) *http.Request {
	return req.WithContext(auth.ContextWithClaimsForTest(req.Context(), c))
}

func ownerA() *auth.Claims {
	return &auth.Claims{TenantID: "tenant-A", Subject: "boss", Roles: []string{"owner"}}
}

func nodeA() *auth.Claims {
	return &auth.Claims{TenantID: "tenant-A", Subject: "local-store-server"}
}

const validItemEdit = `{"kind":"upsert_item","payload":{
  "sku":"SKU-1","name":"Widget","price":{"currency_code":"USD","units":7,"nanos":0},
  "tax_category_id":"GST-18","archived":false}}`

func TestCatalogEdits_AppendPullAckRoundTrip(t *testing.T) {
	admin, syncH := newEditsFixture(t)

	// Owner appends.
	req := withClaims(httptest.NewRequest(http.MethodPost, "/v1/admin/catalog/edits",
		strings.NewReader(validItemEdit)), ownerA())
	rec := httptest.NewRecorder()
	admin.ServeHTTP(rec, req)
	if rec.Code != http.StatusCreated {
		t.Fatalf("append: %d %s", rec.Code, rec.Body)
	}
	var created struct {
		Seq    int64  `json:"seq"`
		EditID string `json:"edit_id"`
	}
	_ = json.Unmarshal(rec.Body.Bytes(), &created)
	if created.Seq == 0 || created.EditID == "" {
		t.Fatalf("created = %+v", created)
	}

	// Store pulls from 0.
	req = withClaims(httptest.NewRequest(http.MethodGet, "/v1/sync/catalog-edits?after=0", nil), nodeA())
	rec = httptest.NewRecorder()
	syncH.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("pull: %d", rec.Code)
	}
	var pulled struct {
		Edits []catalog.Edit `json:"edits"`
	}
	_ = json.Unmarshal(rec.Body.Bytes(), &pulled)
	if len(pulled.Edits) != 1 || pulled.Edits[0].Kind != catalog.KindUpsertItem {
		t.Fatalf("pulled = %+v", pulled.Edits)
	}

	// Pull after that seq → empty.
	req = withClaims(httptest.NewRequest(http.MethodGet, "/v1/sync/catalog-edits?after=1", nil), nodeA())
	rec = httptest.NewRecorder()
	syncH.ServeHTTP(rec, req)
	_ = json.Unmarshal(rec.Body.Bytes(), &pulled)
	if len(pulled.Edits) != 0 {
		t.Fatalf("expected drained queue, got %d", len(pulled.Edits))
	}

	// Store acks applied.
	ack := `{"node_id":"node-1","acks":[{"seq":1,"status":"applied"}]}`
	req = withClaims(httptest.NewRequest(http.MethodPost, "/v1/sync/catalog-edits/ack",
		strings.NewReader(ack)), nodeA())
	rec = httptest.NewRecorder()
	syncH.ServeHTTP(rec, req)
	if rec.Code != http.StatusNoContent {
		t.Fatalf("ack: %d %s", rec.Code, rec.Body)
	}

	// Owner sees the ack on the edit.
	req = withClaims(httptest.NewRequest(http.MethodGet, "/v1/admin/catalog/edits", nil), ownerA())
	rec = httptest.NewRecorder()
	admin.ServeHTTP(rec, req)
	var listed struct {
		Edits []catalog.EditWithAcks `json:"edits"`
	}
	_ = json.Unmarshal(rec.Body.Bytes(), &listed)
	if len(listed.Edits) != 1 || len(listed.Edits[0].Acks) != 1 {
		t.Fatalf("listed = %+v", listed.Edits)
	}
	if listed.Edits[0].Acks[0].Status != catalog.AckApplied {
		t.Fatalf("ack status = %q", listed.Edits[0].Acks[0].Status)
	}
}

func TestCatalogEdits_TenantIsolation(t *testing.T) {
	admin, syncH := newEditsFixture(t)

	req := withClaims(httptest.NewRequest(http.MethodPost, "/v1/admin/catalog/edits",
		strings.NewReader(validItemEdit)), ownerA())
	rec := httptest.NewRecorder()
	admin.ServeHTTP(rec, req)
	if rec.Code != http.StatusCreated {
		t.Fatal(rec.Code)
	}

	// tenant-B node pulls → sees nothing.
	nodeB := &auth.Claims{TenantID: "tenant-B", Subject: "store"}
	req = withClaims(httptest.NewRequest(http.MethodGet, "/v1/sync/catalog-edits?after=0", nil), nodeB)
	rec = httptest.NewRecorder()
	syncH.ServeHTTP(rec, req)
	if strings.Contains(rec.Body.String(), "SKU-1") {
		t.Fatal("cross-tenant edit visible")
	}
}

func TestCatalogEdits_Validation(t *testing.T) {
	admin, syncH := newEditsFixture(t)

	cases := []struct{ name, body string }{
		{"unknown kind", `{"kind":"delete_everything","payload":{}}`},
		{"item missing sku", `{"kind":"upsert_item","payload":{"name":"x","price":{"currency_code":"USD"}}}`},
		{"item negative price", `{"kind":"upsert_item","payload":{"sku":"s","name":"x","price":{"currency_code":"USD","units":-1}}}`},
		{"tax missing id", `{"kind":"upsert_tax_category","payload":{"name":"x"}}`},
		{"garbage", `{`},
	}
	for _, tc := range cases {
		req := withClaims(httptest.NewRequest(http.MethodPost, "/v1/admin/catalog/edits",
			strings.NewReader(tc.body)), ownerA())
		rec := httptest.NewRecorder()
		admin.ServeHTTP(rec, req)
		if rec.Code != http.StatusBadRequest {
			t.Errorf("%s: %d", tc.name, rec.Code)
		}
	}

	// Ack with bad status → 400.
	req := withClaims(httptest.NewRequest(http.MethodPost, "/v1/sync/catalog-edits/ack",
		strings.NewReader(`{"node_id":"n","acks":[{"seq":1,"status":"maybe"}]}`)), nodeA())
	rec := httptest.NewRecorder()
	syncH.ServeHTTP(rec, req)
	if rec.Code != http.StatusBadRequest {
		t.Fatalf("bad ack status: %d", rec.Code)
	}

	// Ack missing node_id → 400.
	req = withClaims(httptest.NewRequest(http.MethodPost, "/v1/sync/catalog-edits/ack",
		strings.NewReader(`{"acks":[]}`)), nodeA())
	rec = httptest.NewRecorder()
	syncH.ServeHTTP(rec, req)
	if rec.Code != http.StatusBadRequest {
		t.Fatalf("missing node_id: %d", rec.Code)
	}
}
