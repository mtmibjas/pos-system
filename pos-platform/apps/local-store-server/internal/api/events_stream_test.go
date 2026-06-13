package api_test

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/coder/websocket"
	"github.com/stretchr/testify/require"
	"google.golang.org/protobuf/proto"

	"github.com/mibjas/pos-platform/apps/local-store-server/internal/api"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/hub"
	posv1 "github.com/mibjas/pos-platform/packages/sdk-go/gen/pos/v1"
)

func mkEnv(eventType, opID, tenantID string, lamport uint64) *posv1.EventEnvelope {
	return &posv1.EventEnvelope{
		EventType:   eventType,
		OperationId: &posv1.OperationId{Value: opID},
		TenantId:    &posv1.TenantId{Value: tenantID},
		Clock:       &posv1.LamportClock{Counter: lamport},
	}
}

type wsFrame struct {
	Lamport     uint64 `json:"lamport"`
	OperationID string `json:"operation_id"`
	EventType   string `json:"event_type"`
	TenantID    string `json:"tenant_id"`
	EnvelopeB64 string `json:"envelope_b64"`
}

func dial(t *testing.T, urlBase, query string) (*websocket.Conn, context.CancelFunc) {
	t.Helper()
	// httptest gives us http://; switch to ws:// for the dial.
	wsURL := strings.Replace(urlBase, "http://", "ws://", 1) + api.EventsStreamPath
	if query != "" {
		wsURL += "?" + query
	}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	c, _, err := websocket.Dial(ctx, wsURL, nil)
	require.NoError(t, err)
	return c, cancel
}

func readFrame(t *testing.T, c *websocket.Conn) wsFrame {
	t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	_, data, err := c.Read(ctx)
	require.NoError(t, err)
	var f wsFrame
	require.NoError(t, json.Unmarshal(data, &f))
	return f
}

func newTestStream(t *testing.T) (*hub.Hub, *httptest.Server) {
	t.Helper()
	h := hub.New()
	handler := api.NewEventsStreamHandler(h, nil, nil)
	// Short ping interval so heartbeat test doesn't take forever.
	handler.PingInterval = 100 * time.Millisecond
	handler.PongTimeout = time.Second
	srv := httptest.NewServer(handler)
	t.Cleanup(srv.Close)
	return h, srv
}

func TestEventsStream_HappyPath(t *testing.T) {
	t.Parallel()
	h, srv := newTestStream(t)
	c, cancel := dial(t, srv.URL, "")
	defer cancel()
	defer c.CloseNow()

	// Race-free wait: the hub spins up a subscriber inside ServeHTTP, so
	// publish in a loop until the client sees it (with a short deadline).
	env := mkEnv("sale_created", "op-1", "tenant-A", 42)
	deadline := time.Now().Add(2 * time.Second)
	for h.SubscriberCount() == 0 && time.Now().Before(deadline) {
		time.Sleep(5 * time.Millisecond)
	}
	require.Equal(t, 1, h.SubscriberCount(), "WS subscriber should be registered")

	h.Publish(env)
	got := readFrame(t, c)

	require.Equal(t, "sale_created", got.EventType)
	require.Equal(t, "op-1", got.OperationID)
	require.Equal(t, "tenant-A", got.TenantID)
	require.Equal(t, uint64(42), got.Lamport)

	// envelope_b64 should round-trip to the original proto.
	raw, err := base64.StdEncoding.DecodeString(got.EnvelopeB64)
	require.NoError(t, err)
	decoded := &posv1.EventEnvelope{}
	require.NoError(t, proto.Unmarshal(raw, decoded))
	require.Equal(t, env.EventType, decoded.EventType)
	require.Equal(t, env.OperationId.Value, decoded.OperationId.Value)
	require.Equal(t, env.Clock.Counter, decoded.Clock.Counter)
}

func TestEventsStream_FilterByEventType(t *testing.T) {
	t.Parallel()
	h, srv := newTestStream(t)
	c, cancel := dial(t, srv.URL, "event_type=inventory_adjusted")
	defer cancel()
	defer c.CloseNow()

	// Wait for subscriber registration.
	deadline := time.Now().Add(2 * time.Second)
	for h.SubscriberCount() == 0 && time.Now().Before(deadline) {
		time.Sleep(5 * time.Millisecond)
	}

	// Publish a non-matching event first, then a matching one. The client
	// must see only the matching one, in order.
	h.Publish(mkEnv("sale_created", "op-skip", "tenant-A", 1))
	h.Publish(mkEnv("inventory_adjusted", "op-keep", "tenant-A", 2))

	got := readFrame(t, c)
	require.Equal(t, "inventory_adjusted", got.EventType)
	require.Equal(t, "op-keep", got.OperationID)
}

