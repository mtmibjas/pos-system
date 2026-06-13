package catalogsync

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"testing"
	"time"

	"github.com/mibjas/pos-platform/apps/local-store-server/internal/db"
)

// fakeCloud is an in-memory stand-in for cloud-api's edit queue.
type fakeCloud struct {
	t       *testing.T
	edits   []pulledEdit
	acks    []ackVerdict
	ackNode string
	failAck bool
}

func (f *fakeCloud) server() *httptest.Server {
	return httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch {
		case r.Method == http.MethodGet && r.URL.Path == "/v1/sync/catalog-edits":
			var after int64
			_, _ = fmt.Sscan(r.URL.Query().Get("after"), &after)
			out := []pulledEdit{}
			for _, e := range f.edits {
				if e.Seq > after {
					out = append(out, e)
				}
			}
			_ = json.NewEncoder(w).Encode(map[string]any{"edits": out})
		case r.Method == http.MethodPost && r.URL.Path == "/v1/sync/catalog-edits/ack":
			if f.failAck {
				w.WriteHeader(http.StatusInternalServerError)
				return
			}
			body, _ := io.ReadAll(r.Body)
			var req struct {
				NodeID string       `json:"node_id"`
				Acks   []ackVerdict `json:"acks"`
			}
			_ = json.Unmarshal(body, &req)
			f.ackNode = req.NodeID
			f.acks = append(f.acks, req.Acks...)
			w.WriteHeader(http.StatusNoContent)
		default:
			f.t.Errorf("unexpected request: %s %s", r.Method, r.URL.Path)
		}
	}))
}

func newApplierFixture(t *testing.T, cloud *fakeCloud) (*Applier, *sql.DB) {
	t.Helper()
	ctx := context.Background()
	sqlDB, err := db.Open(ctx, db.Config{Path: filepath.Join(t.TempDir(), "t.db")})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = sqlDB.Close() })
	if err := db.RunMigrations(sqlDB); err != nil {
		t.Fatal(err)
	}
	srv := cloud.server()
	t.Cleanup(srv.Close)
	return &Applier{
		DB:       sqlDB,
		CloudURL: srv.URL,
		TenantID: "tenant-A",
		NodeID:   "node-test",
		Logger:   slog.New(slog.DiscardHandler),
	}, sqlDB
}

func itemEdit(seq int64, createdAt time.Time, sku, name string, taxID string) pulledEdit {
	p := Item{SKU: sku, Name: name,
		Price: Money{CurrencyCode: "USD", Units: 9, Nanos: 0}, TaxCategoryID: taxID}
	raw, _ := json.Marshal(p)
	return pulledEdit{Seq: seq, EditID: fmt.Sprintf("e-%d", seq),
		Kind: kindUpsertItem, Payload: raw, CreatedAt: createdAt}
}

func taxEdit(seq int64, createdAt time.Time, id, name string) pulledEdit {
	p := TaxCategory{ID: id, Name: name, PriceIncludesTax: true}
	raw, _ := json.Marshal(p)
	return pulledEdit{Seq: seq, EditID: fmt.Sprintf("e-%d", seq),
		Kind: kindUpsertTaxCategory, Payload: raw, CreatedAt: createdAt}
}

