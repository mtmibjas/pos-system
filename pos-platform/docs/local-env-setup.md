# Local environment setup

End-to-end guide for running the full pos-platform stack on a single
developer machine. Target audience: UAT operators and new contributors.

> **Just want to start everything?** See `runbook-local.md` — the
> condensed terminal-by-terminal sequence verified on the dev machine.

> **Status:** local-only. A `Production deltas` section at the bottom
> lists what changes when this same stack moves to real infrastructure.
> Update both halves whenever a config surface shifts.

---

## 1. Topology

```
                                   ┌──────────────────────┐
                                   │  mobile-owner        │
                                   │  (Flutter, iOS/      │
                                   │   Android sim or     │
                                   │   real device)       │
                                   └──────────┬───────────┘
                                              │  HTTPS-later / HTTP-now
                                              │  JSON over /v1/...
                                              ▼
┌──────────────────────┐        ┌─────────────────────────────┐
│  desktop-pos         │        │  cloud-api                  │
│  (Flutter, macOS)    │        │  (Go, multi-tenant SaaS)    │
│                      │        │  :8080                      │
│  ConnectRPC          │        │  • /v1/sync/batches         │
│  127.0.0.1:8081      │        │  • /v1/reports/*            │
│       │              │        │  • /v1/auth/login           │
│       ▼              │        │  • /healthz /readyz         │
└───────┴──────────────┘        │  GL projection worker       │
        │                       │  SQLite: cloud.db           │
        │ ConnectRPC            └──────────────▲──────────────┘
        ▼                                      │
┌──────────────────────────────────────┐       │
│  local-store-server                  │       │
│  (Go, per-store binary)              │       │
│  :8081                               │       │
│  • SaleService / RefundService       │       │
│  • TaxAdminService                   │       │
│  • Sync engine ──────────────────────┼───────┘
│    POSTs operations_log to cloud     │
│  • WebSocket hub                     │
│  SQLite: pos-local.db (WAL)          │
└──────────────────────────────────────┘
```

| Component             | Language          | Default port | DB file        |
|-----------------------|-------------------|--------------|----------------|
| cloud-api             | Go 1.25           | 8080         | `cloud.db`     |
| local-store-server    | Go 1.25           | 8081         | `pos-local.db` |
| desktop-pos           | Flutter (macOS)   | —            | none           |
| mobile-owner          | Flutter (iOS/And) | —            | none           |

