// seed-platform-admin bootstraps the first platform_admin user
// directly into the cloud DB (slice 6.7). The tenant-scoped admin API
// deliberately cannot assign this role, so the first platform operator
// must come from out-of-band provisioning — this tool.
//
// Usage (stop cloud-api first — single SQLite writer):
//
//	go run ./cmd/seed-platform-admin --db ./cloud.db \
//	  --username admin@platform --password <pw>
package main

import (
	"context"
	"flag"
	"fmt"
	"os"

	"github.com/mibjas/pos-platform/apps/cloud-api/internal/db"
	"github.com/mibjas/pos-platform/apps/cloud-api/internal/users"
)

func main() {
	dbPath := flag.String("db", "cloud.db", "SQLite database path")
	username := flag.String("username", "admin@platform", "platform admin username")
	password := flag.String("password", "", "password (required, 8+ chars)")
	tenant := flag.String("tenant", "platform", "tenant_id stamped on the account (informational — platform routes ignore it)")
	flag.Parse()

	if len(*password) < 8 {
		fmt.Fprintln(os.Stderr, "seed-platform-admin: --password is required (8+ chars)")
		os.Exit(1)
	}

	ctx := context.Background()
	sqlDB, err := db.Open(ctx, db.Config{Path: *dbPath})
	if err != nil {
		fmt.Fprintf(os.Stderr, "seed-platform-admin: open db: %v\n", err)
		os.Exit(1)
	}
	defer sqlDB.Close()
	if err := db.RunMigrations(sqlDB); err != nil {
		fmt.Fprintf(os.Stderr, "seed-platform-admin: migrate: %v\n", err)
		os.Exit(1)
	}

	store := users.NewDBStore(sqlDB)
	rec, err := store.Create(ctx, *tenant, *username, *password,
		[]string{"platform_admin", "owner"})
	if err != nil {
		fmt.Fprintf(os.Stderr, "seed-platform-admin: %v\n", err)
		os.Exit(1)
	}
	fmt.Printf("seed-platform-admin: created %s (tenant=%s roles=%v)\n",
		rec.Username, rec.TenantID, rec.Roles)
	fmt.Println("  log in to the dashboard with this account to see the Platform page")
}
