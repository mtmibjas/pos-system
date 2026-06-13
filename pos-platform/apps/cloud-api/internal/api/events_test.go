package api_test

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"strconv"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/require"
	"google.golang.org/protobuf/types/known/timestamppb"

	"github.com/mibjas/pos-platform/apps/cloud-api/internal/api"
	"github.com/mibjas/pos-platform/apps/cloud-api/internal/auth"
	"github.com/mibjas/pos-platform/apps/cloud-api/internal/db"
	"github.com/mibjas/pos-platform/apps/cloud-api/internal/ingest"
	posv1 "github.com/mibjas/pos-platform/packages/sdk-go/gen/pos/v1"
)

func newTestStore(t *testing.T) *ingest.Store {
	t.Helper()
	ctx := context.Background()
	sqlDB, err := db.Open(ctx, db.Config{Path: filepath.Join(t.TempDir(), "cloud.db")})
	require.NoError(t, err)
	t.Cleanup(func() { _ = sqlDB.Close() })
	require.NoError(t, db.RunMigrations(sqlDB))
	return ingest.NewStore(sqlDB, nil)
}

func seedOp(t *testing.T, s *ingest.Store, tenant, batchID string, lamport uint64) {
	t.Helper()
	id := uuid.NewString()
	op := &posv1.Operation{
		OperationId:   &posv1.OperationId{Value: id},
		OperationType: "sale_created",
		EntityType:    "sale",
		EntityId:      "sale-" + id,
		Envelope: &posv1.EventEnvelope{
			OperationId:   &posv1.OperationId{Value: id},
			EventType:     "sale_created",
			SchemaVersion: 1,
			TenantId:      &posv1.TenantId{Value: tenant},
			Origin:        &posv1.OriginNode{NodeId: "n-1"},
			Clock:         &posv1.LamportClock{Counter: lamport, NodeId: "n-1"},
			OccurredAt:    timestamppb.New(time.Now()),
			Payload: &posv1.EventEnvelope_SaleCreated{
				SaleCreated: &posv1.SaleCreated{SaleId: "sale-" + id},
			},
		},
		Origin: &posv1.OriginNode{NodeId: "n-1"},
	}
	res, err := s.Apply(context.Background(), &posv1.SyncBatch{
		BatchId:    batchID,
		TenantId:   &posv1.TenantId{Value: tenant},
		Operations: []*posv1.Operation{op},
	})
	require.NoError(t, err)
	require.Equal(t, posv1.SyncBatchAck_STATUS_APPLIED, res.Status)
}

// newServer returns a test httptest.Server with the EventsHandler
// directly mounted (no JWT middleware) using X-Tenant for tenant
// scope. The auth-on path is covered by the e2e tests in main_test.go.
func newServer(t *testing.T, store *ingest.Store) *httptest.Server {
	t.Helper()
	logger := slog.New(slog.NewTextHandler(io.Discard, nil))
	h := api.NewEventsHandler(store, nil, logger)
	srv := httptest.NewServer(h)
	t.Cleanup(srv.Close)
	return srv
}

type wireResp struct {
	Events []struct {
		ID            int64  `json:"id"`
		OperationID   string `json:"operation_id"`
		BatchID       string `json:"batch_id"`
		TenantID      string `json:"tenant_id"`
		OperationType string `json:"operation_type"`
		EntityType    string `json:"entity_type"`
		EntityID      string `json:"entity_id"`
		PayloadB64    string `json:"payload_b64"`
		Lamport       int64  `json:"lamport"`
	} `json:"events"`
	NextCursor string `json:"next_cursor"`
}

func fetch(t *testing.T, srv *httptest.Server, tenant, cursor string, limit int) wireResp {
	t.Helper()
	u := srv.URL + "?"
	q := []string{}
	if cursor != "" {
		q = append(q, "cursor="+cursor)
	}
	if limit > 0 {
		q = append(q, "limit="+strconv.Itoa(limit))
	}
	u += strings.Join(q, "&")
	req, _ := http.NewRequest(http.MethodGet, u, nil)
	if tenant != "" {
		req.Header.Set("X-Tenant", tenant)
	}
	resp, err := http.DefaultClient.Do(req)
	require.NoError(t, err)
	defer resp.Body.Close()
	require.Equal(t, http.StatusOK, resp.StatusCode)

	var out wireResp
	require.NoError(t, json.NewDecoder(resp.Body).Decode(&out))
	return out
}

