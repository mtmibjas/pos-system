package api_test

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"strconv"
	"strings"
	"testing"
	"time"

	"connectrpc.com/connect"
	"github.com/coder/websocket"
	"github.com/google/uuid"
	"github.com/stretchr/testify/require"
	"google.golang.org/protobuf/proto"
	"google.golang.org/protobuf/types/known/timestamppb"

	"github.com/mibjas/pos-platform/apps/local-store-server/internal/api"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/payments"
	posv1 "github.com/mibjas/pos-platform/packages/sdk-go/gen/pos/v1"
)

// rtFrame mirrors the wire JSON the events stream emits (kept local so this
// test doesn't depend on internal types).
type rtFrame struct {
	Lamport     uint64 `json:"lamport"`
	OperationID string `json:"operation_id"`
	EventType   string `json:"event_type"`
	TenantID    string `json:"tenant_id"`
	EnvelopeB64 string `json:"envelope_b64"`
}

func dialEventsStream(t *testing.T, httpURL, query string) (*websocket.Conn, context.CancelFunc) {
	t.Helper()
	wsURL := strings.Replace(httpURL, "http://", "ws://", 1) + api.EventsStreamPath
	if query != "" {
		wsURL += "?" + query
	}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	c, _, err := websocket.Dial(ctx, wsURL, nil)
	require.NoError(t, err)
	return c, cancel
}

func readRTFrame(t *testing.T, c *websocket.Conn) rtFrame {
	t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	_, data, err := c.Read(ctx)
	require.NoError(t, err)
	var f rtFrame
	require.NoError(t, json.Unmarshal(data, &f))
	return f
}

// TestRealtime_FinalizeBroadcastsSaleCreatedInventoryAdjustedAndPaymentAdded
// proves the slice 4.2 end-to-end contract: a sale finalization through the
// Connect-RPC API surface results in three events arriving at a connected
// WebSocket client in the same logical order.
func TestRealtime_FinalizeBroadcastsTrioOverWebSocket(t *testing.T) {
	srv := newTestServer(t)
	srv.seedStock(t, "SKU-A", 5)

	c, cancel := dialEventsStream(t, srv.url, "")
	defer cancel()
	defer c.CloseNow()

	// Wait for the server-side Subscribe to register before triggering the
	// publish so the client doesn't miss the early frames.
	require.Eventually(t, func() bool { return srv.hub.SubscriberCount() == 1 },
		2*time.Second, 5*time.Millisecond, "ws subscriber should register")

	saleID := uuid.New()
	lineID := uuid.New()
	payID := uuid.New()

	_, err := srv.saleCli.Finalize(context.Background(), connect.NewRequest(&posv1.FinalizeRequest{
		SaleId:    saleID.String(),
		StoreId:   &posv1.StoreId{Value: testStore},
		CounterId: &posv1.CounterId{Value: "counter-1"},
		Lines: []*posv1.FinalizeSaleLine{{
			LineId:    lineID.String(),
			Sku:       "SKU-A",
			Quantity:  2,
			UnitPrice: &posv1.Money{CurrencyCode: "USD", Units: 5},
			LineTotal: &posv1.Money{CurrencyCode: "USD", Units: 10},
		}},
		Tenders: []*posv1.FinalizeSaleTender{{
			PaymentId: payID.String(),
			Method:    string(payments.MethodCash),
			Amount:    &posv1.Money{CurrencyCode: "USD", Units: 10},
		}},
		OccurredAt: timestamppb.New(time.Now().UTC()),
	}))
	require.NoError(t, err)

	// Expect exactly three frames in opslog insertion order:
	// 1) sale_created, 2) inventory_adjusted, 3) payment_added.
	f1 := readRTFrame(t, c)
	f2 := readRTFrame(t, c)
	f3 := readRTFrame(t, c)

	require.Equal(t, "sale_created", f1.EventType)
	require.Equal(t, "inventory_adjusted", f2.EventType)
	require.Equal(t, "payment_added", f3.EventType)

	// All three share the same lamport (atomic batch) and tenant id.
	require.Equal(t, f1.Lamport, f2.Lamport)
	require.Equal(t, f2.Lamport, f3.Lamport)
	require.Equal(t, testTenant, f1.TenantID)

	// sale_created's operation_id == SaleID — the producer's idempotency key.
	require.Equal(t, saleID.String(), f1.OperationID)
	// payment_added's operation_id == PaymentID — same idempotency story.
	require.Equal(t, payID.String(), f3.OperationID)

	// The envelope round-trips back to a typed payload.
	raw, err := base64.StdEncoding.DecodeString(f1.EnvelopeB64)
	require.NoError(t, err)
	env := &posv1.EventEnvelope{}
	require.NoError(t, proto.Unmarshal(raw, env))
	sc, ok := env.Payload.(*posv1.EventEnvelope_SaleCreated)
	require.True(t, ok, "first frame's payload should be SaleCreated")
	require.Equal(t, saleID.String(), sc.SaleCreated.SaleId)
	require.Len(t, sc.SaleCreated.Lines, 1)
	require.Equal(t, "SKU-A", sc.SaleCreated.Lines[0].Sku)
}

