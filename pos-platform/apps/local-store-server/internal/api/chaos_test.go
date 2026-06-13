// Phase 4 Slice 4.6: multi-counter chaos tests.
//
// These tests stress the realtime + reservation + finalize surface from
// MULTIPLE concurrent clients to prove the per-SKU lock + per-batch txn
// invariants hold under contention. They sit on top of the same
// newTestServer harness used by api_test.go and realtime_test.go.
//
// Run under `-race` (CI default). Each sub-test uses t.Parallel and is
// sized to complete well under 5s wall-clock so it stays in the normal
// test loop, not behind a `make stress` gate.
//
// Invariants verified:
//
//	#1 NEVER-OVERSELL — concurrent Finalize on a single SKU never drives
//	   stock negative; failures are CodeFailedPrecondition only.
//	#2 RESERVATION CONSISTENCY — mixing Reserve+Finalize with direct
//	   Finalize on one SKU keeps on_hand math closed (sum-of-line-qty
//	   across successful sales == initial - final on_hand).
//	#3 SLOW-CONSUMER ISOLATION — slow WS subscribers get evicted; their
//	   slowness MUST NOT block Finalize's commit path.
//	#4 EVICTION → CATCH-UP — after the server evicts a slow consumer,
//	   reconnecting with since_lamport replays every missed envelope
//	   followed by catchup_complete.
package api_test

import (
	"context"
	"strconv"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"connectrpc.com/connect"
	"github.com/coder/websocket"
	"github.com/google/uuid"
	"github.com/stretchr/testify/require"
	"google.golang.org/protobuf/types/known/timestamppb"

	"github.com/mibjas/pos-platform/apps/local-store-server/internal/hub"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/payments"
	posv1 "github.com/mibjas/pos-platform/packages/sdk-go/gen/pos/v1"
)

// chaosFinalizeOne fires a Finalize for one line of the given SKU at the
// given quantity. Returns the connect error (nil = success). Pure helper
// — every caller passes its own sale/line/payment ids so retries are
// safe.
func chaosFinalizeOne(srv *testServer, sku string, qty int64, reservationIDs ...string) error {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	_, err := srv.saleCli.Finalize(ctx, connect.NewRequest(&posv1.FinalizeRequest{
		SaleId:    uuid.NewString(),
		StoreId:   &posv1.StoreId{Value: testStore},
		CounterId: &posv1.CounterId{Value: "counter-chaos"},
		Lines: []*posv1.FinalizeSaleLine{{
			LineId:    uuid.NewString(),
			Sku:       sku,
			Quantity:  qty,
			UnitPrice: &posv1.Money{CurrencyCode: "USD", Units: 1},
			LineTotal: &posv1.Money{CurrencyCode: "USD", Units: qty},
		}},
		Tenders: []*posv1.FinalizeSaleTender{{
			PaymentId: uuid.NewString(),
			Method:    string(payments.MethodCash),
			Amount:    &posv1.Money{CurrencyCode: "USD", Units: qty},
		}},
		OccurredAt:     timestamppb.New(time.Now().UTC()),
		ReservationIds: reservationIDs,
	}))
	return err
}

