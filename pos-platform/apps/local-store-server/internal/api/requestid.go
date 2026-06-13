package api

import (
	"context"
	"log/slog"
	"net/http"
	"time"

	"github.com/google/uuid"
)

// HeaderRequestID is the canonical correlation-ID header. Matches the
// header cloud-api uses so a single ID can be traced across both
// services when the local-store-server's sync engine forwards a batch.
const HeaderRequestID = "X-Request-ID"

type requestIDCtxKey struct{}

// RequestIDFromContext returns the ID attached by RequestIDMiddleware,
// or "" if there isn't one (middleware not in the chain).
func RequestIDFromContext(ctx context.Context) string {
	v, _ := ctx.Value(requestIDCtxKey{}).(string)
	return v
}

type statusRecorder struct {
	http.ResponseWriter
	status int
}

func (s *statusRecorder) WriteHeader(code int) {
	s.status = code
	s.ResponseWriter.WriteHeader(code)
}

// RequestIDMiddleware mirrors the cloud-api equivalent: accept or
// generate X-Request-ID, attach to ctx + response header, emit one
// access-log line per request (skipping probes). See cloud-api's
// internal/server/requestid.go for the design rationale.
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

			// Probes hit every few seconds — silence them.
			if r.URL.Path == "/healthz" || r.URL.Path == "/readyz" {
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