func TestRealtime_FilterToInventoryAdjustedOnly(t *testing.T) {
	srv := newTestServer(t)
	srv.seedStock(t, "SKU-B", 5)

	// Only listen for inventory_adjusted — the live-tile use case for 4.5.
	c, cancel := dialEventsStream(t, srv.url, "event_type=inventory_adjusted")
	defer cancel()
	defer c.CloseNow()

	require.Eventually(t, func() bool { return srv.hub.SubscriberCount() == 1 },
		2*time.Second, 5*time.Millisecond)

	saleID := uuid.New()
	_, err := srv.saleCli.Finalize(context.Background(), connect.NewRequest(&posv1.FinalizeRequest{
		SaleId:    saleID.String(),
		StoreId:   &posv1.StoreId{Value: testStore},
		CounterId: &posv1.CounterId{Value: "counter-1"},
		Lines: []*posv1.FinalizeSaleLine{{
			LineId:    uuid.NewString(),
			Sku:       "SKU-B",
			Quantity:  3,
			UnitPrice: &posv1.Money{CurrencyCode: "USD", Units: 2},
			LineTotal: &posv1.Money{CurrencyCode: "USD", Units: 6},
		}},
		Tenders: []*posv1.FinalizeSaleTender{{
			PaymentId: uuid.NewString(),
			Method:    string(payments.MethodCash),
			Amount:    &posv1.Money{CurrencyCode: "USD", Units: 6},
		}},
		OccurredAt: timestamppb.New(time.Now().UTC()),
	}))
	require.NoError(t, err)

	// The single matching frame should arrive; sale_created and
	// payment_added must NOT — they'd show up as a second readable frame.
	got := readRTFrame(t, c)
	require.Equal(t, "inventory_adjusted", got.EventType)

	// Decode the payload and confirm the delta is the expected -3 (sale
	// debits stock).
	raw, err := base64.StdEncoding.DecodeString(got.EnvelopeB64)
	require.NoError(t, err)
	env := &posv1.EventEnvelope{}
	require.NoError(t, proto.Unmarshal(raw, env))
	ia, ok := env.Payload.(*posv1.EventEnvelope_InventoryAdjusted)
	require.True(t, ok)
	require.Equal(t, "SKU-B", ia.InventoryAdjusted.Sku)
	require.Equal(t, int64(-3), ia.InventoryAdjusted.Delta)

	// No second frame for the non-matching events.
	ctx, c2 := context.WithTimeout(context.Background(), 150*time.Millisecond)
	defer c2()
	_, _, err = c.Read(ctx)
	require.Error(t, err, "filter should drop sale_created and payment_added")
}

