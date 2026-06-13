// Package tenants — slice 6.7. Explicit tenant registry for the
// platform-admin area, plus the suspension gate used by login and sync
// ingest. A tenant with no row is implicitly ACTIVE (legacy data from
// before this table existed).
package tenants

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"strings"
	"time"
)

const (
	StatusActive    = "active"
	StatusSuspended = "suspended"
)

var (
	ErrNotFound    = errors.New("tenants: not found")
	ErrIDTaken     = errors.New("tenants: tenant_id already exists")
	ErrSuspended   = errors.New("tenants: tenant is suspended")
	ErrBadStatus   = errors.New("tenants: status must be active or suspended")
	ErrEmptyID     = errors.New("tenants: tenant_id is required")
)

type Tenant struct {
	TenantID  string    `json:"tenant_id"`
	Name      string    `json:"name"`
	Status    string    `json:"status"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

// Usage is the per-tenant activity summary shown on the platform page.
type Usage struct {
	UserCount  int        `json:"user_count"`
	EventCount int64      `json:"event_count"`
	NodeCount  int        `json:"node_count"`
	LastEvent  *time.Time `json:"last_event,omitempty"`
}

type TenantWithUsage struct {
	Tenant
	Usage Usage `json:"usage"`
}

type Store struct {
	db  *sql.DB
	now func() time.Time
}

func NewStore(db *sql.DB) *Store {
	return &Store{db: db, now: time.Now}
}

// Create registers a new tenant (status active).
func (s *Store) Create(ctx context.Context, tenantID, name string) (Tenant, error) {
	tenantID = strings.TrimSpace(tenantID)
	if tenantID == "" {
		return Tenant{}, ErrEmptyID
	}
	now := s.now().UTC()
	_, err := s.db.ExecContext(ctx,
		`INSERT INTO tenants (tenant_id, name, status, created_at, updated_at)
		 VALUES (?, ?, 'active', ?, ?)`,
		tenantID, name, now.Unix(), now.Unix())
	if err != nil {
		if strings.Contains(err.Error(), "UNIQUE constraint failed") {
			return Tenant{}, ErrIDTaken
		}
		return Tenant{}, fmt.Errorf("tenants: create: %w", err)
	}
	return Tenant{TenantID: tenantID, Name: name, Status: StatusActive,
		CreatedAt: now, UpdatedAt: now}, nil
}

// SetStatus flips active/suspended.
func (s *Store) SetStatus(ctx context.Context, tenantID, status string) (Tenant, error) {
	if status != StatusActive && status != StatusSuspended {
		return Tenant{}, ErrBadStatus
	}
	now := s.now().UTC()
	res, err := s.db.ExecContext(ctx,
		`UPDATE tenants SET status = ?, updated_at = ? WHERE tenant_id = ?`,
		status, now.Unix(), tenantID)
	if err != nil {
		return Tenant{}, fmt.Errorf("tenants: set status: %w", err)
	}
	if n, _ := res.RowsAffected(); n == 0 {
		return Tenant{}, ErrNotFound
	}
	return s.Get(ctx, tenantID)
}

// Get returns one tenant. ErrNotFound when no row exists.
func (s *Store) Get(ctx context.Context, tenantID string) (Tenant, error) {
	row := s.db.QueryRowContext(ctx,
		`SELECT tenant_id, name, status, created_at, updated_at
		 FROM tenants WHERE tenant_id = ?`, tenantID)
	var t Tenant
	var cAt, uAt int64
	if err := row.Scan(&t.TenantID, &t.Name, &t.Status, &cAt, &uAt); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return Tenant{}, ErrNotFound
		}
		return Tenant{}, fmt.Errorf("tenants: get: %w", err)
	}
	t.CreatedAt = time.Unix(cAt, 0).UTC()
	t.UpdatedAt = time.Unix(uAt, 0).UTC()
	return t, nil
}

// CheckActive is the gate used by login and sync ingest: nil for
// active or UNKNOWN tenants (legacy implicit), ErrSuspended otherwise.
func (s *Store) CheckActive(ctx context.Context, tenantID string) error {
	t, err := s.Get(ctx, tenantID)
	if errors.Is(err, ErrNotFound) {
		return nil // implicit tenant — active by definition
	}
	if err != nil {
		return err
	}
	if t.Status == StatusSuspended {
		return ErrSuspended
	}
	return nil
}

// ListWithUsage returns all tenants with activity stats, newest first.
func (s *Store) ListWithUsage(ctx context.Context) ([]TenantWithUsage, error) {
	rows, err := s.db.QueryContext(ctx,
		`SELECT tenant_id, name, status, created_at, updated_at
		 FROM tenants ORDER BY created_at DESC, tenant_id`)
	if err != nil {
		return nil, fmt.Errorf("tenants: list: %w", err)
	}
	defer rows.Close()

	var out []TenantWithUsage
	for rows.Next() {
		var t TenantWithUsage
		var cAt, uAt int64
		if err := rows.Scan(&t.TenantID, &t.Name, &t.Status, &cAt, &uAt); err != nil {
			return nil, err
		}
		t.CreatedAt = time.Unix(cAt, 0).UTC()
		t.UpdatedAt = time.Unix(uAt, 0).UTC()
		out = append(out, t)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}

	for i := range out {
		u, err := s.usage(ctx, out[i].TenantID)
		if err != nil {
			return nil, err
		}
		out[i].Usage = u
	}
	return out, nil
}

func (s *Store) usage(ctx context.Context, tenantID string) (Usage, error) {
	var u Usage
	if err := s.db.QueryRowContext(ctx,
		`SELECT COUNT(*) FROM users WHERE tenant_id = ?`, tenantID).Scan(&u.UserCount); err != nil {
		return u, fmt.Errorf("tenants: usage users: %w", err)
	}
	var lastNs sql.NullInt64
	if err := s.db.QueryRowContext(ctx,
		`SELECT COUNT(*), MAX(received_at_unix_ns) FROM events WHERE tenant_id = ?`,
		tenantID).Scan(&u.EventCount, &lastNs); err != nil {
		return u, fmt.Errorf("tenants: usage events: %w", err)
	}
	if lastNs.Valid {
		t := time.Unix(0, lastNs.Int64).UTC()
		u.LastEvent = &t
	}
	if err := s.db.QueryRowContext(ctx,
		`SELECT COUNT(*) FROM catalog_snapshots WHERE tenant_id = ?`,
		tenantID).Scan(&u.NodeCount); err != nil {
		return u, fmt.Errorf("tenants: usage nodes: %w", err)
	}
	return u, nil
}
