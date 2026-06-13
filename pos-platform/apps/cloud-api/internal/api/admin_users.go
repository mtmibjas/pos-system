// Admin user management — slice 6.1. Mounted at /v1/admin/users behind
// RequireJWT + RequireRole(owner); tenant scope always comes from the
// JWT claim, never from the request, so an owner can only ever see and
// mutate their own tenant's users.
//
// Guard rails enforced here (not in the store, because they depend on
// WHO is asking):
//   - you cannot disable your own account
//   - you cannot remove the owner role from your own account
// Both prevent a tenant from locking themselves out entirely.
package api

import (
	"encoding/json"
	"errors"
	"log/slog"
	"net/http"
	"strings"

	"github.com/mibjas/pos-platform/apps/cloud-api/internal/auth"
	"github.com/mibjas/pos-platform/apps/cloud-api/internal/users"
)

// AdminUsersHandler serves:
//
//	GET   /v1/admin/users             — list own-tenant users
//	POST  /v1/admin/users             — create a user
//	PATCH /v1/admin/users/{username}  — partial update (password/disabled/roles)
type AdminUsersHandler struct {
	store  *users.DBStore
	logger *slog.Logger
}

func NewAdminUsersHandler(store *users.DBStore, logger *slog.Logger) *AdminUsersHandler {
	return &AdminUsersHandler{store: store, logger: logger}
}

type createUserRequest struct {
	Username string   `json:"username"`
	Password string   `json:"password"`
	Roles    []string `json:"roles"`
}

type patchUserRequest struct {
	Password *string   `json:"password"`
	Disabled *bool     `json:"disabled"`
	Roles    *[]string `json:"roles"`
}

func (h *AdminUsersHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.FromContext(r.Context())
	if !ok {
		// Only reachable when the route is mounted without RequireJWT
		// (i.e. a wiring bug) — fail closed rather than serving cross-
		// tenant data.
		writeJSONStatus(w, http.StatusUnauthorized, errorResponse{Error: "missing claims"})
		return
	}
	tenant := claims.TenantID
	caller := claims.Subject

	// Path shape: /v1/admin/users or /v1/admin/users/{username}
	rest := strings.TrimPrefix(r.URL.Path, "/v1/admin/users")
	rest = strings.Trim(rest, "/")

	switch {
	case rest == "" && r.Method == http.MethodGet:
		h.list(w, r, tenant)
	case rest == "" && r.Method == http.MethodPost:
		h.create(w, r, tenant)
	case rest != "" && r.Method == http.MethodPatch:
		h.patch(w, r, tenant, caller, rest)
	default:
		writeJSONStatus(w, http.StatusMethodNotAllowed, errorResponse{Error: "method not allowed"})
	}
}

func (h *AdminUsersHandler) list(w http.ResponseWriter, r *http.Request, tenant string) {
	recs, err := h.store.List(r.Context(), tenant)
	if err != nil {
		h.logger.Error("admin: list users", "tenant", tenant, "err", err)
		writeJSONStatus(w, http.StatusInternalServerError, errorResponse{Error: "list failed"})
		return
	}
	if recs == nil {
		recs = []users.Record{}
	}
	writeJSONStatus(w, http.StatusOK, map[string]any{"users": recs})
}

func (h *AdminUsersHandler) create(w http.ResponseWriter, r *http.Request, tenant string) {
	defer r.Body.Close()
	var req createUserRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSONStatus(w, http.StatusBadRequest, errorResponse{Error: "malformed request body"})
		return
	}
	if req.Username == "" || req.Password == "" {
		writeJSONStatus(w, http.StatusBadRequest, errorResponse{Error: "username and password are required"})
		return
	}
	if len(req.Password) < 8 {
		writeJSONStatus(w, http.StatusBadRequest, errorResponse{Error: "password must be at least 8 characters"})
		return
	}
	// Privilege ceiling: the tenant-scoped admin API can never mint
	// platform staff. platform_admin users are provisioned out-of-band
	// (DB seed) or by other platform admins.
	if hasRole(req.Roles, auth.RolePlatformAdmin) {
		writeJSONStatus(w, http.StatusForbidden, errorResponse{Error: "cannot assign platform_admin role"})
		return
	}

	rec, err := h.store.Create(r.Context(), tenant, req.Username, req.Password, req.Roles)
	if err != nil {
		if errors.Is(err, users.ErrUsernameTaken) {
			writeJSONStatus(w, http.StatusConflict, errorResponse{Error: "username already taken"})
			return
		}
		h.logger.Error("admin: create user", "tenant", tenant, "username", req.Username, "err", err)
		writeJSONStatus(w, http.StatusInternalServerError, errorResponse{Error: "create failed"})
		return
	}
	h.logger.Info("admin: user created", "tenant", tenant, "username", rec.Username, "roles", rec.Roles)
	writeJSONStatus(w, http.StatusCreated, rec)
}

func (h *AdminUsersHandler) patch(w http.ResponseWriter, r *http.Request, tenant, caller, username string) {
	defer r.Body.Close()
	var req patchUserRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSONStatus(w, http.StatusBadRequest, errorResponse{Error: "malformed request body"})
		return
	}
	if req.Password == nil && req.Disabled == nil && req.Roles == nil {
		writeJSONStatus(w, http.StatusBadRequest, errorResponse{Error: "no fields to update"})
		return
	}
	if req.Password != nil && len(*req.Password) < 8 {
		writeJSONStatus(w, http.StatusBadRequest, errorResponse{Error: "password must be at least 8 characters"})
		return
	}

	// Privilege ceiling — same rule as create.
	if req.Roles != nil && hasRole(*req.Roles, auth.RolePlatformAdmin) {
		writeJSONStatus(w, http.StatusForbidden, errorResponse{Error: "cannot assign platform_admin role"})
		return
	}

	// Self-lockout guards.
	if username == caller {
		if req.Disabled != nil && *req.Disabled {
			writeJSONStatus(w, http.StatusUnprocessableEntity, errorResponse{Error: "cannot disable your own account"})
			return
		}
		if req.Roles != nil && !hasRole(*req.Roles, auth.RoleOwner) {
			writeJSONStatus(w, http.StatusUnprocessableEntity, errorResponse{Error: "cannot remove your own owner role"})
			return
		}
	}

	rec, err := h.store.Update(r.Context(), tenant, username, users.Patch{
		Password: req.Password,
		Disabled: req.Disabled,
		Roles:    req.Roles,
	})
	if err != nil {
		if errors.Is(err, users.ErrNotFound) {
			writeJSONStatus(w, http.StatusNotFound, errorResponse{Error: "user not found"})
			return
		}
		h.logger.Error("admin: patch user", "tenant", tenant, "username", username, "err", err)
		writeJSONStatus(w, http.StatusInternalServerError, errorResponse{Error: "update failed"})
		return
	}
	h.logger.Info("admin: user updated", "tenant", tenant, "username", username,
		"password_changed", req.Password != nil, "disabled", rec.Disabled, "roles", rec.Roles)
	writeJSONStatus(w, http.StatusOK, rec)
}

func hasRole(roles []string, want string) bool {
	for _, r := range roles {
		if r == want {
			return true
		}
	}
	return false
}