For local UAT you run **all four** on the same machine. The mobile app
can run on the iOS simulator (reaches the host on `127.0.0.1`) or on a
real device (needs your Mac's LAN IP — see §7).

---

## 2. Prerequisites

Install once, then move on:

| Tool                | Version       | Install (macOS)                                      |
|---------------------|---------------|------------------------------------------------------|
| Go                  | 1.25+         | `brew install go` (or asdf/gvm)                      |
| Flutter             | 3.24+         | https://docs.flutter.dev/get-started/install/macos   |
| buf                 | 1.40+         | `brew install bufbuild/buf/buf`                      |
| protoc-gen-go       | latest        | `go install google.golang.org/protobuf/cmd/protoc-gen-go@latest` |
| protoc_plugin (Dart)| 22.5.0        | `dart pub global activate protoc_plugin 22.5.0`      |
| sqlite3             | any           | preinstalled on macOS                                |
| jq                  | any           | `brew install jq` (only for the smoke flow)          |

Verify:

```sh
go version            # go1.25.x
flutter --version     # 3.24.x or newer
buf --version         # 1.40.x or newer
protoc-gen-go --version
which protoc-gen-dart # ~/.pub-cache/bin/protoc-gen-dart
```

For mobile development on iOS you additionally need (all one-time):

```sh
# 1. Full Xcode.app (NOT just CommandLineTools — flutter needs xcodebuild).
#    On older macOS the App Store may refuse the newest Xcode; download a
#    compatible version from https://developer.apple.com/download/all/
#    (e.g. Xcode 16.4 is the last release supporting macOS 15.x).
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -license accept
xcodebuild -runFirstLaunch

# 2. iOS simulator runtime (~8 GB, separate from Xcode itself):
xcodebuild -downloadPlatform iOS
```

`flutter run` auto-boots the simulator afterwards — no manual launch
needed. For Android instead: Android Studio + an AVD.

---

## 3. One-time bootstrap

```sh
# 1. Clone (if you haven't)
git clone <repo-url> pos-system && cd pos-system/pos-platform

# 2. Regenerate proto / Dart bindings, prime module caches
make proto-gen

# 3. Sanity test
make test           # Go suite for cloud-api + local-store-server
make desktop-test   # Flutter test for desktop-pos
( cd apps/mobile-owner && flutter test )
```

All three test runs must pass before you proceed. If `make proto-gen`
errors, re-read §2 — it almost always means `protoc-gen-dart` isn't on
`PATH`.

### 3.1 JWT secret

cloud-api refuses to boot without `JWT_SECRET`. Generate one and persist
it in your shell profile so every terminal sees the same value:

```sh
# Generate
openssl rand -hex 32

# Add to ~/.zshrc (or ~/.bash_profile)
export JWT_SECRET=<the-hex-string-from-above>

# Reload your shell
source ~/.zshrc
```

The same secret is used to mint owner tokens via `/v1/auth/login`. If
you rotate `JWT_SECRET`, every issued token immediately becomes invalid
— users must re-login.

---

## 4. cloud-api (port 8080)

```sh
cd apps/cloud-api
go build -o cloud-api .

# First-time only: seed a default owner user.
go run ./cmd/seed-dev                       # writes ./users.yaml
# (defaults: username=owner@tenant-a / password=owner-dev-pass / tenant-A / owner)

JWT_SECRET=$JWT_SECRET ./cloud-api \
  --addr :8080 \
  --db ./cloud.db \
  --users ./users.yaml \
  --token-ttl 24h
```

What you should see in the log on startup:

```
level=INFO msg="cloud-api listening" addr=:8080 ... gl_projection=on
```

If `--users` points at a file that doesn't exist, cloud-api logs a
warning and starts up without `/v1/auth/login` mounted — useful when
you're booting it before seed-dev has run, but mobile-owner won't be
able to log in until you create the file and restart.

Both probes are unauthenticated so you can hit them from a script:

```sh
curl -sS http://127.0.0.1:8080/healthz   # liveness — 200 once process is up
curl -sS http://127.0.0.1:8080/readyz    # readiness — 200 only after DB ping succeeds
```

A SIGINT (Ctrl-C) triggers a graceful shutdown: the HTTP server stops
accepting new connections, the projection worker drains its current
tick, and the process exits cleanly within 5s.

**Configuration:**

| Flag / Env             | Default                     | Notes                                                                                     |
|------------------------|-----------------------------|-------------------------------------------------------------------------------------------|
| `--addr`               | `:8080`                     | HTTP listen address.                                                                      |
| `--db`                 | `cloud.db`                  | SQLite file path. Migrations run automatically on boot.                                   |
| `--users`              | _(unset)_                   | Path to YAML user store. Required for `/v1/auth/login`; warn-only if missing.             |
| `--token-ttl`          | `24h`                       | Lifetime of tokens minted by `/v1/auth/login`.                                            |
| `--insecure-no-auth`   | `false`                     | DEV ONLY. Disables JWT verification. Never set in any environment another human reaches.  |
| `JWT_SECRET` (env)     | —                           | Required unless `--insecure-no-auth` is set. HS256 shared secret used to both verify incoming tokens and sign new ones minted by `/v1/auth/login`. |

### 4.1 Adding more users

`cmd/seed-dev` only creates one entry. To add a second user, hash the
password with the same tool, then merge the printed YAML block into
`users.yaml` by hand:

```sh
cd apps/cloud-api
go run ./cmd/seed-dev \
  --path /tmp/extra.yaml \
  --username cashier@tenant-a \
  --password cashier-dev-pass \
  --tenant tenant-A \
  --roles cashier
# Open both files, copy the new `- username:` block across.
```

Restart cloud-api after editing — the file is loaded once at boot.

---

## 5. local-store-server (port 8081)

```sh
cd apps/local-store-server
go build -o local-store-server .
POS_LOCAL_DB=./pos-local.db \
POS_CLOUD_URL=http://127.0.0.1:8080 \
POS_TENANT_ID=tenant-A \
./local-store-server
```

Same liveness / readiness pattern as cloud-api:

```sh
curl -sS http://127.0.0.1:8081/healthz
curl -sS http://127.0.0.1:8081/readyz
```

To populate a freshly-created DB with sample items + tax categories so
the desktop POS isn't empty:

```sh
cd apps/local-store-server
go run ./cmd/seed-demo
```

This is idempotent — re-run it any time you blow away `pos-local.db`.

**Configuration:**

| Env var                | Default                     | Notes                                                                                     |
|------------------------|-----------------------------|-------------------------------------------------------------------------------------------|
| `POS_LOCAL_DB`         | `pos-local.db`              | SQLite path (WAL).                                                                        |
| `POS_CLOUD_URL`        | `http://localhost:8080`     | Where the sync engine ships operations_log.                                               |
| `POS_TENANT_ID`        | `tenant-A`                  | Stamped on outbound batches.                                                              |
| `POS_NODE_ID`          | `node-local`                | Identifies this store binary in logs + sync metadata.                                     |
| `POS_STORE_TZ`         | `UTC`                       | IANA tz name used for day-bucket math.                                                    |
| `POS_VOID_WINDOW`      | `12h`                       | Refund/void cutoff after sale finalization.                                               |
| `POS_LISTEN_ADDR`      | `127.0.0.1:8081`            | ConnectRPC listen address for desktop-pos.                                                |

---

## 6. desktop-pos (Flutter macOS)

```sh
cd apps/desktop-pos
flutter pub get
make -C ../.. desktop-codegen     # only if you touched any *.g.dart-producing file
flutter run -d macos
```

Configuration lives in `lib/config.dart`:

| Const                | Default                  | When to change                          |
|----------------------|--------------------------|-----------------------------------------|
| `kLocalServerUrl`    | `http://127.0.0.1:8081`  | Almost never — local-store-server is on the same Mac. |
| `kStoreId`           | `store-1`                | Until a real provisioning flow exists.  |
| `kCounterId`         | `counter-1`              | Same.                                   |
| `kCashierId`         | `cashier-1`              | Same.                                   |

The desktop client does **not** talk to cloud-api directly — only to the
local-store-server, which forwards via the sync engine.

---

## 7. mobile-owner

```sh
cd apps/mobile-owner
flutter pub get
flutter run                 # picks the first available simulator
```

On first launch you'll see a **Sign in** screen with three fields:

1. **Cloud API URL** — prefilled with the compile-time default
   (`http://127.0.0.1:8080`). Edit in place if needed (see §7.1).
2. **Username** / **Password** — whatever you seeded into
   `users.yaml` (default `owner@tenant-a` / `owner-dev-pass`).

The token is persisted in the platform secure store
(Keychain on iOS, Keystore on Android) — close the app, reopen it, and
you'll land directly on the Today dashboard. A 401 from any cloud-api
call automatically signs you back out and routes to the login screen.

### 7.1 Editing the server URL after login

The gear icon in the Today AppBar opens **Settings**, which exposes
the same URL field. Saving a new URL signs you out (different server =
different identity), so the next login round-trips against the new
host.

### 7.2 Real device on the same Wi-Fi

If you're testing on a physical phone, `127.0.0.1` will resolve to the
device itself. Find your Mac's LAN IP and bind cloud-api to it:

```sh
ipconfig getifaddr en0    # e.g. 192.168.1.42
./cloud-api --addr 192.168.1.42:8080 --db ./cloud.db ...
```

Then type `http://192.168.1.42:8080` into the URL field on the login
screen. No rebuild needed — the URL is editable at runtime.

---

## 7b. admin-dashboard (web, React + Vite)

Browser admin for tenant owners: reports, user management, read-only
catalog. Phase 6 — see `docs/admin-dashboard-plan.md`.

```sh
cd apps/admin-dashboard
npm install            # first time only
npm run dev            # http://localhost:5173, proxies /v1/* to cloud-api
```

The dev proxy targets `http://127.0.0.1:18080` by default; override
with `VITE_API_TARGET=http://127.0.0.1:8080 npm run dev` if your
cloud-api runs on the default port.

Sign in with the same credentials as mobile-owner
(`owner@tenant-a` / `owner-dev-pass`). Pages:

- **Today / Browse** — same reports as mobile-owner + CSV export.
- **Users** — create users, disable, reset passwords (backed by
  `/v1/admin/users`; users now live in cloud.db, the `users.yaml` file
  is only imported once into an empty table).
- **Catalog** — live mirror + editing. Each local-store-server uploads
  its catalog on boot + every 5 min (only when changed). Edits made in
  the dashboard become *intents* that each store pulls (~30 s),
  applies locally, and acks — the "Recent changes" panel shows
  per-store applied/conflict status. A conflict means the store's
  local copy changed more recently than your edit; re-issue the edit
  to overrule. Design: `catalog-editing-design.md`.

- **Platform** (nav appears only for `platform_admin` tokens) — tenant
  list with usage stats, create/suspend tenants, per-tenant user
  listing. Suspension blocks logins and sync ingest immediately.
  Bootstrap the first platform admin (stop cloud-api first):

  ```sh
  cd apps/cloud-api
  go run ./cmd/seed-platform-admin --db ./cloud.db --password <pw>
  # → admin@platform / <pw>, roles: platform_admin + owner
  ```

Tests/build: `npm test`, `npm run build` (output in `dist/`).

---

## 8. End-to-end smoke flow

Run this whenever you're verifying a fresh setup or after a hardening
change. Confirms every wire is hot: login → write on desktop → sync →
projection → mobile dashboard.

**Pre-reqs:** §3 done, `$JWT_SECRET` exported, `users.yaml` seeded
(§4).

### Step 1 — boot the stack (three terminals)

```sh
# Terminal A: cloud-api
cd apps/cloud-api
JWT_SECRET=$JWT_SECRET ./cloud-api \
  --addr :8080 --db ./cloud.db --users ./users.yaml --token-ttl 24h

# Terminal B: local-store-server
cd apps/local-store-server
POS_LOCAL_DB=./pos-local.db POS_CLOUD_URL=http://127.0.0.1:8080 \
POS_TENANT_ID=tenant-A ./local-store-server

# Terminal C: probes
watch -n2 'echo -n "cloud:  "; curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:8080/readyz; \
           echo -n "local:  "; curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:8081/readyz'
# Expect both → 200 within a few seconds.
```

### Step 2 — seed demo catalog (one-shot)

```sh
cd apps/local-store-server
go run ./cmd/seed-demo
```

### Step 3 — verify login from CLI

```sh
TOKEN=$(curl -s -X POST http://127.0.0.1:8080/v1/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"username":"owner@tenant-a","password":"owner-dev-pass"}' | jq -r .token)
echo "$TOKEN" | cut -c1-40    # just to confirm we got one
```

If this 401s, your `users.yaml` doesn't match your inputs — re-run
seed-dev with the right values.

### Step 4 — write a sale on desktop

```sh
cd apps/desktop-pos
flutter run -d macos
# In the app: pick an item, add to cart, tap Pay (Cash), confirm.
```

### Step 5 — watch sync push it

```sh
# In local-store-server's log you should see, within ~5s:
#   batch_id=<uuid>  events=1  status=accepted
# And in cloud-api's log:
#   request_id=<same uuid>  POST /v1/sync/batches  200
```

### Step 6 — confirm revenue on mobile

```sh
cd apps/mobile-owner
flutter run
# Log in (owner@tenant-a / owner-dev-pass).
# Today dashboard shows the sale's grand total.
# Pull-to-refresh re-fetches.
```

### Step 7 — exercise the auto-logout

In `apps/cloud-api/users.yaml`, change the bcrypt hash to anything
that won't validate (e.g. swap a character) and restart cloud-api.
Pull-to-refresh on mobile → the call 401s → you're auto-routed back to
the login screen. Restore the hash, log in again.

That's the full hot loop. If any step fails, the matching row in §11
likely explains why.

---

## 9. Daily ops

### Restart everything cleanly

```sh
# Ctrl-C each foreground process. They register SIGINT and drain.
# Order doesn't matter — restart safe.
```

### Reset to a clean slate

```sh
# Stop both servers first.
rm apps/cloud-api/cloud.db apps/cloud-api/cloud.db-wal apps/cloud-api/cloud.db-shm
rm apps/local-store-server/pos-local.db*
# Then restart and re-seed:
( cd apps/cloud-api && JWT_SECRET=$JWT_SECRET ./cloud-api ) &
( cd apps/local-store-server && go run ./cmd/seed-demo )
( cd apps/local-store-server && ./local-store-server ) &
```

### Regenerate a JWT manually

Normal use: log in via the mobile app. For service-account or
scripting use cases (e.g. a curl smoke test against `/v1/reports/*`),
mint one directly:

```sh
cd apps/cloud-api
go run ./cmd/mint-owner-jwt -secret="$JWT_SECRET" -tenant=tenant-A -roles=owner -ttl=24h
```

### Tail logs

Both servers emit JSON-ish slog text to stdout. The simplest pattern
is to run them in two terminals with `tee`:

```sh
./cloud-api 2>&1 | tee -a cloud-api.log
./local-store-server 2>&1 | tee -a local-store-server.log
```

### Correlate a request across both services

Every HTTP request gets an `X-Request-ID` (echoed in the response
header). For sync batches the ID *is* the `batch_id`, so a single grep
lights up the full round-trip:

```sh
# Find a batch in the local server's log
grep batch_id=abc-123 local-store-server.log
# Same ID lands in cloud-api's access log
grep request_id=abc-123 cloud-api.log
```

For ad-hoc requests, the client can set its own:

```sh
curl -H 'X-Request-ID: my-debug-1' http://127.0.0.1:8080/v1/reports/stores
```

---

## 10. Backup and restore (local)

`scripts/backup/snapshot.sh` takes an atomic (`VACUUM INTO`) snapshot
of both SQLite files into a timestamped folder, with a `MANIFEST` of
sha256 checksums.

```sh
# From the apps directory where the .db files live:
cd apps/cloud-api
POS_LOCAL_DB=../local-store-server/pos-local.db \
  ../../scripts/backup/snapshot.sh --out ../../backups
# → ../../backups/<UTC-timestamp>/cloud.db
# → ../../backups/<UTC-timestamp>/pos-local.db
# → ../../backups/<UTC-timestamp>/MANIFEST
```

Safe to run while the servers are up — `VACUUM INTO` takes a read
transaction internally, so the snapshot is point-in-time consistent.

Restore:

```sh
# 1. Stop the matching server.
# 2. Verify the snapshot is intact.
shasum -a 256 -c <(awk '{print $2"  "$1}' backups/<ts>/MANIFEST)
# 3. Move the file into place.
cp backups/<ts>/cloud.db apps/cloud-api/cloud.db
# 4. Restart.
```

Schedule via cron / launchd as needed:

```cron
0 */6 * * *  /usr/bin/env bash /Users/you/pos-system/pos-platform/scripts/backup/snapshot.sh --out /var/backups/pos
```

---

## 11. Troubleshooting

| Symptom                                                  | Likely cause                                                                                       | Fix                                                                                       |
|----------------------------------------------------------|----------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------|
| `cloud-api: JWT_SECRET missing or empty`                 | Env var not exported in this shell.                                                                | `export JWT_SECRET=...` and rerun. Verify with `echo $JWT_SECRET`.                        |
| `401 Unauthorized` from mobile-owner                     | Token expired (default 24h) or `JWT_SECRET` was rotated.                                           | App auto-routes to login screen; sign in again.                                           |
| Login screen returns `invalid credentials`               | Username/password mismatch, or cloud-api was booted without `--users`.                             | Confirm `users.yaml` exists; re-seed with `cmd/seed-dev` if needed.                       |
| Login screen returns `connection failed`                 | URL in the form points at a host/port nothing is listening on.                                      | Verify `curl <url>/healthz` returns 200 from the same machine the app runs on.            |
| Desktop POS hangs on startup                             | local-store-server isn't running on `127.0.0.1:8081`.                                              | Start it first; then restart the desktop client.                                          |
| Sync stays at 0 / never reaches cloud                    | `POS_CLOUD_URL` points at a host the local-store-server can't reach.                               | Confirm `curl $POS_CLOUD_URL/healthz` works from the same machine.                        |
| Mobile owner sees "Could not load"                       | `kCloudApiUrl` wrong, or you're on a real phone trying to hit `127.0.0.1`.                        | Use the Mac's LAN IP — see §7.1.                                                          |
| `database is locked` errors                              | Another process is writing the same SQLite file.                                                   | Kill any stale `cloud-api`/`local-store-server`. Only one writer per DB.                  |
| Tests pass but POS shows empty product list              | Fresh DB; you haven't seeded.                                                                      | `cd apps/local-store-server && go run ./cmd/seed-demo`.                                   |
| Flutter codegen error on launch                          | You edited a `.g.dart`-producing file and skipped `desktop-codegen`.                               | `make desktop-codegen`.                                                                   |

---

## 12. Production deltas

The local setup intentionally cuts corners. When this stack moves to
real infrastructure, expect to address:

| Local choice                          | Production change                                                          |
|---------------------------------------|----------------------------------------------------------------------------|
| SQLite (cloud-api)                    | Postgres per tenant (see `docs/tenant-rules.md`). DSN env var.             |
| HTTP                                  | TLS termination at the load balancer / reverse proxy. HSTS.                |
| HS256 shared secret                   | RS256 / JWKS with rotating signing keys.                                   |
| File-based user list                  | Real users table + invitation flow + password reset.                       |
| Hand-edited `JWT_SECRET` env var      | Secret manager (AWS Secrets Manager / Vault / GCP SM).                     |
| `127.0.0.1` everywhere                | DNS + service discovery. mDNS for in-store, public DNS for cloud.          |
| `flutter run`                         | TestFlight / Play Internal Track distribution. App signing.                |
| No metrics                            | Prometheus scrape + OTel tracing on both Go services.                      |
| No rate limiting                      | Per-tenant token-bucket rate limits on cloud-api.                          |
| Manual `sqlite3 .backup`              | Continuous WAL archiving / managed Postgres backups + retention policy.    |
| Logs to stdout                        | Centralized log aggregation (Loki / CloudWatch / Datadog).                 |
| `--insecure-no-auth` exists           | Build tag the flag out of production binaries.                             |

Each of these is tracked in the platform backlog (Bucket B from the UAT
hardening plan). None block local UAT.
