// Package server wires the cloud-api HTTP surface. It exists so that
// integration tests (and slice 3.6's chaos suite) can mount the exact
// production handler stack — auth middleware, batches handler, events
// handler — without re-implementing routing in test fixtures.
//
// main.go is now a thin wire-up: parse flags, open DB, call New, listen.
package server

import (
	"context"
	"errors"
	"io"
	"log/slog"
	"net/http"

	"google.golang.org/protobuf/proto"

	"github.com/mibjas/pos-platform/apps/cloud-api/internal/api"
	"github.com/mibjas/pos-platform/apps/cloud-api/internal/auth"
	"github.com/mibjas/pos-platform/apps/cloud-api/internal/ingest"
	"github.com/mibjas/pos-platform/apps/cloud-api/internal/reports"
	posv1 "github.com/mibjas/pos-platform/packages/sdk-go/gen/pos/v1"
)

// Route constants are exported so test fixtures and clients can refer
// to them by name instead of duplicating the literal.
const (
	PathSyncBatches        = "/v1/sync/batches"
	PathSyncEvents         = "/v1/sync/events"
	PathReportsSalesSummary = "/v1/reports/sales-summary"
	PathReportsSalesByMethod = "/v1/reports/sales-by-method"
	PathReportsTaxSummary   = "/v1/reports/tax-summary"
	PathReportsStores       = "/v1/reports/stores"
	PathHealthz             = "/healthz"
	PathReadyz              = "/readyz"
	PathAuthLogin           = "/v1/auth/login"
	PathAdminUsers          = "/v1/admin/users"
	PathSyncCatalog         = "/v1/sync/catalog"
	PathAdminCatalog        = "/v1/admin/catalog"
	PathSyncCatalogEdits    = "/v1/sync/catalog-edits"
	PathAdminCatalogEdits   = "/v1/admin/catalog/edits"
	PathPlatformTenants     = "/v1/platform/tenants"
	ContentTypeProto        = "application/x-protobuf"

	// HeaderForce lets the local-store-server's transport-layer tests
	// drive specific ack paths deterministically. Honored regardless of
	// auth state; ignored in production traffic because no real client
	// sets it.
	HeaderForce = "X-Test-Force"
)

// Server is the cloud-api HTTP handler set. It owns the mux but not the
// DB — wiring (open/migrate) is the caller's job so the same Server can
// front a Postgres pool in a later phase without changing this code.
type Server struct {
	store    *ingest.Store
	verifier *auth.Verifier // nil → no auth (tests / --insecure-no-auth)
	logger   *slog.Logger
	mux      *http.ServeMux

	// handler is mux wrapped with cross-cutting middleware (request ID,
	// access log). Built once in New so ServeHTTP doesn't allocate per
	// request.
	handler http.Handler

	// readyCheck, when set, gates /readyz. Returning nil = 200, otherwise
	// 503 with the error in the body. nil → /readyz is a stub-200 (test
	// mode), which is fine because tests don't probe readiness.
	readyCheck func(context.Context) error

	// loginHandler, when set, is mounted at /v1/auth/login. Unauth.
	loginHandler http.Handler

	// adminUsersHandler, when set, is mounted at /v1/admin/users (and
	// the /{username} subtree) behind RequireJWT + RequireRole(owner).
	adminUsersHandler http.Handler

	// catalogUploadHandler / adminCatalogHandler — slice 6.5. Upload is
	// JWT-only (store nodes), read is owner-gated (dashboard).
	catalogUploadHandler http.Handler
	adminCatalogHandler  http.Handler

	// Slice 6.6: catalog edit intents. Admin side appends/lists
	// (owner-gated); sync side pulls/acks (JWT-only).
	adminCatalogEditsHandler http.Handler
	syncCatalogEditsHandler  http.Handler

	// Slice 6.7: platform-admin tenant management (platform_admin role).
	platformTenantsHandler http.Handler

	// tenantGate (slice 6.7), when set, runs in handleBatches after the
	// JWT tenant pin. Non-nil error → batch rejected with 403. Wired to
	// tenants.Store.CheckActive so suspended tenants stop ingesting.
	tenantGate func(ctx context.Context, tenantID string) error
}

