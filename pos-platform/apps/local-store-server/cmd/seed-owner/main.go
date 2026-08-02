// Package main seeds a local user (an owner by default) into the
// store-server SQLite database, so AuthService.RegisterDevice + Login can
// be exercised by hand before the cloud->store user sync lands.
//
// It opens (and migrates) the same DB the local-store-server uses, then
// creates one user via users.Store.Create. Re-runs are idempotent: an
// existing username is reported and skipped (the store has no update path —
// disable-and-recreate, or edit via the eventual admin sync, instead).
//
// Usage:
//
//	# default: owner "owner@a" / "ownerpw", roles [owner]
//	go run ./cmd/seed-owner
//
//	# custom owner
//	go run ./cmd/seed-owner -username boss@shop -password 's3cret' -display "The Boss"
//
//	# a cashier, to test non-owner login (cannot RegisterDevice)
//	go run ./cmd/seed-owner -username cash@a -password cashpw -roles cashier
//
//	POS_LOCAL_DB=/tmp/dev.db POS_TENANT_ID=tenant-A go run ./cmd/seed-owner
//
// This is a DEV seeder — the default password is convenience, not security.
package main

import (
	"context"
	"errors"
	"flag"
	"log/slog"
	"os"
	"strings"

	"github.com/mibjas/pos-platform/apps/local-store-server/internal/db"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/users"
)

func main() {
	logger := slog.New(slog.NewTextHandler(os.Stdout, nil))
	ctx := context.Background()

	username := flag.String("username", "owner@a", "username to create")
	password := flag.String("password", "ownerpw", "plaintext password (dev convenience)")
	display := flag.String("display", "Shop Owner", "display name (empty → login shows username)")
	rolesCSV := flag.String("roles", "owner", "comma-separated roles, e.g. owner or cashier")
	flag.Parse()

	dbPath := envOr("POS_LOCAL_DB", "pos-local.db")
	tenantID := envOr("POS_TENANT_ID", "tenant-A")

	roles := splitRoles(*rolesCSV)
	if len(roles) == 0 {
		logger.Error("at least one role is required (-roles)")
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

	store := users.NewStore(sqlDB)
	err = store.Create(ctx, *username, tenantID, *password, roles, *display)
	switch {
	case errors.Is(err, users.ErrUsernameTaken):
		logger.Info("user already exists — skipping (re-run is a no-op)",
			"username", *username, "tenant", tenantID)
		return
	case err != nil:
		logger.Error("create user", "err", err, "username", *username)
		os.Exit(1)
	}

	logger.Info("user seeded",
		"db_path", dbPath,
		"tenant", tenantID,
		"username", *username,
		"roles", roles,
	)
}

// splitRoles parses the comma-separated -roles flag, trimming blanks.
func splitRoles(csv string) []string {
	out := make([]string, 0, 2)
	for _, r := range strings.Split(csv, ",") {
		if r = strings.TrimSpace(r); r != "" {
			out = append(out, r)
		}
	}
	return out
}

func envOr(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}
