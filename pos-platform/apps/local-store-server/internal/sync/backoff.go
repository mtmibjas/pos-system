// Package sync is the cloud sync engine: batcher, transport, retry loop.
// See docs/sync-rules.md for the rules this implements.
package sync

import (
	"math/rand/v2"
	"time"
)

// Backoff yields successive sleep durations for retry attempts. The
// returned duration is "full jitter": rand(0, min(cap, base*2^attempt)).
// Full jitter (vs equal/decorrelated) is the right default because it
// spreads retries widely and avoids retry-storms when many clients
// reconnect to a recovered cloud at once.
//
// Backoff is not safe for concurrent use; each worker owns its own.
type Backoff struct {
	base    time.Duration
	cap     time.Duration
	attempt uint
	rng     *rand.Rand
}

// BackoffOpts configures Backoff. Zero values get sane defaults.
type BackoffOpts struct {
	Base time.Duration // first attempt's ceiling; default 1s
	Cap  time.Duration // max ceiling regardless of attempt; default 60s
	Rng  *rand.Rand    // injected for deterministic tests; default cryptographically-seeded
}

// NewBackoff returns a Backoff with the given options.
func NewBackoff(opts BackoffOpts) *Backoff {
	if opts.Base <= 0 {
		opts.Base = 1 * time.Second
	}
	if opts.Cap <= 0 {
		opts.Cap = 60 * time.Second
	}
	if opts.Rng == nil {
		// math/rand/v2 NewPCG is seeded by the caller; we want non-deterministic
		// by default but reproducible when the caller passes one.
		opts.Rng = rand.New(rand.NewPCG(uint64(time.Now().UnixNano()), 0xa5a5a5a5))
	}
	return &Backoff{base: opts.Base, cap: opts.Cap, rng: opts.Rng}
}

// Next advances the attempt counter and returns the next sleep duration.
// The first call returns rand(0, base); each subsequent call doubles the
// ceiling until cap.
func (b *Backoff) Next() time.Duration {
	ceiling := b.base << b.attempt
	// Overflow / past-cap guard.
	if ceiling <= 0 || ceiling > b.cap {
		ceiling = b.cap
	} else {
		b.attempt++
	}
	// rand.Int64N requires n > 0.
	if ceiling <= 0 {
		return 0
	}
	return time.Duration(b.rng.Int64N(int64(ceiling)))
}

// Reset clears the attempt counter so the next Next() starts from base
// again. Call this after a successful attempt.
func (b *Backoff) Reset() {
	b.attempt = 0
}

// Attempt returns how many attempts have elapsed (i.e. how many times
// Next has incremented). Useful for "give up after N" loops.
func (b *Backoff) Attempt() uint {
	return b.attempt
}