// Option tweaks a Server post-construction. Variadic so existing callers
// don't need to thread arguments they don't care about (tests).
type Option func(*Server)

// WithReadyCheck wires /readyz to the given probe. Typical use: pass a
// closure that pings the DB. A nil probe means "always ready".
func WithReadyCheck(fn func(context.Context) error) Option {
	return func(s *Server) { s.readyCheck = fn }
}

// WithLogin mounts POST /v1/auth/login backed by the given handler. The
// route is unauthenticated (it's the door). Omit this option in test
// fixtures that don't need login.
func WithLogin(h http.Handler) Option {
	return func(s *Server) { s.loginHandler = h }
}

// WithAdminUsers mounts the user-management API at /v1/admin/users,
// owner-role-gated. Omit in fixtures that don't exercise admin.
func WithAdminUsers(h http.Handler) Option {
	return func(s *Server) { s.adminUsersHandler = h }
}

// WithCatalog mounts the snapshot upload (PUT /v1/sync/catalog, JWT)
// and the dashboard read (GET /v1/admin/catalog, owner-gated).
func WithCatalog(upload, adminRead http.Handler) Option {
	return func(s *Server) {
		s.catalogUploadHandler = upload
		s.adminCatalogHandler = adminRead
	}
}

// WithCatalogEdits mounts the 6.6 edit-intent queue: admin append/list
// (owner-gated) and store pull/ack (JWT-gated).
func WithCatalogEdits(admin, syncSide http.Handler) Option {
	return func(s *Server) {
		s.adminCatalogEditsHandler = admin
		s.syncCatalogEditsHandler = syncSide
	}
}

// WithPlatformAdmin mounts /v1/platform/tenants (and subtree) behind
// RequireRole(platform_admin).
func WithPlatformAdmin(h http.Handler) Option {
	return func(s *Server) { s.platformTenantsHandler = h }
}

// WithTenantGate rejects sync batches from suspended tenants.
func WithTenantGate(fn func(ctx context.Context, tenantID string) error) Option {
	return func(s *Server) { s.tenantGate = fn }
}

