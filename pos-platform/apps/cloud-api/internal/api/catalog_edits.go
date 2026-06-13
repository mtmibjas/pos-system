// Catalog edit endpoints — slice 6.6 (see docs/catalog-editing-design.md).
//
//	POST /v1/admin/catalog/edits      — owner appends an intent
//	GET  /v1/admin/catalog/edits      — owner lists recent intents + acks
//	GET  /v1/sync/catalog-edits       — store pulls intents after a cursor
//	POST /v1/sync/catalog-edits/ack   — store reports per-edit verdicts
package api

import (
	"encoding/json"
	"log/slog"
	"net/http"
	"strconv"
	"strings"

	"github.com/google/uuid"

	"github.com/mibjas/pos-platform/apps/cloud-api/internal/auth"
	"github.com/mibjas/pos-platform/apps/cloud-api/internal/catalog"
)

// ---- payload shapes (validated here; opaque to the catalog store) ----

type moneyJSON struct {
	CurrencyCode string `json:"currency_code"`
	Units        int64  `json:"units"`
	Nanos        int32  `json:"nanos"`
}

type itemPayload struct {
	SKU           string    `json:"sku"`
	Name          string    `json:"name"`
	Price         moneyJSON `json:"price"`
	TaxCategoryID string    `json:"tax_category_id,omitempty"`
	Archived      bool      `json:"archived"`
}

type taxCategoryPayload struct {
	ID               string `json:"id"`
	Name             string `json:"name"`
	PriceIncludesTax bool   `json:"price_includes_tax"`
	Archived         bool   `json:"archived"`
}

func validateEdit(kind string, payload json.RawMessage) string {
	switch kind {
	case catalog.KindUpsertItem:
		var p itemPayload
		if err := json.Unmarshal(payload, &p); err != nil {
			return "malformed item payload"
		}
		switch {
		case p.SKU == "":
			return "item sku is required"
		case p.Name == "":
			return "item name is required"
		case p.Price.CurrencyCode == "":
			return "item price currency_code is required"
		case p.Price.Units < 0 || p.Price.Nanos < 0:
			return "item price must not be negative"
		}
	case catalog.KindUpsertTaxCategory:
		var p taxCategoryPayload
		if err := json.Unmarshal(payload, &p); err != nil {
			return "malformed tax category payload"
		}
		switch {
		case p.ID == "":
			return "tax category id is required"
		case p.Name == "":
			return "tax category name is required"
		}
	default:
		return "unknown kind"
	}
	return ""
}

// ---- owner side ----

// AdminCatalogEditsHandler serves /v1/admin/catalog/edits. Mounted
// behind RequireJWT + RequireRole(owner).
type AdminCatalogEditsHandler struct {
	store  *catalog.Store
	logger *slog.Logger
}

func NewAdminCatalogEditsHandler(store *catalog.Store, logger *slog.Logger) *AdminCatalogEditsHandler {
	return &AdminCatalogEditsHandler{store: store, logger: logger}
}

type createEditRequest struct {
	Kind    string          `json:"kind"`
	Payload json.RawMessage `json:"payload"`
}

