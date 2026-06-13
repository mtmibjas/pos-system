package sync_test

import (
	"math/rand/v2"
	"testing"
	"time"

	"github.com/stretchr/testify/require"

	"github.com/mibjas/pos-platform/apps/local-store-server/internal/sync"
)

func TestBackoff_FullJitter_WithinCeiling(t *testing.T) {
	// Inject a deterministic RNG so the test is reproducible.
	rng := rand.New(rand.NewPCG(1, 2))
	b := sync.NewBackoff(sync.BackoffOpts{
		Base: 100 * time.Millisecond,
		Cap:  10 * time.Second,
		Rng:  rng,
	})

	// First attempt: ceiling = base (100ms).
	for i := 0; i < 5; i++ {
		// Re-seed each loop to a fresh Backoff so we sample first-attempt only.
		fresh := sync.NewBackoff(sync.BackoffOpts{
			Base: 100 * time.Millisecond,
			Cap:  10 * time.Second,
			Rng:  rand.New(rand.NewPCG(uint64(i+1), 99)),
		})
		d := fresh.Next()
		require.GreaterOrEqual(t, d, time.Duration(0))
		require.Less(t, d, 100*time.Millisecond,
			"first attempt must be < base (full jitter)")
	}

	// Continuing attempts on the same Backoff double the ceiling until cap.
	prevCeil := 100 * time.Millisecond
	for attempt := 1; attempt < 8; attempt++ {
		d := b.Next()
		require.GreaterOrEqual(t, d, time.Duration(0))
		ceil := time.Duration(int64(prevCeil) * 2)
		if ceil > 10*time.Second {
			ceil = 10 * time.Second
		}
		require.Less(t, d, ceil+time.Nanosecond,
			"attempt %d: %s must be < ceiling %s", attempt, d, ceil)
		prevCeil = ceil
	}
}

func TestBackoff_CappedAtCap(t *testing.T) {
	b := sync.NewBackoff(sync.BackoffOpts{
		Base: 1 * time.Second,
		Cap:  5 * time.Second,
		Rng:  rand.New(rand.NewPCG(42, 42)),
	})
	// Burn through enough attempts that ceiling would massively exceed cap.
	for i := 0; i < 30; i++ {
		d := b.Next()
		require.LessOrEqual(t, d, 5*time.Second,
			"sample %d (%s) exceeded cap", i, d)
	}
}

func TestBackoff_Reset_StartsFromBase(t *testing.T) {
	b := sync.NewBackoff(sync.BackoffOpts{
		Base: 200 * time.Millisecond,
		Cap:  10 * time.Second,
		Rng:  rand.New(rand.NewPCG(7, 7)),
	})
	for i := 0; i < 5; i++ {
		_ = b.Next()
	}
	require.Greater(t, b.Attempt(), uint(0))
	b.Reset()
	require.Equal(t, uint(0), b.Attempt())

	d := b.Next()
	require.Less(t, d, 200*time.Millisecond, "post-reset first sample must be < base")
}

func TestBackoff_Determinism_SameSeedSameSequence(t *testing.T) {
	// Two Backoffs seeded identically must yield the same sequence.
	mkBO := func() *sync.Backoff {
		return sync.NewBackoff(sync.BackoffOpts{
			Base: 100 * time.Millisecond,
			Cap:  5 * time.Second,
			Rng:  rand.New(rand.NewPCG(99, 99)),
		})
	}
	a, b := mkBO(), mkBO()
	for i := 0; i < 20; i++ {
		require.Equal(t, a.Next(), b.Next(), "step %d diverged", i)
	}
}

func TestBackoff_Defaults(t *testing.T) {
	// Defaults are accepted (no panics, durations sane).
	b := sync.NewBackoff(sync.BackoffOpts{})
	for i := 0; i < 5; i++ {
		d := b.Next()
		require.GreaterOrEqual(t, d, time.Duration(0))
		require.LessOrEqual(t, d, 60*time.Second)
	}
}
