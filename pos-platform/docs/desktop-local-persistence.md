# Desktop POS — Local Persistence & Crash Recovery (§6 step 6)

> **Status: IMPLEMENTED (2026-08-02) — 6c deferred.** Landed: **6a** SQLite
> adapter (`lib/data/local_db.dart` via `sqflite_common_ffi`) + config store
> (`terminal_config_store.dart`); **6b** cart-draft store
> (`cart_draft_store.dart`) + `CartController` checkpoint-on-mutation &
> crash-recovery hydrate + stable `sale_id` on `CartState`; **6d-1**
> write-gating in `finalize_controller` (block finalize when `unreachable`,
> surfaced as `FinalizeBlockedException`) + clear-draft-on-success; **6d-2**
> `pending_finalize_store.dart` (persist-before-call + JSON serde), finalize
> keeps-on-ambiguous / clears-on-definitive, and `pending_finalize_controller`
> (auto-replay on the reachable edge + manual "Retry now" banner in the nav
> shell). Tests: `local_persistence_test.dart` (9) + `finalize_gating_test.dart`
> (2) + `pending_finalize_test.dart` (7); full suite 97/97 green, analyze clean.
> **6c** read cache deferred by decision (§6 Q4) — §4 retained as its spec.
> Design for migration step 6 of
> `docs/desktop-architecture.md` (§4.6 / §4.7). No code yet. Consumes the
> `ConnectionHealth` signal shipped in step 5. Elevates `apps/desktop-pos` —
> *add a persistence layer + gate writes*, no rewrite.

---

## 1. What this slice delivers

Four capabilities, in dependency order (proposed as sub-slices 6a–6d so the
app stays shippable and reviewable at each step):

| Sub-slice | Capability | Architecture ref |
|---|---|---|
| **6a** | SQLite persistence adapter (schema, migrations, one `LocalDb` port) + `TerminalConfig` read/write through it | §4.6 |
| **6b** | In-progress **cart draft** checkpoint + crash-recovery restore on launch | §4.6 |
| **6c** | **Local read cache** (catalog/items/prices/tax + last-known availability) — advisory, never authoritative | §4.6 |
| **6d** | **Write-gating** on `ConnectionHealth` (block finalize when unreachable) + **stable idempotency keys** for the ambiguous-response reconnect-retry | §4.7 |

> **Sequencing note.** 6a→6b→6d is the crash-recovery + consistency core and
> is self-contained. 6c (read cache) is the largest and only *enhances*
> degraded-mode usability — it can land last, or be split to just-in-time
> when P7 needs fast catalog reads. Flagged as **Q4** below.

---

## 2. The persistence engine (6a)

**Decided in the architecture doc: SQLite (`sqflite`).** The wrinkle: plain
`sqflite` is mobile-only. On desktop (our Windows-primary + macOS targets)
SQLite runs via **`sqflite_common_ffi`** with `databaseFactoryFfi` over the
bundled SQLite C library. Same SQL/API surface, desktop-capable. (See **Q1**.)

- New deps: `sqflite_common_ffi`, `path_provider` (for the DB directory).
- **One `LocalDb` port** (a thin Dart interface) in the data layer; the
  concrete adapter opens the DB in the OS app-support dir
  (`getApplicationSupportDirectory()/pos_desktop.db`). Tests inject an
  **in-memory** DB (`inMemoryDatabasePath`) — no files, fully deterministic,
  preserving the "runs without a server/hardware" property.
- Schema versioning via `onCreate`/`onUpgrade`, mirroring the store server's
  own migration discipline. Initial schema: `terminal_config`, `cart_draft`,
  `cart_draft_line`, `pending_finalize`, and the 6c cache tables.
- **The session token stays OUT of SQLite** — it remains in
  `flutter_secure_storage` (§4.2). SQLite holds only non-secret operational
  state.

### Config through the DB
`terminalConfigProvider` today returns hardcoded defaults (`config.dart:43`).
This slice makes it read a persisted row when present, else fall back to the
defaults. **Writing** the config is the provisioning flow's job (step 7) — 6a
only adds the read path + a `saveConfig()` the provisioning screen will call
later. No behavior change until something writes a row.

---

## 3. Cart draft & crash recovery (6b)

The cart (`cart_controller.dart`) is keepAlive but **in-memory** — a crash or
power blip mid-sale loses it. Fix:

- **Checkpoint on every mutation.** `CartController`'s `addLine` / `setQuantity`
  / `removeLine` / `clear` / `replaceLines` already replace state wholesale —
  the single choke point. After each, persist the draft (serialize `CartLine`s:
  sku, description, `Money`{currency,units,nanos}, taxCategoryId, quantity).
  Cart mutations are human-paced, so per-mutation writes are cheap (see **Q3**
  if we ever want debounce).
- **One active draft per (store, counter).** Keyed by terminal identity so a
  relaunch restores *this* terminal's open sale.
- **Restore on launch.** On `CartController.build()`, load the persisted draft
  (if any) instead of `const CartState()`. The operator returns to exactly the
  unfinalized cart they had.
