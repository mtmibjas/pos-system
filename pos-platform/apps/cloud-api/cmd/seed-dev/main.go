// seed-dev creates a starter users.yaml for local UAT if one does not
// exist. Idempotent — running it twice does nothing the second time.
//
// Usage:
//
//	cd apps/cloud-api && go run ./cmd/seed-dev
//
// Flags let an operator customize the seeded credentials without hand-
// editing the YAML afterwards.
package main

import (
	"flag"
	"fmt"
	"os"
	"strings"

	"golang.org/x/crypto/bcrypt"
	"gopkg.in/yaml.v3"
)

type seedUser struct {
	Username   string   `yaml:"username"`
	TenantID   string   `yaml:"tenant_id"`
	Roles      []string `yaml:"roles"`
	BcryptHash string   `yaml:"bcrypt"`
}

type seedFile struct {
	Users []seedUser `yaml:"users"`
}

func main() {
	path := flag.String("path", "users.yaml", "destination YAML file")
	username := flag.String("username", "owner@tenant-a", "seeded username")
	password := flag.String("password", "owner-dev-pass", "seeded password (plaintext, will be bcrypt'd)")
	tenant := flag.String("tenant", "tenant-A", "tenant_id for the seeded user")
	rolesCSV := flag.String("roles", "owner", "comma-separated roles for the seeded user")
	force := flag.Bool("force", false, "overwrite an existing file (default: refuse and exit 0)")
	flag.Parse()

	if _, err := os.Stat(*path); err == nil && !*force {
		fmt.Printf("seed-dev: %s already exists — skipping (use --force to overwrite)\n", *path)
		return
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(*password), bcrypt.DefaultCost)
	if err != nil {
		fmt.Fprintf(os.Stderr, "seed-dev: bcrypt: %v\n", err)
		os.Exit(1)
	}

	roles := []string{}
	for _, r := range strings.Split(*rolesCSV, ",") {
		if r = strings.TrimSpace(r); r != "" {
			roles = append(roles, r)
		}
	}

	out := seedFile{
		Users: []seedUser{{
			Username:   *username,
			TenantID:   *tenant,
			Roles:      roles,
			BcryptHash: string(hash),
		}},
	}
	body, err := yaml.Marshal(out)
	if err != nil {
		fmt.Fprintf(os.Stderr, "seed-dev: marshal: %v\n", err)
		os.Exit(1)
	}
	header := []byte(
		"# Local-dev user store for cloud-api /v1/auth/login.\n" +
			"# Hand-edit to add more users. Re-hash a password with:\n" +
			"#   go run ./cmd/seed-dev -password=NEW -username=u -force\n" +
			"# then merge the produced entry into the existing file.\n",
	)
	if err := os.WriteFile(*path, append(header, body...), 0o600); err != nil {
		fmt.Fprintf(os.Stderr, "seed-dev: write %s: %v\n", *path, err)
		os.Exit(1)
	}

	fmt.Printf("seed-dev: wrote %s\n", *path)
	fmt.Printf("  username : %s\n", *username)
	fmt.Printf("  password : %s\n", *password)
	fmt.Printf("  tenant   : %s\n", *tenant)
	fmt.Printf("  roles    : %s\n", strings.Join(roles, ","))
}