// TestChaos_ConcurrentFinalizesNeverOversell fires K concurrent Finalize
// calls against a single SKU seeded with N units. Each call wants
// qty=3, so the upper bound on successes is floor(N/3). Verifies:
//
//   - No success can drive stock below 0 (the inventory lock contract).
//   - Failures carry CodeFailedPrecondition (insufficient stock), never
//     Internal or Unavailable — i.e. the lock didn't break, the API
//     surface returned a clean domain error.
//   - successes × 3 == initial - final on_hand (no leaked or doubled
//     decrements).
func TestChaos_ConcurrentFinalizesNeverOversell(t *testing.T) {
	t.Parallel()

	const (
		initialStock = int64(50)
		actors       = 20
		qtyPerSale   = int64(3)
	)
	srv := newTestServer(t)
	srv.seedStock(t, "SKU-CHAOS-1", initialStock)

	var (
		successes int32
		failures  int32
		wg        sync.WaitGroup
	)
	// Barrier so every goroutine fires roughly simultaneously — bigger
	// contention window, more likely to surface a missing lock.
	start := make(chan struct{})
	for i := 0; i < actors; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			<-start
			err := chaosFinalizeOne(srv, "SKU-CHAOS-1", qtyPerSale)
			if err == nil {
				atomic.AddInt32(&successes, 1)
				return
			}
			// Any non-FailedPrecondition error is a bug — the lock must
			// have produced a clean domain failure, not a 500.
			if code := connect.CodeOf(err); code != connect.CodeFailedPrecondition {
				t.Errorf("unexpected error code %v from Finalize: %v", code, err)
			}
			atomic.AddInt32(&failures, 1)
		}()
	}
	close(start)
	wg.Wait()

	totalSucc := int(atomic.LoadInt32(&successes))
	totalFail := int(atomic.LoadInt32(&failures))
	require.Equal(t, actors, totalSucc+totalFail, "every goroutine reported")

	// Upper bound from initial stock.
	require.LessOrEqual(t, int64(totalSucc)*qtyPerSale, initialStock,
		"successes cannot exceed initial stock budget")

	// Stock math is exact: each success decremented qtyPerSale.
	finalStock, err := srv.inv.StockOnHand(context.Background(), testStore, "SKU-CHAOS-1")
	require.NoError(t, err)
	require.Equal(t, initialStock-int64(totalSucc)*qtyPerSale, finalStock,
		"final stock must match initial minus committed deltas")
	require.GreaterOrEqual(t, finalStock, int64(0), "stock never goes negative")
}

// TestChaos_ConcurrentReserveAndFinalizeNoDoubleSpend mixes two flows on
// one SKU:
//
//   - "reserve-then-finalize" actors: call Reserve(qty=1), then Finalize
//     consuming that reservation_id.
//   - "direct-finalize" actors: call Finalize(qty=1) with no reservation.
//
// The invariant under test: successful Finalize.qty totals match the
// on_hand drop exactly, regardless of whether the units passed through
// a reservation. No double-spend, no inventory leak.
//
// Note: a Reserve can succeed while its paired Finalize fails (e.g.
// direct actors raced ahead and consumed on_hand). The orphan
// reservation lives until TTL — that's expected; the test only asserts
// stock math, not active-reservation count.
func TestChaos_ConcurrentReserveAndFinalizeNoDoubleSpend(t *testing.T) {
	t.Parallel()

	const (
		initialStock     = int64(50)
		reserveActors    = 10
		directActors     = 10
		qtyPerSale       = int64(1)
	)
	srv := newTestServer(t)
	srv.seedStock(t, "SKU-CHAOS-2", initialStock)

	var (
		succ     int32
		wg       sync.WaitGroup
		start    = make(chan struct{})
	)
	tryFinalize := func(reservationIDs ...string) {
		err := chaosFinalizeOne(srv, "SKU-CHAOS-2", qtyPerSale, reservationIDs...)
		if err == nil {
			atomic.AddInt32(&succ, 1)
			return
		}
		if code := connect.CodeOf(err); code != connect.CodeFailedPrecondition {
			t.Errorf("unexpected Finalize error %v: %v", code, err)
		}
	}

	// Reserve-then-finalize actors.
	for i := 0; i < reserveActors; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			<-start
			rctx, rcancel := context.WithTimeout(context.Background(), 5*time.Second)
			defer rcancel()
			resp, err := srv.resvCli.Reserve(rctx, connect.NewRequest(&posv1.ReserveRequest{
				ReservationId: uuid.NewString(),
				Sku:           "SKU-CHAOS-2",
				StoreId:       &posv1.StoreId{Value: testStore},
				CounterId:     &posv1.CounterId{Value: "counter-resv"},
				Quantity:      qtyPerSale,
			}))
			if err != nil {
				// Reserve can legitimately fail with FailedPrecondition once
				// available hits zero. Anything else = bug.
				if code := connect.CodeOf(err); code != connect.CodeFailedPrecondition {
					t.Errorf("unexpected Reserve error %v: %v", code, err)
				}
				return
			}
			tryFinalize(resp.Msg.GetReservation().GetReservationId())
		}()
	}
	// Direct-finalize actors.
	for i := 0; i < directActors; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			<-start
			tryFinalize()
		}()
	}
	close(start)
	wg.Wait()

	totalSucc := int64(atomic.LoadInt32(&succ))
	finalStock, err := srv.inv.StockOnHand(context.Background(), testStore, "SKU-CHAOS-2")
	require.NoError(t, err)
	require.Equal(t, initialStock-totalSucc*qtyPerSale, finalStock,
		"every successful Finalize must decrement on_hand exactly once")
	require.GreaterOrEqual(t, finalStock, int64(0), "stock never goes negative")
}

