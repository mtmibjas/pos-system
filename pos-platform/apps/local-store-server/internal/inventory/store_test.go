package inventory_test

import (
	"context"
	"database/sql"
	"errors"
	"path/filepath"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/require"

	"github.com/mibjas/pos-platform/apps/local-store-server/internal/db"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/inventory"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/txn"
)

func newTestStore(t *testing.T, allow inventory.AllowOversell) (*inventory.Store, *sql.DB) {
	t.Helper()
	ctx := context.Background()
	path := filepath.Join(t.TempDir(), "inv.db")
	sqlDB, err := db.Open(ctx, db.Config{Path: path})
	require.NoError(t, err)
	t.Cleanup(func() { _ = sqlDB.Close() })
	require.NoError(t, db.RunMigrations(sqlDB))
	return inventory.NewStore(sqlDB, allow), sqlDB
}

func newMovement(sku, store string, delta int64) inventory.Movement {
	return inventory.Movement{
		MovementID:   uuid.New(),
		SKU:          sku,
		StoreID:      store,
		CounterID:    "counter-1",
		Delta:        delta,
		Reason:       inventory.ReasonReceive,
		RefType:      "receive",
		RefID:        uuid.NewString(),
		OccurredAt:   time.Now().UTC(),
		Lamport:      1,
		OriginNodeID: "node-test",
	}
}

func TestAvailable_SubtractsActiveReservations(t *testing.T) {
	// Slice 4.3: Available = on_hand - SUM(active-not-expired reservations).
	// Verified directly against the inventory_reservations table — we don't
	// import the reservations package here to keep this an inventory-only
	// unit test.
	s, sqlDB := newTestStore(t, nil)
	ctx := context.Background()

	require.NoError(t, s.Append(ctx, newMovement("SKU-AV", "store-A", 10)))

	now := time.Now().UTC()
	insert := func(qty int64, status string, expiresAt time.Time) {
		_, err := sqlDB.Exec(`
			INSERT INTO inventory_reservations
			  (reservation_id, sku, store_id, counter_id, quantity, created_at, expires_at, status)
			VALUES (?, 'SKU-AV', 'store-A', 'counter-1', ?, ?, ?, ?)
		`, uuid.NewString(), qty, now.UnixNano(), expiresAt.UnixNano(), status)
		require.NoError(t, err)
	}
	// 3 active + 2 active = 5 held → available = 10 - 5 = 5.
	insert(3, "active", now.Add(5*time.Minute))
	insert(2, "active", now.Add(5*time.Minute))
	// Terminal rows don't count.
	insert(7, "released", now.Add(5*time.Minute))
	insert(4, "finalized", now.Add(5*time.Minute))
	// Expired-by-time row doesn't count.
	insert(6, "active", now.Add(-time.Minute))

	avail, err := s.Available(ctx, "store-A", "SKU-AV", now.UnixNano())
	require.NoError(t, err)
	require.Equal(t, int64(5), avail)

	// StockOnHand is unchanged — reservations don't touch the ledger sum.
	soh, err := s.StockOnHand(ctx, "store-A", "SKU-AV")
	require.NoError(t, err)
	require.Equal(t, int64(10), soh)
}

func TestAvailable_NoReservations_EqualsStockOnHand(t *testing.T) {
	s, _ := newTestStore(t, nil)
	ctx := context.Background()
	require.NoError(t, s.Append(ctx, newMovement("SKU-NORES", "store-A", 7)))
	got, err := s.Available(ctx, "store-A", "SKU-NORES", time.Now().UnixNano())
	require.NoError(t, err)
	require.Equal(t, int64(7), got)
}

func TestStockOnHand_DerivedFromLedger(t *testing.T) {
	s, _ := newTestStore(t, nil)
	ctx := context.Background()

	// Receive 10, sell 3, sell 2 → 5.
	require.NoError(t, s.Append(ctx, newMovement("SKU1", "store-A", 10)))
	sale1 := newMovement("SKU1", "store-A", -3)
	sale1.Reason = inventory.ReasonSale
	sale1.RefType = "sale"
	require.NoError(t, s.Append(ctx, sale1))

	sale2 := newMovement("SKU1", "store-A", -2)
	sale2.Reason = inventory.ReasonSale
	sale2.RefType = "sale"
	require.NoError(t, s.Append(ctx, sale2))

	got, err := s.StockOnHand(ctx, "store-A", "SKU1")
	require.NoError(t, err)
	require.Equal(t, int64(5), got)
}

func TestOversell_RejectedByDefault(t *testing.T) {
	s, _ := newTestStore(t, nil)
	ctx := context.Background()

	// Receive 2.
	require.NoError(t, s.Append(ctx, newMovement("SKU1", "store-A", 2)))

	// Try to sell 5.
	sale := newMovement("SKU1", "store-A", -5)
	sale.Reason = inventory.ReasonSale
	sale.RefType = "sale"
	err := s.Append(ctx, sale)

	var oerr *inventory.OversellError
	require.ErrorAs(t, err, &oerr)
	require.Equal(t, int64(2), oerr.Have)
	require.Equal(t, int64(5), oerr.Want)

	// Stock unchanged.
	got, _ := s.StockOnHand(ctx, "store-A", "SKU1")
	require.Equal(t, int64(2), got)
}

