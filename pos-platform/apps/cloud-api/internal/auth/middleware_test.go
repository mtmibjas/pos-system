package auth_test

import (
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/stretchr/testify/require"

	"github.com/mibjas/pos-platform/apps/cloud-api/internal/auth"
)

func nopLogger() *slog.Logger {
	return slog.New(slog.NewTextHandler(io.Discard, nil))
}

func newAuthedServer(t *testing.T, v *auth.Verifier) *httptest.Server {
	t.Helper()
	mw := auth.RequireJWT(v, nopLogger())
	h := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		c, ok := auth.FromContext(r.Context())
		require.True(t, ok, "Claims must be in context after middleware")
		w.Header().Set("X-Tenant", c.TenantID)
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ok"))
	})
	srv := httptest.NewServer(mw(h))
	t.Cleanup(srv.Close)
	return srv
}

func TestMiddleware_NoToken_Returns401(t *testing.T) {
	v, _ := auth.NewVerifier(testSecret)
	srv := newAuthedServer(t, v)

	resp, err := http.Get(srv.URL)
	require.NoError(t, err)
	defer resp.Body.Close()
	require.Equal(t, http.StatusUnauthorized, resp.StatusCode)
}

func TestMiddleware_ValidToken_PropagatesClaims(t *testing.T) {
	v, _ := auth.NewVerifier(testSecret)
	srv := newAuthedServer(t, v)

	tok := mintHS256(t, testSecret, jwt.MapClaims{
		"tenant_id": "tenant-Z",
		"exp":       time.Now().Add(time.Minute).Unix(),
	})
	req, _ := http.NewRequest(http.MethodGet, srv.URL, nil)
	req.Header.Set("Authorization", "Bearer "+tok)
	resp, err := http.DefaultClient.Do(req)
	require.NoError(t, err)
	defer resp.Body.Close()

	require.Equal(t, http.StatusOK, resp.StatusCode)
	require.Equal(t, "tenant-Z", resp.Header.Get("X-Tenant"))
}

func TestMiddleware_NilVerifier_PassesThroughWithoutClaims(t *testing.T) {
	// nil verifier = test/dev mode — middleware must not block.
	mw := auth.RequireJWT(nil, nopLogger())
	called := false
	h := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		called = true
		_, ok := auth.FromContext(r.Context())
		require.False(t, ok, "no Claims should be attached in no-auth mode")
		w.WriteHeader(http.StatusOK)
	})
	srv := httptest.NewServer(mw(h))
	defer srv.Close()

	resp, err := http.Get(srv.URL)
	require.NoError(t, err)
	defer resp.Body.Close()
	require.Equal(t, http.StatusOK, resp.StatusCode)
	require.True(t, called)
}

func TestMiddleware_ExpiredToken_Returns401(t *testing.T) {
	v, _ := auth.NewVerifier(testSecret)
	srv := newAuthedServer(t, v)

	tok := mintHS256(t, testSecret, jwt.MapClaims{
		"tenant_id": "tenant-A",
		"exp":       time.Now().Add(-time.Minute).Unix(),
	})
	req, _ := http.NewRequest(http.MethodGet, srv.URL, nil)
	req.Header.Set("Authorization", "Bearer "+tok)
	resp, err := http.DefaultClient.Do(req)
	require.NoError(t, err)
	defer resp.Body.Close()
	require.Equal(t, http.StatusUnauthorized, resp.StatusCode)
}
