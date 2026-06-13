package api

import (
	"context"
	"encoding/json"
	"log/slog"
	"net/http"
	"time"

	"github.com/mibjas/pos-platform/apps/cloud-api/internal/auth"
	"github.com/mibjas/pos-platform/apps/cloud-api/internal/users"
)

// Authenticator is what the login handler needs from a user store.
// Both users.Store (YAML, legacy) and users.DBStore (slice 6.1)
// satisfy it.
type Authenticator interface {
	Authenticate(username, password string) (users.User, error)
}

// LoginHandler answers POST /v1/auth/login by looking the username up
// in the user store, comparing the bcrypt hash, and minting an HS256
// JWT with the user's tenant_id + roles. Unauthenticated by design
// (it's the door, not the room).
type LoginHandler struct {
	users  Authenticator
	issuer *auth.Issuer
	logger *slog.Logger

	// TenantGate (optional, slice 6.7) runs after a successful password
	// check. Non-nil error → 403, no token. Wired to
	// tenants.Store.CheckActive so suspended tenants can't log in.
	TenantGate func(ctx context.Context, tenantID string) error
}

// NewLoginHandler wires a LoginHandler. All three deps are required —
// no nil guards because a misconfigured wire-up should fail at boot,
// not in a handler.
func NewLoginHandler(u Authenticator, i *auth.Issuer, logger *slog.Logger) *LoginHandler {
	return &LoginHandler{users: u, issuer: i, logger: logger}
}

type loginRequest struct {
	Username string `json:"username"`
	Password string `json:"password"`
}

type loginResponse struct {
	Token     string    `json:"token"`
	ExpiresAt time.Time `json:"expires_at"`
	TenantID  string    `json:"tenant_id"`
	Roles     []string  `json:"roles"`
}

type errorResponse struct {
	Error string `json:"error"`
}

func (h *LoginHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeJSONStatus(w, http.StatusMethodNotAllowed, errorResponse{Error: "method not allowed"})
		return
	}
	defer r.Body.Close()

	var req loginRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSONStatus(w, http.StatusBadRequest, errorResponse{Error: "malformed request body"})
		return
	}
	if req.Username == "" || req.Password == "" {
		writeJSONStatus(w, http.StatusBadRequest, errorResponse{Error: "username and password are required"})
		return
	}

	u, err := h.users.Authenticate(req.Username, req.Password)
	if err != nil {
		// Log username for ops visibility — but NOT the password and NOT
		// the failure reason (which already collapses unknown-user vs
		// wrong-password in users.Authenticate).
		h.logger.Warn("auth: login failed", "username", req.Username)
		// 401 with a generic message. Same wording for every failure so
		// the client can't enumerate users.
		writeJSONStatus(w, http.StatusUnauthorized, errorResponse{Error: "invalid credentials"})
		return
	}

	if h.TenantGate != nil {
		if err := h.TenantGate(r.Context(), u.TenantID); err != nil {
			// Deliberately specific (unlike the 401s above): the password
			// WAS right, the account's tenant is switched off. Telling the
			// user means one support call instead of three reset attempts.
			h.logger.Warn("auth: login blocked, tenant suspended",
				"username", req.Username, "tenant", u.TenantID)
			writeJSONStatus(w, http.StatusForbidden, errorResponse{Error: "tenant is suspended"})
			return
		}
	}

	token, exp, err := h.issuer.Mint(u.TenantID, u.Username, u.Roles)
	if err != nil {
		// This is a server-side wiring failure (missing tenant, bad
		// signing key), not user error. Log the detail; surface 500.
		h.logger.Error("auth: mint token failed", "username", req.Username, "err", err)
		writeJSONStatus(w, http.StatusInternalServerError, errorResponse{Error: "could not issue token"})
		return
	}

	h.logger.Info("auth: login ok",
		"username", req.Username, "tenant", u.TenantID, "roles", u.Roles, "exp", exp)

	writeJSONStatus(w, http.StatusOK, loginResponse{
		Token:     token,
		ExpiresAt: exp,
		TenantID:  u.TenantID,
		Roles:     u.Roles,
	})
}

// writeJSONStatus is the status-carrying sibling of writeJSON
// (defined in reports.go), kept separate so the existing 200-only
// callers don't need to thread a status int.
func writeJSONStatus(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}
