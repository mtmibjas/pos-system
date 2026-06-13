# Local runbook — terminal by terminal

The exact, verified startup sequence for this machine (last validated
2026-06-13, Phase 6 complete: all five components + platform admin).
For the full reference (prerequisites, config tables, troubleshooting,
production deltas) see `local-env-setup.md`.

> **Why port 18080?** Docker Desktop runs Kafka UI on `:8080` on this
> machine, so cloud-api uses `:18080` everywhere below. If you ever
> free up :8080 (stop that container), you can switch back to defaults
> — but then update the URL in the mobile app + dashboard proxy too.

---

## One-time setup (already done on this machine)

Skip on a machine that's already been set up. For a fresh machine:

1. **Toolchain**: Go 1.25+, Flutter 3.24+, Node 20+, sqlite3, jq.
2. **Full Xcode.app** (not just CommandLineTools). On macOS 15.x the
   App Store version is too new — download Xcode 16.4 from
   https://developer.apple.com/download/all/ then:
   ```sh
   sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
   sudo xcodebuild -license accept
   xcodebuild -runFirstLaunch
   xcodebuild -downloadPlatform iOS   # ~8 GB simulator runtime
   brew install cocoapods
   ```
3. **Build the Go servers**:
   ```sh
   cd /Users/mibjas/pos-system/pos-platform
   ( cd apps/cloud-api && go build -o cloud-api . )
   ( cd apps/local-store-server && go build -o local-store-server . )
   ```
4. **JWT secret** (shared by both servers; regenerate if /tmp was cleaned —
   that invalidates old logins, which is fine, just sign in again):
   ```sh
   [ -f /tmp/pos-smoke-secret ] || openssl rand -hex 32 > /tmp/pos-smoke-secret
   ```
5. **Seed data** (only after deleting a DB):
   ```sh
   ( cd apps/cloud-api && go run ./cmd/seed-dev )            # users.yaml: owner@tenant-a
   ( cd apps/local-store-server && go run ./cmd/seed-demo )  # 6 items + GST-18
   ```
5b. **Platform admin** (one-time; cloud-api must be STOPPED — single
   SQLite writer). Already done on this machine
   (`admin@platform` / `platform-dev-pass`):
   ```sh
   ( cd apps/cloud-api && go run ./cmd/seed-platform-admin --db ./cloud.db --password platform-dev-pass )
   ```
6. **Dashboard deps**: `( cd apps/admin-dashboard && npm install )`

---

## Terminal A — cloud-api (SaaS backend)

```sh
cd /Users/mibjas/pos-system/pos-platform/apps/cloud-api
JWT_SECRET=$(cat /tmp/pos-smoke-secret) ./cloud-api \
  --addr 127.0.0.1:18080 --db ./cloud.db --users ./users.yaml --token-ttl 24h
```

Ready when the log shows: `cloud-api listening ... auth=true gl_projection=on`.

First boot also runs DB migrations and imports `users.yaml` into the
users table (once — DB edits are never overwritten afterwards).

## Terminal B — local-store-server (store + sync)

```sh
cd /Users/mibjas/pos-system/pos-platform/apps/local-store-server
SYNC_JWT_SECRET=$(cat /tmp/pos-smoke-secret) \
POS_LOCAL_DB=./pos-local.db \
POS_CLOUD_URL=http://127.0.0.1:18080 \
POS_TENANT_ID=tenant-A \
./local-store-server
```