// New wires the routes. Pass a nil verifier for --insecure-no-auth /
// test mode; that path is loud-logged at the call site (main.go).
// reportStore is the read-only aggregate store (slice 5.3). Pass nil
// to skip mounting the /v1/reports/* routes — useful in older tests
// that don't care about reports.
func New(logger *slog.Logger, store *ingest.Store, verifier *auth.Verifier, reportStore *reports.Store, opts ...Option) *Server {
	s := &Server{
		store:    store,
		verifier: verifier,
		logger:   logger,
		mux:      http.NewServeMux(),
	}
	for _, o := range opts {
		o(s)
	}
	// /healthz stays open (load balancers, monitors). Liveness only — a
	// 200 here does NOT imply the DB is reachable. Use /readyz for that.
	s.mux.HandleFunc(PathHealthz, func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ok"))
	})
	// /readyz: probes the DB (and, in future, any other hard dep). 503 on
	// failure so a smart load balancer / supervisor can keep traffic off
	// during transient outages. Unauthed on purpose — operators must be
	// able to debug a broken process without a token.
	s.mux.HandleFunc(PathReadyz, func(w http.ResponseWriter, r *http.Request) {
		if s.readyCheck == nil {
			w.WriteHeader(http.StatusOK)
			_, _ = w.Write([]byte("ready"))
			return
		}
		if err := s.readyCheck(r.Context()); err != nil {
			w.WriteHeader(http.StatusServiceUnavailable)
			_, _ = w.Write([]byte("not ready: " + err.Error()))
			return
		}
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ready"))
	})
	// /v1/sync/batches sits behind the JWT middleware. Wrapping at the
	// route level keeps /healthz unauthed and lets future endpoints opt
	// in individually.
	requireJWT := auth.RequireJWT(verifier, logger)
	s.mux.Handle(PathSyncBatches, requireJWT(http.HandlerFunc(s.handleBatches)))
	// /v1/sync/events — read-side cursor stream, same auth requirement.
	events := api.NewEventsHandler(store, verifier, logger)
	s.mux.Handle(PathSyncEvents, requireJWT(events))

	// /v1/reports/* — Phase 5 slice 5.3. Owner-only: cashier tokens see
	// 403. RequireRole composes after RequireJWT (which populates the
	// claims ctx); authRequired flag mirrors verifier!=nil so test mode
	// (no verifier) bypasses the role gate as well.
	if reportStore != nil {
		rep := api.NewReportsHandler(reportStore, verifier, logger)
		requireOwner := auth.RequireRole(auth.RoleOwner, verifier != nil, logger)
		ownerOnly := func(h http.Handler) http.Handler {
			return requireJWT(requireOwner(h))
		}
		s.mux.Handle(PathReportsSalesSummary, ownerOnly(http.HandlerFunc(rep.SalesSummary)))
		s.mux.Handle(PathReportsSalesByMethod, ownerOnly(http.HandlerFunc(rep.SalesByMethod)))
		s.mux.Handle(PathReportsTaxSummary, ownerOnly(http.HandlerFunc(rep.TaxSummary)))
		s.mux.Handle(PathReportsStores, ownerOnly(http.HandlerFunc(rep.Stores)))
	}
	// Login route — explicitly unauth; mount only when wired by main.go
	// so test fixtures that don't need login can omit it.
	if s.loginHandler != nil {
		s.mux.Handle(PathAuthLogin, s.loginHandler)
	}
	// Admin user management — owner-only, same gate as reports. Mounted
	// on both the bare path (list/create) and the trailing-slash subtree
	// (PATCH /{username}); the handler routes internally.
	if s.adminUsersHandler != nil {
		requireOwner := auth.RequireRole(auth.RoleOwner, verifier != nil, logger)
		gated := requireJWT(requireOwner(s.adminUsersHandler))
		s.mux.Handle(PathAdminUsers, gated)
		s.mux.Handle(PathAdminUsers+"/", gated)
	}
	// Catalog snapshots — slice 6.5. Upload uses the same auth posture
	// as /v1/sync/batches (JWT, tenant pinned in-handler); the admin
	// read shares the owner gate with reports.
	if s.catalogUploadHandler != nil {
		s.mux.Handle(PathSyncCatalog, requireJWT(s.catalogUploadHandler))
	}
	if s.adminCatalogHandler != nil {
		requireOwner := auth.RequireRole(auth.RoleOwner, verifier != nil, logger)
		s.mux.Handle(PathAdminCatalog, requireJWT(requireOwner(s.adminCatalogHandler)))
	}
	// Catalog edit intents — slice 6.6. NOTE: /v1/admin/catalog/edits is
	// registered before the bare /v1/admin/catalog above only in path
	// specificity terms; ServeMux picks the longer pattern, so both
	// coexist.
	if s.adminCatalogEditsHandler != nil {
		requireOwner := auth.RequireRole(auth.RoleOwner, verifier != nil, logger)
		s.mux.Handle(PathAdminCatalogEdits, requireJWT(requireOwner(s.adminCatalogEditsHandler)))
	}
	if s.syncCatalogEditsHandler != nil {
		s.mux.Handle(PathSyncCatalogEdits, requireJWT(s.syncCatalogEditsHandler))
		s.mux.Handle(PathSyncCatalogEdits+"/", requireJWT(s.syncCatalogEditsHandler))
	}
	// Platform-admin area — slice 6.7. Cross-tenant by design; the
	// platform_admin role is the entire authorization story here.
	if s.platformTenantsHandler != nil {
		requirePlatform := auth.RequireRole(auth.RolePlatformAdmin, verifier != nil, logger)
		gated := requireJWT(requirePlatform(s.platformTenantsHandler))
		s.mux.Handle(PathPlatformTenants, gated)
		s.mux.Handle(PathPlatformTenants+"/", gated)
	}
	// Cross-cutting middleware wraps the entire mux once at construction
	// time. Request ID is outermost so probe-skip + access-log see the ID
	// and downstream auth failures land in the same correlated log line.
	s.handler = RequestIDMiddleware(logger)(s.mux)
	return s
}

