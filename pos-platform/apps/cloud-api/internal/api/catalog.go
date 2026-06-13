// Catalog snapshot endpoints — slice 6.5.
//
//	PUT /v1/sync/catalog   — store nodes upload their catalog (JWT,
//	                          tenant pinned to the claim like batches)
//	GET /v1/admin/catalog  — owner-gated read for the dashboard
package api

import (
	"encoding/json"
	"io"
	"log/slog"
	"net/http"

	"github.com/mibjas/pos-platform/apps/cloud-api/internal/auth"
	"github.com/mibjas/pos-platform/apps/cloud-api/internal/catalog"
)

// snapshotEnvelope is the minimal shape we validate on upload. items /
// tax_categories stay raw — the cloud mirrors, it doesn't interpret.
type snapshotEnvelope struct {
	TenantID string `json:"tenant_id"`
	NodeID   string `json:"node_id"`
}

// maxSnapshotBytes bounds upload size; a retail catalog measured in
// megabytes is a bug (or an abuse attempt), not a use case.
const maxSnapshotBytes = 4 << 20

// CatalogUploadHandler accepts PUT /v1/sync/catalog. Mounted behind
// RequireJWT; tenant enforcement mirrors handleBatches (claims tenant
// must equal body tenant when auth is on).
type CatalogUploadHandler struct {
	store        *catalog.Store
	authRequired bool
	logger       *slog.Logger
}

func NewCatalogUploadHandler(store *catalog.Store, authRequired bool, logger *slog.Logger) *CatalogUploadHandler {
	return &CatalogUploadHandler{store: store, authRequired: authRequired, logger: logger}
}

func (h *CatalogUploadHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPut {
		writeJSONStatus(w, http.StatusMethodNotAllowed, errorResponse{Error: "method not allowed"})
		return
	}
	defer r.Body.Close()
	body, err := io.ReadAll(io.LimitReader(r.Body, maxSnapshotBytes+1))
	if err != nil {
		writeJSONStatus(w, http.StatusBadRequest, errorResponse{Error: "read body failed"})
		return
	}
	if len(body) > maxSnapshotBytes {
		writeJSONStatus(w, http.StatusRequestEntityTooLarge, errorResponse{Error: "snapshot too large"})
		return
	}
	var env snapshotEnvelope
	if err := json.Unmarshal(body, &env); err != nil {
		writeJSONStatus(w, http.StatusBadRequest, errorResponse{Error: "malformed JSON"})
		return
	}
	if env.TenantID == "" || env.NodeID == "" {
		writeJSONStatus(w, http.StatusBadRequest, errorResponse{Error: "tenant_id and node_id are required"})
		return
	}
	if err := auth.EnforceTenant(r.Context(), env.TenantID, h.authRequired); err != nil {
		status, ok := auth.IsAuthError(err)
		if !ok {
			status = http.StatusForbidden
		}
		writeJSONStatus(w, status, errorResponse{Error: err.Error()})
		return
	}
	if err := h.store.Upsert(r.Context(), env.TenantID, env.NodeID, body); err != nil {
		h.logger.Error("catalog: upsert", "tenant", env.TenantID, "node", env.NodeID, "err", err)
		writeJSONStatus(w, http.StatusInternalServerError, errorResponse{Error: "store failed"})
		return
	}
	h.logger.Info("catalog: snapshot stored",
		"tenant", env.TenantID, "node", env.NodeID, "bytes", len(body))
	w.WriteHeader(http.StatusNoContent)
}

// AdminCatalogHandler serves GET /v1/admin/catalog. Mounted behind
// RequireJWT + RequireRole(owner); tenant comes from claims only.
type AdminCatalogHandler struct {
	store  *catalog.Store
	logger *slog.Logger
}

func NewAdminCatalogHandler(store *catalog.Store, logger *slog.Logger) *AdminCatalogHandler {
	return &AdminCatalogHandler{store: store, logger: logger}
}

func (h *AdminCatalogHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeJSONStatus(w, http.StatusMethodNotAllowed, errorResponse{Error: "method not allowed"})
		return
	}
	claims, ok := auth.FromContext(r.Context())
	if !ok {
		writeJSONStatus(w, http.StatusUnauthorized, errorResponse{Error: "missing claims"})
		return
	}
	snaps, err := h.store.List(r.Context(), claims.TenantID)
	if err != nil {
		h.logger.Error("catalog: list", "tenant", claims.TenantID, "err", err)
		writeJSONStatus(w, http.StatusInternalServerError, errorResponse{Error: "list failed"})
		return
	}
	if snaps == nil {
		snaps = []catalog.Snapshot{}
	}
	writeJSONStatus(w, http.StatusOK, map[string]any{"snapshots": snaps})
}
