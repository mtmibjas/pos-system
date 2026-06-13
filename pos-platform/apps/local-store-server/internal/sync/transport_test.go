package sync_test

import (
	"context"
	"io"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/require"
	"google.golang.org/protobuf/proto"

	"github.com/mibjas/pos-platform/apps/local-store-server/internal/sync"
	posv1 "github.com/mibjas/pos-platform/packages/sdk-go/gen/pos/v1"
)

func mustMarshalAck(t *testing.T, ack *posv1.SyncBatchAck) []byte {
	t.Helper()
	b, err := proto.Marshal(ack)
	require.NoError(t, err)
	return b
}

func newBatch(id string) *posv1.SyncBatch {
	return &posv1.SyncBatch{BatchId: id, TenantId: &posv1.TenantId{Value: "tenant-A"}}
}

func TestHTTPTransport_Send_Applied(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		require.Equal(t, http.MethodPost, r.Method)
		require.Equal(t, "/v1/sync/batches", r.URL.Path)
		require.Equal(t, "application/x-protobuf", r.Header.Get("Content-Type"))
		body, err := io.ReadAll(r.Body)
		require.NoError(t, err)
		batch := &posv1.SyncBatch{}
		require.NoError(t, proto.Unmarshal(body, batch))
		require.Equal(t, "batch-1", batch.BatchId)

		w.Header().Set("Content-Type", "application/x-protobuf")
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write(mustMarshalAck(t, &posv1.SyncBatchAck{
			BatchId: batch.BatchId,
			Status:  posv1.SyncBatchAck_STATUS_APPLIED,
		}))
	}))
	defer srv.Close()

	tr := sync.NewHTTPTransport(srv.URL)
	ack, err := tr.Send(context.Background(), newBatch("batch-1"))
	require.NoError(t, err)
	require.Equal(t, posv1.SyncBatchAck_STATUS_APPLIED, ack.Status)
}

func TestHTTPTransport_Send_5xxIsTransient(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusInternalServerError)
		_, _ = w.Write([]byte("oops"))
	}))
	defer srv.Close()

	tr := sync.NewHTTPTransport(srv.URL)
	_, err := tr.Send(context.Background(), newBatch("b"))
	require.Error(t, err)
	require.True(t, sync.IsTransient(err), "5xx must classify as transient")
}

func TestHTTPTransport_Send_429IsTransient(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusTooManyRequests)
	}))
	defer srv.Close()

	tr := sync.NewHTTPTransport(srv.URL)
	_, err := tr.Send(context.Background(), newBatch("b"))
	require.True(t, sync.IsTransient(err), "429 must classify as transient")
}

func TestHTTPTransport_Send_4xxIsPermanent(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusBadRequest)
		_, _ = w.Write([]byte("malformed batch"))
	}))
	defer srv.Close()

	tr := sync.NewHTTPTransport(srv.URL)
	_, err := tr.Send(context.Background(), newBatch("b"))
	require.Error(t, err)
	require.False(t, sync.IsTransient(err), "4xx (non-429) must classify as permanent")
}

func TestHTTPTransport_Send_NetworkErrorIsTransient(t *testing.T) {
	// Point at a closed port.
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {}))
	srv.Close() // close immediately so the connection refuses.

	tr := sync.NewHTTPTransport(srv.URL)
	tr.Client = &http.Client{Timeout: 500 * time.Millisecond}
	_, err := tr.Send(context.Background(), newBatch("b"))
	require.Error(t, err)
	require.True(t, sync.IsTransient(err), "connection refused must be transient")
}

func TestHTTPTransport_Send_MalformedAckBodyIsPermanent(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte{0xff, 0xff, 0xff}) // not a valid proto
	}))
	defer srv.Close()

	tr := sync.NewHTTPTransport(srv.URL)
	_, err := tr.Send(context.Background(), newBatch("b"))
	require.Error(t, err)
	require.False(t, sync.IsTransient(err),
		"malformed ack body is permanent — retrying won't change the outcome")
}

func TestHTTPTransport_Send_AckMissingBatchID(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write(mustMarshalAck(t, &posv1.SyncBatchAck{Status: posv1.SyncBatchAck_STATUS_APPLIED}))
	}))
	defer srv.Close()

	tr := sync.NewHTTPTransport(srv.URL)
	_, err := tr.Send(context.Background(), newBatch("b"))
	require.Error(t, err, "ack with empty batch_id must be rejected")
}

func TestHTTPTransport_Send_RetryAfter_DeltaSeconds(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Retry-After", "7")
		w.WriteHeader(http.StatusTooManyRequests)
	}))
	defer srv.Close()

	tr := sync.NewHTTPTransport(srv.URL)
	_, err := tr.Send(context.Background(), newBatch("b"))
	require.True(t, sync.IsTransient(err))
	ra, ok := sync.AsRetryAfter(err)
	require.True(t, ok, "must surface as RetryAfterError")
	require.Equal(t, 7*time.Second, ra.RetryAfter)
}

func TestHTTPTransport_Send_RetryAfter_HTTPDate(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// 3 seconds in the future, formatted as HTTP-date.
		w.Header().Set("Retry-After", time.Now().Add(3*time.Second).UTC().Format(http.TimeFormat))
		w.WriteHeader(http.StatusServiceUnavailable)
	}))
	defer srv.Close()

	tr := sync.NewHTTPTransport(srv.URL)
	_, err := tr.Send(context.Background(), newBatch("b"))
	require.True(t, sync.IsTransient(err))
	ra, ok := sync.AsRetryAfter(err)
	require.True(t, ok)
	// HTTP-date has 1s resolution; allow a wide window for test scheduling.
	require.InDelta(t, 3*time.Second, ra.RetryAfter, float64(2*time.Second))
}

func TestHTTPTransport_Send_503WithoutRetryAfter_PlainTransient(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusServiceUnavailable)
	}))
	defer srv.Close()

	tr := sync.NewHTTPTransport(srv.URL)
	_, err := tr.Send(context.Background(), newBatch("b"))
	require.True(t, sync.IsTransient(err))
	_, ok := sync.AsRetryAfter(err)
	require.False(t, ok, "no Retry-After header → plain TransientError")
}

func TestHTTPTransport_Send_RetryAfter_GarbageHeaderIgnored(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Retry-After", "not-a-number")
		w.WriteHeader(http.StatusTooManyRequests)
	}))
	defer srv.Close()

	tr := sync.NewHTTPTransport(srv.URL)
	_, err := tr.Send(context.Background(), newBatch("b"))
	require.True(t, sync.IsTransient(err))
	_, ok := sync.AsRetryAfter(err)
	require.False(t, ok, "unparseable header must fall back to plain TransientError")
}

func TestHTTPTransport_Send_AuthHeaderFuncWiredIn(t *testing.T) {
	var seen string
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		seen = r.Header.Get("Authorization")
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write(mustMarshalAck(t, &posv1.SyncBatchAck{
			BatchId: "b", Status: posv1.SyncBatchAck_STATUS_APPLIED,
		}))
	}))
	defer srv.Close()

	tr := sync.NewHTTPTransport(srv.URL)
	tr.AuthHeaderFunc = func(ctx context.Context) (string, error) {
		return "Bearer test-token-" + uuid.New().String(), nil
	}
	_, err := tr.Send(context.Background(), newBatch("b"))
	require.NoError(t, err)
	require.True(t, len(seen) > len("Bearer test-token-"), "Authorization header must be sent: %q", seen)
}
