package reservations_test

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"path/filepath"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/require"

	"github.com/mibjas/pos-platform/apps/local-store-server/internal/db"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/inventory"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/reservations"
)

const (
	tStore = "store-R"
	tCount = "counter-R"
)

// rawSpy captures every PublishRaw call so tests can assert on the
// inventory_available_changed wire shape end-to-end.
type rawSpy struct {
	mu     sync.Mutex
	frames []rawFrame
}

type rawFrame struct {
	eventType string
	payload   map[string]any
}

func (s *rawSpy) PublishRaw(eventType string, jsonBytes []byte) {
	var m map[string]any
	_ = json.Unmarshal(jsonBytes, &m)
	s.mu.Lock()
	defer s.mu.Unlock()
	s.frames = append(s.frames, rawFrame{eventType: eventType, payload: m})
}

func (s *rawSpy) snapshot() []rawFrame {
	s.mu.Lock()
	defer s.mu.Unlock()
	out := make([]rawFrame, len(s.frames))
	copy(out, s.frames)
	return out
}

type harness struct {
	db    *sql.DB
	inv   *inventory.Store
	store *reservations.Store
	pub   *rawSpy
	svc   *reservations.Service
	now   time.Time
}

func newHarness(t *testing.T) *harness {
	t.Helper()
	ctx := context.Background()
	path := filepath.Join(t.TempDir(), "resv.db")
	sqlDB, err := db.Open(ctx, db.Config{Path: path})
	require.NoError(t, err)
	t.Cleanup(func() { _ = sqlDB.Close() })
	require.NoError(t, db.RunMigrations(sqlDB))

	inv := inventory.NewStore(sqlDB, nil)
	store := reservations.NewStore(sqlDB)
	pub := &rawSpy{}
	now := time.Unix(1_700_000_000, 0).UTC() // pinned for deterministic expiry math
	svc, err := reservations.NewService(reservations.Config{
		DB:        sqlDB,
		Store:     store,
		Inv:       inv,
		Publisher: pub,
		Now:       func() time.Time { return now },
		TTL:       5 * time.Minute,
	})
	require.NoError(t, err)
	return &harness{db: sqlDB, inv: inv, store: store, pub: pub, svc: svc, now: now}
}

// seedStock receives qty into tStore for sku.
func (h *harness) seedStock(t *testing.T, sku string, qty int64) {
	t.Helper()
	require.NoError(t, h.inv.Append(context.Background(), inventory.Movement{
		MovementID:   uuid.New(),
		SKU:          sku,
		StoreID:      tStore,
		Delta:        qty,
		Reason:       inventory.ReasonReceive,
		RefType:      "receive",
		RefID:        "seed",
		OccurredAt:   h.now,
		Lamport:      0,
		OriginNodeID: "seed",
	}))
}

func TestReserve_HappyPath_DecreasesAvailableAndBroadcasts(t *testing.T) {
	h := newHarness(t)
	h.seedStock(t, "SKU-A", 5)

	resp, err := h.svc.Reserve(context.Background(), reservations.ReserveRequest{
		SKU: "SKU-A", StoreID: tStore, CounterID: tCount, Quantity: 2,
	})
	require.NoError(t, err)
	require.Equal(t, int64(3), resp.Available)
	require.Equal(t, reservations.StatusActive, resp.Reservation.Status)
	require.Equal(t, h.now.Add(5*time.Minute), resp.Reservation.ExpiresAt)

	// Available reflects the hold.
	avail, err := h.inv.Available(context.Background(), tStore, "SKU-A", h.now.UnixNano())
	require.NoError(t, err)
	require.Equal(t, int64(3), avail)

	// Broadcast: one inventory_available_changed frame with the new qty.
	frames := h.pub.snapshot()
	require.Len(t, frames, 1)
	require.Equal(t, "inventory_available_changed", frames[0].eventType)
	require.EqualValues(t, 3, frames[0].payload["available_qty"])
	require.Equal(t, "SKU-A", frames[0].payload["sku"])
	require.Equal(t, tStore, frames[0].payload["store_id"])
}

func TestReserve_InsufficientAvailable_Rejects(t *testing.T) {
	h := newHarness(t)
	h.seedStock(t, "SKU-B", 1)

	// First counter takes the unit.
	_, err := h.svc.Reserve(context.Background(), reservations.ReserveRequest{
		SKU: "SKU-B", StoreID: tStore, CounterID: "c1", Quantity: 1,
	})
	require.NoError(t, err)

	// Second counter tries the same — fails because available = 0.
	_, err = h.svc.Reserve(context.Background(), reservations.ReserveRequest{
		SKU: "SKU-B", StoreID: tStore, CounterID: "c2", Quantity: 1,
	})
	require.Error(t, err)
	var insuff *reservations.ErrInsufficientAvailable
	require.True(t, errors.As(err, &insuff), "expected ErrInsufficientAvailable, got %v", err)
	require.Equal(t, int64(0), insuff.Available)
	require.Equal(t, int64(1), insuff.Requested)
}

