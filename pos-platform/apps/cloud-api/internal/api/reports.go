package api

import (
	"encoding/json"
	"errors"
	"log/slog"
	"net/http"

	"github.com/mibjas/pos-platform/apps/cloud-api/internal/auth"
	"github.com/mibjas/pos-platform/apps/cloud-api/internal/reports"
)

// ReportsHandler serves the slice-5.3 sales / tax aggregate endpoints.
// All three routes share the same auth/tenant/store-scoping logic, so
// they live on one handler that picks behaviour per URL path.
//
// Routes (registered in internal/server):
//   GET /v1/reports/sales-summary?from=&to=&store_id=&period=
//   GET /v1/reports/sales-by-method?from=&to=&store_id=
//   GET /v1/reports/tax-summary?from=&to=&store_id=&period=
type ReportsHandler struct {
	store    *reports.Store
	verifier *auth.Verifier // nil → X-Tenant header path (same convention as EventsHandler)
	logger   *slog.Logger
}

func NewReportsHandler(store *reports.Store, verifier *auth.Verifier, logger *slog.Logger) *ReportsHandler {
	return &ReportsHandler{store: store, verifier: verifier, logger: logger}
}

// SalesSummary serves GET /v1/reports/sales-summary.
func (h *ReportsHandler) SalesSummary(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	tenant, rng, storeID, period, ok := h.commonParams(w, r, true)
	if !ok {
		return
	}
	buckets, err := h.store.SalesSummary(r.Context(), tenant, rng, storeID, period)
	if err != nil {
		h.logger.Error("reports: sales-summary", "tenant", tenant, "err", err)
		http.Error(w, "sales-summary", http.StatusInternalServerError)
		return
	}
	writeJSON(w, map[string]any{"buckets": buckets})
}

// SalesByMethod serves GET /v1/reports/sales-by-method.
func (h *ReportsHandler) SalesByMethod(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	tenant, rng, storeID, _, ok := h.commonParams(w, r, false)
	if !ok {
		return
	}
	buckets, err := h.store.SalesByMethod(r.Context(), tenant, rng, storeID)
	if err != nil {
		h.logger.Error("reports: sales-by-method", "tenant", tenant, "err", err)
		http.Error(w, "sales-by-method", http.StatusInternalServerError)
		return
	}
	writeJSON(w, map[string]any{"buckets": buckets})
}

// Stores serves GET /v1/reports/stores. No date range / period — it
// returns every store with any GL activity (capped server-side).
func (h *ReportsHandler) Stores(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	tenant, err := h.resolveTenant(r)
	if err != nil {
		status, isAuth := auth.IsAuthError(err)
		if !isAuth {
			status = http.StatusBadRequest
		}
		http.Error(w, err.Error(), status)
		return
	}
	stores, err := h.store.ListStores(r.Context(), tenant)
	if err != nil {
		h.logger.Error("reports: stores", "tenant", tenant, "err", err)
		http.Error(w, "stores", http.StatusInternalServerError)
		return
	}
	writeJSON(w, map[string]any{"stores": stores})
}

// TaxSummary serves GET /v1/reports/tax-summary.
func (h *ReportsHandler) TaxSummary(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	tenant, rng, storeID, period, ok := h.commonParams(w, r, true)
	if !ok {
		return
	}
	buckets, err := h.store.TaxSummary(r.Context(), tenant, rng, storeID, period)
	if err != nil {
		h.logger.Error("reports: tax-summary", "tenant", tenant, "err", err)
		http.Error(w, "tax-summary", http.StatusInternalServerError)
		return
	}
	writeJSON(w, map[string]any{"buckets": buckets})
}

// commonParams parses & validates the shared query string. acceptPeriod
// controls whether `?period=` is recognised — sales-by-method is always
// daily so its endpoint ignores period to keep the contract crisp.
//
// On failure writes the error response and returns ok=false.
func (h *ReportsHandler) commonParams(w http.ResponseWriter, r *http.Request, acceptPeriod bool) (
	tenant string, rng reports.Range, storeID string, period reports.Period, ok bool,
) {
	tenant, err := h.resolveTenant(r)
	if err != nil {
		status, isAuth := auth.IsAuthError(err)
		if !isAuth {
			status = http.StatusBadRequest
		}
		http.Error(w, err.Error(), status)
		return "", reports.Range{}, "", "", false
	}
	q := r.URL.Query()
	rng, err = reports.ParseDateRange(q.Get("from"), q.Get("to"))
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return "", reports.Range{}, "", "", false
	}
	storeID = q.Get("store_id") // "" → all stores in tenant
	if acceptPeriod {
		period, err = reports.ParsePeriod(q.Get("period"))
		if err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return "", reports.Range{}, "", "", false
		}
	}
	return tenant, rng, storeID, period, true
}

// resolveTenant mirrors EventsHandler's logic so the auth contract is
// identical across read-side endpoints: JWT claim when auth is on,
// X-Tenant header in --insecure-no-auth mode.
func (h *ReportsHandler) resolveTenant(r *http.Request) (string, error) {
	if h.verifier != nil {
		claims, ok := auth.FromContext(r.Context())
		if !ok {
			return "", auth.ErrMissingToken
		}
		return claims.TenantID, nil
	}
	t := r.Header.Get("X-Tenant")
	if t == "" {
		return "", errors.New("X-Tenant header is required in insecure-no-auth mode")
	}
	return t, nil
}

func writeJSON(w http.ResponseWriter, v any) {
	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(v); err != nil {
		// Headers already written; nothing we can do but bail.
		_ = err
	}
}
