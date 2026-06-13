package auth_test

import (
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/mibjas/pos-platform/apps/cloud-api/internal/auth"
)

func TestIssuer_MintRoundTripsThroughVerifier(t *testing.T) {
	const secret = "shared-secret-for-test"
	iss, err := auth.NewIssuer(secret, time.Hour)
	require.NoError(t, err)
	ver, err := auth.NewVerifier(secret)
	require.NoError(t, err)

	tok, exp, err := iss.Mint("tenant-A", "alice", []string{"owner", "cashier"})
	require.NoError(t, err)
	assert.NotEmpty(t, tok)
	assert.True(t, exp.After(time.Now()), "expires in the future")

	claims, err := ver.Verify(tok)
	require.NoError(t, err)
	assert.Equal(t, "tenant-A", claims.TenantID)
	assert.Equal(t, "alice", claims.Subject)
	assert.True(t, claims.HasRole("owner"))
	assert.True(t, claims.HasRole("cashier"))
	assert.False(t, claims.HasRole("admin"))
}

func TestIssuer_EmptySecretRejected(t *testing.T) {
	_, err := auth.NewIssuer("", time.Hour)
	require.ErrorIs(t, err, auth.ErrEmptySecret)
}

func TestIssuer_EmptyTenantRejected(t *testing.T) {
	iss, err := auth.NewIssuer("s", time.Hour)
	require.NoError(t, err)
	_, _, err = iss.Mint("", "alice", []string{"owner"})
	require.ErrorIs(t, err, auth.ErrMissingTenant)
}

func TestIssuer_DefaultsTTLWhenZero(t *testing.T) {
	iss, err := auth.NewIssuer("s", 0)
	require.NoError(t, err)
	_, exp, err := iss.Mint("tenant-A", "alice", nil)
	require.NoError(t, err)
	// Should land roughly 24h out (the default). Wide tolerance — this
	// guards against accidentally getting a sub-second TTL, not against
	// fine-grained drift.
	assert.True(t, exp.After(time.Now().Add(23*time.Hour)), "TTL too short: %v", exp)
}

func TestIssuer_DropsEmptyRoles(t *testing.T) {
	const secret = "s"
	iss, err := auth.NewIssuer(secret, time.Hour)
	require.NoError(t, err)
	ver, err := auth.NewVerifier(secret)
	require.NoError(t, err)
	tok, _, err := iss.Mint("tenant-A", "alice", []string{"owner", "", "cashier"})
	require.NoError(t, err)
	claims, err := ver.Verify(tok)
	require.NoError(t, err)
	assert.Equal(t, []string{"owner", "cashier"}, claims.Roles)
}
