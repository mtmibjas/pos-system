// Applier — slice 6.6 downstream half. Pulls catalog edit intents from
// cloud-api, applies them to the local items / tax_categories tables
// (the store's SQLite stays the source of truth — an intent the store
// rejects simply doesn't happen), and acks per-edit verdicts.
//
// Conflict rule (docs/catalog-editing-design.md §3): skip with status
// "conflict" when the local row's updated_at is newer than the
// intent's created_at — a store-local manual edit beats a stale cloud
// push. The cursor advances past conflicts; they are terminal for this
// node and the owner re-issues from the dashboard.
package catalogsync

import (
	"bytes"
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"log/slog"
	"net/http"
	"time"
)

// Edit kinds — mirror cloud-api's catalog package.
const (
	kindUpsertItem        = "upsert_item"
	kindUpsertTaxCategory = "upsert_tax_category"
)

type pulledEdit struct {
	Seq       int64           `json:"seq"`
	EditID    string          `json:"edit_id"`
	Kind      string          `json:"kind"`
	Payload   json.RawMessage `json:"payload"`
	CreatedAt time.Time       `json:"created_at"`
}

type ackVerdict struct {
	Seq    int64  `json:"seq"`
	Status string `json:"status"`
	Detail string `json:"detail,omitempty"`
}

// Applier pulls and applies catalog edit intents. Same wiring shape as
// Uploader; OnApplied (optional) fires after a tick that applied at
// least one edit — main.go points it at Uploader.UploadOnce so the
// dashboard converges quickly instead of waiting for the 5-minute
// snapshot tick.
type Applier struct {
	DB             *sql.DB
	CloudURL       string
	TenantID       string
	NodeID         string
	Interval       time.Duration // 0 → 30s default
	AuthHeaderFunc func(ctx context.Context) (string, error)
	Logger         *slog.Logger
	HTTPClient     *http.Client
	OnApplied      func(ctx context.Context)
	Now            func() time.Time // tests override; nil → time.Now
}

// Run blocks until ctx cancels. First pull happens immediately.
func (a *Applier) Run(ctx context.Context) {
	interval := a.Interval
	if interval <= 0 {
		interval = 30 * time.Second
	}
	t := time.NewTicker(interval)
	defer t.Stop()

	a.tick(ctx)
	for {
		select {
		case <-ctx.Done():
			return
		case <-t.C:
			a.tick(ctx)
		}
	}
}

func (a *Applier) tick(ctx context.Context) {
	applied, err := a.PullApplyOnce(ctx)
	if err != nil {
		a.Logger.Warn("catalogsync: pull/apply failed", "err", err)
		return
	}
	if applied > 0 && a.OnApplied != nil {
		a.OnApplied(ctx)
	}
}

// PullApplyOnce pulls one page of intents after the local cursor,
// applies them, acks, and advances the cursor. Returns how many edits
// were applied (not counting conflicts). Exported for tests.
func (a *Applier) PullApplyOnce(ctx context.Context) (int, error) {
	cursor, err := a.loadCursor(ctx)
	if err != nil {
		return 0, err
	}
	edits, err := a.pull(ctx, cursor)
	if err != nil {
		return 0, err
	}
	if len(edits) == 0 {
		return 0, nil
	}

	applied := 0
	verdicts := make([]ackVerdict, 0, len(edits))
	maxSeq := cursor
	for _, e := range edits {
		v := a.applyOne(ctx, e)
		verdicts = append(verdicts, v)
		if v.Status == "applied" {
			applied++
		}
		if e.Seq > maxSeq {
			maxSeq = e.Seq
		}
	}

	// Ack BEFORE advancing the cursor: if the ack fails we re-pull the
	// same page next tick and re-apply. Apply is idempotent (same
	// upsert) so the retry is safe; the reverse order could lose acks
	// forever.
	if err := a.ack(ctx, verdicts); err != nil {
		return applied, fmt.Errorf("ack: %w", err)
	}
	if err := a.saveCursor(ctx, maxSeq); err != nil {
		return applied, fmt.Errorf("cursor: %w", err)
	}
	a.Logger.Info("catalogsync: edits processed",
		"pulled", len(edits), "applied", applied, "cursor", maxSeq)
	return applied, nil
}

func (a *Applier) applyOne(ctx context.Context, e pulledEdit) ackVerdict {
	var err error
	switch e.Kind {
	case kindUpsertItem:
		err = a.upsertItem(ctx, e)
	case kindUpsertTaxCategory:
		err = a.upsertTaxCategory(ctx, e)
	default:
		return ackVerdict{Seq: e.Seq, Status: "conflict", Detail: "unknown kind " + e.Kind}
	}
	if err != nil {
		return ackVerdict{Seq: e.Seq, Status: "conflict", Detail: err.Error()}
	}
	return ackVerdict{Seq: e.Seq, Status: "applied"}
}

func (a *Applier) now() time.Time {
	if a.Now != nil {
		return a.Now()
	}
	return time.Now()
}