func (h *AdminCatalogEditsHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.FromContext(r.Context())
	if !ok {
		writeJSONStatus(w, http.StatusUnauthorized, errorResponse{Error: "missing claims"})
		return
	}
	switch r.Method {
	case http.MethodGet:
		edits, err := h.store.RecentEditsWithAcks(r.Context(), claims.TenantID, 50)
		if err != nil {
			h.logger.Error("catalog-edits: list", "tenant", claims.TenantID, "err", err)
			writeJSONStatus(w, http.StatusInternalServerError, errorResponse{Error: "list failed"})
			return
		}
		if edits == nil {
			edits = []catalog.EditWithAcks{}
		}
		writeJSONStatus(w, http.StatusOK, map[string]any{"edits": edits})
	case http.MethodPost:
		defer r.Body.Close()
		var req createEditRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			writeJSONStatus(w, http.StatusBadRequest, errorResponse{Error: "malformed request body"})
			return
		}
		if msg := validateEdit(req.Kind, req.Payload); msg != "" {
			writeJSONStatus(w, http.StatusBadRequest, errorResponse{Error: msg})
			return
		}
		editID := uuid.NewString()
		seq, err := h.store.AppendEdit(r.Context(), claims.TenantID, editID, req.Kind, req.Payload, claims.Subject)
		if err != nil {
			h.logger.Error("catalog-edits: append", "tenant", claims.TenantID, "err", err)
			writeJSONStatus(w, http.StatusInternalServerError, errorResponse{Error: "append failed"})
			return
		}
		h.logger.Info("catalog-edits: appended",
			"tenant", claims.TenantID, "seq", seq, "kind", req.Kind, "by", claims.Subject)
		writeJSONStatus(w, http.StatusCreated, map[string]any{"seq": seq, "edit_id": editID})
	default:
		writeJSONStatus(w, http.StatusMethodNotAllowed, errorResponse{Error: "method not allowed"})
	}
}

// ---- store side ----

// SyncCatalogEditsHandler serves /v1/sync/catalog-edits (pull) and
// /v1/sync/catalog-edits/ack. Mounted behind RequireJWT only — store
// tokens have no owner role. Tenant always from claims.
type SyncCatalogEditsHandler struct {
	store  *catalog.Store
	logger *slog.Logger
}

func NewSyncCatalogEditsHandler(store *catalog.Store, logger *slog.Logger) *SyncCatalogEditsHandler {
	return &SyncCatalogEditsHandler{store: store, logger: logger}
}

type ackRequest struct {
	NodeID string `json:"node_id"`
	Acks   []struct {
		Seq    int64  `json:"seq"`
		Status string `json:"status"`
		Detail string `json:"detail"`
	} `json:"acks"`
}

func (h *SyncCatalogEditsHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	claims, ok := auth.FromContext(r.Context())
	if !ok {
		writeJSONStatus(w, http.StatusUnauthorized, errorResponse{Error: "missing claims"})
		return
	}
	isAck := strings.HasSuffix(strings.TrimRight(r.URL.Path, "/"), "/ack")
	switch {
	case !isAck && r.Method == http.MethodGet:
		after, _ := strconv.ParseInt(r.URL.Query().Get("after"), 10, 64)
		edits, err := h.store.EditsAfter(r.Context(), claims.TenantID, after, 100)
		if err != nil {
			h.logger.Error("catalog-edits: pull", "tenant", claims.TenantID, "err", err)
			writeJSONStatus(w, http.StatusInternalServerError, errorResponse{Error: "pull failed"})
			return
		}
		if edits == nil {
			edits = []catalog.Edit{}
		}
		writeJSONStatus(w, http.StatusOK, map[string]any{"edits": edits})
	case isAck && r.Method == http.MethodPost:
		defer r.Body.Close()
		var req ackRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			writeJSONStatus(w, http.StatusBadRequest, errorResponse{Error: "malformed request body"})
			return
		}
		if req.NodeID == "" {
			writeJSONStatus(w, http.StatusBadRequest, errorResponse{Error: "node_id is required"})
			return
		}
		for _, a := range req.Acks {
			if err := h.store.RecordAck(r.Context(), claims.TenantID, req.NodeID, a.Seq, a.Status, a.Detail); err != nil {
				h.logger.Error("catalog-edits: ack", "tenant", claims.TenantID, "node", req.NodeID, "seq", a.Seq, "err", err)
				writeJSONStatus(w, http.StatusBadRequest, errorResponse{Error: err.Error()})
				return
			}
		}
		w.WriteHeader(http.StatusNoContent)
	default:
		writeJSONStatus(w, http.StatusMethodNotAllowed, errorResponse{Error: "method not allowed"})
	}
}
