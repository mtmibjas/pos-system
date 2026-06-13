package api_test

import (
	"context"
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"testing"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"google.golang.org/protobuf/types/known/timestamppb"

	"github.com/mibjas/pos-platform/apps/cloud-api/internal/api"
	"github.com/mibjas/pos-platform/apps/cloud-api/internal/auth"
	"github.com/mibjas/pos-platform/apps/cloud-api/internal/db"
	"github.com/mibjas/pos-platform/apps/cloud-api/internal/ingest"
	"github.com/mibjas/pos-platform/apps/cloud-api/internal/projection"
	"github.com/mibjas/pos-platform/apps/cloud-api/internal/reports"
	posv1 "github.com/mibjas/pos-platform/packages/sdk-go/gen/pos/v1"
)

const testJWTSecret = "reports-test-secret"

func stubVerifier(t *testing.T) *auth.Verifier {
	t.Helper()
	v, err := auth.NewVerifier(testJWTSecret)
	require.NoError(t, err)
	return v
}

func mintTok(t *testing.T, roles []string) string {
	t.Helper()
	rolesAny := make([]any, len(roles))
	for i, r := range roles {
		rolesAny[i] = r
	}
	tok := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
		"tenant_id": "tenant-A",
		"roles":     rolesAny,
		"exp":       time.Now().Add(5 * time.Minute).Unix(),
	})
	s, err := tok.SignedString([]byte(testJWTSecret))
	require.NoError(t, err)
	return s
}

// reportsHarness mounts the real ReportsHandler in no-auth mode
// (verifier=nil → X-Tenant header carries the tenant). The auth/role
// gate composition is covered separately below.
type reportsHarness struct {
	t      *testing.T
	srv    *httptest.Server
	ingest *ingest.Store
	worker *projection.Worker
}

func newReportsServer(t *testing.T) *reportsHarness {
	t.Helper()
	ctx := context.Background()
	sqlDB, err := db.Open(ctx, db.Config{Path: filepath.Join(t.TempDir(), "cloud.db")})
	require.NoError(t, err)
	t.Cleanup(func() { _ = sqlDB.Close() })
	require.NoError(t, db.RunMigrations(sqlDB))

	logger := slog.New(slog.NewTextHandler(io.Discard, nil))
	h := api.NewReportsHandler(reports.NewStore(sqlDB), nil, logger)

	mux := http.NewServeMux()
	mux.HandleFunc("/v1/reports/sales-summary", h.SalesSummary)
	mux.HandleFunc("/v1/reports/sales-by-method", h.SalesByMethod)
	mux.HandleFunc("/v1/reports/tax-summary", h.TaxSummary)
	mux.HandleFunc("/v1/reports/stores", h.Stores)
	srv := httptest.NewServer(mux)
	t.Cleanup(srv.Close)

	return &reportsHarness{
		t:      t,
		srv:    srv,
		ingest: ingest.NewStore(sqlDB, nil),
		worker: projection.New(sqlDB, projection.NewStore(sqlDB), logger, projection.WithBatch(100)),
	}
}

func (h *reportsHarness) seedSale(occurredAt time.Time, store string, subtotal, tax, total int64) {
	h.t.Helper()
	saleID := uuid.NewString()
	op := &posv1.Operation{
		OperationId:   &posv1.OperationId{Value: saleID},
		OperationType: "sale_created",
		EntityType:    "sale",
		EntityId:      saleID,
		Envelope: &posv1.EventEnvelope{
			OperationId:   &posv1.OperationId{Value: saleID},
			EventType:     "sale_created",
			SchemaVersion: 1,
			TenantId:      &posv1.TenantId{Value: "tenant-A"},
			Origin:        &posv1.OriginNode{NodeId: "n-1"},
			Clock:         &posv1.LamportClock{Counter: 1, NodeId: "n-1"},
			OccurredAt:    timestamppb.New(occurredAt),
			Payload: &posv1.EventEnvelope_SaleCreated{
				SaleCreated: &posv1.SaleCreated{
					SaleId:  saleID,
					StoreId: &posv1.StoreId{Value: store},
					Lines: []*posv1.SaleLine{{
						TaxCategoryId: "std",
						LineTax:       &posv1.Money{CurrencyCode: "USD", Units: tax},
					}},
					Subtotal:   &posv1.Money{CurrencyCode: "USD", Units: subtotal},
					TaxTotal:   &posv1.Money{CurrencyCode: "USD", Units: tax},
					GrandTotal: &posv1.Money{CurrencyCode: "USD", Units: total},
				},
			},
		},
		Origin: &posv1.OriginNode{NodeId: "n-1"},
	}
	res, err := h.ingest.Apply(context.Background(), &posv1.SyncBatch{
		BatchId:    uuid.NewString(),
		TenantId:   &posv1.TenantId{Value: "tenant-A"},
		Operations: []*posv1.Operation{op},
	})
	require.NoError(h.t, err)
	require.Equal(h.t, posv1.SyncBatchAck_STATUS_APPLIED, res.Status)
}

func (h *reportsHarness) drain() {
	h.t.Helper()
	_, err := h.worker.RunOnce(context.Background())
	require.NoError(h.t, err)
}

