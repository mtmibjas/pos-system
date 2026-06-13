package auth

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
)

// ctxKey is the unexported key for stashing Claims in a request context.
// Handlers read it via FromContext.
type ctxKey struct{}

// FromContext returns the Claims that RequireJWT attached to ctx, or
// (nil, false) if there are none (e.g. middleware not in the chain).
func FromContext(ctx context.Context) (*Claims, bool) {
	c, ok := ctx.Value(ctxKey{}).(*Claims)
	return c, ok
}

// RequireJWT returns middleware that verifies the Authorization header,
// attaches the parsed Claims to the request context, and forwards to
// next. Pass nil verifier to no-op (handy for tests that don't want to
// mint tokens).
//
// Status mapping:
//   - missing/invalid/expired → 401
//   - tenant mismatch is enforced by handlers (after they read the
//     batch), not here — middleware can't know the batch tenant yet.
func RequireJWT(v *Verifier, logger *slog.Logger) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		// no-auth shortcut for tests / dev with --insecure-no-auth.
		if v == nil {
			return next
		}
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			h := r.Header.Get("Authorization")
			claims, err := v.Verify(h)
			if err != nil {
				logger.Warn("auth: reject", "path", r.URL.Path, "err", err)
				http.Error(w, err.Error(), http.StatusUnauthorized)
				return
			}
			ctx := context.WithValue(r.Context(), ctxKey{}, claims)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}

// EnforceTenant is the helper handlers call once they know the
// request's intended tenant (e.g. after decoding a SyncBatch). Returns
// nil on match, ErrTenantMismatch or ErrMissingToken on failure so the
// caller can map to HTTP code (403 / 401).
//
// Returns nil when no Claims are attached AND the supplied verifier is
// nil — this keeps test mode (no auth) working without sprinkling
// conditionals through handlers.
func EnforceTenant(ctx context.Context, requestedTenant string, authRequired bool) error {
	claims, ok := FromContext(ctx)
	if !ok {
		if !authRequired {
			return nil
		}
		return ErrMissingToken
	}
	if claims.TenantID != requestedTenant {
		return ErrTenantMismatch
	}
	return nil
}

// ContextWithClaimsForTest stashes Claims into ctx using the same
// unexported key the middleware uses. Test-only — it lets handler
// tests simulate having passed RequireJWT without minting a real
// token. Never call from production code.
func ContextWithClaimsForTest(ctx context.Context, c *Claims) context.Context {
	return context.WithValue(ctx, ctxKey{}, c)
}

// IsAuthError reports whether err is one of this package's sentinels.
// Used by handlers to choose 401 vs 403.
func IsAuthError(err error) (status int, ok bool) {
	switch {
	case errors.Is(err, ErrTenantMismatch), errors.Is(err, ErrMissingRole):
		return http.StatusForbidden, true
	case errors.Is(err, ErrMissingToken),
		errors.Is(err, ErrInvalidToken),
		errors.Is(err, ErrExpiredToken),
		errors.Is(err, ErrMissingTenant),
		errors.Is(err, ErrUnsupportedAlg):
		return http.StatusUnauthorized, true
	}
	return 0, false
}

// RequireRole returns middleware that 403s requests whose Claims do
// not include role r. Composes after RequireJWT (which attaches the
// Claims to ctx); when verifier is nil at the RequireJWT layer this
// middleware is a no-op so test mode keeps working. authRequired is
// true in production wiring — pass false from tests that intentionally
// skip auth.
func RequireRole(role string, authRequired bool, logger *slog.Logger) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			claims, ok := FromContext(r.Context())
			if !ok {
				if !authRequired {
					next.ServeHTTP(w, r)
					return
				}
				http.Error(w, ErrMissingToken.Error(), http.StatusUnauthorized)
				return
			}
			if !claims.HasRole(role) {
				logger.Warn("auth: role denied", "path", r.URL.Path, "required", role, "have", claims.Roles)
				http.Error(w, ErrMissingRole.Error(), http.StatusForbidden)
				return
			}
			next.ServeHTTP(w, r)
		})
	}
}
