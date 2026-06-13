package auth

import (
	"fmt"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

// Issuer mints HS256 tokens with the same shape Verifier accepts. The
// shared secret here MUST match the verifier's secret; in main.go both
// come from JWT_SECRET so the invariant holds by construction.
type Issuer struct {
	secret []byte
	ttl    time.Duration
}

// NewIssuer returns an Issuer for the given shared secret and default
// token TTL. Returns ErrEmptySecret on "" — same fail-secure behaviour
// as NewVerifier.
func NewIssuer(secret string, ttl time.Duration) (*Issuer, error) {
	if secret == "" {
		return nil, ErrEmptySecret
	}
	if ttl <= 0 {
		ttl = 24 * time.Hour
	}
	return &Issuer{secret: []byte(secret), ttl: ttl}, nil
}

// Mint signs a token with the given claims. expiresAt is returned
// alongside the token string so the caller (typically a login handler)
// can echo it to the client without re-parsing.
func (i *Issuer) Mint(tenantID, subject string, roles []string) (token string, expiresAt time.Time, err error) {
	if tenantID == "" {
		return "", time.Time{}, ErrMissingTenant
	}
	expiresAt = time.Now().Add(i.ttl)
	rolesAny := make([]any, 0, len(roles))
	for _, r := range roles {
		if r != "" {
			rolesAny = append(rolesAny, r)
		}
	}
	tok := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
		"tenant_id": tenantID,
		"sub":       subject,
		"roles":     rolesAny,
		"exp":       expiresAt.Unix(),
	})
	signed, err := tok.SignedString(i.secret)
	if err != nil {
		return "", time.Time{}, fmt.Errorf("auth: sign token: %w", err)
	}
	return signed, expiresAt, nil
}