- **Clear on finalize.** The draft row is deleted once a sale finalizes
  (the receipt "new sale" path) — not before, so a crash *during* the receipt
  step still recovers the just-sold cart if finalize hadn't completed.

---

## 4. Local read cache (6c) — advisory, never authoritative

A SQLite copy of catalog/item/price/tax-category rows plus **last-known**
availability. **Hard rule (from §4.6): the cache is advisory and never
authorizes a sale** — finalize authorization is always live on the server
(§4.7). Two jobs: (1) make the read-only degraded mode usable (browse/lookup
when the server is unreachable); (2) fast, blip-resilient normal reads.

- Kept warm by the **existing realtime WS** (`realtime.dart` — catalog +
  `inventory_available_changed`) plus a **snapshot fetch on (re)connect**; the
  high-water lamport replay means a reconnecting terminal catches up misses.
- Item/inventory repositories read cache-first, then refresh from the server;
  a **staleness marker** feeds the UI banner.
- This is the sub-slice that touches the most existing controllers
  (items/inventory/lookup), hence the "land last / just-in-time" option (**Q4**).

---

## 5. Write-gating + ambiguous-response retry (6d) — the §4.7 core

### 5.1 Block finalize when unreachable
- Finalize/Refund actions consult `connectionHealthProvider` (step 5). When
  `unreachable`, the action is **disabled** with a clear non-failure message
  ("Cannot finalize — store server unreachable. Your cart is saved.") The
  draft is already safe in SQLite (6b). When health returns to `reachable`,
  the action re-enables and proceeds against the **live** oversell guard — so
  **stock never goes negative**.
- Enforced in the **controller**, not just the button (domain-level gate,
  consistent with role-policy §4.2) — the UI disable is a mirror.

### 5.2 Stable idempotency keys (correctness fix)
Today `finalize_controller.dart:104` mints `saleId`/`lineIds`/`paymentId`
*inside* `_submit`, so a retry would mint **new** keys and the server would
treat it as a **different** sale — defeating idempotent replay. Fix:

- **Mint the sale's idempotency keys when the draft is created** (first line
  added) and **persist them with the draft**. All retries of that logical sale
  reuse the same keys → the server replays its prior result instead of
  double-applying. (This is what makes §4.6's "ambiguous response is safe"
  actually true.)

### 5.3 Bounded reconnect-retry (NOT an offline queue)
- Finalize is only *attempted* while reachable (5.1). The one durability
  concern is an **ambiguous response**: the request reached the server but the
  reply was lost. Before calling finalize, write a **`pending_finalize`** row
  (the minted request); on a clean success clear it; on an ambiguous
  transport failure keep it and offer retry (auto on the health-reachable
  edge, or a manual "retry last sale"). Because the keys are stable (5.2), the
  retry is a safe replay.
- **At most one** `pending_finalize` at a time — we never hold a completed-
  but-unsent sale (that's the forbidden offline queue). This is a bounded
  retry of a single in-flight write.

---

## 6. Decisions (resolved 2026-08-02)

- **Q1 — SQLite driver:** **`sqflite_common_ffi`** (`databaseFactoryFfi`) —
  honors the prior "sqflite" decision, same API, Windows+macOS capable.
- **Q2 — idempotency-key lifetime:** **mint at draft creation, persisted**
  with the draft. Retries reuse them → safe server replay. This is the §4.6
  ambiguous-response enabler; requires refactoring `finalize_controller` to
  take the keys from the draft instead of minting in `_submit`.
- **Q3 — draft checkpoint cadence:** **per-mutation write** (cart is
  human-paced; simplest, smallest crash window).
- **Q4 — read-cache (6c) timing:** **defer.** Ship the core **6a + 6b + 6d**
  now (crash recovery + write-gating + safe retry). Build 6c just-in-time
  when P7 needs fast catalog reads. §4 below is retained as the 6c spec.

---

## 7. Test plan (server-free, ProviderScope overrides)

- **6a:** in-memory DB adapter opens/migrates; config read returns persisted
  row when present else defaults; round-trip save/read.
- **6b:** mutate cart → draft persisted; new container with same DB restores
  the cart; finalize clears the draft; crash-mid-receipt still recovers.
- **6d:** finalize **disabled** when health `unreachable`, cart draft intact;
  re-enabled on `reachable`; keys stable across two submit attempts (same
  saleId sent); `pending_finalize` written before call, cleared on success,
  retained + replayed on ambiguous failure.
- **6c (if in scope):** cache serves reads when server unreachable with a
  staleness marker; WS event updates cache; snapshot-on-reconnect refresh.

---

## 8. Scope boundary (what step 6 does NOT do)

- **No provisioning UI** — step 7 writes the config row 6a can read.
- **No hardware / ESC-POS** — step 8.
- **No offline-sales queue** — explicitly forbidden (§4.7); only the bounded
  single-pending reconnect-retry (5.3).
- **No Windows runner** — step 9 (though `sqflite_common_ffi` is chosen with
  Windows in mind).

*After approval: implement 6a→6b→6d (and 6c per Q4), each a commit with tests
green, then step 8.*
