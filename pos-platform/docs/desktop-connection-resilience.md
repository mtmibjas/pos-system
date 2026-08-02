# Desktop POS — Connection Health & RPC Resilience (§6 step 5)

> **Status: IMPLEMENTED (2026-08-02).** Landed as `lib/domain/connection_health.dart`,
> `lib/core/{backoff,rpc_policy,connection_health_provider}.dart`, transport
> interceptor wiring, realtime `connected` edges, and the nav-shell chip —
> tests in `test/{backoff,rpc_policy,connection_health}_test.dart` (full suite
> 80/80 green). Design for migration step 5 of
> `docs/desktop-architecture.md` §6. No code yet. Elevates the existing
> `apps/desktop-pos` — *refactor + add, not rewrite*. This slice adds the
> **health signal** and **RPC resilience**; it deliberately does **not**
> gate writes yet — write-gating on unreachable (§4.7) is step 6, which
> consumes the signal this slice produces.

---

## 1. Why this slice, why now

Today (honest state):
- **WebSocket** is resilient — reconnect + exp-backoff + jitter + high-water
  replay (`core/realtime.dart:154`), but it keeps its connection state
  **private**. Nothing else can tell if the server is reachable.
- **Unary RPC** has **no** resilience — `transport.dart` builds a bare
  Connect transport: no timeout, no retry, no error classification. A dead
  or slow store server → an unbounded hang or a raw Connect exception
  bubbling into a controller.
- There is **no shared notion** of "is the store server reachable?", so the
  nav shell can't show status and step 6 has nothing to gate finalize on.

This slice creates that shared signal and makes RPC fail *fast and legibly*.

---

## 2. The three states (domain model)

`ServerReachability` — a plain Dart enum in the domain layer:

| State | Meaning | Entered when | Left when |
|---|---|---|---|
| `reachable` | Recent confirmed contact | any RPC success **or** WS connected | a failure/timeout occurs |
| `degraded` | Uncertain — reconnecting or one recent failure, not yet confirmed down | WS drops & is retrying, **or** 1st RPC failure | success → `reachable`; confirmed-down → `unreachable` |
| `unreachable` | Confirmed down | connection-refused, **or** ≥N consecutive failures, **or** health probe fails | any success → `reachable` |

`degraded` is the honest middle: we don't flip straight to a scary "OFFLINE"
banner on a single blip, but we also don't claim health we can't prove.

```dart
enum ServerReachability { reachable, degraded, unreachable }

@immutable
class ConnectionHealth {
  final ServerReachability state;
  final DateTime? lastOkAt;        // last confirmed contact
  final int consecutiveFailures;
  final String? lastErrorSummary;  // human-readable, never secrets
}
```

> **Design choice — one health object for the whole store server, not
> per-endpoint.** The store server is one process; reachability is a
> property of "can I talk to it," not of individual RPCs. Simpler, and it's
> what the shell indicator and step-6 gate both want.

---

## 3. Signal sources → the aggregator

A keepAlive `connectionHealthProvider` (Riverpod `Notifier`) is the single
sink. Three sources feed it:

1. **RPC outcomes** (primary). Every unary call reports success or a
   classified failure (§4). Success → `reachable`, `consecutiveFailures=0`,
   stamp `lastOkAt`. Failure → increment, transition per the table.
2. **Realtime channel** (secondary, free liveness). The WS is *always trying*
   to connect, so its connected/disconnected edges are a continuous liveness
   probe at zero extra cost. To expose it, `RealtimeChannel` gains a
   `Stream<bool> get connected` (a small, additive change — the reconnect
   loop already knows). WS connected → nudge toward `reachable`; WS dropped
   & retrying → nudge toward `degraded` (never straight to `unreachable`
   on WS alone — RPC is the authority for "confirmed down").
3. **Active health probe** (only while not `reachable`). When state is
   `degraded`/`unreachable` and no RPC traffic is flowing, poll
   `GET /healthz` (the endpoint `auth-smoke.sh` already relies on) on a
   backoff. This recovers the indicator even on an idle terminal. When
   `reachable`, the probe is **off** — real traffic is the signal.

> `lastOkAt`/`stamp` need a clock. Use an injected `DateTime Function()`
> (defaults to `DateTime.now`) so tests are deterministic — mirrors the
> server's `clock` package.

---

## 4. RPC resilience layer

Attach behavior to **all** unary calls via a Connect **interceptor** added in
`transport.dart`, plus a per-call **policy** the repository chooses.