// ServeHTTP delegates to the middleware-wrapped mux so a *Server is
// itself an http.Handler.
func (s *Server) ServeHTTP(w http.ResponseWriter, r *http.Request) { s.handler.ServeHTTP(w, r) }

func (s *Server) handleBatches(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	body, err := io.ReadAll(r.Body)
	if err != nil {
		http.Error(w, "read body: "+err.Error(), http.StatusBadRequest)
		return
	}
	defer r.Body.Close()

	batch := &posv1.SyncBatch{}
	if err := proto.Unmarshal(body, batch); err != nil {
		http.Error(w, "unmarshal batch: "+err.Error(), http.StatusBadRequest)
		return
	}

	// Pin the JWT's tenant to the batch's tenant. Skipped when verifier
	// is nil (test / --insecure-no-auth mode). The local validator in
	// slice 3.2 catches cross-tenant smuggling at the envelope level —
	// this guard catches it at the auth boundary too.
	if s.verifier != nil {
		if err := auth.EnforceTenant(r.Context(), tenantOf(batch), true); err != nil {
			status, _ := auth.IsAuthError(err)
			if status == 0 {
				status = http.StatusForbidden
			}
			http.Error(w, err.Error(), status)
			return
		}
	}

	// Suspended-tenant gate (slice 6.7). After the JWT pin so the error
	// can't be used to probe tenant status without a valid token.
	if s.tenantGate != nil {
		if err := s.tenantGate(r.Context(), tenantOf(batch)); err != nil {
			s.logger.Warn("cloud-api: batch rejected, tenant gate",
				"batch_id", batch.BatchId, "tenant", tenantOf(batch), "err", err)
			http.Error(w, err.Error(), http.StatusForbidden)
			return
		}
	}

	// X-Test-Force overrides give the local-store-server transport tests
	// a deterministic way to exercise every ack branch without staging
	// real failures. They run BEFORE persistence so they don't mutate
	// the DB.
	switch r.Header.Get(HeaderForce) {
	case "500":
		http.Error(w, "forced transient", http.StatusInternalServerError)
		return
	case "400":
		http.Error(w, "forced permanent", http.StatusBadRequest)
		return
	case "rejected":
		s.writeAck(w, &posv1.SyncBatchAck{
			BatchId: batch.BatchId,
			Status:  posv1.SyncBatchAck_STATUS_REJECTED,
			Message: "forced rejection",
		})
		return
	case "retry_later":
		s.writeAck(w, &posv1.SyncBatchAck{
			BatchId: batch.BatchId,
			Status:  posv1.SyncBatchAck_STATUS_RETRY_LATER,
			Message: "forced retry_later",
		})
		return
	case "duplicate":
		s.writeAck(w, &posv1.SyncBatchAck{
			BatchId: batch.BatchId,
			Status:  posv1.SyncBatchAck_STATUS_DUPLICATE,
		})
		return
	}

	result, err := s.store.Apply(r.Context(), batch)
	if err != nil {
		switch {
		case errors.Is(err, ingest.ErrEmptyBatchID), errors.Is(err, ingest.ErrEmptyTenant):
			http.Error(w, err.Error(), http.StatusBadRequest)
		default:
			s.logger.Error("cloud-api: apply", "batch_id", batch.BatchId, "err", err)
			http.Error(w, "apply: "+err.Error(), http.StatusInternalServerError)
		}
		return
	}

	s.logger.Info("cloud-api: ack",
		"batch_id", batch.BatchId,
		"tenant", tenantOf(batch),
		"ops", len(batch.Operations),
		"status", result.Status)

	s.writeAck(w, &posv1.SyncBatchAck{
		BatchId:       batch.BatchId,
		Status:        result.Status,
		Message:       result.Message,
		OperationAcks: result.OperationAcks,
	})
}

func (s *Server) writeAck(w http.ResponseWriter, ack *posv1.SyncBatchAck) {
	body, err := proto.Marshal(ack)
	if err != nil {
		http.Error(w, "marshal ack: "+err.Error(), http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", ContentTypeProto)
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write(body)
}

func tenantOf(b *posv1.SyncBatch) string {
	if b.TenantId == nil {
		return ""
	}
	return b.TenantId.Value
}