// TestChaos_FirehoseEvictsSlowConsumersWithoutBlockingFinalize spins up
// 3 fast WS subscribers + 2 deliberately starved direct hub subscribers
// and fires 50 Finalize calls concurrently. The slow path uses
// Hub.Subscribe directly (not WS) because the WS writer goroutine drains
// sub.C into the network buffer faster than we can saturate it — to
// actually trigger the hub's slow-consumer contract we need a sub that
// never reads. Asserts:
//
//   - Every Finalize returns within a bounded window (hub's non-blocking
//     publish contract — slow consumers MUST NOT block commit).
//   - The 2 silent direct subs are evicted; SubscriberCount drops back
//     to `fast` (the 3 WS subs still draining).
//   - Fast WS subscribers receive at least one frame per Finalize
//     (lower bound: ≥50 frames; real count is 3× larger).
func TestChaos_FirehoseEvictsSlowConsumersWithoutBlockingFinalize(t *testing.T) {
	t.Parallel()

	const (
		stockPerSale = int64(1)
		finalizes    = 50
		fast         = 3
		slow         = 2
	)
	srv := newTestServer(t)
	srv.seedStock(t, "SKU-CHAOS-3", int64(finalizes)*stockPerSale)

	// Direct hub subscribers — never read; will hit defaultBufferSize=32
	// after ~11 finalizes (3 envelopes each) and get evicted.
	silentSubs := make([]*hub.Subscription, 0, slow)
	for i := 0; i < slow; i++ {
		silentSubs = append(silentSubs, srv.hub.Subscribe(hub.AllowAll()))
	}
	t.Cleanup(func() {
		for _, s := range silentSubs {
			s.Close()
		}
	})

	// Fast WS subscribers — drain in a goroutine; never starve.
	type wsSub struct {
		conn   *websocket.Conn
		cancel context.CancelFunc
		count  *int64
	}
	wsSubs := make([]wsSub, 0, fast)
	for i := 0; i < fast; i++ {
		c, cancel := dialEventsStream(t, srv.url, "")
		var n int64
		go func() {
			for {
				ctx, c2 := context.WithTimeout(context.Background(), 10*time.Second)
				_, _, err := c.Read(ctx)
				c2()
				if err != nil {
					return
				}
				atomic.AddInt64(&n, 1)
			}
		}()
		wsSubs = append(wsSubs, wsSub{conn: c, cancel: cancel, count: &n})
	}
	t.Cleanup(func() {
		for _, s := range wsSubs {
			s.conn.CloseNow()
			s.cancel()
		}
	})

	require.Eventually(t,
		func() bool { return srv.hub.SubscriberCount() == fast+slow },
		2*time.Second, 5*time.Millisecond,
		"all subscribers should register")

	// Firehose: K concurrent Finalizes. Each call must return promptly;
	// total wall-clock for the batch is bounded so we know no Finalize
	// is stuck behind a slow consumer.
	deadline := time.Now().Add(15 * time.Second)
	var wg sync.WaitGroup
	for i := 0; i < finalizes; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			if err := chaosFinalizeOne(srv, "SKU-CHAOS-3", stockPerSale); err != nil {
				t.Errorf("Finalize unexpectedly failed under firehose: %v", err)
			}
		}()
	}
	wg.Wait()
	require.True(t, time.Now().Before(deadline),
		"firehose Finalizes blew the deadline — slow consumer may be blocking commit")

	// After eviction the subscriber count is exactly `fast` — the slow
	// direct subs were removed by the hub.
	require.Eventually(t,
		func() bool { return srv.hub.SubscriberCount() == fast },
		5*time.Second, 25*time.Millisecond,
		"slow consumers should be evicted")

	// Sanity: confirm at least one silent sub's channel is closed (the
	// hub-side signal of eviction).
	require.Eventually(t, func() bool {
		for _, s := range silentSubs {
			select {
			case _, ok := <-s.C:
				if !ok {
					return true
				}
			default:
			}
		}
		return false
	}, 2*time.Second, 25*time.Millisecond,
		"at least one silent sub's channel must close on eviction")

	// Fast subscribers — each saw at least `finalizes` frames.
	require.Eventually(t, func() bool {
		for _, s := range wsSubs {
			if atomic.LoadInt64(s.count) < int64(finalizes) {
				return false
			}
		}
		return true
	}, 5*time.Second, 25*time.Millisecond,
		"every fast subscriber must observe at least one frame per Finalize")
}

