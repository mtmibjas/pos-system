package sync

import (
	"context"
	"errors"
	"sync"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

// TokenSource mints HS256 JWTs for the sync transport's
// Authorization header and caches them until they near expiry.
//
// Design notes:
//   - HS256 with a shared secret matches the cloud-api's slice 3.5
//     verifier. Per Phase 3 decisions, key rotation / asymmetric algs
//     are deferred.
//   - Tokens are minted lazily (first call to AuthHeader) and reused
//     until they've burned 80% of their TTL. That's the sweet spot
//     between "always fresh" (wasted CPU/log noise) and "expires
//     mid-request" (transient 401 storms).
//   - Safe for concurrent use — HTTPTransport.Send may run from
//     multiple goroutines in future slices.
type TokenSource struct {
	secret  []byte
	tenant  string
	subject string // optional; usually the node id
	issuer  string // optional
	ttl     time.Duration
	clock   func() time.Time

	mu      sync.Mutex
	token   string
	expires time.Time
}

// TokenSourceOpts configures the minter. Subject/Issuer are optional;
// they help debugging on the cloud side but aren't enforced.
type TokenSourceOpts struct {
	Secret  string
	Tenant  string
	Subject string
	Issuer  string
	TTL     time.Duration   // default 15m
	Clock   func() time.Time // default time.Now (injectable for tests)
}

// NewTokenSource validates opts and returns a ready source.
func NewTokenSource(opts TokenSourceOpts) (*TokenSource, error) {
	if opts.Secret == "" {
		return nil, errors.New("sync: token source secret is empty")
	}
	if opts.Tenant == "" {
		return nil, errors.New("sync: token source tenant is empty")
	}
	if opts.TTL <= 0 {
		opts.TTL = 15 * time.Minute
	}
	if opts.Clock == nil {
		opts.Clock = time.Now
	}
	return &TokenSource{
		secret:  []byte(opts.Secret),
		tenant:  opts.Tenant,
		subject: opts.Subject,
		issuer:  opts.Issuer,
		ttl:     opts.TTL,
		clock:   opts.Clock,
	}, nil
}

// AuthHeader returns "Bearer <jwt>". Designed to plug straight into
// HTTPTransport.AuthHeaderFunc.
func (s *TokenSource) AuthHeader(_ context.Context) (string, error) {
	tok, err := s.token72() // mint or reuse
	if err != nil {
		return "", err
	}
	return "Bearer " + tok, nil
}

// refreshThreshold is the fraction of TTL after which we proactively
// re-mint. 0.8 = re-mint once 80% of the token's life has elapsed.
// Hard-coded — exposing it as a knob complicates the API for no
// real-world benefit at this stage.
const refreshThreshold = 0.8

// token72 returns a current token, minting a new one if the cached
// token has either expired or burned past refreshThreshold of its TTL.
// (Name avoids shadowing the field.)
func (s *TokenSource) token72() (string, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	now := s.clock()
	if s.token != "" && now.Before(s.refreshAt()) {
		return s.token, nil
	}

	exp := now.Add(s.ttl)
	claims := jwt.MapClaims{
		"tenant_id": s.tenant,
		"iat":       now.Unix(),
		"exp":       exp.Unix(),
	}
	if s.subject != "" {
		claims["sub"] = s.subject
	}
	if s.issuer != "" {
		claims["iss"] = s.issuer
	}
	signed, err := jwt.NewWithClaims(jwt.SigningMethodHS256, claims).SignedString(s.secret)
	if err != nil {
		return "", err
	}
	s.token = signed
	s.expires = exp
	return signed, nil
}

// refreshAt is the wall-clock instant at which the cached token should
// be re-minted. Equals expires - (1-threshold)*TTL.
func (s *TokenSource) refreshAt() time.Time {
	// (1 - threshold) is the slack window before expiry. e.g. 20% of TTL.
	slack := time.Duration(float64(s.ttl) * (1 - refreshThreshold))
	return s.expires.Add(-slack)
}