func TestRelease_RestoresAvailableAndBroadcasts(t *testing.T) {
	h := newHarness(t)
	h.seedStock(t, "SKU-C", 3)

	resp, err := h.svc.Reserve(context.Background(), reservations.ReserveRequest{
		SKU: "SKU-C", StoreID: tStore, CounterID: tCount, Quantity: 2,
	})
	require.NoError(t, err)
	require.Equal(t, int64(1), resp.Available)

	require.NoError(t, h.svc.Release(context.Background(), resp.Reservation.ID))

	avail, err := h.inv.Available(context.Background(), tStore, "SKU-C", h.now.UnixNano())
	require.NoError(t, err)
	require.Equal(t, int64(3), avail, "Release must restore available qty")

	// Status flipped to released.
	r, err := h.svc.Get(context.Background(), resp.Reservation.ID)
	require.NoError(t, err)
	require.Equal(t, reservations.StatusReleased, r.Status)

	// Two frames: one for Reserve, one for Release.
	frames := h.pub.snapshot()
	require.Len(t, frames, 2)
	require.EqualValues(t, 1, frames[0].payload["available_qty"]) // after reserve
	require.EqualValues(t, 3, frames[1].payload["available_qty"]) // after release
}

func TestRelease_Idempotent_AlreadyReleased_NoError(t *testing.T) {
	h := newHarness(t)
	h.seedStock(t, "SKU-IR", 1)
	resp, err := h.svc.Reserve(context.Background(), reservations.ReserveRequest{
		SKU: "SKU-IR", StoreID: tStore, CounterID: tCount, Quantity: 1,
	})
	require.NoError(t, err)
	require.NoError(t, h.svc.Release(context.Background(), resp.Reservation.ID))
	require.NoError(t, h.svc.Release(context.Background(), resp.Reservation.ID),
		"second Release on already-released row must be a no-op")
}

func TestRelease_UnknownID_ErrNotFound(t *testing.T) {
	h := newHarness(t)
	err := h.svc.Release(context.Background(), uuid.New())
	require.ErrorIs(t, err, reservations.ErrNotFound)
}

func TestReserve_LazilyExpiresOldHoldsBeforeChecking(t *testing.T) {
	// A stale hold from 10 minutes ago should not block a fresh reservation
	// today. Expiry is lazy — it happens at the next Reserve call.
	h := newHarness(t)
	h.seedStock(t, "SKU-D", 1)

	// Reserve at t=0.
	_, err := h.svc.Reserve(context.Background(), reservations.ReserveRequest{
		SKU: "SKU-D", StoreID: tStore, CounterID: "c1", Quantity: 1,
	})
	require.NoError(t, err)

	// Jump forward 10 minutes (past the 5-minute TTL).
	h.now = h.now.Add(10 * time.Minute)
	// Re-seed the now() closure by reconstructing the svc; cleaner than
	// mutating the live one mid-test.
	svc, err := reservations.NewService(reservations.Config{
		DB: h.db, Store: h.store, Inv: h.inv, Publisher: h.pub,
		Now: func() time.Time { return h.now }, TTL: 5 * time.Minute,
	})
	require.NoError(t, err)

	// Second counter reserves — must succeed because the old hold is lazily expired.
	resp, err := svc.Reserve(context.Background(), reservations.ReserveRequest{
		SKU: "SKU-D", StoreID: tStore, CounterID: "c2", Quantity: 1,
	})
	require.NoError(t, err)
	require.Equal(t, int64(0), resp.Available, "new hold consumes the now-freed unit")
}

func TestReserve_RaceForLastUnit_ExactlyOneWins(t *testing.T) {
	h := newHarness(t)
	h.seedStock(t, "SKU-RACE", 1)

	const N = 10
	results := make(chan error, N)
	start := make(chan struct{})
	var wg sync.WaitGroup
	for i := 0; i < N; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			<-start
			_, err := h.svc.Reserve(context.Background(), reservations.ReserveRequest{
				SKU: "SKU-RACE", StoreID: tStore, CounterID: "c" + uuid.NewString()[:4], Quantity: 1,
			})
			results <- err
		}()
	}
	close(start)
	wg.Wait()
	close(results)

	var wins, losses int
	for err := range results {
		switch {
		case err == nil:
			wins++
		case errors.As(err, new(*reservations.ErrInsufficientAvailable)):
			losses++
		default:
			t.Fatalf("unexpected error: %v", err)
		}
	}
	require.Equal(t, 1, wins)
	require.Equal(t, N-1, losses)
}

func TestFinalizeTx_RemovesActiveButDoesNotChangeAvailableUntilSaleCommits(t *testing.T) {
	// FinalizeTx is for sales.Service.Finalize — it transitions the
	// reservation inside the caller's txn. Available drops permanently
	// only after the SALE writes its inventory_adjusted movement, but the
	// reservation itself is no longer "active" so it stops being
	// subtracted from on_hand.
	h := newHarness(t)
	h.seedStock(t, "SKU-F", 5)

	resp, err := h.svc.Reserve(context.Background(), reservations.ReserveRequest{
		SKU: "SKU-F", StoreID: tStore, CounterID: tCount, Quantity: 2,
	})
	require.NoError(t, err)

	// Available with the hold = 3.
	avail, err := h.inv.Available(context.Background(), tStore, "SKU-F", h.now.UnixNano())
	require.NoError(t, err)
	require.Equal(t, int64(3), avail)

	// Finalize in our own tx; commit.
	require.NoError(t, h.svc.Finalize(context.Background(), resp.Reservation.ID))

	// The hold is gone from the active sum, so without an inventory_movement
	// applied yet, Available is back to 5 (on_hand). The sales service is
	// responsible for the inventory_adjusted that follows.
	avail, err = h.inv.Available(context.Background(), tStore, "SKU-F", h.now.UnixNano())
	require.NoError(t, err)
	require.Equal(t, int64(5), avail)

	r, err := h.svc.Get(context.Background(), resp.Reservation.ID)
	require.NoError(t, err)
	require.Equal(t, reservations.StatusFinalized, r.Status)
}
