// Package api hosts the cloud-api's read-side HTTP handlers.
//
// Phase 3 (slice 3.4) ships the `/v1/sync/events` cursor stream — JSON,
// keyset-paginated, tenant-scoped by the JWT claim. Write-path
// handlers continue to live in main.go for now; this package exists so
// the read side can grow (filters, multi-entity scoping, etc.) without
// touching the wire-shape of the ingest endpoint.
package api

import (
	"encoding/base64"
	"encoding/json"
	"log/slog"
	"net/http"
	"strconv"

	"github.com/mibjas/pos-platform/apps/cloud-api/internal/auth"
	"github.com/mibjas/pos-platform/apps/cloud-api/internal/ingest"
)

// EventsHandler serves GET /v1/sync/events.
type EventsHandler struct {
	store    *ingest.Store
	verifier *auth.Verifier // when nil, the handler trusts an X-Tenant header (test/dev only)
	logger   *slog.Logger
}

// NewEventsHandler wires the read store + verifier. Pass a nil
// verifier to run in --insecure-no-auth mode: in that case the
// tenant must arrive via the X-Tenant header (refusing to default
// keeps the no-auth path from accidentally crossing tenants).
func NewEventsHandler(store *ingest.Store, verifier *auth.Verifier, logger *slog.Logger) *EventsHandler {
	return &EventsHandler{store: store, verifier: verifier, logger: logger}
}

// eventJSON is the wire form of a single event row. Payload is
// base64-encoded so the JSON envelope stays text-safe; callers
// proto-decode it on the client.
type eventJSON struct {
	ID               int64  `json:"id"`
	OperationID      string `json:"operation_id"`
	BatchID          string `json:"batch_id"`
	TenantID         string `json:"tenant_id"`
	OperationType    string `json:"operation_type"`
	EntityType       string `json:"entity_type"`
	EntityID         string `json:"entity_id"`
	PayloadB64       string `json:"payload_b64"`
	Lamport          int64  `json:"lamport"`
	OriginNodeID     string `json:"origin_node_id"`
	OccurredAtUnixNs int64  `json:"occurred_at_unix_ns"`
	ReceivedAtUnixNs int64  `json:"received_at_unix_ns"`
}

type listResponse struct {
	Events     []eventJSON `json:"events"`
	NextCursor string      `json:"next_cursor"` // "" = end of stream
}

// ServeHTTP implements GET /v1/sync/events?cursor=...&limit=...
//
// - method must be GET (anything else → 405)
// - tenant is taken from JWT claims if verifier!=nil, else from X-Tenant header
// - bad cursor / negative limit → 400
// - all other errors → 500 with a one-line slog
func (h *EventsHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	tenant, err := h.resolveTenant(r)
	if err != nil {
		status, ok := auth.IsAuthError(err)
		if !ok {
			status = http.StatusBadRequest
		}
		http.Error(w, err.Error(), status)
		return
	}

	cursor, err := ingest.DecodeCursor(r.URL.Query().Get("cursor"))
	if err != nil {
		http.Error(w, "bad cursor: "+err.Error(), http.StatusBadRequest)
		return
	}

	limit := 0
	if s := r.URL.Query().Get("limit"); s != "" {
		n, err := strconv.Atoi(s)
		if err != nil {
			http.Error(w, "bad limit: "+err.Error(), http.StatusBadRequest)
			return
		}
		if n < 0 {
			http.Error(w, "limit must be non-negative", http.StatusBadRequest)
			return
		}
		limit = n
	}

	events, next, err := h.store.List(r.Context(), tenant, cursor, limit)
	if err != nil {
		h.logger.Error("events: list", "tenant", tenant, "err", err)
		http.Error(w, "list events", http.StatusInternalServerError)
		return
	}

	out := listResponse{
		Events:     make([]eventJSON, 0, len(events)),
		NextCursor: ingest.EncodeCursor(next),
	}
	for _, e := range events {
		out.Events = append(out.Events, eventJSON{
			ID:               e.ID,
			OperationID:      e.OperationID,
			BatchID:          e.BatchID,
			TenantID:         e.TenantID,
			OperationType:    e.OperationType,
			EntityType:       e.EntityType,
			EntityID:         e.EntityID,
			PayloadB64:       base64.StdEncoding.EncodeToString(e.Payload),
			Lamport:          e.Lamport,
			OriginNodeID:     e.OriginNodeID,
			OccurredAtUnixNs: e.OccurredAtUnixNs,
			ReceivedAtUnixNs: e.ReceivedAtUnixNs,
		})
	}

	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(out); err != nil {
		// Headers already written — log and bail; client will see truncated body.
		h.logger.Error("events: encode", "err", err)
	}
}

// resolveTenant pulls the tenant for this request from the JWT claim
// when auth is on, or from the X-Tenant header when running in
// no-auth mode. Returns auth sentinels so the caller can map to 401.
func (h *EventsHandler) resolveTenant(r *http.Request) (string, error) {
	if h.verifier != nil {
		claims, ok := auth.FromContext(r.Context())
		if !ok {
			// Middleware should have populated this; if not, auth was
			// bypassed and the request is unauthenticated.
			return "", auth.ErrMissingToken
		}
		return claims.TenantID, nil
	}
	t := r.Header.Get("X-Tenant")
	if t == "" {
		return "", errInsecureTenantRequired
	}
	return t, nil
}

// errInsecureTenantRequired is returned in --insecure-no-auth mode when
// the caller failed to pin X-Tenant. We refuse to default — picking a
// tenant silently in the no-auth path would defeat the smuggling
// defence that slice 3.5 added on the write side.
var errInsecureTenantRequired = &badRequestError{"X-Tenant header is required in insecure-no-auth mode"}

type badRequestError struct{ msg string }

func (e *badRequestError) Error() string { return e.msg }