func (h *reportsHarness) get(path string, decode any) *http.Response {
	h.t.Helper()
	req, err := http.NewRequest(http.MethodGet, h.srv.URL+path, nil)
	require.NoError(h.t, err)
	req.Header.Set("X-Tenant", "tenant-A")
	resp, err := http.DefaultClient.Do(req)
	require.NoError(h.t, err)
	if decode != nil && resp.StatusCode == http.StatusOK {
		require.NoError(h.t, json.NewDecoder(resp.Body).Decode(decode))
	}
	_ = resp.Body.Close()
	return resp
}

// --- Handler-level happy paths ---

func TestReports_SalesSummary_HappyPath(t *testing.T) {
	h := newReportsServer(t)
	occ := time.Date(2026, 5, 31, 10, 0, 0, 0, time.UTC)
	h.seedSale(occ, "store-A", 10, 1, 11)
	h.drain()

	var resp struct {
		Buckets []reports.SalesSummaryBucket `json:"buckets"`
	}
	r := h.get("/v1/reports/sales-summary?from=2026-05-31", &resp)
	require.Equal(t, http.StatusOK, r.StatusCode)
	require.Len(t, resp.Buckets, 1)
	assert.Equal(t, "2026-05-31", resp.Buckets[0].PeriodStart)
	assert.Equal(t, int64(11), resp.Buckets[0].GrandTotal.Units)
}

func TestReports_TaxSummary_HappyPath(t *testing.T) {
	h := newReportsServer(t)
	occ := time.Date(2026, 5, 31, 10, 0, 0, 0, time.UTC)
	h.seedSale(occ, "store-A", 10, 1, 11)
	h.drain()

	var resp struct {
		Buckets []reports.TaxSummaryBucket `json:"buckets"`
	}
	r := h.get("/v1/reports/tax-summary?from=2026-05-31", &resp)
	require.Equal(t, http.StatusOK, r.StatusCode)
	require.Len(t, resp.Buckets, 1)
	assert.Equal(t, "std", resp.Buckets[0].TaxCategory)
}

func TestReports_Stores_HappyPath(t *testing.T) {
	h := newReportsServer(t)
	occ := time.Date(2026, 5, 31, 10, 0, 0, 0, time.UTC)
	h.seedSale(occ, "store-A", 10, 1, 11)
	h.seedSale(occ, "store-B", 20, 2, 22)
	h.drain()

	var resp struct {
		Stores []reports.StoreSummary `json:"stores"`
	}
	r := h.get("/v1/reports/stores", &resp)
	require.Equal(t, http.StatusOK, r.StatusCode)
	require.Len(t, resp.Stores, 2)
	assert.Equal(t, "store-A", resp.Stores[0].StoreID)
	assert.Equal(t, "store-B", resp.Stores[1].StoreID)
}

func TestReports_Stores_EmptyWhenNoActivity(t *testing.T) {
	h := newReportsServer(t)
	var resp struct {
		Stores []reports.StoreSummary `json:"stores"`
	}
	r := h.get("/v1/reports/stores", &resp)
	require.Equal(t, http.StatusOK, r.StatusCode)
	assert.Empty(t, resp.Stores)
}

func TestReports_BadDate_400(t *testing.T) {
	h := newReportsServer(t)
	r := h.get("/v1/reports/sales-summary?from=not-a-date", nil)
	assert.Equal(t, http.StatusBadRequest, r.StatusCode)
}

func TestReports_MissingFrom_400(t *testing.T) {
	h := newReportsServer(t)
	r := h.get("/v1/reports/sales-summary", nil)
	assert.Equal(t, http.StatusBadRequest, r.StatusCode)
}

func TestReports_BadPeriod_400(t *testing.T) {
	h := newReportsServer(t)
	r := h.get("/v1/reports/sales-summary?from=2026-05-31&period=year", nil)
	assert.Equal(t, http.StatusBadRequest, r.StatusCode)
}

func TestReports_WrongMethod_405(t *testing.T) {
	h := newReportsServer(t)
	resp, err := http.Post(h.srv.URL+"/v1/reports/sales-summary", "application/json", nil)
	require.NoError(t, err)
	_ = resp.Body.Close()
	assert.Equal(t, http.StatusMethodNotAllowed, resp.StatusCode)
}

// --- Owner-role gate composition ---

func TestReports_RoleGate_CashierGetsForbidden(t *testing.T) {
	logger := slog.New(slog.NewTextHandler(io.Discard, nil))
	require := require.New(t)

	// Build the JWT-on stack — exactly how server.New composes it.
	requireJWT := auth.RequireJWT(stubVerifier(t), logger)
	requireOwner := auth.RequireRole(auth.RoleOwner, true, logger)
	final := requireJWT(requireOwner(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusOK)
	})))
	srv := httptest.NewServer(final)
	t.Cleanup(srv.Close)

	// Cashier token (no owner role) → 403.
	cashierTok := mintTok(t, []string{"cashier"})
	req, _ := http.NewRequest(http.MethodGet, srv.URL+"/", nil)
	req.Header.Set("Authorization", "Bearer "+cashierTok)
	resp, err := http.DefaultClient.Do(req)
	require.NoError(err)
	_ = resp.Body.Close()
	assert.Equal(t, http.StatusForbidden, resp.StatusCode)

	// Owner token → 200.
	ownerTok := mintTok(t, []string{auth.RoleOwner})
	req, _ = http.NewRequest(http.MethodGet, srv.URL+"/", nil)
	req.Header.Set("Authorization", "Bearer "+ownerTok)
	resp, err = http.DefaultClient.Do(req)
	require.NoError(err)
	_ = resp.Body.Close()
	assert.Equal(t, http.StatusOK, resp.StatusCode)
}
