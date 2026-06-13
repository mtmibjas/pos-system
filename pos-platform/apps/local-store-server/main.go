// Package main is the entry point for the Local Store Server.
//
// Responsibilities (see docs/architecture.md and Development Guide §7):
//   - Local inventory ownership (append-only ledger)
//   - Local transaction processing (sales, payments, refunds)
//   - WebSocket real-time updates to multi-counter POS clients
//   - Receipt generation
//   - Local sync queue (operations_log)
//   - Offline-first operation (never blocks sales)
//   - Counter synchronization within the LAN
//
// Discovery: serves on POS_LISTEN_ADDR (default 127.0.0.1:8081) over
// HTTP/Connect; advertises via mDNS on the LAN (mDNS deferred to Phase 2).
//
// Current scope: Phase 2 Slice 5 — opens the local SQLite DB, applies
// migrations, wires the data-access stores, boots a durable Lamport clock,
// starts the sync engine (worker → batcher → HTTP transport), and exposes
// the SaleService / RefundService / TaxAdminService Connect-RPC endpoints
// on the loopback socket for the desktop client.
package main

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/mibjas/pos-platform/apps/local-store-server/internal/api"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/catalogsync"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/clock"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/db"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/hub"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/inventory"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/invoices"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/items"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/opslog"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/payments"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/refunds"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/reservations"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/sales"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/sync"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/syncstate"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/tax"
)

