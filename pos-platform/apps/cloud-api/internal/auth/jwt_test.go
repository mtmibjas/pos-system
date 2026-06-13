package auth_test

import (
	"testing"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/stretchr/testify/require"

	"github.com/mibjas/pos-platform/apps/cloud-api/internal/auth"
)

const testSecret = "test-secret-do-not-use-in-prod"

func mintHS256(t *testing.T, secret string, claims jwt.MapClaims) string {
	t.Helper()
	tok := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	signed, err := tok.SignedString([]byte(secret))
	require.NoError(t, err)
	return signed
}

func TestNewVerifier_EmptySecret(t *testing.T) {
	_, err := auth.NewVerifier("")
	require.ErrorIs(t, err, auth.ErrEmptySecret)
}

func TestVerify_HappyPath(t *testing.T) {
	v, err := auth.NewVerifier(testSecret)
	require.NoError(t, err)

	tok := mintHS256(t, testSecret, jwt.MapClaims{
		"tenant_id": "tenant-A",
		"sub":       "store-1",
		"iss":       "local-store-server",
		"iat":       time.Now().Unix(),
		"exp":       time.Now().Add(15 * time.Minute).Unix(),
	})

	claims, err := v.Verify(tok)
	require.NoError(t, err)
	require.Equal(t, "tenant-A", claims.TenantID)
	require.Equal(t, "store-1", claims.Subject)
	require.Equal(t, "local-store-server", claims.Issuer)
	require.WithinDuration(t, time.Now().Add(15*time.Minute), claims.ExpireAt, 2*time.Second)
}

func TestVerify_BearerPrefixStripped(t *testing.T) {
	v, _ := auth.NewVerifier(testSecret)
	tok := mintHS256(t, testSecret, jwt.MapClaims{
		"tenant_id": "tenant-A",
		"exp":       time.Now().Add(time.Minute).Unix(),
	})
	for _, prefix := range []string{"Bearer ", "bearer ", "BEARER "} {
		_, err := v.Verify(prefix + tok)
		require.NoError(t, err, "prefix %q must be stripped", prefix)
	}
}

func TestVerify_MissingToken(t *testing.T) {
	v, _ := auth.NewVerifier(testSecret)
	_, err := v.Verify("")
	require.ErrorIs(t, err, auth.ErrMissingToken)
}

func TestVerify_WrongSecret(t *testing.T) {
	v, _ := auth.NewVerifier(testSecret)
	tok := mintHS256(t, "different-secret", jwt.MapClaims{
		"tenant_id": "tenant-A",
		"exp":       time.Now().Add(time.Minute).Unix(),
	})
	_, err := v.Verify(tok)
	require.ErrorIs(t, err, auth.ErrInvalidToken)
}

func TestVerify_Expired(t *testing.T) {
	v, _ := auth.NewVerifier(testSecret)
	tok := mintHS256(t, testSecret, jwt.MapClaims{
		"tenant_id": "tenant-A",
		"exp":       time.Now().Add(-time.Minute).Unix(),
	})
	_, err := v.Verify(tok)
	require.ErrorIs(t, err, auth.ErrExpiredToken)
}

func TestVerify_MissingExp(t *testing.T) {
	v, _ := auth.NewVerifier(testSecret)
	// No exp claim — jwt parser with WithExpirationRequired must reject.
	tok := mintHS256(t, testSecret, jwt.MapClaims{"tenant_id": "tenant-A"})
	_, err := v.Verify(tok)
	require.ErrorIs(t, err, auth.ErrInvalidToken)
}

func TestVerify_MissingTenant(t *testing.T) {
	v, _ := auth.NewVerifier(testSecret)
	tok := mintHS256(t, testSecret, jwt.MapClaims{
		"sub": "store-1",
		"exp": time.Now().Add(time.Minute).Unix(),
	})
	_, err := v.Verify(tok)
	require.ErrorIs(t, err, auth.ErrMissingTenant)
}

func TestVerify_NoneAlg_Rejected(t *testing.T) {
	v, _ := auth.NewVerifier(testSecret)
	// Construct an alg=none token by hand — must NOT be accepted.
	// (Defense against the classic "alg confusion" attack on JWT libs.)
	tok := jwt.NewWithClaims(jwt.SigningMethodNone, jwt.MapClaims{
		"tenant_id": "tenant-A",
		"exp":       time.Now().Add(time.Minute).Unix(),
	})
	signed, err := tok.SignedString(jwt.UnsafeAllowNoneSignatureType)
	require.NoError(t, err)
	_, verr := v.Verify(signed)
	require.Error(t, verr, "alg=none must be rejected")
}

func TestVerify_GarbageToken(t *testing.T) {
	v, _ := auth.NewVerifier(testSecret)
	_, err := v.Verify("not-a-jwt-at-all")
	require.ErrorIs(t, err, auth.ErrInvalidToken)
}