Ready when: `local-store-server ready ... listen_addr=127.0.0.1:8081`,
followed shortly by `catalogsync: snapshot uploaded` (catalog reaching
the cloud for the dashboard's Catalog page).

⚠ `SYNC_JWT_SECRET` must match Terminal A's `JWT_SECRET`, otherwise
sync batches get 401'd and sales never reach the cloud.

## Terminal C — admin dashboard (web)

```sh
cd /Users/mibjas/pos-system/pos-platform/apps/admin-dashboard
npm run dev
```

Open **http://localhost:5173** → sign in `owner@tenant-a` /
`owner-dev-pass`. The dev server proxies `/v1/*` to `:18080`
(override: `VITE_API_TARGET=http://host:port npm run dev`).

Accounts on this machine:

| Account | Password | Sees |
|---|---|---|
| `owner@tenant-a` | `owner-dev-pass` | tenant-A reports, users, catalog (incl. editing) |
| `admin@platform` | `platform-dev-pass` | + Platform page (tenant CRUD, suspend, usage stats) |

Catalog edits made in the dashboard reach each store within ~30 s
(stores pull, apply, ack — watch for `catalogsync: edits processed` in
Terminal B). Suspending a tenant on the Platform page blocks its
logins and sync ingest until reactivated.

## Terminal D — desktop POS (cashier, macOS)

```sh
cd /Users/mibjas/pos-system/pos-platform/apps/desktop-pos
flutter run -d macos
```

No configuration — hardcoded to local-store-server at `127.0.0.1:8081`.
Needs full Xcode (see one-time setup); first build is slow, then fast.

## Terminal E — mobile owner app (iOS simulator)

```sh
cd /Users/mibjas/pos-system/pos-platform/apps/mobile-owner
flutter run
```

Auto-boots the iPhone simulator. On the sign-in screen:

| Field | Value |
|---|---|
| Cloud API URL | `http://127.0.0.1:18080` ← **not 8080** (that's Kafka UI in Docker) |
| Username | `owner@tenant-a` |
| Password | `owner-dev-pass` |

The URL persists after the first successful login. A 404/NOT_FOUND
error on login = wrong port. Physical phone instead of simulator:
use the Mac's LAN IP (`ipconfig getifaddr en0`) and bind cloud-api
to it in Terminal A.

---

## Verify the loop (60 seconds)

1. Terminal D: ring a sale (item → Pay → Cash → Confirm).
2. Terminal B logs `batch_id=... status=accepted` within ~5 s;
   Terminal A logs the same ID as `request_id`.
3. Dashboard (C) Today page + mobile (E) pull-to-refresh both show the
   revenue.

## Stop / restart

- Ctrl-C in A and B — both drain gracefully (SIGINT handled). Order
  doesn't matter. C/D/E: Ctrl-C / `q` as usual.
- Health probes: `curl http://127.0.0.1:18080/readyz` and
  `curl http://127.0.0.1:8081/readyz` → `ready`.

## Gotchas we actually hit (so you don't again)

| Symptom | Cause | Fix |
|---|---|---|
| cloud-api exits: `bind: address already in use` | Docker (Kafka UI) owns :8080, or a stale server | `lsof -i :18080`; kill the stale PID or change `--addr` |
| Mobile login: `404 NOT_FOUND` | URL points at :8080 = Kafka UI | Use `http://127.0.0.1:18080` |
| All logins suddenly 401 | `/tmp/pos-smoke-secret` regenerated (tmp cleanup) while a server still ran with the old one | Restart both servers; sign in again |
| Desktop sale never syncs | Desktop app never actually built (missing Xcode), or `SYNC_JWT_SECRET` mismatch | `flutter doctor`; compare secrets in A and B |
| `flutter run` in mobile-owner: "No supported devices" | No simulator runtime / platform folders | One-time setup steps 2; `ios/`+`android/` now exist in-repo |
| Dashboard login: "cloud-api unreachable" | cloud-api not running; the vite proxy has nothing to forward to | Start Terminal A, retry |
| Dashboard login: "tenant is suspended" | Someone suspended the tenant on the Platform page | Log in as `admin@platform` → Platform → Activate |
| Catalog edit stuck on "pending…" | local-store-server not running, or pre-6.6 binary | Start/rebuild Terminal B; pulls happen every ~30 s |
| Catalog edit shows "conflict" | Store's local copy changed more recently than your edit | Re-issue the edit from the dashboard to overrule |
