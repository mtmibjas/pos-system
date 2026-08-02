# Desktop POS — Architecture Baseline

> **Status: DRAFT for review.** This is the first per-app architecture
> baseline (the desktop app sets the standard; other apps get baselined
> just-in-time). It defines the layering and the six structural pillars
> that the existing `apps/desktop-pos` must be **elevated** to match —
> *refactor, not rewrite*. No new product features are designed here;
> feature screens (LK invoicing, parties, purchases) are built **on** this
> spine later.

---

## 1. Purpose & scope

The desktop POS is the **offline-capable shop terminal**. The organizing
rule is the **offline boundary**: this app owns everything that must work
*without internet* at the shop, talking only to the local store server
(`apps/local-store-server`). Cloud/cross-store concerns (consolidated
reports, tenant admin, multi-store) live in the web `admin-dashboard` and
are explicitly **out of scope** here.

**Form factor decided:** one binary, **role-adaptive** —
- *Cashier login* → billing subset (sell, lookup, refund/void, day-close-as-permitted).
- *Owner login* → full offline-capable suite (items, parties, purchases, cashier mgmt, local reports).

**Platforms:** **Windows-primary, macOS also supported.** (Supersedes the
Phase-2 macOS-only decision.) The dev machine is macOS; **the user must
validate Windows builds and real hardware on actual Windows terminals.**

### Inherited golden constraints (from `docs/architecture.md`)

These are non-negotiable and shape every decision below:

1. **Local store always works / internet is optional** → the unit that
   "always works" is the **store server + its terminals as a system**, not
   a lone terminal. With the **cloud** unreachable the app fully functions
   (sell, print, reconcile) — that's the headline guarantee. With the
   **store server** unreachable the terminal **degrades explicitly to
   read-only** (browse/lookup from local cache; finalize blocked, §4.7) —
   it does *not* sell independently. Availability of the store server is
   bought on the server side (resilience/topology), not by making each
   terminal an authority.
2. **Local operations are the source of truth; sync is idempotent** →
   every mutating call mints client-side idempotency keys (already done in
   `finalize_controller.dart`) so retries are safe.
3. **Multi-counter consistency is owned by the store server** → the
   desktop **domain layer is intentionally thin.** It does *not* re-derive
   business invariants the server owns; it orchestrates, validates input,
   and renders. Cart math, money formatting, tender rules, and role policy
   are the only real client-side domain logic.
4. **Finalized invoices never change** → reversal is a new event
   (RefundSale / Void), never a destructive edit. Already honored.

---

## 2. Current state (honest gap map)

What exists today (Phases 2 & 4) and where it stands against this baseline.
*Cited line numbers are point-in-time — verify before editing.*

| Pillar | Today | Gap |
|---|---|---|
| **Layering** | screen → Riverpod controller → generated Connect client directly (`finalize_controller.dart:102`) | No domain/data seam. Controllers import `pos_sdk` proto types and call clients inline. |
| **Provisioning / config** | hardcoded consts `kLocalServerUrl`, `kStoreId`, `kCounterId`, `kCashierId` (`config.dart:10-20`) | No per-terminal provisioning; identity is fake. |
| **Auth / session / roles** | none | No login, no session, no role gating. |
| **Nav shell** | `main.dart:28` boots directly into `ItemPickerScreen` | No shell, no module slots, no role-adaptive nav. |
| **Hardware** | OS-level HTML/PDF print only; ESC/POS deferred | No printer/scanner/cash-drawer/customer-display abstraction. |
| **Connection resilience** | WebSocket has reconnect + backoff + jitter + high-water replay (`realtime.dart:154`) | Unary RPC has **no** resilience; store-server-unreachable is unhandled. |
| **Crash recovery** | none (cart is in-memory Riverpod state) | An in-progress sale is lost on crash. |
| **Cross-platform** | `macos/` only | No `windows/` runner; no per-OS hardware adapters. |