func TestApplier_CreatesAndUpdates(t *testing.T) {
	now := time.Now().UTC()
	cloud := &fakeCloud{edits: []pulledEdit{
		taxEdit(1, now, "VAT-5", "VAT 5%"),
		itemEdit(2, now, "SKU-NEW", "New Widget", "VAT-5"),
	}}
	cloud.t = t
	a, sqlDB := newApplierFixture(t, cloud)

	applied, err := a.PullApplyOnce(context.Background())
	if err != nil {
		t.Fatal(err)
	}
	if applied != 2 {
		t.Fatalf("applied = %d; acks: %+v", applied, cloud.acks)
	}
	if cloud.ackNode != "node-test" {
		t.Fatalf("ack node = %q", cloud.ackNode)
	}

	var name string
	var taxID sql.NullString
	if err := sqlDB.QueryRow(`SELECT name, tax_category_id FROM items WHERE sku='SKU-NEW'`).
		Scan(&name, &taxID); err != nil {
		t.Fatal(err)
	}
	if name != "New Widget" || taxID.String != "VAT-5" {
		t.Fatalf("item = %s/%s", name, taxID.String)
	}

	// Cursor advanced — second pull sees nothing, no new acks.
	before := len(cloud.acks)
	if _, err := a.PullApplyOnce(context.Background()); err != nil {
		t.Fatal(err)
	}
	if len(cloud.acks) != before {
		t.Fatal("drained queue re-acked")
	}

	// Update via a later edit wins over the applier's own earlier write.
	cloud.edits = append(cloud.edits,
		itemEdit(3, now.Add(time.Hour), "SKU-NEW", "Renamed", "VAT-5"))
	if _, err := a.PullApplyOnce(context.Background()); err != nil {
		t.Fatal(err)
	}
	_ = sqlDB.QueryRow(`SELECT name FROM items WHERE sku='SKU-NEW'`).Scan(&name)
	if name != "Renamed" {
		t.Fatalf("name = %q", name)
	}
}

func TestApplier_ConflictGuards(t *testing.T) {
	now := time.Now().UTC()
	cloud := &fakeCloud{edits: []pulledEdit{
		// Edit created an hour AGO; the local row below is newer → conflict.
		itemEdit(1, now.Add(-time.Hour), "SKU-LOCAL", "Stale Cloud Name", ""),
		// References a tax category this store doesn't have → conflict.
		itemEdit(2, now, "SKU-X", "X", "NO-SUCH-TAX"),
	}}
	cloud.t = t
	a, sqlDB := newApplierFixture(t, cloud)

	// Local row edited "now" — newer than the seq-1 intent.
	if _, err := sqlDB.Exec(`INSERT INTO items
		(sku, tenant_id, name, price_currency, price_units, price_nanos, created_at, updated_at)
		VALUES ('SKU-LOCAL', 'tenant-A', 'Local Name', 'USD', 1, 0, ?, ?)`,
		now.Unix(), now.Unix()); err != nil {
		t.Fatal(err)
	}

	applied, err := a.PullApplyOnce(context.Background())
	if err != nil {
		t.Fatal(err)
	}
	if applied != 0 {
		t.Fatalf("applied = %d, want 0", applied)
	}
	if len(cloud.acks) != 2 {
		t.Fatalf("acks = %+v", cloud.acks)
	}
	for _, ack := range cloud.acks {
		if ack.Status != "conflict" {
			t.Fatalf("ack = %+v", ack)
		}
	}

	// Local name untouched.
	var name string
	_ = sqlDB.QueryRow(`SELECT name FROM items WHERE sku='SKU-LOCAL'`).Scan(&name)
	if name != "Local Name" {
		t.Fatalf("local row clobbered: %q", name)
	}

	// Cursor advanced PAST the conflicts (terminal; no infinite retry).
	var cursor int64
	_ = sqlDB.QueryRow(`SELECT last_seq FROM catalog_pull_state`).Scan(&cursor)
	if cursor != 2 {
		t.Fatalf("cursor = %d, want 2", cursor)
	}
}

func TestApplier_AckFailureDoesNotAdvanceCursor(t *testing.T) {
	now := time.Now().UTC()
	cloud := &fakeCloud{edits: []pulledEdit{taxEdit(1, now, "T1", "Tax 1")}, failAck: true}
	cloud.t = t
	a, sqlDB := newApplierFixture(t, cloud)

	if _, err := a.PullApplyOnce(context.Background()); err == nil {
		t.Fatal("expected error when ack fails")
	}
	var cursor int64
	_ = sqlDB.QueryRow(`SELECT last_seq FROM catalog_pull_state`).Scan(&cursor)
	if cursor != 0 {
		t.Fatalf("cursor advanced despite ack failure: %d", cursor)
	}

	// Recovery: ack works → re-pull re-applies idempotently and advances.
	cloud.failAck = false
	if _, err := a.PullApplyOnce(context.Background()); err != nil {
		t.Fatal(err)
	}
	_ = sqlDB.QueryRow(`SELECT last_seq FROM catalog_pull_state`).Scan(&cursor)
	if cursor != 1 {
		t.Fatalf("cursor = %d", cursor)
	}
}