func TestEventsHandler_PaginatesAndScopesByTenant(t *testing.T) {
	store := newTestStore(t)
	for i := uint64(1); i <= 4; i++ {
		seedOp(t, store, "tenant-A", "b-A-"+strconv.FormatUint(i, 10), i)
	}
	seedOp(t, store, "tenant-B", "b-B-1", 10)

	srv := newServer(t, store)

	page1 := fetch(t, srv, "tenant-A", "", 2)
	require.Len(t, page1.Events, 2)
	require.NotEmpty(t, page1.NextCursor)
	for _, e := range page1.Events {
		require.Equal(t, "tenant-A", e.TenantID)
		_, err := base64.StdEncoding.DecodeString(e.PayloadB64)
		require.NoError(t, err, "payload must be valid base64")
	}

	page2 := fetch(t, srv, "tenant-A", page1.NextCursor, 2)
	require.Len(t, page2.Events, 2)
	require.Empty(t, page2.NextCursor, "exactly drained — next cursor must be empty")

	// tenant-B sees only its own row.
	all := fetch(t, srv, "tenant-B", "", 0)
	require.Len(t, all.Events, 1)
	require.Equal(t, "tenant-B", all.Events[0].TenantID)
}

func TestEventsHandler_MissingTenantHeader_400(t *testing.T) {
	srv := newServer(t, newTestStore(t))
	resp, err := http.Get(srv.URL)
	require.NoError(t, err)
	defer resp.Body.Close()
	require.Equal(t, http.StatusBadRequest, resp.StatusCode,
		"insecure-no-auth mode without X-Tenant must NOT default — risk of cross-tenant leak")
}

func TestEventsHandler_RejectsNonGET(t *testing.T) {
	srv := newServer(t, newTestStore(t))
	resp, err := http.Post(srv.URL, "application/json", nil)
	require.NoError(t, err)
	defer resp.Body.Close()
	require.Equal(t, http.StatusMethodNotAllowed, resp.StatusCode)
}

func TestEventsHandler_RejectsBadCursor(t *testing.T) {
	srv := newServer(t, newTestStore(t))
	req, _ := http.NewRequest(http.MethodGet, srv.URL+"?cursor=!!!notbase64!!!", nil)
	req.Header.Set("X-Tenant", "tenant-A")
	resp, err := http.DefaultClient.Do(req)
	require.NoError(t, err)
	defer resp.Body.Close()
	require.Equal(t, http.StatusBadRequest, resp.StatusCode)
}

func TestEventsHandler_RejectsNegativeLimit(t *testing.T) {
	srv := newServer(t, newTestStore(t))
	req, _ := http.NewRequest(http.MethodGet, srv.URL+"?limit=-1", nil)
	req.Header.Set("X-Tenant", "tenant-A")
	resp, err := http.DefaultClient.Do(req)
	require.NoError(t, err)
	defer resp.Body.Close()
	require.Equal(t, http.StatusBadRequest, resp.StatusCode)
}

func TestEventsHandler_WithAuth_UsesJWTTenant(t *testing.T) {
	store := newTestStore(t)
	seedOp(t, store, "tenant-A", "b-1", 1)
	seedOp(t, store, "tenant-B", "b-2", 1)

	v, _ := auth.NewVerifier("secret")
	logger := slog.New(slog.NewTextHandler(io.Discard, nil))
	h := api.NewEventsHandler(store, v, logger)

	// Inject claims via context to simulate having passed the middleware.
	// We deliberately use the verifier=non-nil path so resolveTenant
	// pulls from the JWT and ignores any X-Tenant override.
	req := httptest.NewRequest(http.MethodGet, "/v1/sync/events", nil)
	req.Header.Set("X-Tenant", "tenant-B") // should be IGNORED
	ctx := contextWithFakeClaims(req.Context(), "tenant-A")
	req = req.WithContext(ctx)
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)

	require.Equal(t, http.StatusOK, rec.Code)
	var resp wireResp
	require.NoError(t, json.NewDecoder(rec.Body).Decode(&resp))
	require.Len(t, resp.Events, 1)
	require.Equal(t, "tenant-A", resp.Events[0].TenantID,
		"with auth on, the JWT's tenant must win over any header")
}

// contextWithFakeClaims sets a Claims into ctx in the same way the
// auth middleware does. Lives here (test-only) so we don't have to
// export the context key from the auth package.
func contextWithFakeClaims(ctx context.Context, tenant string) context.Context {
	return auth.ContextWithClaimsForTest(ctx, &auth.Claims{TenantID: tenant})
}
