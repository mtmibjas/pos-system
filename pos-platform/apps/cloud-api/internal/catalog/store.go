// Package catalog persists per-node catalog snapshots (slice 6.5).
// Payloads are opaque JSON — validation happens at the API layer
// (shape only), and the dashboard renders whatever the store sent.
package catalog

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"time"
)

type Store struct {
	db  *sql.DB
	now func() time.Time
}

func NewStore(db *sql.DB) *Store {
	return &Store{db: db, now: time.Now}
}

// Snapshot is one node's latest catalog as returned by List. Payload is
// raw JSON so the handler can embed it without re-marshalling.
type Snapshot struct {
	NodeID    string          `json:"node_id"`
	Payload   json.RawMessage `json:"payload"`
	UpdatedAt time.Time       `json:"updated_at"`
}

// Upsert stores payload as the latest snapshot for (tenant, node).
func (s *Store) Upsert(ctx context.Context, tenantID, nodeID string, payload []byte) error {
	_, err := s.db.ExecContext(ctx,
		`INSERT INTO catalog_snapshots (tenant_id, node_id, payload, updated_at)
		 VALUES (?, ?, ?, ?)
		 ON CONFLICT (tenant_id, node_id) DO UPDATE SET
		   payload = excluded.payload, updated_at = excluded.updated_at`,
		tenantID, nodeID, string(payload), s.now().UTC().Unix())
	if err != nil {
		return fmt.Errorf("catalog: upsert: %w", err)
	}
	return nil
}

// List returns every node's latest snapshot for a tenant, newest first.
func (s *Store) List(ctx context.Context, tenantID string) ([]Snapshot, error) {
	rows, err := s.db.QueryContext(ctx,
		`SELECT node_id, payload, updated_at FROM catalog_snapshots
		 WHERE tenant_id = ? ORDER BY updated_at DESC`, tenantID)
	if err != nil {
		return nil, fmt.Errorf("catalog: list: %w", err)
	}
	defer rows.Close()

	var out []Snapshot
	for rows.Next() {
		var snap Snapshot
		var payload string
		var uAt int64
		if err := rows.Scan(&snap.NodeID, &payload, &uAt); err != nil {
			return nil, fmt.Errorf("catalog: scan: %w", err)
		}
		snap.Payload = json.RawMessage(payload)
		snap.UpdatedAt = time.Unix(uAt, 0).UTC()
		out = append(out, snap)
	}
	return out, rows.Err()
}
