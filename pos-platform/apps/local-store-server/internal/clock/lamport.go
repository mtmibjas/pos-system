// Package clock provides the monotonic Lamport counter used to stamp every
// operation. The cloud orders operations across stores by Lamport (NOT by
// wall-clock — see docs/sync-rules.md "clock drift").
//
// Persistence: each Next() durably writes the new value to syncstate before
// returning, so a crash never replays an old Lamport. Cost is one SQLite
// upsert per op; with WAL mode that's cheap, and correctness > a few hundred
// extra writes per second.
package clock

import (
	"context"
	"errors"
	"fmt"
	"sync"

	"github.com/mibjas/pos-platform/apps/local-store-server/internal/syncstate"
)

// Lamport is a monotonic uint64 counter persisted via syncstate under
// syncstate.KeyNextLamport. Safe for concurrent use.
type Lamport struct {
	mu    sync.Mutex
	state *syncstate.Store
	next  uint64
}

// New loads the next-to-issue value from syncstate (0 if never written).
// The returned clock's first Next() emits that value, then persists the
// successor.
func New(ctx context.Context, state *syncstate.Store) (*Lamport, error) {
	if state == nil {
		return nil, errors.New("clock: syncstate.Store is required")
	}
	cur, err := state.GetUint64(ctx, syncstate.KeyNextLamport)
	if err != nil {
		if !errors.Is(err, syncstate.ErrNotFound) {
			return nil, fmt.Errorf("clock: load %s: %w", syncstate.KeyNextLamport, err)
		}
		cur = 1 // first-ever value is 1; 0 reads as "unset" in proto3
	}
	if cur == 0 {
		cur = 1
	}
	return &Lamport{state: state, next: cur}, nil
}

// Next returns the next Lamport value and durably persists the successor.
// On persistence failure the counter is rolled back so the same value is
// re-issued on retry — preferable to a forward jump that wastes ids.
func (l *Lamport) Next(ctx context.Context) (uint64, error) {
	l.mu.Lock()
	defer l.mu.Unlock()
	v := l.next
	if err := l.state.SetUint64(ctx, syncstate.KeyNextLamport, v+1); err != nil {
		return 0, fmt.Errorf("clock: persist next lamport: %w", err)
	}
	l.next = v + 1
	return v, nil
}

// Observe bumps the counter so the next issued value is strictly greater
// than `seen`. Used when receiving an operation from another node — the
// local clock must not lag behind any value we've already acknowledged.
func (l *Lamport) Observe(ctx context.Context, seen uint64) error {
	l.mu.Lock()
	defer l.mu.Unlock()
	if seen < l.next {
		return nil
	}
	newNext := seen + 1
	if err := l.state.SetUint64(ctx, syncstate.KeyNextLamport, newNext); err != nil {
		return fmt.Errorf("clock: persist observed lamport: %w", err)
	}
	l.next = newNext
	return nil
}

// Peek returns the value that the next Next() call would issue, without
// advancing the counter. For diagnostics only.
func (l *Lamport) Peek() uint64 {
	l.mu.Lock()
	defer l.mu.Unlock()
	return l.next
}
