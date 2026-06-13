package api

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"errors"
	"log/slog"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/coder/websocket"
	"google.golang.org/protobuf/proto"

	"github.com/mibjas/pos-platform/apps/local-store-server/internal/hub"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/opslog"
	posv1 "github.com/mibjas/pos-platform/packages/sdk-go/gen/pos/v1"
)

// EventsStreamPath is the route the websocket fan-out listens on.
// Exported so clients (Flutter, integration tests) share the constant.
const EventsStreamPath = "/v1/events/stream"

// defaultMaxReplay caps how many EventEnvelope rows a single reconnect can
// replay before the server gives up and tells the client to snapshot.
// 1000 is comfortable headroom for a short outage at LAN-store scale
// without making the catch-up loop too expensive on the SQLite read side.
const defaultMaxReplay = 1000

// EventsStreamHandler upgrades the HTTP request to a websocket, subscribes
// to the hub with an optional event_type filter, and forwards each matching
// envelope as a JSON frame. The handler is intentionally minimal: no auth
// (LAN-trusted), no per-client backpressure (the hub evicts slow consumers).
//
// JSON wire format per data frame:
//
//	{
//	  "lamport":      <uint64>,
//	  "operation_id": "<uuid>",
//	  "event_type":   "<sale_created|inventory_adjusted|…>",
//	  "tenant_id":    "<uuid>",
//	  "envelope_b64": "<base64 of marshaled posv1.EventEnvelope>"
//	}
//
// envelope_b64 lets the client decode the full typed payload using the same
// Dart codegen the cloud sync side already uses; the top-level fields make
// debugging and coarse routing possible without a proto dependency.
//
// Catch-up (slice 4.4): clients may pass ?since_lamport=N to request a
// replay of EventEnvelope rows with lamport > N from operations_log
// before the live stream begins. The replay is bounded by max_replay
// (?max_replay=M, or the server's defaultMaxReplay). After replay (or
// when no replay is requested) the server sends one control frame:
//
//	{"type":"catchup_complete","up_to_lamport":<lamport>}
//
// signalling the live stream has no historical gap before that lamport.
// If the backlog exceeds the cap, the server emits a single
//
//	{"type":"catchup_overflow","since_lamport":N,"max_replay":M}
//
// frame instead — the client should snapshot via RPC, then resume.
// In both cases the live stream continues over the same connection.
// Control frames are distinguishable from data frames by the presence
// of the "type" field (data frames carry "event_type" instead).
//
// Heartbeat: server pings every 30s; if no pong arrives within 60s the
// connection is torn down.
type EventsStreamHandler struct {
	Hub    *hub.Hub
	Logger *slog.Logger

	// Opslog enables the reconnect-with-since_lamport catch-up path.
	// Nil disables replay (the handler still accepts the connection and
	// streams live events) — used by tests that don't care about replay.
	Opslog *opslog.Store

	// MaxReplay caps the number of envelopes replayed per reconnect.
	// Zero falls back to defaultMaxReplay (1000).
	MaxReplay int

	// PingInterval and PongTimeout are overridable for tests. Zero values
	// fall back to the production defaults (30s / 60s).
	PingInterval time.Duration
	PongTimeout  time.Duration
}

// NewEventsStreamHandler wires a handler with production defaults.
// ops is optional — when nil, ?since_lamport is silently ignored.
func NewEventsStreamHandler(h *hub.Hub, ops *opslog.Store, logger *slog.Logger) *EventsStreamHandler {
	if logger == nil {
		logger = slog.Default()
	}
	return &EventsStreamHandler{Hub: h, Opslog: ops, Logger: logger}
}

func (h *EventsStreamHandler) pingInterval() time.Duration {
	if h.PingInterval > 0 {
		return h.PingInterval
	}
	return 30 * time.Second
}

func (h *EventsStreamHandler) pongTimeout() time.Duration {
	if h.PongTimeout > 0 {
		return h.PongTimeout
	}
	return 60 * time.Second
}

func (h *EventsStreamHandler) maxReplay() int {
	if h.MaxReplay > 0 {
		return h.MaxReplay
	}
	return defaultMaxReplay
}

