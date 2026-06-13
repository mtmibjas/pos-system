// mint-owner-jwt prints an HS256-signed owner JWT for development use
// with the mobile-owner app. Still useful for one-off testing even after
// the file-based login flow lands — e.g. to mint a token for a
// service-account-style integration that can't go through /v1/auth/login.
//
// Usage:
//
//	go run ./cmd/mint-owner-jwt -secret=$JWT_SECRET -tenant=tenant-A
//
// Defaults: tenant=tenant-A, ttl=24h, roles=owner.
package main

import (
	"flag"
	"fmt"
	"os"
	"strings"
	"time"

	"github.com/mibjas/pos-platform/apps/cloud-api/internal/auth"
)

func main() {
	secret := flag.String("secret", "", "HS256 shared secret (must match cloud-api's JWT_SECRET)")
	tenant := flag.String("tenant", "tenant-A", "tenant_id claim")
	subject := flag.String("sub", "mint-owner-jwt", "sub claim")
	rolesCSV := flag.String("roles", "owner", "comma-separated roles claim")
	ttl := flag.Duration("ttl", 24*time.Hour, "token lifetime")
	flag.Parse()

	if *secret == "" {
		fmt.Fprintln(os.Stderr, "mint-owner-jwt: -secret is required")
		os.Exit(2)
	}

	roles := []string{}
	for _, r := range strings.Split(*rolesCSV, ",") {
		if r = strings.TrimSpace(r); r != "" {
			roles = append(roles, r)
		}
	}

	issuer, err := auth.NewIssuer(*secret, *ttl)
	if err != nil {
		fmt.Fprintf(os.Stderr, "mint-owner-jwt: build issuer: %v\n", err)
		os.Exit(1)
	}
	token, _, err := issuer.Mint(*tenant, *subject, roles)
	if err != nil {
		fmt.Fprintf(os.Stderr, "mint-owner-jwt: sign: %v\n", err)
		os.Exit(1)
	}
	fmt.Println(token)
}