**Good bones to preserve, not discard:**
- Feature-folder layout (`lib/features/<feature>/...`).
- Riverpod codegen everywhere — keep it.
- The `transportProvider` seam (`transport.dart:25`) was *designed* to be
  swapped from a const to a runtime Provider. We cash that in.
- The reconnect/backoff/high-water pattern in `realtime.dart` — generalize
  it into a shared connection-health concept rather than reinventing it.
- Test injection via `ProviderScope` overrides — every new layer must keep
  this property.

---

## 3. Target layering — UI → State → Domain → Data

```
┌──────────────────────────────────────────────────────────────┐
│  UI            screens / widgets  (lib/features/<f>/...)       │
│                role-aware nav shell                            │
├──────────────────────────────────────────────────────────────┤
│  STATE         Riverpod controllers — orchestration only       │
│                (no proto types leak above this line)           │
├──────────────────────────────────────────────────────────────┤
│  DOMAIN        thin: cart math, money, tender rules, role       │
│                policy, session model, plain Dart value types   │
├──────────────────────────────────────────────────────────────┤
│  DATA (ports)  Repositories + Hardware ports + Connection      │
│   ├─ RPC repositories  → wrap generated Connect clients         │
│   ├─ Local persistence → settings, session, offline/recovery   │
│   ├─ Realtime channel  → existing RealtimeChannel               │
│   └─ Hardware ports    → printer / scanner / drawer / display   │
├──────────────────────────────────────────────────────────────┤
│  ADAPTERS      Connect transport · OS keystore · SQLite/file ·  │
│                per-OS hardware drivers (win / macos)            │
└──────────────────────────────────────────────────────────────┘
                            ↓ HTTP + WebSocket
                  Local Store Server (Go, same-machine OR LAN)
```

**The rule that makes this real:** *the RPC service surface does not cross
the DATA→STATE boundary.* Repositories own the generated clients, the
transport, and request/response construction; controllers depend on a
repository interface, never on `SaleServiceClient` / `*Request` / the
transport. This is the change that makes screens testable without a
transport and lets the server contract churn without rippling into the UI.

> **Adopted value types (decided 2026-06-14, D2):** stable *generated
> message DTOs* — `Money`, the read-only `Invoice`, and small response
> envelopes — MAY cross the boundary as view-models. Hand-rewriting them
> into parallel Dart types is churn without near-term benefit, and the
> decoupling that matters (from the RPC *client*, not from value DTOs) is
> already achieved. So `controllers never import pos_sdk/gen` is relaxed to
> *never import the RPC client/request types*; importing a value DTO like
> `Money` is fine. Revisit if a DTO proves unstable.