// ServeHTTP implements http.Handler.
func (h *EventsStreamHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	q := r.URL.Query()
	filter := filterFromQuery(q.Get("event_type"))
	// since_lamport semantics:
	//   absent           → no replay; live-only stream (slice 4.1 behavior)
	//   present (incl 0) → replay rows with lamport > value
	// Lamports start at 1, so since_lamport=0 = "fresh client, replay all".
	rawSince, doReplay := q["since_lamport"], false
	var sinceLamport uint64
	if len(rawSince) > 0 {
		doReplay = true
		sinceLamport = parseUint64Query(rawSince[0])
	}
	maxReplay := parseIntQuery(q.Get("max_replay"))
	if maxReplay <= 0 {
		maxReplay = h.maxReplay()
	}

	c, err := websocket.Accept(w, r, &websocket.AcceptOptions{
		// Loopback / LAN-trusted; the client is the same operator's POS
		// app, not a third-party page, so we don't enforce Origin.
		InsecureSkipVerify: true,
	})
	if err != nil {
		h.Logger.Warn("ws accept", "err", err)
		return
	}
	defer c.CloseNow()

	// We don't expect any client→server messages on this endpoint, but
	// coder/websocket needs an active reader for pongs (and the protocol
	// close frame) to be processed. CloseRead spins a goroutine that
	// handles control frames and discards data frames, and cancels the
	// returned context when the peer closes. That cancellation drives
	// our select below so we tear down promptly on client disconnect.
	ctx := c.CloseRead(r.Context())

	// Subscribe BEFORE replay. Anything published while we replay queues
	// into the sub buffers; we then de-dup the boundary using
	// dedupBelowOrEqual so the client sees each envelope exactly once.
	sub := h.Hub.Subscribe(filter)
	defer sub.Close()

	// Replay path: only if caller asked for it and we have an opslog
	// store wired in.
	var dedupBelowOrEqual uint64
	if h.Opslog != nil && doReplay {
		upTo, overflow, err := h.replay(ctx, c, filter, sinceLamport, maxReplay)
		if err != nil {
			// Logged inside replay; tear down — the client will reconnect.
			return
		}
		if overflow {
			// Backlog too large: client must snapshot. Don't de-dup the
			// live channel — the snapshot will reconcile.
			if err := h.writeControlFrame(ctx, c, map[string]any{
				"type":          "catchup_overflow",
				"since_lamport": sinceLamport,
				"max_replay":    maxReplay,
			}); err != nil {
				return
			}
		} else {
			// Bounded replay finished cleanly. Tell the client where the
			// live stream picks up, and de-dup live envelopes that were
			// already replayed.
			dedupBelowOrEqual = upTo
			if err := h.writeControlFrame(ctx, c, map[string]any{
				"type":           "catchup_complete",
				"up_to_lamport":  upTo,
			}); err != nil {
				return
			}
		}
	}

	pingC := time.NewTicker(h.pingInterval())
	defer pingC.Stop()

	for {
		select {
		case <-ctx.Done():
			_ = c.Close(websocket.StatusNormalClosure, "server context done")
			return

		case env, ok := <-sub.C:
			if !ok {
				// Hub evicted us (slow consumer). Tell the client so it
				// reconnects with its last-seen lamport.
				_ = c.Close(websocket.StatusInternalError, "slow consumer")
				return
			}
			// De-dup boundary with the replay: anything at-or-below the
			// replayed high-water mark was already delivered above.
			if dedupBelowOrEqual > 0 && env.GetClock().GetCounter() <= dedupBelowOrEqual {
				continue
			}
			frame, err := encodeFrame(env)
			if err != nil {
				h.Logger.Warn("encode frame", "err", err)
				continue
			}
			writeCtx, cancel := context.WithTimeout(ctx, 10*time.Second)
			err = c.Write(writeCtx, websocket.MessageText, frame)
			cancel()
			if err != nil {
				if !errors.Is(err, context.Canceled) {
					h.Logger.Debug("ws write", "err", err)
				}
				return
			}

		case raw, ok := <-sub.RawC:
			if !ok {
				_ = c.Close(websocket.StatusInternalError, "slow consumer")
				return
			}
			writeCtx, cancel := context.WithTimeout(ctx, 10*time.Second)
			err := c.Write(writeCtx, websocket.MessageText, raw.JSON)
			cancel()
			if err != nil {
				if !errors.Is(err, context.Canceled) {
					h.Logger.Debug("ws write raw", "err", err)
				}
				return
			}

		case <-pingC.C:
			pingCtx, cancel := context.WithTimeout(ctx, h.pongTimeout())
			err := c.Ping(pingCtx)
			cancel()
			if err != nil {
				h.Logger.Debug("ws ping failed; closing", "err", err)
				return
			}
		}
	}
}

// frame is the wire-level JSON envelope sent to clients.
type frame struct {
	Lamport     uint64 `json:"lamport"`
	OperationID string `json:"operation_id"`
	EventType   string `json:"event_type"`
	TenantID    string `json:"tenant_id"`
	EnvelopeB64 string `json:"envelope_b64"`
}

