package main

import (
	"bytes"
	"context"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"testing"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/stretchr/testify/require"
	"google.golang.org/protobuf/proto"

	"github.com/mibjas/pos-platform/apps/cloud-api/internal/auth"
	"github.com/mibjas/pos-platform/apps/cloud-api/internal/db"
	"github.com/mibjas/pos-platform/apps/cloud-api/internal/ingest"
	"github.com/mibjas/pos-platform/apps/cloud-api/internal/reports"
	"github.com/mibjas/pos-platform/apps/cloud-api/internal/server"
	posv1 "github.com/mibjas/pos-platform/packages/sdk-go/gen/pos/v1"
)

func post(t *testing.T, srv *httptest.Server, batchID, force string) (*http.Response, *posv1.SyncBatchAck) {
	t.Helper()
	body, err := proto.Marshal(&posv1.SyncBatch{
		BatchId:  batchID,
		TenantId: &posv1.TenantId{Value: "tenant-A"},
	})
	require.NoError(t, err)
	req, err := http.NewRequest(http.MethodPost, srv.URL+server.PathSyncBatches, bytes.NewReader(body))
	require.NoError(t, err)
	req.Header.Set("Content-Type", server.ContentTypeProto)
	if force != "" {
		req.Header.Set(server.HeaderForce, force)
	}
	resp, err := http.DefaultClient.Do(req)
	require.NoError(t, err)
	respBody, err := io.ReadAll(resp.Body)
	require.NoError(t, err)
	_ = resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return resp, nil
	}
	ack := &posv1.SyncBatchAck{}
	require.NoError(t, proto.Unmarshal(respBody, ack))
	return resp, ack
}

func newStubServer(t *testing.T) *httptest.Server {
	t.Helper()
	ctx := context.Background()
	sqlDB, err := db.Open(ctx, db.Config{Path: filepath.Join(t.TempDir(), "cloud.db")})
	require.NoError(t, err)
	t.Cleanup(func() { _ = sqlDB.Close() })
	require.NoError(t, db.RunMigrations(sqlDB))

	logger := slog.New(slog.NewTextHandler(io.Discard, nil))
	// nil verifier = no auth (matches Phase 1 stub semantics so the
	// existing transport-layer tests keep working without minting JWTs).
	srv := httptest.NewServer(server.New(logger, ingest.NewStore(sqlDB, nil), nil, reports.NewStore(sqlDB)))
	t.Cleanup(srv.Close)
	return srv
}

func TestStub_AppliedThenDuplicate(t *testing.T) {
	srv := newStubServer(t)

	resp, ack := post(t, srv, "batch-1", "")
	require.Equal(t, http.StatusOK, resp.StatusCode)
	require.Equal(t, posv1.SyncBatchAck_STATUS_APPLIED, ack.Status)

	_, ack2 := post(t, srv, "batch-1", "")
	require.Equal(t, posv1.SyncBatchAck_STATUS_DUPLICATE, ack2.Status,
		"second send with same batch_id must be DUPLICATE")
}

func TestStub_ForceTransient500(t *testing.T) {
	srv := newStubServer(t)
	resp, _ := post(t, srv, "b", "500")
	require.Equal(t, http.StatusInternalServerError, resp.StatusCode)
}

func TestStub_ForcePermanent400(t *testing.T) {
	srv := newStubServer(t)
	resp, _ := post(t, srv, "b", "400")
	require.Equal(t, http.StatusBadRequest, resp.StatusCode)
}

func TestStub_ForceRejected(t *testing.T) {
	srv := newStubServer(t)
	_, ack := post(t, srv, "b", "rejected")
	require.Equal(t, posv1.SyncBatchAck_STATUS_REJECTED, ack.Status)
}

func TestStub_ForceRetryLater(t *testing.T) {
	srv := newStubServer(t)
	_, ack := post(t, srv, "b", "retry_later")
	require.Equal(t, posv1.SyncBatchAck_STATUS_RETRY_LATER, ack.Status)
}

func TestStub_RejectsMissingBatchID(t *testing.T) {
	srv := newStubServer(t)
	resp, _ := post(t, srv, "", "")
	require.Equal(t, http.StatusBadRequest, resp.StatusCode)
}

