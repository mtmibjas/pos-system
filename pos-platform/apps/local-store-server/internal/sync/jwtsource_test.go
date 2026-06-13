package sync_test

import (
	"context"
	"strings"
	"testing"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/stretchr/testify/require"

	syncpkg "github.com/mibjas/pos-platform/apps/local-store-server/internal/sync"
)

func TestTokenSource_RequiresSecretAndTenant(t *testing.T) {
	_, err := syncpkg.NewTokenSource(syncpkg.TokenSourceOpts{Tenant: "t"})
	require.Error(t, err)
	_, err = syncpkg.NewTokenSource(syncpkg.TokenSourceOpts{Secret: "s"})
	require.Error(t, err)
}

func TestTokenSource_AuthHeader_FormatAndClaims(t *testing.T) {
	now := time.Date(2026, 6, 1, 12, 0, 0, 0, time.UTC)
	ts, err := syncpkg.NewTokenSource(syncpkg.TokenSourceOpts{
		Secret:  "shared-secret",
		Tenant:  "tenant-A",
		Subject: "node-1",
		Issuer:  "local-store-server",
		TTL:     10 * time.Minute,
		Clock:   func() time.Time { return now },
	})
	require.NoError(t, err)

	hdr, err := ts.AuthHeader(context.Background())
	require.NoError(t, err)
	require.True(t, strings.HasPrefix(hdr, "Bearer "), "header must use Bearer scheme")

	raw := strings.TrimPrefix(hdr, "Bearer ")
	// Validate expiry against the same fixed clock the token was minted
	// with — real wall-clock here makes the test expire 10 minutes after
	// the hardcoded date.
	tok, err := jwt.Parse(raw, func(_ *jwt.Token) (any, error) {
		return []byte("shared-secret"), nil
	}, jwt.WithTimeFunc(func() time.Time { return now }))
	require.NoError(t, err)
	mc, ok := tok.Claims.(jwt.MapClaims)
	require.True(t, ok)
	require.Equal(t, "tenant-A", mc["tenant_id"])
	require.Equal(t, "node-1", mc["sub"])
	require.Equal(t, "local-store-server", mc["iss"])
	require.EqualValues(t, now.Unix(), mc["iat"])
	require.EqualValues(t, now.Add(10*time.Minute).Unix(), mc["exp"])
}

func TestTokenSource_CachesUntilNearExpiry(t *testing.T) {
	current := time.Date(2026, 6, 1, 12, 0, 0, 0, time.UTC)
	clk := func() time.Time { return current }

	ts, err := syncpkg.NewTokenSource(syncpkg.TokenSourceOpts{
		Secret: "s",
		Tenant: "t",
		TTL:    10 * time.Minute, // refreshAt at +8min (80%)
		Clock:  clk,
	})
	require.NoError(t, err)

	h1, err := ts.AuthHeader(context.Background())
	require.NoError(t, err)

	// 5 minutes later: well within cache window.
	current = current.Add(5 * time.Minute)
	h2, err := ts.AuthHeader(context.Background())
	require.NoError(t, err)
	require.Equal(t, h1, h2, "must reuse cached token before refresh threshold")

	// 9 minutes from t=0 (past 80% threshold) → must re-mint.
	current = current.Add(4 * time.Minute) // total +9m
	h3, err := ts.AuthHeader(context.Background())
	require.NoError(t, err)
	require.NotEqual(t, h1, h3, "must re-mint once past 80%% of TTL")
}

func TestTokenSource_RejectedByWrongSecret(t *testing.T) {
	ts, err := syncpkg.NewTokenSource(syncpkg.TokenSourceOpts{
		Secret: "right-secret",
		Tenant: "t",
		TTL:    time.Minute,
	})
	require.NoError(t, err)

	hdr, err := ts.AuthHeader(context.Background())
	require.NoError(t, err)
	raw := strings.TrimPrefix(hdr, "Bearer ")
	_, err = jwt.Parse(raw, func(_ *jwt.Token) (any, error) {
		return []byte("wrong-secret"), nil
	})
	require.Error(t, err, "parsing with the wrong secret must fail (signature check)")
}