// TestChaos_ReconnectAfterEvictionCatchesUp forces the hub to evict a
// silent direct subscriber, then connects via WS with since_lamport=0
// and verifies the replay path delivers every committed envelope
// followed by catchup_complete. Proves the eviction → reconnect handoff
// is the supported recovery path (slice 4.4 + 4.6).
//
// The eviction-side sub is a direct Hub.Subscribe rather than a WS
// conn because the WS writer goroutine drains sub.C into the network
// faster than we can saturate it from in-process Finalizes; to actually
// hit the hub's slow-consumer contract we need a sub that never reads.
// The WS layer's own close-on-eviction behavior is covered by the
// existing realtime_test.go suite.
func TestChaos_ReconnectAfterEvictionCatchesUp(t *testing.T) {
	t.Parallel()

	// Each Finalize publishes 3 envelopes; defaultBufferSize is 32, so
	// 15 Finalizes (= 45 envelopes) is comfortably past the eviction
	// threshold but small enough that the replay completes in one shot.
	const finalizes = 15
	srv := newTestServer(t)
	srv.seedStock(t, "SKU-CHAOS-4", int64(finalizes))

	// Phase 1: silent direct subscriber — never drains, guaranteed to
	// be evicted once the hub buffer overflows.
	silent := srv.hub.Subscribe(hub.AllowAll())
	defer silent.Close()
	require.Equal(t, 1, srv.hub.SubscriberCount())

	// Phase 2: firehose to fill the buffer and trigger eviction.
	var wg sync.WaitGroup
	for i := 0; i < finalizes; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			if err := chaosFinalizeOne(srv, "SKU-CHAOS-4", 1); err != nil {
				t.Errorf("seed Finalize failed: %v", err)
			}
		}()
	}
	wg.Wait()

	// Eviction: SubscriberCount drops to 0 because the silent sub was
	// the only one registered. Channel close is the hub's signal.
	require.Eventually(t,
		func() bool { return srv.hub.SubscriberCount() == 0 },
		3*time.Second, 25*time.Millisecond,
		"silent subscriber must be evicted")
	require.Eventually(t, func() bool {
		select {
		case _, ok := <-silent.C:
			return !ok
		default:
			return false
		}
	}, 2*time.Second, 10*time.Millisecond,
		"evicted sub's channel must be closed by the hub")

	// Phase 3: reconnect with since_lamport=0 → server replays every
	// envelope from opslog, then sends catchup_complete.
	q := "since_lamport=" + strconv.FormatUint(0, 10)
	reconn, reconnCancel := dialEventsStream(t, srv.url, q)
	defer reconnCancel()
	defer reconn.CloseNow()

	// Drain frames until catchup_complete. Tally typed envelopes; the
	// count must be exactly finalizes × 3 (sale_created, inventory_adjusted,
	// payment_added per sale). Replay is bounded by the server's
	// defaultMaxReplay (1000), well above our 45.
	var replayed int
	deadline := time.Now().Add(5 * time.Second)
	for time.Now().Before(deadline) {
		data, ctrl := readAnyFrame(t, reconn)
		if ctrl != nil {
			require.Equal(t, "catchup_complete", ctrl["type"],
				"expected catchup_complete; got %+v", ctrl)
			if up, ok := ctrl["up_to_lamport"].(float64); ok {
				require.Greater(t, up, float64(0))
			}
			break
		}
		require.NotNil(t, data, "non-control frame must decode")
		replayed++
	}
	require.Equal(t, finalizes*3, replayed,
		"replay must deliver every envelope opslog holds (3 per finalize)")

	// Sanity: subscriber count is 1 (the WS reconnect), no leaked sub.
	require.Equal(t, 1, srv.hub.SubscriberCount(),
		"only the reconnected client should be subscribed")
}