func TestStub_RejectsNonPOST(t *testing.T) {
	srv := newStubServer(t)
	resp, err := http.Get(srv.URL + server.PathSyncBatches)
	require.NoError(t, err)
	_ = resp.Body.Close()
	require.Equal(t, http.StatusMethodNotAllowed, resp.StatusCode)
}

// --- Slice 3.5: JWT auth ---

const e2eSecret = "e2e-jwt-secret"

func newAuthedServer(t *testing.T) *httptest.Server {
	t.Helper()
	ctx := context.Background()
	sqlDB, err := db.Open(ctx, db.Config{Path: filepath.Join(t.TempDir(), "cloud.db")})
	require.NoError(t, err)
	t.Cleanup(func() { _ = sqlDB.Close() })
	require.NoError(t, db.RunMigrations(sqlDB))

	v, err := auth.NewVerifier(e2eSecret)
	require.NoError(t, err)

	logger := slog.New(slog.NewTextHandler(io.Discard, nil))
	srv := httptest.NewServer(server.New(logger, ingest.NewStore(sqlDB, nil), v, reports.NewStore(sqlDB)))
	t.Cleanup(srv.Close)
	return srv
}

func mintToken(t *testing.T, tenant string) string {
	t.Helper()
	tok := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
		"tenant_id": tenant,
		"exp":       time.Now().Add(5 * time.Minute).Unix(),
	})
	s, err := tok.SignedString([]byte(e2eSecret))
	require.NoError(t, err)
	return s
}

func postWithAuth(t *testing.T, srv *httptest.Server, tenant, batchID, bearer string) *http.Response {
	t.Helper()
	body, err := proto.Marshal(&posv1.SyncBatch{
		BatchId:  batchID,
		TenantId: &posv1.TenantId{Value: tenant},
	})
	require.NoError(t, err)
	req, err := http.NewRequest(http.MethodPost, srv.URL+server.PathSyncBatches, bytes.NewReader(body))
	require.NoError(t, err)
	req.Header.Set("Content-Type", server.ContentTypeProto)
	if bearer != "" {
		req.Header.Set("Authorization", "Bearer "+bearer)
	}
	resp, err := http.DefaultClient.Do(req)
	require.NoError(t, err)
	return resp
}

func TestAuth_MissingToken_Returns401(t *testing.T) {
	srv := newAuthedServer(t)
	resp := postWithAuth(t, srv, "tenant-A", "batch-1", "")
	defer resp.Body.Close()
	require.Equal(t, http.StatusUnauthorized, resp.StatusCode)
}

func TestAuth_ValidToken_Applied(t *testing.T) {
	srv := newAuthedServer(t)
	resp := postWithAuth(t, srv, "tenant-A", "batch-1", mintToken(t, "tenant-A"))
	defer resp.Body.Close()
	require.Equal(t, http.StatusOK, resp.StatusCode)

	body, _ := io.ReadAll(resp.Body)
	ack := &posv1.SyncBatchAck{}
	require.NoError(t, proto.Unmarshal(body, ack))
	require.Equal(t, posv1.SyncBatchAck_STATUS_APPLIED, ack.Status)
}

func TestAuth_TenantMismatch_Returns403(t *testing.T) {
	srv := newAuthedServer(t)
	// Token says tenant-A, batch claims tenant-B.
	resp := postWithAuth(t, srv, "tenant-B", "batch-1", mintToken(t, "tenant-A"))
	defer resp.Body.Close()
	require.Equal(t, http.StatusForbidden, resp.StatusCode,
		"token tenant must match batch tenant — defends against cross-tenant smuggling")
}

func TestAuth_HealthzStaysOpen(t *testing.T) {
	srv := newAuthedServer(t)
	resp, err := http.Get(srv.URL + "/healthz")
	require.NoError(t, err)
	defer resp.Body.Close()
	require.Equal(t, http.StatusOK, resp.StatusCode,
		"/healthz must not require auth — load balancers / monitors hit it unauthenticated")
}
