# Store-Server Auth — Login + Device Registration Contract

> **Status: DRAFT for review.** Server-side prerequisite that **gates the
> desktop auth slice** (`docs/desktop-architecture.md` §4.2, §6 step 3).
> No code yet — this specifies the proto surface, data model, token model,
> enforcement, and rollout for review. Implementation (proto + Go +
> migrations) follows approval.

---

## 1. Purpose & constraints

The desktop POS needs **Manager Login + Device Registration** against the
**local store server** (decided 2026-06-14). Two distinct auth acts:

- **Device registration** — a manager/owner authenticates once to bind a
  terminal to a `counter_id` and receive a long-lived **device credential**.
- **Cashier login** — daily use; a cashier authenticates on a registered
  device and receives a short-lived **session token** that rides subsequent
  Connect calls and carries *who-sold-it* + *where*.

**Hard constraints that shape every decision below:**

1. **Offline-first (golden rule #1).** Login and registration must work with
   the **cloud unreachable**. → user records *and* device records live in
   the store server's **local SQLite**; we never proxy login to cloud-api.
2. **Connect-RPC convention** (memory: don't propose alternatives). The
   desktop already speaks Connect via `pos_sdk` + `transportProvider`, so
   auth is a new **Connect `AuthService`**, not a bespoke HTTP endpoint.
   *(cloud-api's `POST /v1/auth/login` is plain HTTP because its client is a
   browser; ours is a Connect client — we diverge deliberately.)*
3. **Reuse the existing HS256 machinery**, don't reinvent it. cloud-api's
   `auth.Issuer`/`auth.Verifier`/`Claims` are generic HMAC helpers; promote
   them to a shared package (`packages/sdk-go`) and use them on both sides.
4. **Stop trusting client-supplied identity.** Today `Finalize` accepts
   `store_id`/`counter_id`/`cashier_id` from the request body (the `kStoreId`
   consts). Post-auth, the server **derives these from the verified token**.

---

## 2. What exists vs. what's missing

| Piece | Today | This contract |
|---|---|---|
| Inbound auth on store server | **none** (loopback, single-tenant env) | new `AuthService` + auth middleware |
| Users | **no table**; cloud-api has `users` (bcrypt, migration 000003) | local `users` table (port of cloud-api schema) |
| Devices | **none** | new `devices` table |
| JWT mint/verify | `sync.TokenSource` mints store→cloud (HS256) | reuse `auth.Issuer`/`Verifier` for client sessions |
| Identity on Finalize | client-supplied (`kStoreId`/`kCounterId`/`kCashierId`) | token-derived |
| Secret | `SYNC_JWT_SECRET` (store→cloud audience) | **new** `POS_SESSION_SECRET` (client-session audience) |

> **Distinct secrets, distinct audiences.** `SYNC_JWT_SECRET` authenticates
> the store *to the cloud*. Client sessions are a different trust domain, so
> they get their own `POS_SESSION_SECRET`. Don't overload one secret.

---

## 3. Token model — two tiers

```
  Manager ──RegisterDevice──> [device_id + device_secret]   (long-lived, revocable)
                                      │  stored: server bcrypt-hashed in `devices`
                                      │          terminal → flutter_secure_storage
                                      ▼
  Cashier ──Login(device creds + user creds)──> [session JWT]  (short-lived, stateless)
                                      │  rides Authorization: Bearer on Connect calls
                                      ▼
            server verifies → derives store/counter/cashier/roles from claims
```

**Tier 1 — Device credential (opaque secret, revocable).**
- A random `device_secret` minted at registration, returned **once**, stored
  **bcrypt-hashed** server-side in `devices`; the terminal keeps it in
  `flutter_secure_storage`.
- *Why opaque-and-hashed, not a long-lived device JWT:* a stolen/retired
  terminal must be **revocable** (disable the `devices` row). A long-lived
  stateless JWT can't be revoked without a denylist. The store has SQLite
  anyway, so a stateful device check is cheap and strictly safer.

**Tier 2 — Session token (HS256 JWT, short-lived, stateless).**
- Minted at `Login`, verified by middleware on every mutating call. Stateless
  so the hot path needs no DB lookup.
- **Claims** (extend cloud-api's `Claims`):

  | Claim | Source | Use |
  |---|---|---|
  | `tenant_id` | server `POS_TENANT_ID` | tenant scoping (existing) |
  | `sub` | username | cashier identity → `cashier_id` on sales |
  | `roles` | user record | role gating (`owner`/`cashier`) |
  | `store_id` | server config | bind sale to store |
  | `counter_id` | **device** record | bind sale to counter |
  | `device_id` | device record | audit / revocation correlation |
  | `iss` | `"local-store-server"` | diagnostics |
  | `exp` | TTL (configurable) | expiry |

- **TTL (decided):** generous enough to cover a shift in a single login —
  default **16h**, env-configurable (`POS_SESSION_TTL`, like
  `POS_VOID_WINDOW`). **No refresh token** — re-login at expiry; simpler and
  better for shift accountability.

---

## 4. Data model (proposed migrations 000011 / 000012)

**`users`** — port of cloud-api `000003_users` so the schema and bcrypt shape
match, and a future cloud→store user sync is a straight copy:

```sql
CREATE TABLE users (
    username     TEXT PRIMARY KEY,
    tenant_id    TEXT    NOT NULL,
    roles        TEXT    NOT NULL DEFAULT '[]',  -- JSON array
    bcrypt_hash  TEXT    NOT NULL,
    display_name TEXT    NOT NULL DEFAULT '',     -- LoginResponse.user_display_name
    disabled     INTEGER NOT NULL DEFAULT 0,
    created_at   INTEGER NOT NULL,
    updated_at   INTEGER NOT NULL
);
```

> `display_name` is the **one addition** over cloud-api's `000003_users`
> schema — it sources `LoginResponse.user_display_name` (falls back to
> `username` when empty). cloud-api has no such column today, so the
> cloud→store user sync carries it only once cloud-api grows it; until then
> it stays empty and login shows the username. Display-only — never an
> authorization input.

**`devices`** — one row per registered terminal:

```sql
CREATE TABLE devices (
    device_id          TEXT PRIMARY KEY,         -- server-minted UUID
    tenant_id          TEXT    NOT NULL,
    store_id           TEXT    NOT NULL,
    counter_id         TEXT    NOT NULL,
    device_name        TEXT    NOT NULL,
    secret_bcrypt_hash TEXT    NOT NULL,         -- hash of device_secret
    disabled           INTEGER NOT NULL DEFAULT 0,
    registered_by      TEXT    NOT NULL,         -- manager username (audit)
    created_at         INTEGER NOT NULL,
    last_seen_at       INTEGER
);
CREATE UNIQUE INDEX idx_devices_counter
    ON devices (store_id, counter_id) WHERE disabled = 0;
```

> The partial unique index enforces **one active device per counter**.
> `counter_id` is **server-assigned** (decided) — sequential per store
> (`counter-1`, `counter-2`, …, derived from existing rows). A replacement
> registration **revokes the old row then reuses its `counter_id`** (§5.1),
> so the index holds (only one active) and counter identity survives a till
> swap for shift-report continuity.

**User provisioning — cloud→store sync (decided).** Users must be local for
offline login. Cloud-api owns users (admin dashboard, slice 6.1), so users
are **pulled cloud→store**, modeled on the catalog pull
(`catalogsync.Applier`, slice 6.6): the store mirrors `username / tenant_id /
roles / bcrypt_hash / disabled` into its local `users` table and
re-authenticates against the mirror offline. For the UAT interim (before the
sync lands), **seed locally** with a `seed-dev`-style command writing a
bcrypt'd owner. The sync itself is a follow-up slice (§8 step 5), but it is
the decided mechanism, not an open question.

---

## 5. The `AuthService` contract (proposed `packages/proto/pos/v1/auth_service.proto`)

Three procedures; `RegisterDevice` and `Login` are **unauthenticated** (the
door), `RefreshSession` deferred. Error codes are Connect codes; messages are
**generic** for credential failures to prevent user/device enumeration
(mirrors cloud-api's "invalid credentials").

### 5.1 `RegisterDevice` — manager-gated

```
RegisterDeviceRequest {
  string manager_username = 1;
  string manager_password = 2;   // never logged
  string device_name = 3;        // human label, e.g. "Front till"
  string replace_counter_id = 4; // OPTIONAL: re-provision an existing counter
                                  // (till swap). Empty = brand-new counter.
}
RegisterDeviceResponse {
  string device_id = 1;
  string device_secret = 2;      // returned ONCE; server stores only the hash
  string store_id = 3;
  string counter_id = 4;         // server-assigned (new) or reused (replace)
}
```
Server: authenticate manager (bcrypt) → **require `owner` role** → then:
- **New device** (`replace_counter_id` empty): assign the next sequential
  `counter_id` for the store, insert a new `devices` row.
- **Replacement** (`replace_counter_id` set): find the active device on that
  counter, **revoke it** (`disabled = 1`), insert a new row **reusing the
  same `counter_id`** so shift reports/audit stay continuous across the swap.

Either way: mint `device_id` + `device_secret`, store only the bcrypt hash,
return the secret once.

| Failure | Code |
|---|---|
| bad manager creds | `Unauthenticated` ("invalid credentials") |
| authenticated but not `owner` | `PermissionDenied` |
| `replace_counter_id` set but no active device on it | `NotFound` |

### 5.2 `Login` — cashier or manager, on a registered device

```
LoginRequest {
  string device_id = 1;
  string device_secret = 2;
  string username = 3;
  string password = 4;           // never logged
}
LoginResponse {
  string access_token = 1;       // HS256 session JWT (§3)
  google.protobuf.Timestamp expires_at = 2;
  string tenant_id = 3;
  repeated string roles = 4;
  string user_display_name = 5;
  string store_id = 6;
  string counter_id = 7;         // from the device record, not the client
}
```
Server: validate device (exists, not disabled, secret matches, tenant
matches) → authenticate user (bcrypt, not disabled) → mint session JWT with
claims from §3 (`counter_id`/`store_id`/`device_id` from the **device**, not
the request).

| Failure | Code |
|---|---|
| unknown/disabled device or bad secret | `Unauthenticated` |
| bad user creds / disabled user | `Unauthenticated` ("invalid credentials") |

### 5.3 `RefreshSession` — NOT INCLUDED (decided)
No refresh token. The 16h session TTL covers a shift; the cashier re-logs in
at expiry. Dropped from the contract entirely (not merely deferred).

---

## 6. Enforcement — auth middleware & phased rollout

A Connect **interceptor** verifies the `Authorization: Bearer` session token
and injects `*auth.Claims` into the request context. Handlers read identity
from claims, **not** the request body.

**Procedure policy:**
- *Unauthenticated:* `AuthService.RegisterDevice`, `AuthService.Login`,
  `/healthz`, `/readyz`.
- *Any valid session:* reads (ListItems, GetSale, inventory queries),
  reservations.
- *Mutations* (`Finalize`, `RefundSale`, `Void`, item/tax edits): valid
  session; server **overrides** `store_id`/`counter_id`/`cashier_id` from
  claims (ignores/validates client-sent values).
- *Owner-only:* cashier management, local reports subset — gated on
  `roles ∋ owner`.

**Phased rollout — don't break the running desktop.** Mirror how
`SYNC_JWT_SECRET` is optional today:
1. Ship `AuthService` + middleware in **permissive mode** (verify a token if
   present; allow if absent). Desktop keeps working unauthenticated.
2. Desktop auth slice lands: terminals register, log in, send Bearer tokens.
3. Flip middleware to **required** (env flag, e.g. `POS_REQUIRE_AUTH=1`);
   client identity fields become token-derived. Single cutover.

---

## 7. Security notes (ties to `docs/security-rules.md`)

- Passwords/secrets **never logged** (mirror `auth_login.go`: log username
  only, generic failure message, no enumeration).
- `device_secret` shown **once**; only its bcrypt hash is stored.
- `POS_SESSION_SECRET` required when auth is enforced; **fail-secure** if
  enforcement is on and the secret is empty (don't silently accept). Reuse
  `auth.NewVerifier`'s `ErrEmptySecret` posture.
- HS256 only; reject other algs at the keyfunc layer (as `auth.Verify` does).
- Loopback/LAN: tokens still matter on a separate-box topology where the LAN
  isn't trusted; TLS for the LAN hop is a separate (deferred) concern.

---

## 8. Rollout plan (server slices, before desktop §6 step 3)

1. **Migrations 000011/000012** + `users`/`devices` stores (bcrypt). Seed an
   owner for UAT.
2. **Promote `auth.Issuer`/`Verifier`/`Claims`** to a shared package; extend
   claims with `store_id`/`counter_id`/`device_id`.
3. **`auth_service.proto`** + codegen (Go + Dart) + `AuthService` handler
   (`RegisterDevice`, `Login`).
4. **Auth interceptor** in permissive mode; wire into `api.NewMux`.
5. *(Later, with/after desktop)* flip to required; **cloud→store user sync**
   (catalog-pull analogue).

---

## 9. Decisions (resolved 2026-06-14)

1. **Session TTL & refresh** — fixed **16h** TTL (`POS_SESSION_TTL`),
   **no refresh token**; re-login at expiry. (§3, §5.3)
2. **Re-registering a counter** — **replace + revoke old** device, reusing
   the `counter_id` for report continuity. (§5.1)
3. **Manager gate for `RegisterDevice`** — **`owner` role**. (§5.1)
4. **User provisioning** — **cloud→store user sync** (catalog-pull
   analogue); local seed for UAT interim. (§4, §8 step 5)
5. **`counter_id` allocation** — **server-assigned** (sequential per store);
   manager never picks. (§4, §5.1)

All open items closed — the contract is ready to implement pending a final
read.

---

*Next: implement §8 slices 1–4 (server), then unblock the desktop auth slice.
Enforcement flip (§6 step 3 / §8 step 5) is coordinated with the desktop
sending tokens.*