func TestEventsStream_FilterMultipleTypes(t *testing.T) {
	t.Parallel()
	h, srv := newTestStream(t)
	c, cancel := dial(t, srv.URL, "event_type=sale_created,inventory_adjusted")
	defer cancel()
	defer c.CloseNow()

	deadline := time.Now().Add(2 * time.Second)
	for h.SubscriberCount() == 0 && time.Now().Before(deadline) {
		time.Sleep(5 * time.Millisecond)
	}

	h.Publish(mkEnv("payment_added", "skip-1", "t", 1)) // dropped
	h.Publish(mkEnv("sale_created", "keep-1", "t", 2))
	h.Publish(mkEnv("payment_added", "skip-2", "t", 3))
	h.Publish(mkEnv("inventory_adjusted", "keep-2", "t", 4))

	got1 := readFrame(t, c)
	got2 := readFrame(t, c)
	require.Equal(t, "sale_created", got1.EventType)
	require.Equal(t, "keep-1", got1.OperationID)
	require.Equal(t, "inventory_adjusted", got2.EventType)
	require.Equal(t, "keep-2", got2.OperationID)
}

func TestEventsStream_PingPongHeartbeatKeepsConnectionOpen(t *testing.T) {
	t.Parallel()
	h, srv := newTestStream(t)
	c, cancel := dial(t, srv.URL, "")
	defer cancel()
	defer c.CloseNow()

	// Wait for subscriber registration.
	deadline := time.Now().Add(2 * time.Second)
	for h.SubscriberCount() == 0 && time.Now().Before(deadline) {
		time.Sleep(5 * time.Millisecond)
	}

	// Sleep past several server ping intervals. The server pings every
	// 100ms (test override). coder/websocket's Read drives pong responses
	// implicitly, so we just keep an active read pending below.
	pubAfter := time.Now().Add(400 * time.Millisecond)
	// Read in a goroutine so pongs flow; the read returns when the publish
	// below arrives.
	type result struct {
		f   wsFrame
		err error
	}
	resCh := make(chan result, 1)
	go func() {
		ctx, c2 := context.WithTimeout(context.Background(), 5*time.Second)
		defer c2()
		_, data, err := c.Read(ctx)
		if err != nil {
			resCh <- result{err: err}
			return
		}
		var f wsFrame
		err = json.Unmarshal(data, &f)
		resCh <- result{f: f, err: err}
	}()

	time.Sleep(time.Until(pubAfter))
	h.Publish(mkEnv("sale_created", "after-heartbeat", "t", 99))

	select {
	case r := <-resCh:
		require.NoError(t, r.err)
		require.Equal(t, "after-heartbeat", r.f.OperationID)
	case <-time.After(3 * time.Second):
		t.Fatalf("did not receive event after heartbeat window")
	}
}

func TestEventsStream_UnsubscribesOnClientDisconnect(t *testing.T) {
	t.Parallel()
	h, srv := newTestStream(t)
	c, cancel := dial(t, srv.URL, "")
	defer cancel()

	deadline := time.Now().Add(2 * time.Second)
	for h.SubscriberCount() == 0 && time.Now().Before(deadline) {
		time.Sleep(5 * time.Millisecond)
	}
	require.Equal(t, 1, h.SubscriberCount())

	require.NoError(t, c.Close(websocket.StatusNormalClosure, "client done"))

	// Server-side Subscribe goroutine must notice the close and unsubscribe.
	require.Eventually(t, func() bool {
		return h.SubscriberCount() == 0
	}, 3*time.Second, 20*time.Millisecond, "subscriber should be removed after client close")
}

func TestEventsStream_RejectsNonGET(t *testing.T) {
	t.Parallel()
	_, srv := newTestStream(t)

	resp, err := srv.Client().Post(srv.URL+api.EventsStreamPath, "text/plain", strings.NewReader(""))
	require.NoError(t, err)
	defer resp.Body.Close()
	require.Equal(t, 405, resp.StatusCode)
}