// TestRealtime_ReserveBroadcastsInventoryAvailableChanged proves slice
// 4.3's wire contract: a Reserve through the Connect API surfaces an
// inventory_available_changed JSON frame to every connected WS client
// filtered to that event type. The frame carries {type, store_id, sku,
// available_qty} — the live-tile use case Counter 2 needs.
func TestRealtime_ReserveBroadcastsInventoryAvailableChanged(t *testing.T) {
	srv := newTestServer(t)
	srv.seedStock(t, "SKU-RT", 5)

	// Connect WS first, filtered to the new event type only.
	c, cancel := dialEventsStream(t, srv.url, "event_type=inventory_available_changed")
	defer cancel()
	defer c.CloseNow()

	require.Eventually(t, func() bool { return srv.hub.SubscriberCount() == 1 },
		2*time.Second, 5*time.Millisecond, "ws subscriber should register")

	// Counter 1 reserves 2 units.
	resp, err := srv.resvCli.Reserve(context.Background(), connect.NewRequest(&posv1.ReserveRequest{
		Sku:       "SKU-RT",
		StoreId:   &posv1.StoreId{Value: testStore},
		CounterId: &posv1.CounterId{Value: "counter-1"},
		Quantity:  2,
	}))
	require.NoError(t, err)
	require.Equal(t, int64(3), resp.Msg.GetAvailableQty())

	// WS must receive one matching frame with {sku, available_qty: 3}.
	ctx, c2 := context.WithTimeout(context.Background(), 2*time.Second)
	defer c2()
	_, data, err := c.Read(ctx)
	require.NoError(t, err)

	var payload struct {
		Type      string `json:"type"`
		SKU       string `json:"sku"`
		StoreID   string `json:"store_id"`
		Available int64  `json:"available_qty"`
	}
	require.NoError(t, json.Unmarshal(data, &payload))
	require.Equal(t, "inventory_available_changed", payload.Type)
	require.Equal(t, "SKU-RT", payload.SKU)
	require.Equal(t, testStore, payload.StoreID)
	require.Equal(t, int64(3), payload.Available)
}

// ---- slice 4.4: WS reconnect catch-up ----------------------------------

// readControlOrData reads one WS frame and returns either a data rtFrame
// (event_type set) or a control map (type set). Distinguishes by which
// field is non-empty.
func readAnyFrame(t *testing.T, c *websocket.Conn) (data *rtFrame, control map[string]any) {
	t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	_, raw, err := c.Read(ctx)
	require.NoError(t, err)
	var probe map[string]any
	require.NoError(t, json.Unmarshal(raw, &probe))
	if _, isControl := probe["type"]; isControl {
		return nil, probe
	}
	var f rtFrame
	require.NoError(t, json.Unmarshal(raw, &f))
	return &f, nil
}

