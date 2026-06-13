// Platform-admin tenant management — slice 6.7. Mounted behind
// RequireJWT + RequireRole(platform_admin); deliberately ignores the
// caller's tenant_id claim (platform staff operate across tenants).
//
//	GET   /v1/platform/tenants              — list all tenants + usage
//	POST  /v1/platform/tenants              — create tenant
//	PATCH /v1/platform/tenants/{id}         — set status (suspend/activate)
//	GET   /v1/platform/tenants/{id}/users   — that tenant's users
package api

import (
	"encoding/json"
	"errors"
	"log/slog"
	"net/http"
	"strings"

	"github.com/mibjas/pos-platform/apps/cloud-api/internal/tenants"
	"github.com/mibjas/pos-platform/apps/cloud-api/internal/users"
)

type PlatformTenantsHandler struct {
	tenants *tenants.Store
	users   *users.DBStore
	logger  *slog.Logger
}

func NewPlatformTenantsHandler(t *tenants.Store, u *users.DBStore, logger *slog.Logger) *PlatformTenantsHandler {
	return &PlatformTenantsHandler{tenants: t, users: u, logger: logger}
}

type createTenantRequest struct {
	TenantID string `json:"tenant_id"`
	Name     string `json:"name"`
}

type patchTenantRequest struct {
	Status string `json:"status"`
}

func (h *PlatformTenantsHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	rest := strings.Trim(strings.TrimPrefix(r.URL.Path, "/v1/platform/tenants"), "/")
	parts := []string{}
	if rest != "" {
		parts = strings.SplitN(rest, "/", 2)
	}

	switch {
	case len(parts) == 0 && r.Method == http.MethodGet:
		h.list(w, r)
	case len(parts) == 0 && r.Method == http.MethodPost:
		h.create(w, r)
	case len(parts) == 1 && r.Method == http.MethodPatch:
		h.patch(w, r, parts[0])
	case len(parts) == 2 && parts[1] == "users" && r.Method == http.MethodGet:
		h.tenantUsers(w, r, parts[0])
	default:
		writeJSONStatus(w, http.StatusMethodNotAllowed, errorResponse{Error: "method not allowed"})
	}
}

func (h *PlatformTenantsHandler) list(w http.ResponseWriter, r *http.Request) {
	out, err := h.tenants.ListWithUsage(r.Context())
	if err != nil {
		h.logger.Error("platform: list tenants", "err", err)
		writeJSONStatus(w, http.StatusInternalServerError, errorResponse{Error: "list failed"})
		return
	}
	if out == nil {
		out = []tenants.TenantWithUsage{}
	}
	writeJSONStatus(w, http.StatusOK, map[string]any{"tenants": out})
}

func (h *PlatformTenantsHandler) create(w http.ResponseWriter, r *http.Request) {
	defer r.Body.Close()
	var req createTenantRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSONStatus(w, http.StatusBadRequest, errorResponse{Error: "malformed request body"})
		return
	}
	t, err := h.tenants.Create(r.Context(), req.TenantID, req.Name)
	switch {
	case errors.Is(err, tenants.ErrEmptyID):
		writeJSONStatus(w, http.StatusBadRequest, errorResponse{Error: "tenant_id is required"})
	case errors.Is(err, tenants.ErrIDTaken):
		writeJSONStatus(w, http.StatusConflict, errorResponse{Error: "tenant_id already exists"})
	case err != nil:
		h.logger.Error("platform: create tenant", "err", err)
		writeJSONStatus(w, http.StatusInternalServerError, errorResponse{Error: "create failed"})
	default:
		h.logger.Info("platform: tenant created", "tenant", t.TenantID)
		writeJSONStatus(w, http.StatusCreated, t)
	}
}

func (h *PlatformTenantsHandler) patch(w http.ResponseWriter, r *http.Request, tenantID string) {
	defer r.Body.Close()
	var req patchTenantRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSONStatus(w, http.StatusBadRequest, errorResponse{Error: "malformed request body"})
		return
	}
	t, err := h.tenants.SetStatus(r.Context(), tenantID, req.Status)
	switch {
	case errors.Is(err, tenants.ErrBadStatus):
		writeJSONStatus(w, http.StatusBadRequest, errorResponse{Error: "status must be active or suspended"})
	case errors.Is(err, tenants.ErrNotFound):
		writeJSONStatus(w, http.StatusNotFound, errorResponse{Error: "tenant not found"})
	case err != nil:
		h.logger.Error("platform: patch tenant", "tenant", tenantID, "err", err)
		writeJSONStatus(w, http.StatusInternalServerError, errorResponse{Error: "update failed"})
	default:
		h.logger.Info("platform: tenant status changed", "tenant", tenantID, "status", t.Status)
		writeJSONStatus(w, http.StatusOK, t)
	}
}

func (h *PlatformTenantsHandler) tenantUsers(w http.ResponseWriter, r *http.Request, tenantID string) {
	recs, err := h.users.List(r.Context(), tenantID)
	if err != nil {
		h.logger.Error("platform: tenant users", "tenant", tenantID, "err", err)
		writeJSONStatus(w, http.StatusInternalServerError, errorResponse{Error: "list failed"})
		return
	}
	if recs == nil {
		recs = []users.Record{}
	}
	writeJSONStatus(w, http.StatusOK, map[string]any{"users": recs})
}
