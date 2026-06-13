package api

import (
	"context"
	"net/http"

	"golang.org/x/net/http2"
	"golang.org/x/net/http2/h2c"

	"github.com/mibjas/pos-platform/packages/sdk-go/gen/pos/v1/posv1connect"
)

// NewMux returns an *http.ServeMux with the POS Connect services
// and a /healthz endpoint mounted.
//
// Wrap the returned mux with h2c so plaintext HTTP/2 works (clients can
// upgrade without TLS) — Connect's gRPC mode needs HTTP/2 framing, and the
// local-store-server listens on a loopback address where TLS would be
// ceremony with no security gain.
func NewMux(
	sale *SaleHandler,
	refund *RefundHandler,
	taxAdmin *TaxAdminHandler,
	item *ItemHandler,
	inv *InventoryHandler,
	reservation *ReservationHandler,
	events *EventsStreamHandler,
) *http.ServeMux {
	mux := http.NewServeMux()

	// Connect handlers.
	mux.Handle(posv1connect.NewSaleServiceHandler(sale))
	mux.Handle(posv1connect.NewRefundServiceHandler(refund))
	mux.Handle(posv1connect.NewTaxAdminServiceHandler(taxAdmin))
	mux.Handle(posv1connect.NewItemServiceHandler(item))
	mux.Handle(posv1connect.NewInventoryServiceHandler(inv))
	if reservation != nil {
		mux.Handle(posv1connect.NewReservationServiceHandler(reservation))
	}

	// WebSocket fan-out for multi-counter realtime (Phase 4 slice 4.1).
	// Optional: when events == nil, the endpoint isn't registered, so
	// tests that don't care about realtime can pass nil.
	if events != nil {
		mux.Handle(EventsStreamPath, events)
	}

	// Operator-facing liveness probe. Kept dumb on purpose — readiness
	// (DB up, sync worker running) is a separate concern (see MountReadyz).
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ok\n"))
	})

	return mux
}

// MountReadyz wires /readyz onto an existing mux. probe is invoked per
// request — return nil for 200, any error for 503 (with the error in the
// body). Kept separate from NewMux so test fixtures don't need to thread
// a DB handle through their wiring.
func MountReadyz(mux *http.ServeMux, probe func(context.Context) error) {
	mux.HandleFunc("/readyz", func(w http.ResponseWriter, r *http.Request) {
		if probe == nil {
			w.WriteHeader(http.StatusOK)
			_, _ = w.Write([]byte("ready\n"))
			return
		}
		if err := probe(r.Context()); err != nil {
			w.WriteHeader(http.StatusServiceUnavailable)
			_, _ = w.Write([]byte("not ready: " + err.Error() + "\n"))
			return
		}
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ready\n"))
	})
}

// H2CHandler returns h handler wrapped so it serves both HTTP/1.1 and
// plaintext HTTP/2 (h2c) on the same socket. Required for gRPC-over-Connect
// without TLS.
func H2CHandler(h http.Handler) http.Handler {
	return h2c.NewHandler(h, &http2.Server{})
}
