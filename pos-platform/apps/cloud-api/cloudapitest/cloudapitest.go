// Package cloudapitest exposes a single helper for booting the real
// cloud-api HTTP stack inside another module's test process. It exists
// so cross-module e2e/chaos tests (e.g. slice 3.6 in local-store-server)
// can mount the production handler stack without re-implementing route
// wiring AND without violating Go's internal/ visibility rule on
// cloud-api's implementation packages.
//
// Test-only: production code never imports this. Kept on the public
// side of cloud-api (not under internal/) so other modules in the
// workspace can reach it.
package cloudapitest

import (
	"context"
	"io"
	"log/slog"
	"net/http/httptest"
	"path/filepath"
	"testing"

	"github.com/mibjas/pos-platform/apps/cloud-api/internal/auth"
	"github.com/mibjas/pos-platform/apps/cloud-api/internal/db"
	"github.com/mibjas/pos-platform/apps/cloud-api/internal/ingest"
	"github.com/mibjas/pos-platform/apps/cloud-api/internal/reports"
	"github.com/mibjas/pos-platform/apps/cloud-api/internal/server"
)

// Fixture is the live cloud-api running in-process. Cleanup is handled
// by t.Cleanup hooks — callers just use URL + Secret.
type Fixture struct {
	URL    string // httptest base URL (no trailing slash)
	Secret string // HS256 shared secret callers must use to mint JWTs

	// BatchesPath / EventsPath are exported so callers don't have to
	// hardcode the routes (they're stable per the wire contract, but
	// surfacing them here keeps the chaos test from drifting).
	BatchesPath string
	EventsPath  string
}

// Boot returns a Fixture pointing at a freshly-migrated SQLite DB and
// the real production handler stack wired with HS256 auth. The DB and
// httptest.Server are torn down via t.Cleanup.
//
// The returned Secret is a fixed deterministic string — callers should
// use it to mint matching JWTs (see local-store-server's TokenSource).
func Boot(t *testing.T) *Fixture {
	t.Helper()
	const secret = "cloudapitest-shared-secret"

	ctx := context.Background()
	sqlDB, err := db.Open(ctx, db.Config{Path: filepath.Join(t.TempDir(), "cloud.db")})
	if err != nil {
		t.Fatalf("cloudapitest: open db: %v", err)
	}
	t.Cleanup(func() { _ = sqlDB.Close() })

	if err := db.RunMigrations(sqlDB); err != nil {
		t.Fatalf("cloudapitest: migrate: %v", err)
	}

	v, err := auth.NewVerifier(secret)
	if err != nil {
		t.Fatalf("cloudapitest: verifier: %v", err)
	}

	store := ingest.NewStore(sqlDB, nil)
	logger := slog.New(slog.NewTextHandler(io.Discard, nil))
	srv := httptest.NewServer(server.New(logger, store, v, reports.NewStore(sqlDB)))
	t.Cleanup(srv.Close)

	return &Fixture{
		URL:         srv.URL,
		Secret:      secret,
		BatchesPath: server.PathSyncBatches,
		EventsPath:  server.PathSyncEvents,
	}
}
