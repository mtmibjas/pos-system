package server

import (
	"context"
	"log/slog"
	"net/http"
	"time"

	"github.com/google/uuid"
)

// HeaderRequestID is the canonical correlation-ID header. We accept it
// on the way in (so an upstream caller's trace propagates), generate one
// if missing, and echo it on the way out.
const HeaderRequestID = "X-Request-ID"

type requestIDCtxKey struct{}

// RequestIDFromContext returns the ID attached by RequestIDMiddleware,
// or "" if there isn't one (middleware not in the chain).
func RequestIDFromContext(ctx context.Context) string {
	v, _ := ctx.Value(requestIDCtxKey{}).(string)
	return v
}

// statusRecorder captures the HTTP status code written by the handler so
// the access log can include it. We do NOT buffer the body — only the
// status line. Defaults to 200 because http.ResponseWriter assumes that
// when nothing has been written explicitly.
type statusRecorder struct {
	http.ResponseWriter
	status int
}

func (s *statusRecorder) WriteHeader(code int) {
	s.status = code
	s.ResponseWriter.WriteHeader(code)
}

// RequestIDMiddleware reads/generates X-Request-ID, attaches it to the
// context (and response header), and emits one access-log line per
// request with request_id, method, path, status, duration. UAT operators
// can grep one ID across cloud-api + local-store-server logs to trace a
// single user action end-to-end.
//
// Liveness/readiness probes are excluded from logging — they fire every
// few seconds from supervisors and would drown the signal.
func RequestIDMiddleware(logger *slog.Logger) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			id := r.Header.Get(HeaderRequestID)
			if id == "" {
				id = uuid.NewString()
			}
			w.Header().Set(HeaderRequestID, id)
			ctx := context.WithValue(r.Context(), requestIDCtxKey{}, id)

			rec := &statusRecorder{ResponseWriter: w, status: http.StatusOK}
			start := time.Now()
			next.ServeHTTP(rec, r.WithContext(ctx))

			// Skip probe noise. Path comparison is exact — anything richer
			// hides real /healthz failures.
			if r.URL.Path == PathHealthz || r.URL.Path == PathReadyz {
				return
			}
			logger.Info("http",
				"request_id", id,
				"method", r.Method,
				"path", r.URL.Path,
				"status", rec.status,
				"dur_ms", time.Since(start).Milliseconds(),
			)
		})
	}
}
