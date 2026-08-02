package api_test

import (
	"context"
	"testing"
	"time"

	"connectrpc.com/connect"
	"github.com/stretchr/testify/require"

	"github.com/mibjas/pos-platform/apps/local-store-server/internal/api"
	"github.com/mibjas/pos-platform/packages/sdk-go/auth"
	posv1 "github.com/mibjas/pos-platform/packages/sdk-go/gen/pos/v1"
)

// stubNext records whether it ran and what claims (if any) reached it.
func stubNext(ran *bool, gotClaims **auth.Claims) connect.UnaryFunc {
	return func(ctx context.Context, _ connect.AnyRequest) (connect.AnyResponse, error) {
		*ran = true
		if c, ok := auth.ClaimsFromContext(ctx); ok {
			*gotClaims = c
		}
		return connect.NewResponse(&posv1.ListItemsResponse{}), nil
	}
}

func interceptorTestToken(t *testing.T) (string, *auth.Verifier) {
	t.Helper()
	iss, err := auth.NewIssuer(authSecret, time.Hour)
	require.NoError(t, err)
	ver, err := auth.NewVerifier(authSecret)
	require.NoError(t, err)
	tok, _, err := iss.Mint(auth.Claims{TenantID: authTenant, Subject: "cash@a", Roles: []string{"cashier"}})
	require.NoError(t, err)
	return tok, ver
}

func TestInterceptor_Permissive_NoToken_PassesThrough(t *testing.T) {
	_, ver := interceptorTestToken(t)
	var ran bool
	var claims *auth.Claims
	wrapped := api.NewAuthInterceptor(ver, false /*require*/, nil).WrapUnary(stubNext(&ran, &claims))

	_, err := wrapped(context.Background(), connect.NewRequest(&posv1.ListItemsRequest{}))
	require.NoError(t, err)
	require.True(t, ran, "permissive mode must allow a tokenless request")
	require.Nil(t, claims, "no token → no claims attached")
}

func TestInterceptor_ValidToken_AttachesClaims(t *testing.T) {
	tok, ver := interceptorTestToken(t)
	var ran bool
	var claims *auth.Claims
	wrapped := api.NewAuthInterceptor(ver, false, nil).WrapUnary(stubNext(&ran, &claims))

	req := connect.NewRequest(&posv1.ListItemsRequest{})
	req.Header().Set("Authorization", "Bearer "+tok)
	_, err := wrapped(context.Background(), req)
	require.NoError(t, err)
	require.True(t, ran)
	require.NotNil(t, claims)
	require.Equal(t, "cash@a", claims.Subject)
	require.True(t, claims.HasRole("cashier"))
}

func TestInterceptor_PresentInvalidToken_Rejected(t *testing.T) {
	_, ver := interceptorTestToken(t)
	var ran bool
	var claims *auth.Claims
	// Even in permissive mode, a token that IS present but invalid is a hard fail.
	wrapped := api.NewAuthInterceptor(ver, false, nil).WrapUnary(stubNext(&ran, &claims))

	req := connect.NewRequest(&posv1.ListItemsRequest{})
	req.Header().Set("Authorization", "Bearer not-a-real-jwt")
	_, err := wrapped(context.Background(), req)
	require.Equal(t, connect.CodeUnauthenticated, connect.CodeOf(err))
	require.False(t, ran, "an invalid token must not reach the handler")
}

func TestInterceptor_Required_NoToken_Rejected(t *testing.T) {
	_, ver := interceptorTestToken(t)
	var ran bool
	var claims *auth.Claims
	// require=true on a non-exempt procedure (empty procedure here) rejects.
	wrapped := api.NewAuthInterceptor(ver, true, nil).WrapUnary(stubNext(&ran, &claims))

	_, err := wrapped(context.Background(), connect.NewRequest(&posv1.ListItemsRequest{}))
	require.Equal(t, connect.CodeUnauthenticated, connect.CodeOf(err))
	require.False(t, ran)
}