func encodeFrame(env *posv1.EventEnvelope) ([]byte, error) {
	wire, err := proto.Marshal(env)
	if err != nil {
		return nil, err
	}
	var (
		opID   string
		tenant string
		lamp   uint64
	)
	if env.OperationId != nil {
		opID = env.OperationId.Value
	}
	if env.TenantId != nil {
		tenant = env.TenantId.Value
	}
	if env.Clock != nil {
		lamp = env.Clock.Counter
	}
	return json.Marshal(frame{
		Lamport:     lamp,
		OperationID: opID,
		EventType:   env.EventType,
		TenantID:    tenant,
		EnvelopeB64: base64.StdEncoding.EncodeToString(wire),
	})
}

// replay reads opslog rows with lamport > sinceLamport, applies the filter,
// and writes one data frame per matching row over c. It returns:
//
//   - upTo:     the highest lamport actually written (0 if none matched)
//   - overflow: true when the backlog exceeded maxReplay (no frames are
//     written in this case; caller emits catchup_overflow)
//   - err:      a non-nil error means the connection is unrecoverable
//     (write error, context done); the caller must tear down.
//
// We over-fetch by one row to detect overflow in a single query — cleaner
// than COUNT(*) + LIMIT and gives us the same answer.
func (h *EventsStreamHandler) replay(
	ctx context.Context,
	c *websocket.Conn,
	filter hub.Filter,
	sinceLamport uint64,
	maxReplay int,
) (upTo uint64, overflow bool, err error) {
	rows, err := h.Opslog.ListSince(ctx, sinceLamport, maxReplay+1)
	if err != nil {
		h.Logger.Warn("replay list-since failed", "err", err)
		return 0, false, err
	}
	if len(rows) > maxReplay {
		// Overflow: caller decides what to send (catchup_overflow).
		return 0, true, nil
	}
	for _, op := range rows {
		env := &posv1.EventEnvelope{}
		if err := proto.Unmarshal(op.Payload, env); err != nil {
			// One bad row shouldn't kill the whole catch-up. Log and skip
			// — the client will still get the rest of the replay and the
			// catchup_complete frame.
			h.Logger.Warn("replay unmarshal", "op_id", op.OperationID, "err", err)
			continue
		}
		if !filter.Matches(env.EventType) {
			// Filter narrows replay too — saves bytes when a tile only
			// cares about one event type.
			continue
		}
		frame, encErr := encodeFrame(env)
		if encErr != nil {
			h.Logger.Warn("replay encode", "err", encErr)
			continue
		}
		writeCtx, cancel := context.WithTimeout(ctx, 10*time.Second)
		werr := c.Write(writeCtx, websocket.MessageText, frame)
		cancel()
		if werr != nil {
			if !errors.Is(werr, context.Canceled) {
				h.Logger.Debug("replay ws write", "err", werr)
			}
			return 0, false, werr
		}
		if env.GetClock().GetCounter() > upTo {
			upTo = env.GetClock().GetCounter()
		}
	}
	if upTo == 0 {
		// Nothing matched (either empty backlog or all filtered out).
		// Use sinceLamport as the high-water mark so the client knows
		// the live stream that follows has no gap before this point.
		upTo = sinceLamport
	}
	return upTo, false, nil
}

func (h *EventsStreamHandler) writeControlFrame(ctx context.Context, c *websocket.Conn, payload map[string]any) error {
	buf, err := json.Marshal(payload)
	if err != nil {
		h.Logger.Warn("control frame marshal", "err", err)
		return err
	}
	writeCtx, cancel := context.WithTimeout(ctx, 10*time.Second)
	defer cancel()
	if err := c.Write(writeCtx, websocket.MessageText, buf); err != nil {
		if !errors.Is(err, context.Canceled) {
			h.Logger.Debug("control frame write", "err", err)
		}
		return err
	}
	return nil
}

func parseUint64Query(raw string) uint64 {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return 0
	}
	n, err := strconv.ParseUint(raw, 10, 64)
	if err != nil {
		return 0
	}
	return n
}

func parseIntQuery(raw string) int {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return 0
	}
	n, err := strconv.Atoi(raw)
	if err != nil || n < 0 {
		return 0
	}
	return n
}

func filterFromQuery(raw string) hub.Filter {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return hub.AllowAll()
	}
	parts := strings.Split(raw, ",")
	cleaned := parts[:0]
	for _, p := range parts {
		if t := strings.TrimSpace(p); t != "" {
			cleaned = append(cleaned, t)
		}
	}
	return hub.AllowTypes(cleaned...)
}
