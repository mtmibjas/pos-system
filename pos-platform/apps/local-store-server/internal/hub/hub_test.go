package hub_test

import (
	"sync"
	"testing"
	"time"

	"github.com/stretchr/testify/require"

	"github.com/mibjas/pos-platform/apps/local-store-server/internal/hub"
	posv1 "github.com/mibjas/pos-platform/packages/sdk-go/gen/pos/v1"
)

func mkEnv(eventType string, lamport uint64) *posv1.EventEnvelope {
	return &posv1.EventEnvelope{
		EventType: eventType,
		Clock:     &posv1.LamportClock{Counter: lamport},
	}
}

func recv(t *testing.T, ch <-chan *posv1.EventEnvelope) *posv1.EventEnvelope {
	t.Helper()
	select {
	case e, ok := <-ch:
		if !ok {
			t.Fatalf("channel closed unexpectedly")
		}
		return e
	case <-time.After(time.Second):
		t.Fatalf("timed out waiting for event")
		return nil
	}
}

// mustClosed drains any buffered values then asserts the channel is closed.
// A closed buffered channel keeps yielding ok=true until the buffer empties,
// so checking only the first recv would flake.
func mustClosed(t *testing.T, ch <-chan *posv1.EventEnvelope) {
	t.Helper()
	deadline := time.After(time.Second)
	for {
		select {
		case _, ok := <-ch:
			if !ok {
				return
			}
		case <-deadline:
			t.Fatalf("channel not closed within deadline")
		}
	}
}

func TestHub_FanOutToAllMatchingSubscribers(t *testing.T) {
	t.Parallel()
	h := hub.New()
	s1 := h.Subscribe(hub.AllowAll())
	defer s1.Close()
	s2 := h.Subscribe(hub.AllowAll())
	defer s2.Close()

	env := mkEnv("sale_created", 1)
	h.Publish(env)

	require.Equal(t, env, recv(t, s1.C))
	require.Equal(t, env, recv(t, s2.C))
}

func TestHub_FilterByEntityType(t *testing.T) {
	t.Parallel()
	h := hub.New()
	salesOnly := h.Subscribe(hub.AllowTypes("sale_created"))
	defer salesOnly.Close()
	invOnly := h.Subscribe(hub.AllowTypes("inventory_adjusted"))
	defer invOnly.Close()

	h.Publish(mkEnv("sale_created", 1))
	h.Publish(mkEnv("inventory_adjusted", 2))
	h.Publish(mkEnv("payment_added", 3)) // matched by neither

	got1 := recv(t, salesOnly.C)
	require.Equal(t, "sale_created", got1.EventType)
	got2 := recv(t, invOnly.C)
	require.Equal(t, "inventory_adjusted", got2.EventType)

	// Neither sub should see a second event.
	select {
	case e := <-salesOnly.C:
		t.Fatalf("salesOnly got unexpected event: %s", e.EventType)
	case e := <-invOnly.C:
		t.Fatalf("invOnly got unexpected event: %s", e.EventType)
	case <-time.After(50 * time.Millisecond):
	}
}

func TestHub_SlowConsumerDropped(t *testing.T) {
	t.Parallel()
	h := hub.New()
	slow := h.Subscribe(hub.AllowAll())
	// Deliberately do NOT read from slow.C — let its buffer fill.

	// Publish enough events to overflow the default 32 buffer.
	for i := 0; i < 100; i++ {
		h.Publish(mkEnv("sale_created", uint64(i)))
	}

	// Drain whatever fit in the buffer, then expect a close.
	for {
		select {
		case _, ok := <-slow.C:
			if !ok {
				return // closed, as expected
			}
		case <-time.After(time.Second):
			t.Fatalf("slow consumer channel never closed")
		}
	}
}

func TestHub_PublishNonBlockingUnderConcurrency(t *testing.T) {
	t.Parallel()
	h := hub.New()
	// One fast reader, one stuck reader.
	fast := h.Subscribe(hub.AllowAll())
	defer fast.Close()
	stuck := h.Subscribe(hub.AllowAll())
	// Don't read stuck.C and don't close it — make sure it can't block Publish.

	done := make(chan struct{})
	go func() {
		defer close(done)
		for i := 0; i < 1000; i++ {
			h.Publish(mkEnv("sale_created", uint64(i)))
		}
	}()

	// Drain fast in parallel.
	var got int
	var wg sync.WaitGroup
	wg.Add(1)
	go func() {
		defer wg.Done()
		for range fast.C {
			got++
		}
	}()

	select {
	case <-done:
	case <-time.After(5 * time.Second):
		t.Fatalf("Publish blocked on a stuck consumer")
	}

	// Allow scheduler to deliver remaining buffered events, then close fast.
	time.Sleep(50 * time.Millisecond)
	fast.Close()
	wg.Wait()
	require.Greater(t, got, 0, "fast consumer should have received some events")

	// stuck should have been evicted; check by confirming the channel closed.
	mustClosed(t, stuck.C)
}

func TestHub_CloseIsIdempotent(t *testing.T) {
	t.Parallel()
	h := hub.New()
	sub := h.Subscribe(hub.AllowAll())
	require.Equal(t, 1, h.SubscriberCount())

	sub.Close()
	sub.Close() // must not panic, must not double-close the channel
	require.Equal(t, 0, h.SubscriberCount())

	mustClosed(t, sub.C)
}

func TestHub_PublishNilIsNoop(t *testing.T) {
	t.Parallel()
	h := hub.New()
	sub := h.Subscribe(hub.AllowAll())
	defer sub.Close()

	h.Publish(nil)

	select {
	case e := <-sub.C:
		t.Fatalf("nil publish produced an event: %+v", e)
	case <-time.After(20 * time.Millisecond):
	}
}

func TestNopPublisher_DoesNotPanic(t *testing.T) {
	t.Parallel()
	var p hub.Publisher = hub.NopPublisher{}
	p.Publish(mkEnv("sale_created", 1))
	p.Publish(nil)
}
