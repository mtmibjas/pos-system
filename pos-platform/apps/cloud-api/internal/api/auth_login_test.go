package api_test

import (
	"bytes"
	"context"
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"golang.org/x/crypto/bcrypt"

	"github.com/mibjas/pos-platform/apps/cloud-api/internal/api"
	"github.com/mibjas/pos-platform/apps/cloud-api/internal/auth"
	"github.com/mibjas/pos-platform/apps/cloud-api/internal/users"
)

func newLoginHandler(t *testing.T, username, password string) http.Handler {
	t.Helper()
	hash, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.MinCost)
	require.NoError(t, err)
	body := "users:\n" +
		"  - username: " + username + "\n" +
		"    tenant_id: tenant-A\n" +
		"    roles: [owner]\n" +
		"    bcrypt: " + string(hash) + "\n"
	path := filepath.Join(t.TempDir(), "users.yaml")
	require.NoError(t, os.WriteFile(path, []byte(body), 0o600))
	store, err := users.Load(path)
	require.NoError(t, err)
	issuer, err := auth.NewIssuer("test-secret", time.Hour)
	require.NoError(t, err)
	return api.NewLoginHandler(store, issuer, slog.New(slog.NewTextHandler(io.Discard, nil)))
}

func post(t *testing.T, h http.Handler, body string) *httptest.ResponseRecorder {
	t.Helper()
	req := httptest.NewRequest(http.MethodPost, "/v1/auth/login", bytes.NewBufferString(body))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()
	h.ServeHTTP(w, req.WithContext(context.Background()))
	return w
}

func TestLogin_Success(t *testing.T) {
	h := newLoginHandler(t, "alice", "hunter2")
	w := post(t, h, `{"username":"alice","password":"hunter2"}`)
	require.Equal(t, http.StatusOK, w.Code, "body=%s", w.Body.String())

	var resp struct {
		Token     string    `json:"token"`
		ExpiresAt time.Time `json:"expires_at"`
		TenantID  string    `json:"tenant_id"`
		Roles     []string  `json:"roles"`
	}
	require.NoError(t, json.Unmarshal(w.Body.Bytes(), &resp))
	assert.NotEmpty(t, resp.Token)
	assert.Equal(t, "tenant-A", resp.TenantID)
	assert.Equal(t, []string{"owner"}, resp.Roles)
	assert.True(t, resp.ExpiresAt.After(time.Now()))

	// Round-trip the token through the verifier to make sure it's valid
	// against the same secret. Catches off-by-one issuer/verifier wiring.
	ver, err := auth.NewVerifier("test-secret")
	require.NoError(t, err)
	claims, err := ver.Verify(resp.Token)
	require.NoError(t, err)
	assert.Equal(t, "tenant-A", claims.TenantID)
	assert.True(t, claims.HasRole("owner"))
}

func TestLogin_WrongPassword(t *testing.T) {
	h := newLoginHandler(t, "alice", "hunter2")
	w := post(t, h, `{"username":"alice","password":"WRONG"}`)
	assert.Equal(t, http.StatusUnauthorized, w.Code)
	assert.Contains(t, w.Body.String(), "invalid credentials")
}

func TestLogin_UnknownUser(t *testing.T) {
	h := newLoginHandler(t, "alice", "hunter2")
	w := post(t, h, `{"username":"bob","password":"x"}`)
	assert.Equal(t, http.StatusUnauthorized, w.Code)
	// Same wording as wrong-password — no enumeration leak.
	assert.Contains(t, w.Body.String(), "invalid credentials")
}

func TestLogin_MalformedBody(t *testing.T) {
	h := newLoginHandler(t, "alice", "hunter2")
	w := post(t, h, `not json`)
	assert.Equal(t, http.StatusBadRequest, w.Code)
}

func TestLogin_MissingFields(t *testing.T) {
	h := newLoginHandler(t, "alice", "hunter2")
	w := post(t, h, `{"username":"alice"}`)
	assert.Equal(t, http.StatusBadRequest, w.Code)
}

func TestLogin_RejectsGET(t *testing.T) {
	h := newLoginHandler(t, "alice", "hunter2")
	req := httptest.NewRequest(http.MethodGet, "/v1/auth/login", nil)
	w := httptest.NewRecorder()
	h.ServeHTTP(w, req)
	assert.Equal(t, http.StatusMethodNotAllowed, w.Code)
}