// TestReconnect_ReplaysMissedEnvelopes proves the catch-up contract:
// a client that disconnects, misses a finalize, then reconnects with
// its last-seen lamport receives the missed envelopes followed by a
// catchup_complete control frame, then live frames.
func TestReconnect_ReplaysMissedEnvelopes(t *testing.T) {
	srv := newTestServer(t)
	srv.seedStock(t, "SKU-RC", 10)

	// Phase 1: connect, drive one sale, capture its lamport.
	c1, cancel1 := dialEventsStream(t, srv.url, "")
	defer cancel1()
	require.Eventually(t, func() bool { return srv.hub.SubscriberCount() == 1 },
		2*time.Second, 5*time.Millisecond)

	saleID1 := uuid.New()
	_, err := srv.saleCli.Finalize(context.Background(), connect.NewRequest(&posv1.FinalizeRequest{
		SaleId:    saleID1.String(),
		StoreId:   &posv1.StoreId{Value: testStore},
		CounterId: &posv1.CounterId{Value: "counter-1"},
		Lines: []*posv1.FinalizeSaleLine{{
			LineId: uuid.NewString(), Sku: "SKU-RC", Quantity: 1,
			UnitPrice: &posv1.Money{CurrencyCode: "USD", Units: 1},
			LineTotal: &posv1.Money{CurrencyCode: "USD", Units: 1},
		}},
		Tenders: []*posv1.FinalizeSaleTender{{
			PaymentId: uuid.NewString(), Method: string(payments.MethodCash),
			Amount: &posv1.Money{CurrencyCode: "USD", Units: 1},
		}},
		OccurredAt: timestamppb.New(time.Now().UTC()),
	}))
	require.NoError(t, err)

	// Drain the three frames; they share one lamport.
	f1 := readRTFrame(t, c1)
	_ = readRTFrame(t, c1)
	_ = readRTFrame(t, c1)
	lastSeen := f1.Lamport
	require.NotZero(t, lastSeen)

	// Phase 2: disconnect.
	c1.Close(websocket.StatusNormalClosure, "client dropping")
	require.Eventually(t, func() bool { return srv.hub.SubscriberCount() == 0 },
		2*time.Second, 5*time.Millisecond)

	// Phase 3: drive a second sale while the client is offline.
	saleID2 := uuid.New()
	_, err = srv.saleCli.Finalize(context.Background(), connect.NewRequest(&posv1.FinalizeRequest{
		SaleId:    saleID2.String(),
		StoreId:   &posv1.StoreId{Value: testStore},
		CounterId: &posv1.CounterId{Value: "counter-1"},
		Lines: []*posv1.FinalizeSaleLine{{
			LineId: uuid.NewString(), Sku: "SKU-RC", Quantity: 2,
			UnitPrice: &posv1.Money{CurrencyCode: "USD", Units: 1},
			LineTotal: &posv1.Money{CurrencyCode: "USD", Units: 2},
		}},
		Tenders: []*posv1.FinalizeSaleTender{{
			PaymentId: uuid.NewString(), Method: string(payments.MethodCash),
			Amount: &posv1.Money{CurrencyCode: "USD", Units: 2},
		}},
		OccurredAt: timestamppb.New(time.Now().UTC()),
	}))
	require.NoError(t, err)

	// Phase 4: reconnect with since_lamport — must replay the second sale's
	// three frames then deliver catchup_complete with up_to_lamport.
	q := "since_lamport=" + strconv.FormatUint(lastSeen, 10)
	c2, cancel2 := dialEventsStream(t, srv.url, q)
	defer cancel2()
	defer c2.CloseNow()

	// Expect three data frames carrying saleID2's identity, then a control frame.
	d1, ctrl := readAnyFrame(t, c2)
	require.NotNil(t, d1, "first frame after reconnect must be a data frame; got control %v", ctrl)
	require.Equal(t, "sale_created", d1.EventType)
	require.Equal(t, saleID2.String(), d1.OperationID)

	d2, _ := readAnyFrame(t, c2)
	require.NotNil(t, d2)
	require.Equal(t, "inventory_adjusted", d2.EventType)

	d3, _ := readAnyFrame(t, c2)
	require.NotNil(t, d3)
	require.Equal(t, "payment_added", d3.EventType)

	_, ctrl2 := readAnyFrame(t, c2)
	require.NotNil(t, ctrl2, "catchup_complete should follow the replayed frames")
	require.Equal(t, "catchup_complete", ctrl2["type"])
	require.EqualValues(t, d3.Lamport, ctrl2["up_to_lamport"])
}

// TestReconnect_NoReplayWhenSinceLamportAbsent preserves the slice 4.1
// behavior: a connect without since_lamport produces no replay frames
// and no control frames — just live.
func TestReconnect_NoReplayWhenSinceLamportAbsent(t *testing.T) {
	srv := newTestServer(t)
	srv.seedStock(t, "SKU-NRC", 5)

	// Pre-existing sale (will be in opslog but must NOT be replayed).
	_, err := srv.saleCli.Finalize(context.Background(), connect.NewRequest(&posv1.FinalizeRequest{
		SaleId:    uuid.NewString(),
		StoreId:   &posv1.StoreId{Value: testStore},
		CounterId: &posv1.CounterId{Value: "counter-1"},
		Lines: []*posv1.FinalizeSaleLine{{
			LineId: uuid.NewString(), Sku: "SKU-NRC", Quantity: 1,
			UnitPrice: &posv1.Money{CurrencyCode: "USD", Units: 1},
			LineTotal: &posv1.Money{CurrencyCode: "USD", Units: 1},
		}},
		Tenders: []*posv1.FinalizeSaleTender{{
			PaymentId: uuid.NewString(), Method: string(payments.MethodCash),
			Amount: &posv1.Money{CurrencyCode: "USD", Units: 1},
		}},
		OccurredAt: timestamppb.New(time.Now().UTC()),
	}))
	require.NoError(t, err)

	c, cancel := dialEventsStream(t, srv.url, "")
	defer cancel()
	defer c.CloseNow()
	require.Eventually(t, func() bool { return srv.hub.SubscriberCount() == 1 },
		2*time.Second, 5*time.Millisecond)

	// 150ms grace: there must be nothing buffered (no replay, no control).
	ctx, cancelRead := context.WithTimeout(context.Background(), 150*time.Millisecond)
	defer cancelRead()
	_, _, err = c.Read(ctx)
	require.Error(t, err, "absence of since_lamport must NOT trigger replay")
}