func main() {
	logger := slog.New(slog.NewTextHandler(os.Stdout, nil))
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	dbPath := envOr("POS_LOCAL_DB", "pos-local.db")
	cloudURL := envOr("POS_CLOUD_URL", "http://localhost:8080")
	tenantID := envOr("POS_TENANT_ID", "tenant-A")
	nodeID := envOr("POS_NODE_ID", "node-local")
	storeTZName := envOr("POS_STORE_TZ", "UTC")
	voidWindowStr := envOr("POS_VOID_WINDOW", "12h")
	listenAddr := envOr("POS_LISTEN_ADDR", "127.0.0.1:8081")

	storeTZ, err := time.LoadLocation(storeTZName)
	if err != nil {
		logger.Error("load store timezone", "err", err, "tz", storeTZName)
		os.Exit(1)
	}
	voidWindow, err := time.ParseDuration(voidWindowStr)
	if err != nil {
		logger.Error("parse void window", "err", err, "value", voidWindowStr)
		os.Exit(1)
	}

	sqlDB, err := db.Open(ctx, db.Config{Path: dbPath})
	if err != nil {
		logger.Error("open db", "err", err, "path", dbPath)
		os.Exit(1)
	}
	defer func() { _ = sqlDB.Close() }()

	if err := db.RunMigrations(sqlDB); err != nil {
		logger.Error("migrate", "err", err)
		os.Exit(1)
	}

	// Data-access layer.
	ops := opslog.NewStore(sqlDB)
	inv := inventory.NewStore(sqlDB, nil) // nil = never allow oversell (safe default)
	pays := payments.NewStore(sqlDB)
	invs := invoices.NewStore(sqlDB, storeTZ)
	taxStore := tax.NewStore(sqlDB)
	taxEng := tax.NewEngine(taxStore)
	itemStore := items.NewStore(sqlDB, taxStore)
	refStore := refunds.NewStore(sqlDB, storeTZ)
	syn := syncstate.NewStore(sqlDB)
	clk, err := clock.New(ctx, syn)
	if err != nil {
		logger.Error("init lamport clock", "err", err)
		os.Exit(1)
	}
	// Sync engine.
	transport := sync.NewHTTPTransport(cloudURL)
	// JWT auth (slice 3.5). Symmetric secret matches cloud-api's JWT_SECRET.
	// When unset, the worker pushes batches without an Authorization
	// header — fine while running against a cloud-api booted with
	// --insecure-no-auth or the test stub; in production the cloud
	// will reject those with 401.
	if secret := os.Getenv("SYNC_JWT_SECRET"); secret != "" {
		ts, err := sync.NewTokenSource(sync.TokenSourceOpts{
			Secret:  secret,
			Tenant:  tenantID,
			Subject: "local-store-server",
			Issuer:  "local-store-server",
		})
		if err != nil {
			logger.Error("init sync token source", "err", err)
			os.Exit(1)
		}
		transport.AuthHeaderFunc = ts.AuthHeader
	} else {
		logger.Warn("SYNC_JWT_SECRET not set — sync requests will be unauthenticated")
	}
	worker := sync.NewWorker(ops, syn, transport, tenantID, sync.WorkerOpts{
		Logger: logger.With("component", "sync"),
		// Spread fleet reconnects after a cloud outage; 0–3s of jitter
		// per worker desynchronizes the first drain without noticeably
		// delaying anyone's catch-up on a healthy boot.
		StartupJitter: 3 * time.Second,
	})

	// Multi-counter realtime hub (Phase 4 slice 4.1). Sales and refunds
	// publish to it post-commit (slice 4.2); the WS endpoint fans out to
	// every connected counter. Soft reservations land in slice 4.3.
	eventHub := hub.New()
	eventsHandler := api.NewEventsStreamHandler(eventHub, ops, logger.With("component", "ws"))

	// Soft inventory reservations (Phase 4 slice 4.3). Intra-store only;
	// publishes inventory_available_changed JSON frames over the hub so
	// other counters' live tiles refresh as carts come and go.
	reservationStore := reservations.NewStore(sqlDB)
	reservationSvc, err := reservations.NewService(reservations.Config{
		DB:        sqlDB,
		Store:     reservationStore,
		Inv:       inv,
		Publisher: eventHub,
	})
	if err != nil {
		logger.Error("init reservation service", "err", err)
		os.Exit(1)
	}

	// Sale producer — uses the worker as its Notifier so committed sales
	// wake the sync loop within milliseconds, and the event hub as its
	// Publisher so multi-counter clients see updates in realtime.
	saleSvc, err := sales.NewService(sales.Config{
		DB:           sqlDB,
		Ops:          ops,
		Inv:          inv,
		Pays:         pays,
		Invoices:     invs,
		Tax:          taxEng,
		Clock:        clk,
		Notifier:     worker,
		Publisher:    eventHub,
		Reservations: reservationSvc,
		NodeID:       nodeID,
		TenantID:     tenantID,
	})
	if err != nil {
		logger.Error("init sale service", "err", err)
		os.Exit(1)
	}

	// Refund/void producer — shares the worker as Notifier so committed
	// reversals also wake the sync loop immediately.
	refundSvc, err := refunds.NewService(refunds.Config{
		DB:         sqlDB,
		Ops:        ops,
		Inv:        inv,
		Pays:       pays,
		Invoices:   invs,
		Refunds:    refStore,
		Tax:        taxEng,
		Clock:      clk,
		Notifier:   worker,
		Publisher:  eventHub,
		NodeID:     nodeID,
		TenantID:   tenantID,
		VoidWindow: voidWindow,
	})
	if err != nil {
		logger.Error("init refund service", "err", err)
		os.Exit(1)
	}

	// Connect-RPC API surface. Mounted on a loopback socket so the local
	// desktop client (Phase 2 Dart codegen) can call SaleService /
	// RefundService / TaxAdminService over HTTP/Connect without going
	// through the cloud.
	mux := api.NewMux(
		api.NewSaleHandler(saleSvc, invs, pays),
		api.NewRefundHandler(refundSvc),
		api.NewTaxAdminHandler(taxStore, tenantID),
		api.NewItemHandler(itemStore, tenantID),
		api.NewInventoryHandler(inv, itemStore, tenantID),
		api.NewReservationHandler(reservationSvc),
		eventsHandler,
	)
	api.MountReadyz(mux, func(probeCtx context.Context) error {
		c, cancel := context.WithTimeout(probeCtx, 2*time.Second)
		defer cancel()
		return sqlDB.PingContext(c)
	})
	// Request-ID middleware wraps the mux before h2c so the correlation
	// header propagates across both HTTP/1.1 and h2c upgrades. Access log
	// goes through logger.With("component", "http") so it's filterable.
	wrapped := api.RequestIDMiddleware(logger.With("component", "http"))(mux)
	httpSrv := &http.Server{
		Addr:              listenAddr,
		Handler:           api.H2CHandler(wrapped),
		ReadHeaderTimeout: 5 * time.Second,
	}

	logger.Info("local-store-server ready",
		"db_path", dbPath,
		"cloud_url", cloudURL,
		"tenant", tenantID,
		"node", nodeID,
		"store_tz", storeTZ.String(),
		"void_window", voidWindow.String(),
		"listen_addr", listenAddr,
		"slice", "phase-2.5",
		"lamport_next", clk.Peek(),
	)

	// Start HTTP server. ListenAndServe returns ErrServerClosed on graceful
	// Shutdown — only non-Closed errors should terminate the process.
	httpErrCh := make(chan error, 1)
	go func() {
		if err := httpSrv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			httpErrCh <- err
		}
		close(httpErrCh)
	}()

	// Start sync worker in parallel; both run until ctx cancels (SIGINT /
	// SIGTERM) or one of them errors out.
	workerErrCh := make(chan error, 1)
	go func() {
		workerErrCh <- worker.Run(ctx)
	}()

	// Catalog snapshot mirror (slice 6.5): pushes items + tax categories
	// to cloud-api for the web dashboard's read-only catalog view.
	// Shares the sync transport's auth header source; failures are
	// logged and retried next tick — never fatal (offline-first).
	catUploader := &catalogsync.Uploader{
		DB:             sqlDB,
		CloudURL:       cloudURL,
		TenantID:       tenantID,
		NodeID:         nodeID,
		AuthHeaderFunc: transport.AuthHeaderFunc,
		Logger:         logger.With("component", "catalogsync"),
	}
	go catUploader.Run(ctx)

	// Downstream half (slice 6.6): pull catalog edit intents from the
	// dashboard, apply locally, ack. After an apply, push a fresh
	// snapshot immediately so the dashboard converges in seconds.
	catApplier := &catalogsync.Applier{
		DB:             sqlDB,
		CloudURL:       cloudURL,
		TenantID:       tenantID,
		NodeID:         nodeID,
		AuthHeaderFunc: transport.AuthHeaderFunc,
		Logger:         logger.With("component", "catalogsync"),
		OnApplied: func(ctx context.Context) {
			if err := catUploader.UploadOnce(ctx); err != nil {
				logger.Warn("catalogsync: post-apply snapshot failed", "err", err)
			}
		},
	}
	go catApplier.Run(ctx)

	// Wait for first terminating signal.
	select {
	case <-ctx.Done():
		logger.Info("shutdown signal received")
	case err := <-httpErrCh:
		if err != nil {
			logger.Error("http server exited", "err", err)
			stop()
		}
	case err := <-workerErrCh:
		if err != nil {
			logger.Error("sync worker exited", "err", err)
		}
		stop()
	}

	// Graceful shutdown of HTTP server with a hard timeout so we never
	// hang on a stuck connection during operator-driven restart.
	shutdownCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := httpSrv.Shutdown(shutdownCtx); err != nil {
		logger.Warn("http server shutdown", "err", err)
	}

	// Drain remaining channels so worker / http goroutines exit cleanly
	// before main returns.
	<-httpErrCh
	if err := <-workerErrCh; err != nil && !errors.Is(err, context.Canceled) {
		logger.Error("sync worker error on exit", "err", err)
		os.Exit(1)
	}
	logger.Info("local-store-server shutdown")
}

func envOr(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}
