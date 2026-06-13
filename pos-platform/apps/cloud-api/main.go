// Package main is the entry point for the Cloud API service.
//
// Phase 3 scope: real persistence (slice 3.1), validation (3.2), JWT
// auth (3.5), read-side cursor stream (3.4). The HTTP wiring lives in
// internal/server so chaos and integration tests can mount the exact
// production handler stack instead of a parallel re-implementation.
package main

import (
	"context"
	"errors"
	"flag"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/mibjas/pos-platform/apps/cloud-api/internal/api"
	"github.com/mibjas/pos-platform/apps/cloud-api/internal/auth"
	"github.com/mibjas/pos-platform/apps/cloud-api/internal/catalog"
	"github.com/mibjas/pos-platform/apps/cloud-api/internal/db"
	"github.com/mibjas/pos-platform/apps/cloud-api/internal/ingest"
	"github.com/mibjas/pos-platform/apps/cloud-api/internal/projection"
	"github.com/mibjas/pos-platform/apps/cloud-api/internal/reports"
	"github.com/mibjas/pos-platform/apps/cloud-api/internal/server"
	"github.com/mibjas/pos-platform/apps/cloud-api/internal/tenants"
	"github.com/mibjas/pos-platform/apps/cloud-api/internal/users"
)

func main() {
	addr := flag.String("addr", ":8080", "listen address")
	dbPath := flag.String("db", "cloud.db", "SQLite database path")
	usersPath := flag.String("users", "users.yaml",
		"path to file-based user store (YAML). Omit/empty to disable /v1/auth/login.")
	tokenTTL := flag.Duration("token-ttl", 24*time.Hour,
		"lifetime of tokens minted via /v1/auth/login")
	insecureNoAuth := flag.Bool("insecure-no-auth", false,
		"disable JWT verification (DEV ONLY — never set in production)")
	flag.Parse()

	logger := slog.New(slog.NewTextHandler(os.Stdout, nil))

	// Auth setup: HS256 shared-secret from env. Fail-secure — refuse
	// to boot if the secret is missing unless --insecure-no-auth was
	// explicitly passed (loud flag intended for local dev only).
	var verifier *auth.Verifier
	if *insecureNoAuth {
		logger.Warn("cloud-api: JWT verification DISABLED (--insecure-no-auth)")
	} else {
		secret := os.Getenv("JWT_SECRET")
		v, err := auth.NewVerifier(secret)
		if err != nil {
			logger.Error("cloud-api: JWT_SECRET missing or empty; refusing to start",
				"hint", "set JWT_SECRET env var or pass --insecure-no-auth for dev")
			os.Exit(1)
		}
		verifier = v
	}

	// Root context cancels on SIGINT / SIGTERM. The GL projection worker
	// derives from this; the HTTP server gets its own Shutdown(ctx) with a
	// hard timeout so a stuck connection can't wedge an operator restart.
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	sqlDB, err := db.Open(ctx, db.Config{Path: *dbPath})
	if err != nil {
		logger.Error("cloud-api: open db", "err", err)
		os.Exit(1)
	}
	defer sqlDB.Close()

	if err := db.RunMigrations(sqlDB); err != nil {
		logger.Error("cloud-api: migrate", "err", err)
		os.Exit(1)
	}

	// Login + admin wiring. Slice 6.1: users live in the DB. The --users
	// YAML file is now only a one-time seed — imported when the table is
	// empty, ignored afterwards (DB edits must never be clobbered by a
	// stale file). Login requires JWT auth (no verifier secret → nothing
	// to sign with; --insecure-no-auth mode doesn't need login anyway).
	tenantStore := tenants.NewStore(sqlDB)

	var loginOpt, adminOpt server.Option
	var dbUsers *users.DBStore
	if verifier != nil {
		secret := os.Getenv("JWT_SECRET") // same secret as the verifier
		issuer, err := auth.NewIssuer(secret, *tokenTTL)
		if err != nil {
			logger.Error("cloud-api: build issuer", "err", err)
			os.Exit(1)
		}
		dbUsers = users.NewDBStore(sqlDB)
		if *usersPath != "" {
			fileStore, err := users.Load(*usersPath)
			if err != nil {
				logger.Warn("cloud-api: users file not loaded (DB users still work)",
					"path", *usersPath, "err", err,
					"hint", "run: go run ./cmd/seed-dev")
			} else if n, err := dbUsers.ImportFromFile(ctx, fileStore); err != nil {
				logger.Error("cloud-api: import users from file", "err", err)
				os.Exit(1)
			} else if n > 0 {
				logger.Info("cloud-api: imported users from file", "path", *usersPath, "count", n)
			}
		}
		loginHandler := api.NewLoginHandler(dbUsers, issuer, logger)
		loginHandler.TenantGate = tenantStore.CheckActive // suspended tenants can't log in
		loginOpt = server.WithLogin(loginHandler)
		adminOpt = server.WithAdminUsers(api.NewAdminUsersHandler(dbUsers, logger))
		logger.Info("cloud-api: login enabled",
			"user_count", dbUsers.Count(), "token_ttl", tokenTTL.String())
	}

	// Catalog snapshot mirror (slice 6.5) — always mounted; upload is
	// JWT-gated, read is owner-gated, both no-ops without traffic.
	catStore := catalog.NewStore(sqlDB)
	catalogOpt := server.WithCatalog(
		api.NewCatalogUploadHandler(catStore, verifier != nil, logger),
		api.NewAdminCatalogHandler(catStore, logger),
	)
	catalogEditsOpt := server.WithCatalogEdits(
		api.NewAdminCatalogEditsHandler(catStore, logger),
		api.NewSyncCatalogEditsHandler(catStore, logger),
	)

	opts := []server.Option{
		server.WithReadyCheck(func(ctx context.Context) error {
			pingCtx, cancel := context.WithTimeout(ctx, 2*time.Second)
			defer cancel()
			return sqlDB.PingContext(pingCtx)
		}),
		catalogOpt,
		catalogEditsOpt,
		server.WithTenantGate(tenantStore.CheckActive),
	}
	if loginOpt != nil {
		opts = append(opts, loginOpt, adminOpt)
		// Platform-admin area (6.7) needs the DB user store for the
		// per-tenant users listing — only available when auth is on.
		opts = append(opts, server.WithPlatformAdmin(
			api.NewPlatformTenantsHandler(tenantStore, dbUsers, logger)))
	}
	srv := server.New(logger, ingest.NewStore(sqlDB, nil), verifier, reports.NewStore(sqlDB), opts...)

	// Phase 5 (slice 5.2): GL projection worker. Drains `events` into
	// journal_entries / journal_lines on a 1s tick. Runs in the same
	// process for simplicity — there is exactly one writer of the GL
	// tables, so no leader election needed.
	glWorker := projection.New(sqlDB, projection.NewStore(sqlDB), logger)

	httpSrv := &http.Server{
		Addr:              *addr,
		Handler:           srv,
		ReadHeaderTimeout: 5 * time.Second,
	}

	httpErrCh := make(chan error, 1)
	go func() {
		if err := httpSrv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			httpErrCh <- err
		}
		close(httpErrCh)
	}()

	workerErrCh := make(chan error, 1)
	go func() {
		workerErrCh <- glWorker.Run(ctx)
	}()

	logger.Info("cloud-api listening",
		"addr", *addr, "batches", server.PathSyncBatches, "events", server.PathSyncEvents,
		"db", *dbPath, "auth", verifier != nil, "gl_projection", "on")

	// Wait for first terminating event.
	select {
	case <-ctx.Done():
		logger.Info("cloud-api: shutdown signal received")
	case err := <-httpErrCh:
		if err != nil {
			logger.Error("cloud-api: http server exited", "err", err)
			stop()
		}
	case err := <-workerErrCh:
		if err != nil && !errors.Is(err, context.Canceled) {
			logger.Error("cloud-api: projection worker exited", "err", err)
		}
		stop()
	}

	// Graceful HTTP drain with hard timeout.
	shutdownCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := httpSrv.Shutdown(shutdownCtx); err != nil {
		logger.Warn("cloud-api: http server shutdown", "err", err)
	}

	<-httpErrCh
	if err := <-workerErrCh; err != nil && !errors.Is(err, context.Canceled) {
		logger.Error("cloud-api: projection worker error on exit", "err", err)
		os.Exit(1)
	}
	logger.Info("cloud-api: shutdown")
}