// TestReconnect_OverflowEmitsSnapshotFallback verifies the cap: with
// MaxReplay=2 and a backlog of 3 sale events (9 opslog rows), the server
// emits a single catchup_overflow control frame and falls back to live
// streaming — no data frames from replay.
func TestReconnect_OverflowEmitsSnapshotFallback(t *testing.T) {
	srv := newTestServer(t)
	// Override the handler's MaxReplay via reflection-free path: we add a
	// dedicated test hook on the server (see overrideMaxReplay below).
	srv.overrideMaxReplay(2)

	srv.seedStock(t, "SKU-OV", 100)
	for i := 0; i < 3; i++ {
		_, err := srv.saleCli.Finalize(context.Background(), connect.NewRequest(&posv1.FinalizeRequest{
			SaleId:    uuid.NewString(),
			StoreId:   &posv1.StoreId{Value: testStore},
			CounterId: &posv1.CounterId{Value: "counter-1"},
			Lines: []*posv1.FinalizeSaleLine{{
				LineId: uuid.NewString(), Sku: "SKU-OV", Quantity: 1,
				UnitPrice: &posv1.Money{CurrencyCode: "USD", Units: 1},
				LineTotal: &posv1.Money{CurrencyCode: "USD", Units: 1},
			}},
			Tenders: []*posv1.FinalizeSaleTender{{
				PaymentId: uuid.NewString(), Method: string(payments.MethodCash),
				Amount: &posv1.Money{CurrencyCode: "USD", Units: 1},
			}},
			OccurredAt: timestamppb.New(time.Now().UTC()),
		}))
		require.NoError(t, err)
	}

	// Reconnect with since_lamport=0 — request the whole backlog.
	c, cancel := dialEventsStream(t, srv.url, "since_lamport=0")
	defer cancel()
	defer c.CloseNow()

	d, ctrl := readAnyFrame(t, c)
	require.Nil(t, d, "overflow path must NOT emit data frames")
	require.NotNil(t, ctrl)
	require.Equal(t, "catchup_overflow", ctrl["type"])
	require.EqualValues(t, 0, ctrl["since_lamport"])
	require.EqualValues(t, 2, ctrl["max_replay"])

	// No second control frame — the connection stays open and ready for
	// live events. Verify by triggering a fresh sale and reading it.
	_, err := srv.saleCli.Finalize(context.Background(), connect.NewRequest(&posv1.FinalizeRequest{
		SaleId:    uuid.NewString(),
		StoreId:   &posv1.StoreId{Value: testStore},
		CounterId: &posv1.CounterId{Value: "counter-1"},
		Lines: []*posv1.FinalizeSaleLine{{
			LineId: uuid.NewString(), Sku: "SKU-OV", Quantity: 1,
			UnitPrice: &posv1.Money{CurrencyCode: "USD", Units: 1},
			LineTotal: &posv1.Money{CurrencyCode: "USD", Units: 1},
		}},
		Tenders: []*posv1.FinalizeSaleTender{{
			PaymentId: uuid.NewString(), Method: string(payments.MethodCash),
			Amount: &posv1.Money{CurrencyCode: "USD", Units: 1},
		}},
		OccurredAt: timestamppb.New(time.Now().UTC()),
	}))
	require.NoError(t, err)
	d2, _ := readAnyFrame(t, c)
	require.NotNil(t, d2)
	require.Equal(t, "sale_created", d2.EventType)
}

