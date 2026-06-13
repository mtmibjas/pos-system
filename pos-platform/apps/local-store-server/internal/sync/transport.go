package sync

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"io"
	"net/http"
	"strconv"
	"time"

	"google.golang.org/protobuf/proto"

	posv1 "github.com/mibjas/pos-platform/packages/sdk-go/gen/pos/v1"
)

// Transport ships one SyncBatch to the cloud and returns the SyncBatchAck.
// The interface exists so tests can plug a fake without httptest, and so
// future transports (e.g. a multiplexed gRPC stream) drop in without
// rewriting the worker.
type Transport interface {
	Send(ctx context.Context, batch *posv1.SyncBatch) (*posv1.SyncBatchAck, error)
}

// TransientError marks a transport failure that the worker should retry.
// Distinguishing transient from permanent at the transport layer is what
// lets the worker make the right ack decision without sniffing strings.
type TransientError struct{ Err error }

func (e *TransientError) Error() string { return "sync: transient: " + e.Err.Error() }
func (e *TransientError) Unwrap() error { return e.Err }

// IsTransient reports whether err (or any wrapped err) is a TransientError.
func IsTransient(err error) bool {
	var t *TransientError
	return errors.As(err, &t)
}

// RetryAfterError is a transient error that carries a server-supplied
// Retry-After hint. When the worker sees this it should honor the
// duration verbatim and NOT increment its own backoff counter — the
// server is the authority on when it expects to be ready again.
//
// Wraps TransientError so existing IsTransient() callers keep working.
type RetryAfterError struct {
	TransientError
	// RetryAfter is the duration parsed from the Retry-After header.
	// May be zero if the header was absent or unparseable (caller falls
	// back to local backoff in that case).
	RetryAfter time.Duration
}

// Unwrap exposes the embedded *TransientError so errors.As walking the
// chain matches *TransientError (and therefore IsTransient returns
// true). Without this, the promoted Unwrap from the embedded value
// jumps past *TransientError to the innermost cause.
func (e *RetryAfterError) Unwrap() error { return &e.TransientError }

// AsRetryAfter extracts a RetryAfterError from err if present. Returns
// (*RetryAfterError, true) on match. Worker uses this in preference to
// the local Backoff schedule.
func AsRetryAfter(err error) (*RetryAfterError, bool) {
	var ra *RetryAfterError
	if errors.As(err, &ra) {
		return ra, true
	}
	return nil, false
}

// parseRetryAfter accepts both RFC 7231 forms:
//   - delta-seconds:  "120"
//   - HTTP-date:      "Wed, 21 Oct 2026 07:28:00 GMT"
//
// Returns 0 if the header is absent, malformed, or non-positive. now is
// injected so tests don't depend on wall-clock time when validating the
// HTTP-date form.
func parseRetryAfter(h string, now time.Time) time.Duration {
	if h == "" {
		return 0
	}
	if secs, err := strconv.Atoi(h); err == nil {
		if secs <= 0 {
			return 0
		}
		return time.Duration(secs) * time.Second
	}
	if t, err := http.ParseTime(h); err == nil {
		d := t.Sub(now)
		if d <= 0 {
			return 0
		}
		return d
	}
	return 0
}

// HTTPTransport posts SyncBatch as application/x-protobuf to BaseURL +
// "/v1/sync/batches" (path is intentionally hardcoded; this is an
// internal cloud RPC, not a user-facing API).
type HTTPTransport struct {
	BaseURL string
	Client  *http.Client
	// AuthHeaderFunc returns the value of the Authorization header for a
	// given outgoing request. Optional — left nil during Phase 1
	// (no auth); Phase 1.5/2 plugs in the JWT minter here without touching
	// any of the rest of the engine.
	AuthHeaderFunc func(ctx context.Context) (string, error)
}

const (
	contentTypeProto = "application/x-protobuf"
	batchesPath      = "/v1/sync/batches"
)

// NewHTTPTransport returns an HTTPTransport with a 30s default client timeout
// (override via Client).
func NewHTTPTransport(baseURL string) *HTTPTransport {
	return &HTTPTransport{
		BaseURL: baseURL,
		Client:  &http.Client{Timeout: 30 * time.Second},
	}
}

// Send marshals batch, POSTs it, and parses the response.
//
// Error classification:
//   - Network failures, 5xx, 429 → wrapped in TransientError (worker will retry).
//   - 4xx other than 429 → plain error (worker will MarkFailed — permanent).
//   - Malformed response body → plain error (permanent — same batch will fail again).
func (t *HTTPTransport) Send(ctx context.Context, batch *posv1.SyncBatch) (*posv1.SyncBatchAck, error) {
	body, err := proto.Marshal(batch)
	if err != nil {
		return nil, fmt.Errorf("sync: marshal batch: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, t.BaseURL+batchesPath, bytes.NewReader(body))
	if err != nil {
		return nil, fmt.Errorf("sync: build request: %w", err)
	}
	req.Header.Set("Content-Type", contentTypeProto)
	req.Header.Set("Accept", contentTypeProto)
	// Use batch_id as the correlation ID so the cloud-api access log
	// shows the same identifier this side already prints. UAT can grep a
	// single batch_id across both services' logs without joining tables.
	if batch.BatchId != "" {
		req.Header.Set("X-Request-ID", batch.BatchId)
	}
	if t.AuthHeaderFunc != nil {
		auth, err := t.AuthHeaderFunc(ctx)
		if err != nil {
			return nil, fmt.Errorf("sync: auth header: %w", err)
		}
		if auth != "" {
			req.Header.Set("Authorization", auth)
		}
	}

	resp, err := t.Client.Do(req)
	if err != nil {
		// Network errors (DNS, refused, timeout, reset) are always transient.
		return nil, &TransientError{Err: err}
	}
	defer resp.Body.Close()

	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, &TransientError{Err: fmt.Errorf("read body: %w", err)}
	}

	switch {
	case resp.StatusCode == http.StatusOK:
		// Fall through to body parsing.
	case resp.StatusCode == http.StatusTooManyRequests || resp.StatusCode >= 500:
		base := TransientError{Err: fmt.Errorf("http %d: %s", resp.StatusCode, snippet(respBody))}
		if ra := parseRetryAfter(resp.Header.Get("Retry-After"), time.Now()); ra > 0 {
			return nil, &RetryAfterError{TransientError: base, RetryAfter: ra}
		}
		return nil, &base
	default:
		return nil, fmt.Errorf("sync: permanent http %d: %s", resp.StatusCode, snippet(respBody))
	}

	ack := &posv1.SyncBatchAck{}
	if err := proto.Unmarshal(respBody, ack); err != nil {
		return nil, fmt.Errorf("sync: unmarshal ack (body=%d bytes): %w", len(respBody), err)
	}
	if ack.BatchId == "" {
		return nil, errors.New("sync: ack missing batch_id")
	}
	return ack, nil
}

// snippet returns up to 200 bytes of body for error messages so a 500 with
// a paragraph of HTML doesn't drown the logs.
func snippet(b []byte) string {
	const n = 200
	if len(b) <= n {
		return string(b)
	}
	return string(b[:n]) + "…"
}
