// Package auth verifies inbound JWTs for the cloud-api.
//
// Slice 3.5 ships HS256 with a shared secret read from the JWT_SECRET
// env var (see Phase 3 decisions: RS256 + key rotation deferred). The
// shared secret is the same value the local-store-server signs with —
// in dev a single string passed to both processes, in prod a per-tenant
// secret distributed out of band.
//
// What this package does NOT do:
//   - secret rotation (deferred; would need kid-keyed verifier map)
//   - asymmetric keys (RS256/EdDSA, deferred to a later phase)
//   - revocation lists (tokens are short-lived; revocation = wait)
//   - tenant→secret lookup (Phase 3 is single-tenant secret)
package auth

import (
	"errors"
	"fmt"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

// Sentinel errors. Middleware translates these to HTTP status codes:
// invalid/expired/missing → 401, tenant/role mismatch → 403.
var (
	ErrMissingToken   = errors.New("auth: missing token")
	ErrInvalidToken   = errors.New("auth: invalid token")
	ErrExpiredToken   = errors.New("auth: token expired")
	ErrMissingTenant  = errors.New("auth: token missing tenant_id claim")
	ErrTenantMismatch = errors.New("auth: token tenant_id does not match request")
	ErrMissingRole    = errors.New("auth: token does not carry required role")
	ErrUnsupportedAlg = errors.New("auth: unsupported signing algorithm (HS256 only)")
	ErrEmptySecret    = errors.New("auth: shared secret is empty")
)

// Role names recognised by the cloud-api. Strings are the wire form
// inside JWT `roles` claims. Phase 5 adds "owner" for /v1/reports/*
// (cashiers can transact but not see aggregate totals).
const (
	RoleOwner = "owner"
	// RolePlatformAdmin (slice 6.7) marks SaaS-operator staff. Routes
	// under /v1/platform/* require it and ignore the token's tenant_id
	// — platform admins operate across tenants.
	RolePlatformAdmin = "platform_admin"
)

// Claims is the parsed/validated payload. Only the fields we actually
// gate on are exposed — adding more is a non-event.
type Claims struct {
	TenantID string    // pinned to batch.tenant_id by handlers
	Subject  string    // typically the store/node id; optional
	Issuer   string    // optional, e.g. "local-store-server"
	Roles    []string  // wire claim `roles: ["owner", ...]`. Empty = no roles.
	ExpireAt time.Time // for diagnostics
}

// HasRole reports whether the claims include role r. Linear scan — the
// list is always a handful of entries.
func (c *Claims) HasRole(r string) bool {
	if c == nil {
		return false
	}
	for _, have := range c.Roles {
		if have == r {
			return true
		}
	}
	return false
}

// Verifier holds the HMAC secret. Safe for concurrent use (jwt.Parser
// is stateless).
type Verifier struct {
	secret []byte
}

// NewVerifier returns a Verifier for the given shared secret. Returns
// ErrEmptySecret on "" — fail-secure so a misconfigured cloud-api
// never silently accepts unsigned traffic.
func NewVerifier(secret string) (*Verifier, error) {
	if secret == "" {
		return nil, ErrEmptySecret
	}
	return &Verifier{secret: []byte(secret)}, nil
}

// Verify parses tokenStr, checks the HS256 signature and `exp`, and
// returns the populated Claims. The leading "Bearer " prefix (case
// insensitive) is stripped if present so handlers can pass the raw
// Authorization header in.
func (v *Verifier) Verify(tokenStr string) (*Claims, error) {
	if tokenStr == "" {
		return nil, ErrMissingToken
	}
	tokenStr = stripBearer(tokenStr)

	parser := jwt.NewParser(
		jwt.WithValidMethods([]string{"HS256"}),
		jwt.WithExpirationRequired(),
	)
	tok, err := parser.Parse(tokenStr, func(t *jwt.Token) (any, error) {
		// WithValidMethods already gated, but be explicit: any non-HMAC
		// alg must hard-fail at the keyfunc layer too — defence in depth
		// against future jwt-go API drift.
		if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, ErrUnsupportedAlg
		}
		return v.secret, nil
	})
	if err != nil {
		switch {
		case errors.Is(err, jwt.ErrTokenExpired):
			return nil, ErrExpiredToken
		case errors.Is(err, jwt.ErrSignatureInvalid),
			errors.Is(err, jwt.ErrTokenMalformed),
			errors.Is(err, jwt.ErrTokenSignatureInvalid):
			return nil, ErrInvalidToken
		default:
			return nil, fmt.Errorf("%w: %v", ErrInvalidToken, err)
		}
	}
	if !tok.Valid {
		return nil, ErrInvalidToken
	}

	mc, ok := tok.Claims.(jwt.MapClaims)
	if !ok {
		return nil, ErrInvalidToken
	}

	tenant, _ := mc["tenant_id"].(string)
	if tenant == "" {
		return nil, ErrMissingTenant
	}
	sub, _ := mc["sub"].(string)
	iss, _ := mc["iss"].(string)

	// roles arrives as []any per JSON decoding — coerce to []string,
	// silently dropping non-string entries. Missing claim → empty slice.
	var roles []string
	if raw, ok := mc["roles"].([]any); ok {
		for _, e := range raw {
			if s, ok := e.(string); ok && s != "" {
				roles = append(roles, s)
			}
		}
	}

	exp, _ := mc.GetExpirationTime()
	out := &Claims{TenantID: tenant, Subject: sub, Issuer: iss, Roles: roles}
	if exp != nil {
		out.ExpireAt = exp.Time
	}
	return out, nil
}

// stripBearer removes a case-insensitive "Bearer " prefix if present.
// jwt.Parser does NOT do this for us — it expects the bare token.
func stripBearer(s string) string {
	if len(s) >= 7 && (s[:7] == "Bearer " || s[:7] == "bearer " || s[:7] == "BEARER ") {
		return s[7:]
	}
	return s
}