// TestReconnect_FilterAppliesToReplay verifies that ?event_type narrows
// the replay set just like it narrows the live stream.
func TestReconnect_FilterAppliesToReplay(t *testing.T) {
	srv := newTestServer(t)
	srv.seedStock(t, "SKU-RF", 10)

	// Two sales pre-reconnect — each produces sale_created + inventory_adjusted + payment_added.
	for i := 0; i < 2; i++ {
		_, err := srv.saleCli.Finalize(context.Background(), connect.NewRequest(&posv1.FinalizeRequest{
			SaleId:    uuid.NewString(),
			StoreId:   &posv1.StoreId{Value: testStore},
			CounterId: &posv1.CounterId{Value: "counter-1"},
			Lines: []*posv1.FinalizeSaleLine{{
				LineId: uuid.NewString(), Sku: "SKU-RF", Quantity: 1,
				UnitPrice: &posv1.Money{CurrencyCode: "USD", Units: 1},
				LineTotal: &posv1.Money{CurrencyCode: "USD", Units: 1},
			}},
			Tenders: []*posv1.FinalizeSaleTender{{
				PaymentId: uuid.NewString(), Method: string(payments.MethodCash),
				Amount: &posv1.Money{CurrencyCode: "USD", Units: 1},
			}},
			OccurredAt: timestamppb.New(time.Now().UTC()),
		}))
		require.NoError(t, err)
	}

	c, cancel := dialEventsStream(t, srv.url, "event_type=sale_created&since_lamport=0")
	defer cancel()
	defer c.CloseNow()

	// Expect exactly two sale_created data frames, then catchup_complete.
	d1, _ := readAnyFrame(t, c)
	require.NotNil(t, d1)
	require.Equal(t, "sale_created", d1.EventType)

	d2, _ := readAnyFrame(t, c)
	require.NotNil(t, d2)
	require.Equal(t, "sale_created", d2.EventType)

	_, ctrl := readAnyFrame(t, c)
	require.NotNil(t, ctrl)
	require.Equal(t, "catchup_complete", ctrl["type"])
}

// TestRealtime_FinalizeConsumingReservation_BroadcastsAvailableChange
// proves the end-to-end multi-counter flow: Counter 1 reserves, Counter 1
// finalizes the sale supplying ReservationIDs, and Counter 2 sees the
// final available qty land.
func TestRealtime_FinalizeConsumingReservation_BroadcastsAvailableChange(t *testing.T) {
	srv := newTestServer(t)
	srv.seedStock(t, "SKU-CHK", 5)

	// Reserve before the WS connects so we only observe the Finalize-side frame.
	resv, err := srv.resvCli.Reserve(context.Background(), connect.NewRequest(&posv1.ReserveRequest{
		Sku:       "SKU-CHK",
		StoreId:   &posv1.StoreId{Value: testStore},
		CounterId: &posv1.CounterId{Value: "counter-1"},
		Quantity:  2,
	}))
	require.NoError(t, err)

	// Now connect Counter 2's WS, filtered to the live-tile event only.
	c, cancel := dialEventsStream(t, srv.url, "event_type=inventory_available_changed")
	defer cancel()
	defer c.CloseNow()
	require.Eventually(t, func() bool { return srv.hub.SubscriberCount() == 1 },
		2*time.Second, 5*time.Millisecond)

	// Counter 1 finalizes the sale, consuming the reservation.
	saleID := uuid.New()
	_, err = srv.saleCli.Finalize(context.Background(), connect.NewRequest(&posv1.FinalizeRequest{
		SaleId:    saleID.String(),
		StoreId:   &posv1.StoreId{Value: testStore},
		CounterId: &posv1.CounterId{Value: "counter-1"},
		Lines: []*posv1.FinalizeSaleLine{{
			LineId:    uuid.NewString(),
			Sku:       "SKU-CHK",
			Quantity:  2,
			UnitPrice: &posv1.Money{CurrencyCode: "USD", Units: 1},
			LineTotal: &posv1.Money{CurrencyCode: "USD", Units: 2},
		}},
		Tenders: []*posv1.FinalizeSaleTender{{
			PaymentId: uuid.NewString(),
			Method:    "cash",
			Amount:    &posv1.Money{CurrencyCode: "USD", Units: 2},
		}},
		OccurredAt:     timestamppb.New(time.Now().UTC()),
		ReservationIds: []string{resv.Msg.GetReservation().GetReservationId()},
	}))
	require.NoError(t, err)

	// The available_changed frame on the sale path: on_hand dropped 5→3,
	// reservation gone, so available = 3.
	ctx, c2 := context.WithTimeout(context.Background(), 2*time.Second)
	defer c2()
	_, data, err := c.Read(ctx)
	require.NoError(t, err)

	var payload struct {
		Type      string `json:"type"`
		SKU       string `json:"sku"`
		Available int64  `json:"available_qty"`
	}
	require.NoError(t, json.Unmarshal(data, &payload))
	require.Equal(t, "inventory_available_changed", payload.Type)
	require.Equal(t, "SKU-CHK", payload.SKU)
	require.Equal(t, int64(3), payload.Available)
}
