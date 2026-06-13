// Package hub is the in-process pub/sub used by the local-store-server's
// websocket fan-out (Phase 4 — multi-counter realtime).
//
// Producers (sales, refunds, inventory, …) call Publish after a successful
// txn.Apply commit. Consumers (websocket subscribers) call Subscribe, get
// a buffered channel of matching events, and Unsubscribe on disconnect.
//
// Design choices:
//
//   - The hub holds *posv1.EventEnvelope directly so we don't invent a
//     second wire shape — the same envelope opslog stores, cloud receives,
//     and clients already decode. The envelope's EventType drives filtering.
//
//   - Publish never blocks. If a subscriber's buffer is full (slow consumer)
//     the hub closes that subscriber's channel and evicts it. The client is
//     then expected to reconnect with a last-seen lamport (slice 4.4) to
//     replay anything it missed. Backpressure must NEVER reach the caller
//     of Publish — sale finalization cannot wait on a stuck websocket.
//
//   - No auth on the hub itself; the websocket endpoint runs on the same
//     LAN-trusted loopback socket as the rest of the local API.
//
// txn.Apply itself is left untouched — the publish hook sits in each
// service after the err == nil branch of Apply, mirroring the existing
// `s.notifier.Notify()` pattern the sync worker uses.
package hub

import (
	"sync"

	posv1 "github.com/mibjas/pos-platform/packages/sdk-go/gen/pos/v1"
)

// Publisher is the producer-facing seam. Services depend on this interface
// (not *Hub) so tests can plug in a NopPublisher and avoid spinning up real
// subscribers when they only care about commit-side behavior.
type Publisher interface {
	Publish(env *posv1.EventEnvelope)
}

// RawPublisher is the producer-facing seam for ad-hoc JSON frames that do
// NOT carry a typed *posv1.EventEnvelope payload (slice 4.3:
// inventory_available_changed — intra-store ephemera that intentionally
// never reaches the cloud / opslog). Reservations service depends on this.
type RawPublisher interface {
	PublishRaw(eventType string, jsonFrame []byte)
}

// NopPublisher discards every event. Use it in service unit tests that
// don't exercise the realtime path. Implements both Publisher and
// RawPublisher so callers can satisfy either contract with one zero-value.
type NopPublisher struct{}

// Publish implements Publisher.
func (NopPublisher) Publish(*posv1.EventEnvelope) {}

// PublishRaw implements RawPublisher.
func (NopPublisher) PublishRaw(string, []byte) {}

// RawFrame is a pre-encoded JSON frame fanned out to subscribers. The
// EventType drives Filter matching the same way typed envelopes do, but
// JSON is delivered byte-for-byte instead of being re-marshalled by the
// websocket layer.
type RawFrame struct {
	EventType string
	JSON      []byte
}

// Subscription is the handle a consumer receives from Subscribe. Read from
// C and RawC until both close; close happens when the consumer calls Close
// OR when the hub evicts a slow consumer (in which case BOTH channels close
// together — the subscriber is gone).
type Subscription struct {
	// C delivers matching typed envelopes in publish order. Buffered; see
	// defaultBufferSize. Closed exactly once.
	C <-chan *posv1.EventEnvelope

	// RawC delivers pre-encoded JSON frames (slice 4.3:
	// inventory_available_changed). Same filtering as C, same buffer
	// budget, closed together with C.
	RawC <-chan *RawFrame

	hub *Hub
	id  uint64
}

// Close removes the subscription from the hub and closes C if it isn't
// already closed. Safe to call multiple times.
func (s *Subscription) Close() {
	if s == nil || s.hub == nil {
		return
	}
	s.hub.unsubscribe(s.id)
}

// Filter narrows the events a subscription receives. An empty Types means
// "all event types".
type Filter struct {
	Types map[string]struct{}
}

// AllowAll is the zero-value filter (no narrowing).
func AllowAll() Filter { return Filter{} }

// AllowTypes builds a Filter that admits only the named event types
// (matched against EventEnvelope.EventType, e.g. "sale_created").
func AllowTypes(types ...string) Filter {
	if len(types) == 0 {
		return AllowAll()
	}
	m := make(map[string]struct{}, len(types))
	for _, t := range types {
		if t == "" {
			continue
		}
		m[t] = struct{}{}
	}
	if len(m) == 0 {
		return AllowAll()
	}
	return Filter{Types: m}
}

