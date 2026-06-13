package catalogsync

import (
	"context"
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"testing"

	"github.com/mibjas/pos-platform/apps/local-store-server/internal/db"
)

func TestUploader_UploadOnce_SkipsUnchanged(t *testing.T) {
	ctx := context.Background()
	sqlDB, err := db.Open(ctx, db.Config{Path: filepath.Join(t.TempDir(), "t.db")})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = sqlDB.Close() })
	if err := db.RunMigrations(sqlDB); err != nil {
		t.Fatal(err)
	}

	// Seed one tax category + one item (+ one archived item).
	mustExec := func(q string, args ...any) {
		t.Helper()
		if _, err := sqlDB.Exec(q, args...); err != nil {
			t.Fatal(err)
		}
	}
	mustExec(`INSERT INTO tax_categories (tax_category_id, name, tenant_id, price_includes_tax)
	          VALUES ('GST-18', 'GST 18%', 'tenant-A', 1)`)
	mustExec(`INSERT INTO items (sku, tenant_id, name, price_currency, price_units, price_nanos,
	          tax_category_id, created_at, updated_at)
	          VALUES ('SKU-1', 'tenant-A', 'Widget', 'USD', 5, 0, 'GST-18', 0, 0)`)
	mustExec(`INSERT INTO items (sku, tenant_id, name, price_currency, price_units, price_nanos,
	          archived_at, created_at, updated_at)
	          VALUES ('SKU-OLD', 'tenant-A', 'Retired', 'USD', 1, 0, 1, 0, 0)`)

	var (
		calls    int
		lastBody []byte
		lastAuth string
	)
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPut || r.URL.Path != "/v1/sync/catalog" {
			t.Errorf("unexpected request: %s %s", r.Method, r.URL.Path)
		}
		calls++
		lastBody, _ = io.ReadAll(r.Body)
		lastAuth = r.Header.Get("Authorization")
		w.WriteHeader(http.StatusNoContent)
	}))
	t.Cleanup(srv.Close)

	u := &Uploader{
		DB:       sqlDB,
		CloudURL: srv.URL,
		TenantID: "tenant-A",
		NodeID:   "node-test",
		AuthHeaderFunc: func(context.Context) (string, error) {
			return "Bearer test-token", nil
		},
		Logger: slog.New(slog.DiscardHandler),
	}

	if err := u.UploadOnce(ctx); err != nil {
		t.Fatalf("upload 1: %v", err)
	}
	if calls != 1 {
		t.Fatalf("calls = %d", calls)
	}
	if lastAuth != "Bearer test-token" {
		t.Fatalf("auth header = %q", lastAuth)
	}

	var snap Snapshot
	if err := json.Unmarshal(lastBody, &snap); err != nil {
		t.Fatal(err)
	}
	if snap.TenantID != "tenant-A" || snap.NodeID != "node-test" {
		t.Fatalf("envelope = %+v", snap)
	}
	if len(snap.Items) != 2 || len(snap.TaxCategories) != 1 {
		t.Fatalf("items=%d tax=%d", len(snap.Items), len(snap.TaxCategories))
	}
	if !snap.Items[1].Archived || snap.Items[0].Archived {
		t.Fatalf("archived flags wrong: %+v", snap.Items)
	}
	if snap.Items[0].Price.Units != 5 || snap.Items[0].TaxCategoryID != "GST-18" {
		t.Fatalf("item 0 = %+v", snap.Items[0])
	}

	// Unchanged catalog → second call skips the network entirely.
	if err := u.UploadOnce(ctx); err != nil {
		t.Fatalf("upload 2: %v", err)
	}
	if calls != 1 {
		t.Fatalf("unchanged catalog re-uploaded: calls = %d", calls)
	}

	// Mutate → third call uploads again.
	mustExec(`UPDATE items SET name = 'Widget v2' WHERE sku = 'SKU-1'`)
	if err := u.UploadOnce(ctx); err != nil {
		t.Fatalf("upload 3: %v", err)
	}
	if calls != 2 {
		t.Fatalf("changed catalog not re-uploaded: calls = %d", calls)
	}
}

func TestUploader_ServerErrorDoesNotMarkUploaded(t *testing.T) {
	ctx := context.Background()
	sqlDB, err := db.Open(ctx, db.Config{Path: filepath.Join(t.TempDir(), "t.db")})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = sqlDB.Close() })
	if err := db.RunMigrations(sqlDB); err != nil {
		t.Fatal(err)
	}

	fail := true
	calls := 0
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		calls++
		if fail {
			w.WriteHeader(http.StatusInternalServerError)
			return
		}
		w.WriteHeader(http.StatusNoContent)
	}))
	t.Cleanup(srv.Close)

	u := &Uploader{
		DB: sqlDB, CloudURL: srv.URL, TenantID: "tenant-A", NodeID: "n",
		Logger: slog.New(slog.DiscardHandler),
	}
	if err := u.UploadOnce(ctx); err == nil {
		t.Fatal("expected error on 500")
	}
	// Failure must not set lastHash — retry hits the network again.
	fail = false
	if err := u.UploadOnce(ctx); err != nil {
		t.Fatalf("retry: %v", err)
	}
	if calls != 2 {
		t.Fatalf("calls = %d", calls)
	}
}
