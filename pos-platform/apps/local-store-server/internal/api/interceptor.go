package api

import (
	"context"
	"errors"
	"log/slog"

	"connectrpc.com/connect"

	"github.com/mibjas/pos-platform/packages/sdk-go/auth"
	"github.com/mibjas/pos-platform/packages/sdk-go/gen/pos/v1/posv1connect"
)

// exemptProcedures never require a session token — they ARE the door
// (AuthService.Login/RegisterDevice carry device + user creds, not a
// session). /healthz and /readyz aren't Connect procedures, so the
// interceptor never sees them.
var exemptProcedures = map[string]bool{
	posv1connect.AuthServiceLoginProcedure:          true,
	posv1connect.AuthServiceRegisterDeviceProcedure: true,
}

// NewAuthInterceptor returns a Connect interceptor that authenticates the
// session token on the Authorization header.
//
// Rollout (docs/store-server-auth-contract.md §6):
//   - require=false (PERMISSIVE, current): a missing token is allowed and
//     the request proceeds with no Claims attached, so the existing desktop
//     keeps working before it learns to log in. A token that IS present is
//     still verified, and a present-but-invalid token is always rejected.
//   - require=true (FLIP, later via POS_REQUIRE_AUTH): a missing token on a
//     non-exempt procedure is rejected; handlers then derive identity from
//     Claims instead of trusting request-body fields.
//
// On success the parsed Claims are stashed in the context
// (auth.ClaimsFromContext). Only the handler side is gated; client-side
// invocations pass through untouched.
func NewAuthInterceptor(ver *auth.Verifier, require bool, logger *slog.Logger) connect.Interceptor {
	if logger == nil {
		logger = slog.Default()
	}
	return connect.UnaryInterceptorFunc(func(next connect.UnaryFunc) connect.UnaryFunc {
		return func(ctx context.Context, req connect.AnyRequest) (connect.AnyResponse, error) {
			if req.Spec().IsClient {
				return next(ctx, req)
			}
			procedure := req.Spec().Procedure
			header := req.Header().Get("Authorization")

			if header == "" {
				if require && !exemptProcedures[procedure] {
					return nil, connect.NewError(connect.CodeUnauthenticated,
						errors.New("authentication required"))
				}
				return next(ctx, req) // permissive / exempt: no claims attached
			}

			claims, err := ver.Verify(header)
			if err != nil {
				// A present-but-invalid token is a hard failure in BOTH modes.
				logger.Warn("auth: token rejected", "procedure", procedure, "err", err)
				return nil, connect.NewError(connect.CodeUnauthenticated, err)
			}
			return next(auth.ContextWithClaims(ctx, claims), req)
		}
	})
}
