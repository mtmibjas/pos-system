package clock_test

import (
	"context"
	"path/filepath"
	"sync"
	"testing"

	"github.com/stretchr/testify/require"

	"github.com/mibjas/pos-platform/apps/local-store-server/internal/clock"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/db"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/syncstate"
)

func newStore(t *testing.T) *syncstate.Store {
	t.Helper()
	ctx := context.Background()
	path := filepath.Join(t.TempDir(), "clock.db")
	sqlDB, err := db.Open(ctx, db.Config{Path: path})
	require.NoError(t, err)
	t.Cleanup(func() { _ = sqlDB.Close() })
	require.NoError(t, db.RunMigrations(sqlDB))
	return syncstate.NewStore(sqlDB)
}

func TestNew_StartsAtOneWhenUnset(t *testing.T) {
	ctx := context.Background()
	l, err := clock.New(ctx, newStore(t))
	require.NoError(t, err)
	v, err := l.Next(ctx)
	require.NoError(t, err)
	require.Equal(t, uint64(1), v)
}

func TestNext_MonotonicAndPersisted(t *testing.T) {
	ctx := context.Background()
	state := newStore(t)
	l, err := clock.New(ctx, state)
	require.NoError(t, err)

	for want := uint64(1); want <= 5; want++ {
		got, err := l.Next(ctx)
		require.NoError(t, err)
		require.Equal(t, want, got)
	}

	// Simulate restart: a fresh clock against the same syncstate must resume.
	l2, err := clock.New(ctx, state)
	require.NoError(t, err)
	v, err := l2.Next(ctx)
	require.NoError(t, err)
	require.Equal(t, uint64(6), v, "next value after restart must be 6, not 1")
}

func TestObserve_BumpsForwardOnly(t *testing.T) {
	ctx := context.Background()
	state := newStore(t)
	l, err := clock.New(ctx, state)
	require.NoError(t, err)

	// Issue 1 and 2 locally.
	_, _ = l.Next(ctx)
	_, _ = l.Next(ctx)
	require.Equal(t, uint64(3), l.Peek())

	// Observing a smaller value is a no-op.
	require.NoError(t, l.Observe(ctx, 1))
	require.Equal(t, uint64(3), l.Peek())

	// Observing a larger value jumps the counter so the next Next() is >seen.
	require.NoError(t, l.Observe(ctx, 100))
	require.Equal(t, uint64(101), l.Peek())

	v, err := l.Next(ctx)
	require.NoError(t, err)
	require.Equal(t, uint64(101), v)
}

func TestNext_ConcurrentNoDuplicatesOrGaps(t *testing.T) {
	ctx := context.Background()
	l, err := clock.New(ctx, newStore(t))
	require.NoError(t, err)

	const N = 200
	var (
		wg   sync.WaitGroup
		mu   sync.Mutex
		seen = make(map[uint64]bool, N)
	)
	for i := 0; i < N; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			v, err := l.Next(ctx)
			require.NoError(t, err)
			mu.Lock()
			require.False(t, seen[v], "value %d issued twice", v)
			seen[v] = true
			mu.Unlock()
		}()
	}
	wg.Wait()

	require.Len(t, seen, N)
	for i := uint64(1); i <= uint64(N); i++ {
		require.True(t, seen[i], "missing value %d (no gaps allowed)", i)
	}
}
