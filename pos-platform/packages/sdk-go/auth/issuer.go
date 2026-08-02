package auth

import (
	"fmt"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

// Issuer mints HS256 tokens with the shape Verifier accepts. The secret
// MUST match the verifier's; callers source both from one env var so the
// invariant holds by construction.
type Issuer struct {
	secret []byte
	ttl    time.Duration
	now    func() time.Time
}

// NewIssuer returns an Issuer for the shared secret and token TTL. Returns
// ErrEmptySecret on "" (fail-secure, same as NewVerifier). A non-positive
// ttl defaults to 24h.
func NewIssuer(secret string, ttl time.Duration) (*Issuer, error) {
	if secret == "" {
		return nil, ErrEmptySecret
	}
	if ttl <= 0 {
		ttl = 24 * time.Hour
	}
	return &Issuer{secret: []byte(secret), ttl: ttl, now: time.Now}, nil
}

// Mint signs a session token from c. tenant_id is required; sub, iss, roles,
// and the optional store/counter/device claims are included only when set.
// exp is derived from the issuer's TTL (any ExpireAt on c is ignored). The
// resolved expiry is returned so a login handler can echo it without
// re-parsing.
func (i *Issuer) Mint(c Claims) (token string, expiresAt time.Time, err error) {
	if c.TenantID == "" {
		return "", time.Time{}, ErrMissingTenant
	}
	expiresAt = i.now().Add(i.ttl)

	mc := jwt.MapClaims{
		"tenant_id": c.TenantID,
		"exp":       expiresAt.Unix(),
	}
	if c.Subject != "" {
		mc["sub"] = c.Subject
	}
	if c.Issuer != "" {
		mc["iss"] = c.Issuer
	}
	if c.StoreID != "" {
		mc["store_id"] = c.StoreID
	}
	if c.CounterID != "" {
		mc["counter_id"] = c.CounterID
	}
	if c.DeviceID != "" {
		mc["device_id"] = c.DeviceID
	}
	if roles := nonEmpty(c.Roles); len(roles) > 0 {
		rolesAny := make([]any, len(roles))
		for idx, r := range roles {
			rolesAny[idx] = r
		}
		mc["roles"] = rolesAny
	}

	signed, err := jwt.NewWithClaims(jwt.SigningMethodHS256, mc).SignedString(i.secret)
	if err != nil {
		return "", time.Time{}, fmt.Errorf("auth: sign token: %w", err)
	}
	return signed, expiresAt, nil
}

func nonEmpty(roles []string) []string {
	out := make([]string, 0, len(roles))
	for _, r := range roles {
		if r != "" {
			out = append(out, r)
		}
	}
	return out
}