func TestOversell_AllowedByPolicy(t *testing.T) {
	allow := inventory.AllowOversell(func(storeID string) bool { return storeID == "store-A" })
	s, _ := newTestStore(t, allow)
	ctx := context.Background()

	require.NoError(t, s.Append(ctx, newMovement("SKU1", "store-A", 2)))

	sale := newMovement("SKU1", "store-A", -5)
	sale.Reason = inventory.ReasonSale
	sale.RefType = "sale"
	require.NoError(t, s.Append(ctx, sale))

	got, _ := s.StockOnHand(ctx, "store-A", "SKU1")
	require.Equal(t, int64(-3), got)
}

func TestMultiCounter_LastItemRace(t *testing.T) {
	// Two counters race to sell the last unit. With per-SKU lock + oversell
	// rejection: exactly one succeeds, the other gets OversellError. The
	// final stock is 0, not -1.
	s, _ := newTestStore(t, nil)
	ctx := context.Background()

	require.NoError(t, s.Append(ctx, newMovement("SKU1", "store-A", 1)))

	tryToSell := func() error {
		sale := newMovement("SKU1", "store-A", -1)
		sale.Reason = inventory.ReasonSale
		sale.RefType = "sale"
		// Real callers would hold WithSKULock and an atomic batch; Append
		// already does both for this simple case.
		return s.Append(ctx, sale)
	}

	const N = 10
	var (
		wg      sync.WaitGroup
		errs    = make([]error, N)
		start   = make(chan struct{})
	)
	for i := 0; i < N; i++ {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			<-start
			errs[i] = tryToSell()
		}(i)
	}
	close(start)
	wg.Wait()

	successes := 0
	oversells := 0
	for _, e := range errs {
		switch {
		case e == nil:
			successes++
		case errors.As(e, new(*inventory.OversellError)):
			oversells++
		default:
			t.Fatalf("unexpected error: %v", e)
		}
	}
	require.Equal(t, 1, successes, "exactly one counter wins the last item")
	require.Equal(t, N-1, oversells)

	got, _ := s.StockOnHand(ctx, "store-A", "SKU1")
	require.Equal(t, int64(0), got, "final stock cannot be negative")
}

func TestAppendTx_ComposesWithTxnApply(t *testing.T) {
	// AppendTx works inside a txn.Apply block — demonstrating atomic
	// composition with other writers (the foundation for sale finalization).
	s, sqlDB := newTestStore(t, nil)
	ctx := context.Background()

	require.NoError(t, s.Append(ctx, newMovement("SKU1", "store-A", 5)))

	movID := uuid.New()
	err := s.WithSKULock("store-A", "SKU1", func() error {
		return txn.Apply(ctx, sqlDB, func(tx *sql.Tx) error {
			m := newMovement("SKU1", "store-A", -2)
			m.MovementID = movID
			m.Reason = inventory.ReasonSale
			m.RefType = "sale"
			return s.AppendTx(ctx, tx, m)
		})
	})
	require.NoError(t, err)

	got, _ := s.StockOnHand(ctx, "store-A", "SKU1")
	require.Equal(t, int64(3), got)

	// Now demonstrate atomicity: if any step in the tx fails, the movement is rolled back.
	err = s.WithSKULock("store-A", "SKU1", func() error {
		return txn.Apply(ctx, sqlDB, func(tx *sql.Tx) error {
			m := newMovement("SKU1", "store-A", -1)
			m.Reason = inventory.ReasonSale
			m.RefType = "sale"
			if err := s.AppendTx(ctx, tx, m); err != nil {
				return err
			}
			return errors.New("simulated downstream failure")
		})
	})
	require.Error(t, err)

	// Stock still 3 — the in-tx movement was rolled back.
	got, _ = s.StockOnHand(ctx, "store-A", "SKU1")
	require.Equal(t, int64(3), got)
}

func TestAppend_ValidationErrors(t *testing.T) {
	s, _ := newTestStore(t, nil)
	cases := []struct {
		name string
		mut  func(*inventory.Movement)
	}{
		{"missing MovementID", func(m *inventory.Movement) { m.MovementID = uuid.Nil }},
		{"missing SKU", func(m *inventory.Movement) { m.SKU = "" }},
		{"missing StoreID", func(m *inventory.Movement) { m.StoreID = "" }},
		{"zero Delta", func(m *inventory.Movement) { m.Delta = 0 }},
		{"invalid Reason", func(m *inventory.Movement) { m.Reason = "garbage" }},
		{"missing RefType", func(m *inventory.Movement) { m.RefType = "" }},
		{"missing RefID", func(m *inventory.Movement) { m.RefID = "" }},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			m := newMovement("SKU1", "store-A", 1)
			c.mut(&m)
			require.Error(t, s.Append(context.Background(), m))
		})
	}
}

func TestListMovements_OldestFirst(t *testing.T) {
	s, _ := newTestStore(t, nil)
	ctx := context.Background()
	base := time.Now().UTC()
	for i := 0; i < 3; i++ {
		m := newMovement("SKU1", "store-A", int64(i+1))
		m.OccurredAt = base.Add(time.Duration(i) * time.Second)
		require.NoError(t, s.Append(ctx, m))
	}
	out, err := s.ListMovements(ctx, "store-A", "SKU1")
	require.NoError(t, err)
	require.Len(t, out, 3)
	for i := 1; i < len(out); i++ {
		require.True(t, out[i-1].OccurredAt.UnixNano() <= out[i].OccurredAt.UnixNano())
	}
}