func (a *Applier) upsertItem(ctx context.Context, e pulledEdit) error {
	var p Item
	if err := json.Unmarshal(e.Payload, &p); err != nil {
		return fmt.Errorf("malformed payload: %w", err)
	}

	tx, err := a.DB.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer func() { _ = tx.Rollback() }()

	// Conflict guard: local manual edit beats stale cloud intent.
	var localUpdated sql.NullInt64
	err = tx.QueryRowContext(ctx,
		`SELECT updated_at FROM items WHERE sku = ? AND tenant_id = ?`,
		p.SKU, a.TenantID).Scan(&localUpdated)
	exists := err == nil
	if err != nil && err != sql.ErrNoRows {
		return err
	}
	if exists && localUpdated.Int64 > e.CreatedAt.Unix() {
		return fmt.Errorf("local change is newer than this edit")
	}

	// Referenced tax category must exist locally (empty = exempt, OK).
	if p.TaxCategoryID != "" {
		var n int
		if err := tx.QueryRowContext(ctx,
			`SELECT COUNT(*) FROM tax_categories WHERE tax_category_id = ? AND tenant_id = ?`,
			p.TaxCategoryID, a.TenantID).Scan(&n); err != nil {
			return err
		}
		if n == 0 {
			return fmt.Errorf("unknown tax category %q", p.TaxCategoryID)
		}
	}

	now := a.now().UTC().Unix()
	var archivedAt any // nil or timestamp
	if p.Archived {
		archivedAt = now
	}
	taxID := any(nil)
	if p.TaxCategoryID != "" {
		taxID = p.TaxCategoryID
	}
	if exists {
		_, err = tx.ExecContext(ctx,
			`UPDATE items SET name = ?, price_currency = ?, price_units = ?, price_nanos = ?,
			 tax_category_id = ?, archived_at = ?, updated_at = ?
			 WHERE sku = ? AND tenant_id = ?`,
			p.Name, p.Price.CurrencyCode, p.Price.Units, p.Price.Nanos,
			taxID, archivedAt, now, p.SKU, a.TenantID)
	} else {
		_, err = tx.ExecContext(ctx,
			`INSERT INTO items (sku, tenant_id, name, price_currency, price_units, price_nanos,
			 tax_category_id, archived_at, created_at, updated_at)
			 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
			p.SKU, a.TenantID, p.Name, p.Price.CurrencyCode, p.Price.Units, p.Price.Nanos,
			taxID, archivedAt, now, now)
	}
	if err != nil {
		return err
	}
	return tx.Commit()
}

func (a *Applier) upsertTaxCategory(ctx context.Context, e pulledEdit) error {
	var p TaxCategory
	if err := json.Unmarshal(e.Payload, &p); err != nil {
		return fmt.Errorf("malformed payload: %w", err)
	}

	// tax_categories has no updated_at column — the conflict guard is
	// existence-free here; whole-record upsert always wins. Acceptable:
	// tax categories change rarely and only deliberately.
	now := a.now().UTC().Unix()
	var archivedAt any
	if p.Archived {
		archivedAt = now
	}
	_, err := a.DB.ExecContext(ctx,
		`INSERT INTO tax_categories (tax_category_id, name, tenant_id, price_includes_tax, archived_at)
		 VALUES (?, ?, ?, ?, ?)
		 ON CONFLICT (tax_category_id) DO UPDATE SET
		   name = excluded.name, price_includes_tax = excluded.price_includes_tax,
		   archived_at = excluded.archived_at`,
		p.ID, p.Name, a.TenantID, boolToInt(p.PriceIncludesTax), archivedAt)
	return err
}

// ---- HTTP plumbing ----

func (a *Applier) pull(ctx context.Context, after int64) ([]pulledEdit, error) {
	url := fmt.Sprintf("%s/v1/sync/catalog-edits?after=%d", a.CloudURL, after)
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return nil, err
	}
	if err := a.setAuth(ctx, req); err != nil {
		return nil, err
	}
	resp, err := a.client().Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("pull returned %d", resp.StatusCode)
	}
	var body struct {
		Edits []pulledEdit `json:"edits"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&body); err != nil {
		return nil, err
	}
	return body.Edits, nil
}

func (a *Applier) ack(ctx context.Context, verdicts []ackVerdict) error {
	payload, err := json.Marshal(map[string]any{"node_id": a.NodeID, "acks": verdicts})
	if err != nil {
		return err
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost,
		a.CloudURL+"/v1/sync/catalog-edits/ack", bytes.NewReader(payload))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	if err := a.setAuth(ctx, req); err != nil {
		return err
	}
	resp, err := a.client().Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusNoContent {
		return fmt.Errorf("ack returned %d", resp.StatusCode)
	}
	return nil
}

func (a *Applier) setAuth(ctx context.Context, req *http.Request) error {
	if a.AuthHeaderFunc == nil {
		return nil
	}
	h, err := a.AuthHeaderFunc(ctx)
	if err != nil {
		return fmt.Errorf("auth: %w", err)
	}
	req.Header.Set("Authorization", h)
	return nil
}

func (a *Applier) client() *http.Client {
	if a.HTTPClient != nil {
		return a.HTTPClient
	}
	return &http.Client{Timeout: 10 * time.Second}
}

func (a *Applier) loadCursor(ctx context.Context) (int64, error) {
	var seq int64
	err := a.DB.QueryRowContext(ctx,
		`SELECT last_seq FROM catalog_pull_state WHERE id = 1`).Scan(&seq)
	return seq, err
}

func (a *Applier) saveCursor(ctx context.Context, seq int64) error {
	_, err := a.DB.ExecContext(ctx,
		`UPDATE catalog_pull_state SET last_seq = ? WHERE id = 1`, seq)
	return err
}

func boolToInt(b bool) int {
	if b {
		return 1
	}
	return 0
}