// Matches reports whether eventType is admitted by the filter. Exported so
// non-hub callers (the WS replay loop in api/events_stream.go) can reuse
// the same matching rules against opslog rows.
func (f Filter) Matches(eventType string) bool {
	if len(f.Types) == 0 {
		return true
	}
	_, ok := f.Types[eventType]
	return ok
}

// defaultBufferSize is the per-subscriber channel buffer. Sized for the
// realistic burst of a multi-line sale finalization (sale_created +
// N inventory_adjusted + M payment_added) plus some headroom. A websocket
// writer that can't keep up with this depth is genuinely slow and the
// reconnect-with-last-seen path (slice 4.4) is the right recovery.
const defaultBufferSize = 32

// Hub is a fan-out broker. The zero value is NOT usable; call New.
type Hub struct {
	mu       sync.RWMutex
	nextID   uint64
	subs     map[uint64]*subscriber
	bufSize  int
}

// New returns a Hub with default settings.
func New() *Hub {
	return &Hub{
		subs:    make(map[uint64]*subscriber),
		bufSize: defaultBufferSize,
	}
}

type subscriber struct {
	filter Filter
	ch     chan *posv1.EventEnvelope
	rawCh  chan *RawFrame
	closed bool // guarded by Hub.mu
}

// Subscribe registers a consumer and returns its Subscription. Callers MUST
// either drain Subscription.C / RawC until they close or call
// Subscription.Close() to free resources.
func (h *Hub) Subscribe(filter Filter) *Subscription {
	h.mu.Lock()
	defer h.mu.Unlock()
	h.nextID++
	id := h.nextID
	ch := make(chan *posv1.EventEnvelope, h.bufSize)
	rawCh := make(chan *RawFrame, h.bufSize)
	h.subs[id] = &subscriber{filter: filter, ch: ch, rawCh: rawCh}
	return &Subscription{C: ch, RawC: rawCh, hub: h, id: id}
}

// Publish fans env out to every subscriber whose filter matches. Never
// blocks the caller. If a subscriber's buffer is full it is evicted and
// its channel is closed — the contract for slow consumers.
func (h *Hub) Publish(env *posv1.EventEnvelope) {
	if env == nil {
		return
	}
	// Collect evictions under a read lock; perform the actual unsubscribe
	// after releasing it to keep Publish's critical section short.
	var toEvict []uint64

	h.mu.RLock()
	for id, s := range h.subs {
		if s.closed || !s.filter.Matches(env.EventType) {
			continue
		}
		select {
		case s.ch <- env:
		default:
			toEvict = append(toEvict, id)
		}
	}
	h.mu.RUnlock()

	for _, id := range toEvict {
		h.unsubscribe(id)
	}
}

// PublishRaw fans a pre-encoded JSON frame out to subscribers whose filter
// matches eventType. Same backpressure contract as Publish — slow
// consumers get evicted, fast consumers keep going.
func (h *Hub) PublishRaw(eventType string, jsonFrame []byte) {
	if len(jsonFrame) == 0 {
		return
	}
	frame := &RawFrame{EventType: eventType, JSON: jsonFrame}
	var toEvict []uint64

	h.mu.RLock()
	for id, s := range h.subs {
		if s.closed || !s.filter.Matches(eventType) {
			continue
		}
		select {
		case s.rawCh <- frame:
		default:
			toEvict = append(toEvict, id)
		}
	}
	h.mu.RUnlock()

	for _, id := range toEvict {
		h.unsubscribe(id)
	}
}

// SubscriberCount reports the number of live subscribers. Intended for
// tests and /healthz-style introspection — not a load-bearing metric.
func (h *Hub) SubscriberCount() int {
	h.mu.RLock()
	defer h.mu.RUnlock()
	return len(h.subs)
}

func (h *Hub) unsubscribe(id uint64) {
	h.mu.Lock()
	defer h.mu.Unlock()
	s, ok := h.subs[id]
	if !ok {
		return
	}
	delete(h.subs, id)
	if !s.closed {
		s.closed = true
		close(s.ch)
		close(s.rawCh)
	}
}
