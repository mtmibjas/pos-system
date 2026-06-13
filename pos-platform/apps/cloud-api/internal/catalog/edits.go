// Catalog edit intent queue — slice 6.6. The dashboard appends intents;
// store nodes pull/ack them. See docs/catalog-editing-design.md.
package catalog

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"time"
)

// Edit kinds. Payload validation is the API layer's job; this store
// treats payloads as opaque JSON.
const (
	KindUpsertItem        = "upsert_item"
	KindUpsertTaxCategory = "upsert_tax_category"
)

// Ack statuses a node can report.
const (
	AckApplied  = "applied"
	AckConflict = "conflict"
)

type Edit struct {
	Seq       int64           `json:"seq"`
	EditID    string          `json:"edit_id"`
	Kind      string          `json:"kind"`
	Payload   json.RawMessage `json:"payload"`
	CreatedBy string          `json:"created_by"`
	CreatedAt time.Time       `json:"created_at"`
}

// NodeAck is one node's verdict on one edit.
type NodeAck struct {
	NodeID  string    `json:"node_id"`
	Status  string    `json:"status"`
	Detail  string    `json:"detail,omitempty"`
	AckedAt time.Time `json:"acked_at"`
}

// EditWithAcks is the dashboard view: the intent plus every node's ack.
type EditWithAcks struct {
	Edit
	Acks []NodeAck `json:"acks"`
}

// AppendEdit stores a new intent and returns its assigned seq.
func (s *Store) AppendEdit(ctx context.Context, tenantID, editID, kind string, payload []byte, createdBy string) (int64, error) {
	res, err := s.db.ExecContext(ctx,
		`INSERT INTO catalog_edits (edit_id, tenant_id, kind, payload, created_by, created_at)
		 VALUES (?, ?, ?, ?, ?, ?)`,
		editID, tenantID, kind, string(payload), createdBy, s.now().UTC().Unix())
	if err != nil {
		return 0, fmt.Errorf("catalog: append edit: %w", err)
	}
	return res.LastInsertId()
}

// EditsAfter returns intents with seq > after for one tenant, oldest
// first, capped at limit (0 → 100).
func (s *Store) EditsAfter(ctx context.Context, tenantID string, after int64, limit int) ([]Edit, error) {
	if limit <= 0 {
		limit = 100
	}
	rows, err := s.db.QueryContext(ctx,
		`SELECT seq, edit_id, kind, payload, created_by, created_at
		 FROM catalog_edits WHERE tenant_id = ? AND seq > ?
		 ORDER BY seq LIMIT ?`, tenantID, after, limit)
	if err != nil {
		return nil, fmt.Errorf("catalog: edits after: %w", err)
	}
	defer rows.Close()
	return scanEdits(rows)
}

// RecordAck upserts one node's verdict for one edit. Re-acks overwrite
// (a node that re-applies after a wipe reports the newest truth).
func (s *Store) RecordAck(ctx context.Context, tenantID, nodeID string, seq int64, status, detail string) error {
	if status != AckApplied && status != AckConflict {
		return fmt.Errorf("catalog: bad ack status %q", status)
	}
	_, err := s.db.ExecContext(ctx,
		`INSERT INTO catalog_edit_acks (tenant_id, node_id, seq, status, detail, acked_at)
		 VALUES (?, ?, ?, ?, ?, ?)
		 ON CONFLICT (tenant_id, node_id, seq) DO UPDATE SET
		   status = excluded.status, detail = excluded.detail, acked_at = excluded.acked_at`,
		tenantID, nodeID, seq, status, detail, s.now().UTC().Unix())
	if err != nil {
		return fmt.Errorf("catalog: record ack: %w", err)
	}
	return nil
}

// RecentEditsWithAcks returns the newest `limit` intents (newest first)
// with their per-node acks — the dashboard's "pending changes" panel.
func (s *Store) RecentEditsWithAcks(ctx context.Context, tenantID string, limit int) ([]EditWithAcks, error) {
	if limit <= 0 {
		limit = 50
	}
	rows, err := s.db.QueryContext(ctx,
		`SELECT seq, edit_id, kind, payload, created_by, created_at
		 FROM catalog_edits WHERE tenant_id = ?
		 ORDER BY seq DESC LIMIT ?`, tenantID, limit)
	if err != nil {
		return nil, fmt.Errorf("catalog: recent edits: %w", err)
	}
	defer rows.Close()
	edits, err := scanEdits(rows)
	if err != nil {
		return nil, err
	}

	out := make([]EditWithAcks, 0, len(edits))
	for _, e := range edits {
		acks, err := s.acksFor(ctx, tenantID, e.Seq)
		if err != nil {
			return nil, err
		}
		out = append(out, EditWithAcks{Edit: e, Acks: acks})
	}
	return out, nil
}

func (s *Store) acksFor(ctx context.Context, tenantID string, seq int64) ([]NodeAck, error) {
	rows, err := s.db.QueryContext(ctx,
		`SELECT node_id, status, detail, acked_at FROM catalog_edit_acks
		 WHERE tenant_id = ? AND seq = ? ORDER BY node_id`, tenantID, seq)
	if err != nil {
		return nil, fmt.Errorf("catalog: acks: %w", err)
	}
	defer rows.Close()
	acks := []NodeAck{}
	for rows.Next() {
		var a NodeAck
		var at int64
		if err := rows.Scan(&a.NodeID, &a.Status, &a.Detail, &at); err != nil {
			return nil, err
		}
		a.AckedAt = time.Unix(at, 0).UTC()
		acks = append(acks, a)
	}
	return acks, rows.Err()
}

func scanEdits(rows *sql.Rows) ([]Edit, error) {
	var out []Edit
	for rows.Next() {
		var e Edit
		var payload string
		var cAt int64
		if err := rows.Scan(&e.Seq, &e.EditID, &e.Kind, &payload, &e.CreatedBy, &cAt); err != nil {
			return nil, fmt.Errorf("catalog: scan edit: %w", err)
		}
		e.Payload = json.RawMessage(payload)
		e.CreatedAt = time.Unix(cAt, 0).UTC()
		out = append(out, e)
	}
	return out, rows.Err()
}
