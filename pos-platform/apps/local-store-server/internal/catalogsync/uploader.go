// Package catalogsync mirrors this store's catalog up to cloud-api
// (slice 6.5) so the web dashboard can display items and tax
// categories. Strictly one-directional and read-only on the store
// side: the local SQLite remains the source of truth, the cloud copy
// is display-only.
//
// Upload policy: once at startup, then on a fixed interval — but only
// when the snapshot content actually changed (sha256 over the payload
// minus the timestamp), so an idle store costs one no-op query per
// tick, not network traffic.
package catalogsync

import (
	"bytes"
	"context"
	"crypto/sha256"
	"database/sql"
	"encoding/json"
	"fmt"
	"log/slog"
	"net/http"
	"time"
)

// Money mirrors the JSON shape the dashboard expects (google.type.Money
// convention, same as reports).
type Money struct {
	CurrencyCode string `json:"currency_code"`
	Units        int64  `json:"units"`
	Nanos        int32  `json:"nanos"`
}

type Item struct {
	SKU           string `json:"sku"`
	Name          string `json:"name"`
	Price         Money  `json:"price"`
	TaxCategoryID string `json:"tax_category_id,omitempty"`
	Archived      bool   `json:"archived"`
}

type TaxCategory struct {
	ID               string `json:"id"`
	Name             string `json:"name"`
	PriceIncludesTax bool   `json:"price_includes_tax"`
	Archived         bool   `json:"archived"`
}

// Snapshot is the full upload payload. CapturedAt is informational —
// the cloud stamps its own updated_at on receipt.
type Snapshot struct {
	TenantID      string        `json:"tenant_id"`
	NodeID        string        `json:"node_id"`
	CapturedAt    time.Time     `json:"captured_at"`
	Items         []Item        `json:"items"`
	TaxCategories []TaxCategory `json:"tax_categories"`
}

// Uploader periodically snapshots the catalog tables and PUTs them to
// cloud-api. AuthHeaderFunc is the same hook the sync transport uses
// (nil = unauthenticated, matches --insecure-no-auth dev mode).
type Uploader struct {
	DB             *sql.DB
	CloudURL       string // base, e.g. http://127.0.0.1:8080
	TenantID       string
	NodeID         string
	Interval       time.Duration // 0 → 5m default
	AuthHeaderFunc func(ctx context.Context) (string, error)
	Logger         *slog.Logger
	HTTPClient     *http.Client // nil → 10s-timeout default

	lastHash [32]byte
}

// Run blocks until ctx is cancelled. First upload happens immediately.
func (u *Uploader) Run(ctx context.Context) {
	interval := u.Interval
	if interval <= 0 {
		interval = 5 * time.Minute
	}
	t := time.NewTicker(interval)
	defer t.Stop()

	u.tick(ctx)
	for {
		select {
		case <-ctx.Done():
			return
		case <-t.C:
			u.tick(ctx)
		}
	}
}

func (u *Uploader) tick(ctx context.Context) {
	if err := u.UploadOnce(ctx); err != nil {
		// Upload failure is never fatal — the store keeps selling and we
		// retry next tick. Same offline-first posture as the sync engine.
		u.Logger.Warn("catalogsync: upload failed", "err", err)
	}
}

// UploadOnce builds the snapshot and PUTs it if changed since the last
// successful upload. Exported for tests and for a future manual
// "push catalog now" admin action.
func (u *Uploader) UploadOnce(ctx context.Context) error {
	snap, err := u.buildSnapshot(ctx)
	if err != nil {
		return fmt.Errorf("build: %w", err)
	}
	// Hash the content WITHOUT captured_at so an unchanged catalog hashes
	// stable across ticks.
	snap.CapturedAt = time.Time{}
	stable, err := json.Marshal(snap)
	if err != nil {
		return fmt.Errorf("marshal: %w", err)
	}
	h := sha256.Sum256(stable)
	if h == u.lastHash {
		return nil // unchanged — skip network
	}

	snap.CapturedAt = time.Now().UTC()
	body, err := json.Marshal(snap)
	if err != nil {
		return fmt.Errorf("marshal: %w", err)
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPut,
		u.CloudURL+"/v1/sync/catalog", bytes.NewReader(body))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	if u.AuthHeaderFunc != nil {
		auth, err := u.AuthHeaderFunc(ctx)
		if err != nil {
			return fmt.Errorf("auth: %w", err)
		}
		req.Header.Set("Authorization", auth)
	}

	client := u.HTTPClient
	if client == nil {
		client = &http.Client{Timeout: 10 * time.Second}
	}
	resp, err := client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusNoContent {
		return fmt.Errorf("cloud returned %d", resp.StatusCode)
	}
	u.lastHash = h
	u.Logger.Info("catalogsync: snapshot uploaded",
		"items", len(snap.Items), "tax_categories", len(snap.TaxCategories), "bytes", len(body))
	return nil
}

func (u *Uploader) buildSnapshot(ctx context.Context) (Snapshot, error) {
	snap := Snapshot{
		TenantID:      u.TenantID,
		NodeID:        u.NodeID,
		Items:         []Item{},
		TaxCategories: []TaxCategory{},
	}

	rows, err := u.DB.QueryContext(ctx,
		`SELECT sku, name, price_currency, price_units, price_nanos,
		        COALESCE(tax_category_id, ''), archived_at IS NOT NULL
		 FROM items WHERE tenant_id = ? ORDER BY sku`, u.TenantID)
	if err != nil {
		return snap, fmt.Errorf("items: %w", err)
	}
	defer rows.Close()
	for rows.Next() {
		var it Item
		if err := rows.Scan(&it.SKU, &it.Name, &it.Price.CurrencyCode,
			&it.Price.Units, &it.Price.Nanos, &it.TaxCategoryID, &it.Archived); err != nil {
			return snap, fmt.Errorf("items scan: %w", err)
		}
		snap.Items = append(snap.Items, it)
	}
	if err := rows.Err(); err != nil {
		return snap, err
	}

	tRows, err := u.DB.QueryContext(ctx,
		`SELECT tax_category_id, name, price_includes_tax, archived_at IS NOT NULL
		 FROM tax_categories WHERE tenant_id = ? ORDER BY tax_category_id`, u.TenantID)
	if err != nil {
		return snap, fmt.Errorf("tax_categories: %w", err)
	}
	defer tRows.Close()
	for tRows.Next() {
		var tc TaxCategory
		if err := tRows.Scan(&tc.ID, &tc.Name, &tc.PriceIncludesTax, &tc.Archived); err != nil {
			return snap, fmt.Errorf("tax scan: %w", err)
		}
		snap.TaxCategories = append(snap.TaxCategories, tc)
	}
	return snap, tRows.Err()
}
