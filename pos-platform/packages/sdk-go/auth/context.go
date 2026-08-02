package auth

import "context"

// ctxKey is the unexported key for stashing Claims in a request context.
type ctxKey struct{}

// ContextWithClaims returns a copy of ctx carrying c. Transports (HTTP
// middleware / Connect interceptors) call this after a successful Verify so
// downstream handlers can read the authenticated identity.
func ContextWithClaims(ctx context.Context, c *Claims) context.Context {
	return context.WithValue(ctx, ctxKey{}, c)
}

// ClaimsFromContext returns the Claims attached by ContextWithClaims, or
// (nil, false) if the request was unauthenticated (e.g. permissive mode
// with no token).
func ClaimsFromContext(ctx context.Context) (*Claims, bool) {
	c, ok := ctx.Value(ctxKey{}).(*Claims)
	return c, ok
}
