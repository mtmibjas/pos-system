// Package auth is the shared HS256 session-token machinery used across the
// platform's Go services. It mints and verifies the short-lived session
// JWTs that ride Authorization: Bearer on Connect/HTTP calls.
//
// Origin: lifted from cloud-api's internal/auth (slice 3.5) and generalized
// for reuse by the local-store-server's AuthService
// (docs/store-server-auth-contract.md). The Claims here are a SUPERSET of
// cloud-api's — the extra store_id/counter_id/device_id claims are optional,
// so a cloud-api token that omits them verifies fine.
//
// Deliberately NOT here: HTTP middleware (cloud-api) and Connect
// interceptors (store-server) live with their respective transports; this
// package is just the sign/verify core.
//
// Scope (matches Phase 3 decisions): HS256 + shared secret. No key rotation,
// no asymmetric algs, no revocation lists (tokens are short-lived).
package auth

import (
	"errors"
	"fmt"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

// Sentinel errors. Transports translate these to status codes: invalid/
// expired/missing → Unauthenticated, role mismatch → PermissionDenied.
var (
	ErrMissingToken   = errors.New("auth: missing token")
	ErrInvalidToken   = errors.New("auth: invalid token")
	ErrExpiredToken   = errors.New("auth: token expired")
	ErrMissingTenant  = errors.New("auth: token missing tenant_id claim")
	ErrUnsupportedAlg = errors.New("auth: unsupported signing algorithm (HS256 only)")
	ErrEmptySecret    = errors.New("auth: shared secret is empty")
)

// Role names recognised across the platform. Strings are the wire form
// inside JWT `roles` claims.
const (
	RoleOwner   = "owner"
	RoleCashier = "cashier"
)

// Claims is the parsed/validated session payload. The store/counter/device
// fields are populated by the store-server AuthService and empty on
// cloud-api tokens.
type Claims struct {
	TenantID  string
	Subject   string // sub — the username (cashier identity)
	Issuer    string // iss — e.g. "local-store-server"
	Roles     []string
	StoreID   string // optional (store-server sessions)
	CounterID string // optional (store-server sessions)
	DeviceID  string // optional (store-server sessions)
	ExpireAt  time.Time
}

// HasRole reports whether the claims include role r.
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

// Verifier holds the HMAC secret. Safe for concurrent use.
type Verifier struct {
	secret []byte
}

// NewVerifier returns a Verifier for the shared secret. Returns
// ErrEmptySecret on "" — fail-secure so a misconfigured service never
// silently accepts unsigned traffic.
func NewVerifier(secret string) (*Verifier, error) {
	if secret == "" {
		return nil, ErrEmptySecret
	}
	return &Verifier{secret: []byte(secret)}, nil
}

// Verify parses tokenStr, checks the HS256 signature + exp, and returns the
// populated Claims. A leading "Bearer " (case-insensitive) is stripped.
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
		// WithValidMethods already gated; be explicit as defence in depth.
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
	out := &Claims{
		TenantID:  tenant,
		Subject:   stringClaim(mc, "sub"),
		Issuer:    stringClaim(mc, "iss"),
		StoreID:   stringClaim(mc, "store_id"),
		CounterID: stringClaim(mc, "counter_id"),
		DeviceID:  stringClaim(mc, "device_id"),
		Roles:     stringSliceClaim(mc, "roles"),
	}
	if exp, _ := mc.GetExpirationTime(); exp != nil {
		out.ExpireAt = exp.Time
	}
	return out, nil
}

func stringClaim(mc jwt.MapClaims, key string) string {
	s, _ := mc[key].(string)
	return s
}

// stringSliceClaim coerces a JSON-decoded []any to []string, dropping
// non-string/empty entries. Missing claim → nil.
func stringSliceClaim(mc jwt.MapClaims, key string) []string {
	raw, ok := mc[key].([]any)
	if !ok {
		return nil
	}
	var out []string
	for _, e := range raw {
		if s, ok := e.(string); ok && s != "" {
			out = append(out, s)
		}
	}
	return out
}

// stripBearer removes a case-insensitive "Bearer " prefix if present.
func stripBearer(s string) string {
	if len(s) >= 7 {
		switch s[:7] {
		case "Bearer ", "bearer ", "BEARER ":
			return s[7:]
		}
	}
	return s
}
