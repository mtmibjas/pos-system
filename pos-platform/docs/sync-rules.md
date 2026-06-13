# Sync Rules

> The sync engine is the heart of the system. Idempotency, ordering, and atomicity are non-negotiable.

## Core invariants

- Every operation has an **`operation_uuid`** (UUIDv4 or UUIDv7). It is the **only** idempotency key. Cloud dedupes on it.
- Operations are **append-only** in `operations_log`. They are never updated except for `sync_status` and `retry_count`.
- **Local completed operations are never rejected by the cloud** (Development Guide §11, §16). If the cloud disagrees, it surfaces the conflict as a new compensating event — it does not retroactively reject.

## `operations_log` (mandatory schema)

| Column          | Type      | Notes |
|-----------------|-----------|-------|
| `id`            | INTEGER PK| autoincrement; local ordering only |
| `operation_id`  | TEXT      | UUID, **UNIQUE**, indexed |
| `operation_type`| TEXT      | mirrors event_type, e.g. `sale_created` |
| `entity_type`   | TEXT      | `sale` / `payment` / `inventory` / … |
| `entity_id`     | TEXT      | UUID of the entity touched |
| `payload`       | BLOB      | serialized `EventEnvelope` (Protobuf) |
| `created_at`    | INTEGER   | unix nanos at origin (wall clock — see clock drift below) |
| `lamport`       | INTEGER   | logical clock counter at origin |
| `origin_node_id`| TEXT      | stable per-device install id |
| `sync_status`   | TEXT      | `pending` / `in_flight` / `acked` / `failed` |
| `retry_count`   | INTEGER   | bumped on each retry; capped (see Retry policy) |
| `last_error`    | TEXT      | last failure reason for diagnostics |
| `batch_id`      | TEXT      | UUID of the batch this op shipped in (nullable until shipped) |

Indexes: `operation_id` (UNIQUE), `(sync_status, created_at)`, `batch_id`.

## Batching (atomic groups)

Related operations MUST be batched and applied atomically. Canonical example: an invoice batch contains
- `SaleCreated`
- `PaymentAdded` (one or more)
- `InventoryAdjusted` (one per line)

Either the whole batch is applied at the cloud, or none of it is. The batch envelope is `pos.v1.SyncBatch`.

## Retry policy

- Exponential backoff with **full jitter**: `delay = rand(0, base * 2^attempt)`, base = 1s, cap = 5 min.
- `max_retry_count = 10` for transient errors. After that the operation is parked into a `failed` state and surfaced via observability (`sync_failed` event), **not silently dropped**.
- Permanent errors (4xx that aren't "RETRY_LATER") move straight to `failed` — no retry.

## Idempotency at the cloud

```
if exists(operation_id):
    return DUPLICATE   # safe — drop from local queue
else:
    apply(operation)
    persist(operation_id)
    return APPLIED
```

`DUPLICATE` is a success signal for the client (means "you can stop retrying me").

## Ordering

We use **Lamport clocks** (per-node monotonic counter) over wall-clock time. Cloud accepts out-of-order arrivals, then orders by `(lamport, origin_node_id)`. Wall-clock is recorded for human diagnostics only.

## Edge cases (MUST handle — Development Guide §13)

| Case                 | Handling |
|----------------------|----------|
| Duplicate sync       | Cloud returns `DUPLICATE`. Client clears from queue. |
| Out-of-order sync    | Cloud accepts; orders by lamport on read. |
| Partial sync failure | Batch is atomic — partial = whole batch retried. |
| Reconnect storms     | Jittered backoff. Server may return 429 with `Retry-After`. |
| Clock drift          | We never trust client wall-clock for ordering. Lamport wins. Cloud also logs the wall-clock skew. |
| Replay attacks       | Operations are signed (`SignedEnvelope`). Cloud rejects unsigned or replay-after-key-rotation. See `docs/security-rules.md`. |

## Failure surfacing

The system MUST emit observable events:
- `sync_started`, `sync_completed`, `sync_failed` — at the batch level.
- `inventory_locked` — when a multi-counter lock is held (see `docs/inventory-rules.md`).
- `refund_completed` — when a refund event is acknowledged.

Operators should be able to see, at a glance: "X operations pending, oldest is Y seconds old, Z failed permanently."

## Tests required before Phase 2 starts

- Unit: idempotency, retry math, batch atomicity, lamport ordering.
- Integration: sync retry, reconnect, duplicate replay, out-of-order arrival, multi-counter inventory race.
- Chaos: internet disconnect mid-batch, duplicate sync, power failure during write, server crash during ack.