### 4.1 What the interceptor always does
- **Typed timeout** — a default deadline (proposed **5 s** for reads /
  **10 s** for writes) so no call hangs forever. Configurable per call.
- **Error classification** → maps the Connect error code to (a) a health
  signal and (b) a retryability verdict:
  - `unavailable`, `deadlineExceeded`, transport/socket errors →
    **transient**, counts as a reachability failure, retryable-if-idempotent.
  - `unauthenticated`/`permissionDenied` → **not** a reachability failure
    (server answered!) → session concern, surfaced up, no retry.
  - everything else (`invalidArgument`, `failedPrecondition` e.g. oversell,
    `alreadyExists`) → **business** outcome, `reachable`, surfaced, no retry.
- **Reports** the outcome to `connectionHealthProvider`.

### 4.2 Retry — idempotent calls only, opt-in per call
- Reads (catalog, lookup, inventory) are naturally idempotent → **retry**
  with bounded backoff+jitter (reuse the realtime backoff shape), cap ~3
  attempts within the deadline budget.
- **Writes are NOT auto-retried in this slice.** Our mutating calls mint
  client-side idempotency keys (`finalize_controller.dart`), so retry is
  *safe*, but the **ambiguous-response** handling (retry a Finalize whose
  reply was lost) is deliberately **step 6's** job (§4.7 / architecture
  §4.6). Here, a failed write surfaces a clean, actionable error. Keeping
  the write-retry decision in one place (step 6) avoids double-owning it.

### 4.3 Shared backoff utility
Extract the exp-backoff+jitter math currently inline in
`realtime.dart:181-188` into `core/backoff.dart` so both the realtime loop
and the RPC retry use one tested implementation (the architecture doc calls
for exactly this generalization). Realtime is refactored to use it — behavior
identical, now covered by its own unit test.

---

## 5. UI — always-visible status indicator

The nav shell (`features/shell/nav_shell.dart`) gains a small status chip
that `watch`es `connectionHealthProvider`:

- `reachable` → subtle/green (or hidden-when-healthy; **open Q6.1**).
- `degraded` → amber "Reconnecting…".
- `unreachable` → red "Store server unreachable" + last-ok time.

No blocking dialogs — it's ambient. Finalize-disabling UX comes in step 6.

---

## 6. Decisions (resolved 2026-08-02)

- **Q6.1 — indicator when healthy:** **always show a green "Connected"
  chip.** Cashiers get a positive affirmation the till is live; the chip
  turns amber/red on degrade/outage.
- **Q6.2 — timeouts:** **5 s read / 10 s write**, configurable via
  `TerminalConfig` later.
- **Q6.3 — confirmed unreachable:** **immediately on connection-refused;
  otherwise after 2 consecutive transient failures.**
- **Q6.4 — idle health-probe:** **backoff 1 s → 15 s** with the same jitter
  as realtime, active only while not `reachable`.

---

## 7. Deliverables & test plan

New/changed files (proposed):
- `lib/domain/connection_health.dart` — enum + `ConnectionHealth` value type.
- `lib/core/connection_health_provider.dart` — the aggregator Notifier.
- `lib/core/backoff.dart` — extracted backoff utility (+ realtime uses it).
- `lib/core/rpc_policy.dart` — interceptor + per-call policy; wired in
  `transport.dart`.
- `lib/core/realtime.dart` — add `Stream<bool> get connected`; use `backoff.dart`.
- `lib/features/shell/nav_shell.dart` — status chip.

Tests (all server-free, via `ProviderScope` overrides — preserves the
existing property):
- Health transitions: success→reachable; 1 fail→degraded; connection-refused→
  unreachable; recovery→reachable. Table-driven.
- RPC interceptor: read times out → transient → health failure + retried;
  business error (oversell) → reachable + surfaced, no retry; unauthenticated
  → surfaced, health untouched.
- Backoff utility: monotonic growth, cap respected, jitter bounded.
- Realtime still passes after refactor (regression).

---

## 8. Scope boundary (what this slice does NOT do)

- **No write-gating / finalize-disable** — step 6 (§4.7).
- **No SQLite / read-cache / cart-draft** — step 6.
- **No ambiguous-response finalize retry** — step 6.
- **No hardware, no Windows runner** — steps 8/9.

*After approval: implement §7 top-to-bottom, one commit, tests green, then
proceed to step 6.*
