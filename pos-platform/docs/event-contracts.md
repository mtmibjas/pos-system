# Event Contracts

> Events describe **things that happened**. They are append-only, idempotent, and the only thing we sync.

The Protobuf source of truth is `packages/proto/pos/v1/events.proto`. This doc is the human-readable companion.

## Envelope

Every event flows through `pos.v1.EventEnvelope`:

| Field             | Required | Meaning |
|-------------------|----------|---------|
| `operation_id`    | yes      | UUID — idempotency key |
| `event_type`      | yes      | string name, e.g. `sale_created` |
| `schema_version`  | yes      | uint32; bump when payload shape changes |
| `tenant_id`       | yes      | resolved at origin from JWT |
| `origin`          | yes      | node + store + counter ids |
| `clock`           | yes      | Lamport (counter + node_id) |
| `occurred_at`     | yes      | wall-clock at origin (diagnostics only — never trusted for ordering) |
| `payload`         | yes      | typed Event* message packed in `Any` |

## Naming

- `snake_case` past-tense verbs: `sale_created`, `payment_added`, `inventory_adjusted`, `stock_transferred`, `payment_refunded`, `sync_completed`, `sync_failed`, `user_logged_in`, `inventory_locked`, `refund_completed`.
- Never present-tense (no `create_sale`) and never imperative (no `process_payment`).

## Versioning

Schema changes follow these rules:

| Change                                          | Allowed without version bump? | Notes |
|-------------------------------------------------|-------------------------------|-------|
| Add a new optional field                        | Yes                           | Default zero value must mean "old behavior". |
| Remove a field                                  | No                            | New schema_version + new proto package. |
| Rename a field                                  | No                            | Same as remove. |
| Change a field's type                           | No                            | Same as remove. |
| Add a new event type                            | Yes                           | New message in `events.proto`. |
| Tighten validation (e.g. require previously-optional) | No                      | Counts as breaking. |

Breaking change → new proto package version (`pos.v2`). Old version stays until all clients have migrated. Clients and servers MUST tolerate seeing future `schema_version` values they don't understand (forward-compat: skip or surface for manual review, never crash).

## Transport

| Event class               | Transport                            |
|---------------------------|--------------------------------------|
| Domain events (sale, payment, inventory, etc.) | sync queue → cloud via REST+proto |
| Real-time UI updates (`InventoryUpdate`, `CartUpdate`) | WebSocket (`pos.v1.WsMessage`) |
| Sync status (`sync_started`, `sync_failed`)     | local-only log + observability sink (not synced) |
| Auth events (`user_logged_in`)                  | included in sync batch |

## Ordering guarantees

- **Within one origin node**: strict per-`operation_id` ordering (Lamport monotonic). The cloud will refuse to apply an op from a node with a lamport lower than the highest already-seen, unless it's a known late-arrival within the configured replay window.
- **Across origin nodes**: no global order guarantee. Multi-counter consistency is handled at the local-store-server (one node owns the LAN). Cross-store consistency is eventually consistent — readers MUST tolerate that.

## Required logged events (Development Guide §19)

These MUST be emitted and observable:

- `sale_created`
- `payment_added`
- `payment_refunded`
- `inventory_adjusted`
- `stock_transferred`
- `sync_started`
- `sync_completed`
- `sync_failed`
- `inventory_locked`
- `refund_completed`
- `user_logged_in`

## Conflict resolution as new events

When the cloud detects a conflict (e.g. two stores claim the same transfer was received), it does NOT edit the past. It emits a **new** compensating event (`stock_transfer_disputed`, `inventory_reconciled`, etc.) that an operator can review.

## Tests required

- Unit: envelope roundtrip (proto encode/decode), forward-compat on unknown schema_version.
- Integration: replay of a recorded event stream rebuilds the same derived state.