**Keep the domain thin (deliberate).** The store server owns invariants
(golden rule #8/#3). We are not building a second source of truth on the
desktop. Domain here = the minimum the client legitimately decides:
input validation, cart arithmetic, money/precision, tender composition,
and **role policy** (what this session may do).

---

## 4. The baseline spine — six pillars

Sequenced in dependency order; the migration plan (§6) follows the same order.

### 4.1 Per-terminal provisioning & config

Kills the hardcoded consts. A terminal is **provisioned once** with:
- store server endpoint(s) (same-machine `127.0.0.1` *or* a LAN host),
- `store_id`, `counter_id` (this terminal's identity within the store),
- terminal display name.

This becomes a `TerminalConfig` loaded at startup from local persistence
(see §4.6), exposed as a Riverpod provider. `transportProvider` and
`defaultRealtimeUrl()` read it instead of `kLocalServerUrl` — the seam
that `transport.dart` already anticipated.

**Provisioning is a manager-gated device registration (decided).**
First-run with no config → a provisioning screen where a **manager/owner
authenticates once** (server address + manager credentials), the terminal
is **registered as a device** (binding `store_id` + `counter_id` and
receiving a device credential/token), and the result is persisted. After
that, the terminal boots straight to the cashier login (§4.2) with no
manager involvement. Re-provisioning requires manager auth again.

> `cashier_id` is **not** terminal config — it comes from login (§4.2).
> Multiple terminals per shop is the assumed topology (decided), so each
> device registration is distinct and multi-counter realtime (§4.5) is
> exercised from day one in UAT.

### 4.2 Auth / session / roles

UAT model: **cashier identity per terminal** (not shift-shared via login
switching, but sales must carry *who sold it* and support shift reports).

Two distinct auth acts, by design:
- **Manager login** (provisioning, §4.1) — owner/manager authenticates to
  register the device. Rare, high-privilege.
- **Cashier login** (daily use) → a `Session { userId, displayName, role,
  token }`. Role ∈ {`cashier`, `owner`} (extensible).

- Session held in a keepAlive Riverpod provider; token persisted via
  **`flutter_secure_storage` (OS-keystore backed)** — decided — so a
  relaunch resumes without re-login until expiry/logout. Works on Windows
  (Credential Manager / DPAPI) and macOS (Keychain).
- `cashier_id` on `FinalizeRequest` (currently `kCashierId`) comes from the
  session. Shift open/close anchors to the session.
- **Role policy** is a domain concern: a `RolePolicy` object answers
  "may this session see/do X" and the nav shell + controllers consult it.
  No UI-only gating — controllers enforce too.

> ⚠️ **Server prerequisite — confirmed by inspection (2026-06-14):** the
> local store server has **no client auth/login endpoint and no users
> table today.** Its only JWT use is the sync worker minting tokens *to*
> the cloud (`internal/sync/jwtsource.go`). All login currently lives in
> `cloud-api` (`POST /v1/auth/login`, bcrypt + HS256 with tenant/roles,
> `internal/api/auth_login.go`; `users` table in migration `000003`).
>
> Therefore **Manager Login + Device Registration is net-new store-server
> work** and must ship as a server slice *before* the desktop auth slice
> (§6 step 3). Good news: `cloud-api/auth_login.go` is a clean reference
> to port (same bcrypt → HS256 shape), and HS256-with-shared-secret is
> already the store↔cloud convention. New server surface needed:
> a cashier/manager login endpoint **and** a device-registration endpoint
> (issuing the per-terminal device credential). Confirm the exact
> contract with the user when that server slice is scoped.

### 4.3 Role-aware nav shell + feature modules

Replace the direct-to-`ItemPickerScreen` boot with a **shell**:
- a left-nav (Vyapar-class full suite as the mental model, but **better
  UX, not a clone**) whose entries are filtered by `RolePolicy`;
- a `FeatureModule` registry so each feature declares its nav entry, route,
  and required role — the shell renders whatever is registered and
  permitted.

**Module slots (offline-boundary scoped).** Build the *slots* now even
though most features come later:

| Module | State today | Notes |
|---|---|---|
| Billing / Sell | exists (cart, tender, receipt) | move under shell |
| Item catalog | exists (item picker, inventory) | owner-editable later |
| Sale lookup / Refund / Void | exists | move under shell |
| Parties (udhaar) | **slot only** | built in P8 |
| Purchases / expenses | **slot only** | built in P9 |
| Local reports (subset) | **slot only** | day-close, shift, sales |
| Cashier management | **slot only** | owner-only |
| Settings / terminal | new | provisioning, printer test, about |

Detailed per-feature screens are designed at feature-build time
(breadth-now, depth-later).

### 4.4 Hardware ports & adapters

Hardware is a **first-class layer** of swappable interfaces (ports), each
with per-OS adapters. All four in scope:

| Port | Direction | Adapters (initial) |
|---|---|---|
| `ReceiptPrinter` | out | ESC/POS (USB/serial/network), OS HTML/PDF fallback |
| `BarcodeScanner` | in | HID keyboard-wedge (default); generalize today's `scan_buffer.dart` |
| `CashDrawer` | out | kick via printer; standalone USB/serial |
| `CustomerDisplay` | out | secondary window; pole/line display later |

Principles:
- Ports are plain Dart interfaces in the domain/data boundary; **no UI or
  controller talks to a driver directly.**
- Every port has a **`Noop`/simulated adapter** so the full app runs on the
  dev macOS box and in tests with no hardware attached.
- Adapter selection is per-terminal config (§4.1) + OS detection.
- ESC/POS (deferred since Phase 2) lands here as the first real adapter —
  it is the **adoption gate** for the LK invoicing/printing phase (P7).
- The scanner port wraps the existing keyboard-wedge buffer logic so
  scanning works the same whether focus is on the item picker or elsewhere.

### 4.5 Connection resilience to the store server

The server may be **same-machine or a LAN box**, and **must be tolerated
unreachable** at startup, mid-sale, and on reconnect. Today only the
WebSocket is resilient; unary RPC is not.

> **Two distinct "offline" states — do not conflate (this is the crux):**
> - **Cloud offline** — store server + terminals are a working local
>   island. Finalize hits the server synchronously, the server does the
>   locked, oversell-guarded ledger deduction (`inventory/store.go`) and
>   reservations coordinate counters. **Inventory deduction happens
>   normally.** This is the competitive advantage and 99% of "offline".
> - **Store server unreachable** — a genuine *degraded* mode, because the
>   store server **is** the multi-counter coordinator (golden rule #8).
>   No server → no reservation → no cross-counter coordination. This is
>   the case the write-policy below governs.

- A shared **`ConnectionHealth`** provider tracks reachable / degraded /
  offline, fed by both the realtime channel and RPC outcomes. The nav
  shell shows an always-visible status indicator.
- **RPC policy:** typed timeouts; bounded retry with backoff+jitter for
  *idempotent* calls (safe because we already mint idempotency keys);
  surface a clear, actionable error otherwise — never a silent hang.
- **Reads vs. writes split on reachability.** Reads (browse catalog,
  recall a sale) may serve last-known cached data with a staleness banner.
  **Inventory-affecting writes (Finalize, Refund) require a reachable
  server** — see the write policy in §4.7.
- **Startup:** unreachable server → app still loads to a usable, read-only
  state (last-known catalog from local cache where available) + a reconnect
  banner; provisioning/login flows degrade explicitly.
- Generalize `realtime.dart`'s backoff/high-water into a small shared
  reconnect utility rather than duplicating it.

### 4.6 Crash recovery & local persistence

A power blip or crash mid-sale must not lose the operator's work.

- **Local persistence adapter — SQLite (`sqflite`), decided** — backing
  `TerminalConfig`, the **in-progress cart draft**, and the **local read
  cache** (below). (The session *token* is the exception: it lives in
  `flutter_secure_storage`, not SQLite — §4.2.) SQLite mirrors the
  server's own storage model.
- Cart mutations checkpoint the draft so a crash/relaunch restores the
  open, *unfinalized* sale.
- **Local read cache (read-side replica) — explicit, not authoritative.**
  A SQLite copy of catalog, item details, prices, and tax categories, plus
  *last-known* inventory availability. Two purposes: (1) it makes the §4.7
  read-only degraded mode genuinely usable — a cashier can still browse and
  look up items/prices when the store server is unreachable (Case 2 below),
  they just can't finalize; (2) it makes normal reads fast and resilient to
  brief blips. **Hard rule: the cache is advisory and never authorizes a
  sale.** Cached availability may be stale; finalize authorization is
  always live on the server (§4.7) — this is what keeps the thin-domain +
  consistency-first decisions intact. Kept warm by the existing realtime
  WS channel (`realtime.dart` — catalog + `inventory_available_changed`
  events) plus a snapshot fetch on (re)connect; the high-water lamport
  replay means a reconnecting terminal catches up missed changes.
- **No durable offline-sales queue** (consequence of the §4.7 block-on-
  unreachable policy — we never hold a completed-but-unsent sale). The
  only durability concern at finalize time is an **ambiguous response**: a
  Finalize that *reached* the server but whose reply was lost. Because IDs
  are minted client-side (`finalize_controller.dart`), the retry is
  idempotent — the server replays its prior result instead of double-
  applying. That's a bounded reconnect-retry, not an offline write buffer.

---

### 4.7 Offline inventory policy — block finalize (DECIDED 2026-06-14)

When a terminal **cannot reach the store server**, it does **not** finalize
inventory-affecting sales. Rationale and behavior:

- **Why block, not queue-and-reconcile.** The store server is the sole
  inventory authority and multi-counter coordinator. Reservations —
  the anti-double-sell mechanism — are computed server-side
  (`Available() = on-hand − active reservations`, `inventory/store.go:115`)
  and the oversell guard **hard-rejects** by default (`store.go:88`).
  With the server gone there is no way to coordinate counters, so any
  offline sale risks cross-counter oversell whose only outcomes are
  (a) reject a completed sale at replay — violates *"completed sales are
  never rejected"* — or (b) silently let stock go negative. We avoid the
  dilemma entirely: **don't accept the write while blind.**

- **Behavior.** Cart building, item lookup, and recall stay available
  (read-only, served from the local cache §4.6, possibly stale). The
  **Finalize / Refund action is disabled** with a clear, non-failure
  message ("Cannot finalize — store server unreachable. Your cart is
  saved."). The cart draft is preserved in SQLite (§4.6); when
  `ConnectionHealth` (§4.5) reports the server back, finalize re-enables
  and proceeds with the **live** oversell guard — so **stock never goes
  negative.**

- **Blast radius — two cases, very different (the multi-counter answer):**
  - **Case 1 — one terminal isolated from a healthy server** (bad cable/
    wifi on one station). Only *that* terminal goes read-only; **every
    other counter keeps selling normally** — the server still coordinates
    them. Consistency risk ≈ zero (the isolated terminal sold nothing).
    Recovery is automatic: reconnect → WS high-water catch-up
    (`realtime.dart`) → cache refresh → finalize re-enables. This is the
    *common* case.
  - **Case 2 — the store server itself is down** (process crash, LAN box
    power loss). **No terminal can finalize — shop-wide sales stop.** The
    shared server is a **single point of failure** for selling; there are
    **no independent terminal sales during a multi-counter server
    outage**, by design — without a coordinator, two terminals would both
    sell the last unit. The read cache keeps lookup/prices alive so staff
    aren't blind. Recovery is *clean precisely because nothing sold
    offline*: restart → reconnect → catch-up → re-enable, **no
    reconciliation**. This SPOF is the cost of consistency-first; it's
    mitigated on the server (resilience/topology below), not by making
    terminals authorities.

- **The accepted cost** is *lost availability* during a true server outage
  (you can't sell until it's back). We pay this down on the **server**
  side, not the client:
  - Prefer the **same-machine** topology where viable — then "server
    unreachable" ≈ "machine down" ≈ terminal down anyway, so this rarely
    bites; the LAN-box topology is where a healthy terminal can outlive a
    dead server.
  - Treat store-server **resilience** (supervised auto-restart, health
    endpoint, fast recovery) as a first-class requirement — it is now the
    real availability guarantee, consistent with golden rule #1 (*the
    local store always works* = keep the local **server** alive, not turn
    each terminal into an authority).

- **Not foreclosed.** The server already exposes a per-store
  `allow_oversell` hook (`store.go:16`); a future "hybrid by item/store"
  policy could selectively permit offline sales for low-risk items. We are
  *not* building that now — block-finalize is the baseline.

## 5. Cross-platform (Windows + macOS)

- Add a `windows/` runner alongside `macos/`; keep all Dart business code
  OS-agnostic.
- OS-specific code lives **only** behind adapters (hardware drivers, secure
  storage, file paths). Selection by `Platform` checks at the adapter
  factory, never sprinkled through features.
- **Validation split:** assistant builds/runs cross-platform Dart on macOS;
  **user validates Windows builds + real printer/scanner/drawer drivers on
  actual Windows terminals.** Treat Windows hardware adapters as
  user-verified, not assistant-verified.

---

## 6. Migration plan — elevate, don't rewrite

Low-risk, ordered to keep the app shippable at every step. Each step is a
slice with tests; later steps unblock the LK feature work.

1. **Config seam** — introduce `TerminalConfig` provider; route transport +
   realtime URL through it; keep current values as defaults. *No behavior
   change, pure seam.* (Pillar 4.1)
2. **Repository seam** — wrap existing Connect clients in repositories
   returning domain types; move proto imports out of controllers. Do this
   feature-by-feature (start with sale/finalize). (Layering §3)
3. **Auth/session** — *gated on a server slice first:* build store-server
   manager-login + cashier-login + device-registration endpoints (port
   `cloud-api/auth_login.go`). Then desktop login + session provider +
   role policy; replace `kCashierId` with session identity. (Pillar 4.2)
4. **Nav shell + module registry** — wrap existing screens; add empty slots.
   (Pillar 4.3)
5. **Connection health + RPC resilience** — shared health provider, retry
   policy, status indicator. (Pillar 4.5)
6. **Local persistence + crash recovery** — SQLite config + cart-draft
   checkpointing; write-gating on `ConnectionHealth` (block finalize when
   unreachable, §4.7) + idempotent reconnect-retry. (Pillars 4.6/4.7)
7. **Provisioning UI** — first-run flow now that config + persistence exist.
   (Pillar 4.1)
8. **Hardware ports** — interfaces + Noop adapters first; ESC/POS printer
   adapter as the bridge into P7. (Pillar 4.4)
9. **Windows runner** — add `windows/`; user validates. (§5)

> Steps 1–4 are internal refactors with no user-visible change beyond
> login + shell; 5–9 add the resilience/hardware capabilities P7+ needs.

---

## 7. Testing strategy

Preserve the property that the whole app runs and is testable without a
server or hardware:
- Repositories and hardware ports are injected via `ProviderScope`
  overrides (as `transportProvider`/`realtimeChannelProvider` already are).
- Every hardware port ships a simulated adapter; tests assert against it.
- Connection-resilience paths get explicit tests using a fake repository
  that fails on demand: finalize **disabled** when unreachable with the
  cart draft preserved (§4.7); finalize re-enabled and oversell-guarded on
  reconnect; idempotent retry on an ambiguous (lost-reply) Finalize.
- Role policy is unit-tested independently of the UI.

---

## 8. Decisions & remaining prerequisite

**Resolved (2026-06-14):**

1. **Local persistence engine — SQLite (`sqflite`).** Config, cart draft,
   and local read cache (advisory, non-authoritative — §4.6). No offline-
   sales queue (consequence of §4.7). Token excepted → secure storage.
2. **Desktop login model — Manager Login + Device Registration.** Confirmed
   the store server has *no* client auth today; this is net-new server work
   to be built (porting `cloud-api/auth_login.go`'s shape) **before** the
   desktop auth slice. See the §4.2 callout.
3. **UAT topology — multiple terminals per shop.** Multi-counter realtime
   is exercised from the start; device registration is per-terminal.
4. **Secure token storage — `flutter_secure_storage` (OS-keystore backed).**
   Windows Credential Manager / macOS Keychain.

**One open prerequisite (server, not desktop):** scope and confirm the
exact **store-server login + device-registration contract** with the user
when that server slice is planned (request/response shapes, device
credential lifetime, how a registered device authenticates cashier logins).
This is the only thing that must be nailed down before §6 step 3 can begin;
everything else in the migration plan can proceed.

---

*Next after this doc is approved: elevate `apps/desktop-pos` per §6,
starting with the config seam. Then LK invoicing + ESC/POS printing (P7)
build on this baseline.*
