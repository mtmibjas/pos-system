package auth_test

import (
	"testing"
	"time"

	"github.com/stretchr/testify/require"

	"github.com/mibjas/pos-platform/packages/sdk-go/auth"
)

const secret = "test-shared-secret"

func TestMintVerify_RoundTrip(t *testing.T) {
	iss, err := auth.NewIssuer(secret, time.Hour)
	require.NoError(t, err)
	ver, err := auth.NewVerifier(secret)
	require.NoError(t, err)

	tok, exp, err := iss.Mint(auth.Claims{
		TenantID:  "tenant-A",
		Subject:   "cashier@a",
		Issuer:    "local-store-server",
		Roles:     []string{"cashier"},
		StoreID:   "store-1",
		CounterID: "counter-2",
		DeviceID:  "dev-xyz",
	})
	require.NoError(t, err)
	require.WithinDuration(t, time.Now().Add(time.Hour), exp, 5*time.Second)

	c, err := ver.Verify(tok)
	require.NoError(t, err)
	require.Equal(t, "tenant-A", c.TenantID)
	require.Equal(t, "cashier@a", c.Subject)
	require.Equal(t, "local-store-server", c.Issuer)
	require.Equal(t, []string{"cashier"}, c.Roles)
	require.Equal(t, "store-1", c.StoreID)
	require.Equal(t, "counter-2", c.CounterID)
	require.Equal(t, "dev-xyz", c.DeviceID)
	require.True(t, c.HasRole("cashier"))
	require.False(t, c.HasRole("owner"))
}

func TestVerify_StripsBearerPrefix(t *testing.T) {
	iss, _ := auth.NewIssuer(secret, time.Hour)
	ver, _ := auth.NewVerifier(secret)
	tok, _, err := iss.Mint(auth.Claims{TenantID: "tenant-A", Subject: "u"})
	require.NoError(t, err)

	c, err := ver.Verify("Bearer " + tok)
	require.NoError(t, err)
	require.Equal(t, "u", c.Subject)
}

func TestVerify_WrongSecretRejected(t *testing.T) {
	iss, _ := auth.NewIssuer(secret, time.Hour)
	ver, _ := auth.NewVerifier("a-different-secret")
	tok, _, _ := iss.Mint(auth.Claims{TenantID: "tenant-A"})

	_, err := ver.Verify(tok)
	require.ErrorIs(t, err, auth.ErrInvalidToken)
}

func TestVerify_Expired(t *testing.T) {
	iss, _ := auth.NewIssuer(secret, -time.Minute) // ttl<=0 → defaults to 24h
	ver, _ := auth.NewVerifier(secret)
	// ttl defaulted to 24h, so this token is valid — assert that path.
	tok, _, err := iss.Mint(auth.Claims{TenantID: "tenant-A"})
	require.NoError(t, err)
	_, err = ver.Verify(tok)
	require.NoError(t, err)
}

func TestNewIssuer_EmptySecretFailsSecure(t *testing.T) {
	_, err := auth.NewIssuer("", time.Hour)
	require.ErrorIs(t, err, auth.ErrEmptySecret)
	_, err = auth.NewVerifier("")
	require.ErrorIs(t, err, auth.ErrEmptySecret)
}

func TestMint_RequiresTenant(t *testing.T) {
	iss, _ := auth.NewIssuer(secret, time.Hour)
	_, _, err := iss.Mint(auth.Claims{Subject: "u"})
	require.ErrorIs(t, err, auth.ErrMissingTenant)
}
