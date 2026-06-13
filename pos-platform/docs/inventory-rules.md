# Inventory Rules

> Inventory is an **append-only ledger**. Never `UPDATE stock SET quantity = …`.

## Core principle

Current stock-on-hand is **derived** from the sum of `inventory_movements`. It is never stored as a directly-writable value.

```
quantity_on_hand(sku, store)
    = SUM(delta) FROM inventory_movements
      WHERE sku = ? AND store_id = ? AND voided_at IS NULL
```

A cached/materialized snapshot may exist for read performance, but it is rebuildable from the ledger at any time. If snapshot disagrees with ledger, **ledger wins** and the snapshot is rebuilt.

## `inventory_movements` (mandatory schema)

| Column         | Type    | Notes |
|----------------|---------|-------|
| `id`           | INTEGER PK | local ordering |
| `movement_id`  | TEXT    | UUID, UNIQUE, indexed |
| `sku`          | TEXT    | |
| `store_id`     | TEXT    | |
| `counter_id`   | TEXT    | nullable (e.g. stock-take is store-level) |
| `delta`        | INTEGER | signed; **never zero** |
| `reason`       | TEXT    | `sale` / `receive` / `transfer_in` / `transfer_out` / `stock_take` / `shrinkage` / `refund` |
| `ref_type`     | TEXT    | `sale` / `transfer` / `stock_take` / `refund` |
| `ref_id`       | TEXT    | links to the originating entity |
| `occurred_at`  | INTEGER | unix nanos at origin |
| `lamport`      | INTEGER | logical clock |
| `origin_node_id`| TEXT   | |
| `voided_at`    | INTEGER | nullable; voiding is itself an append-only event (see Voiding below) |
| `voided_by_id` | TEXT    | `movement_id` of the voiding entry, when voided |

Indexes: `movement_id` (UNIQUE), `(sku, store_id)`, `(ref_type, ref_id)`.

## Voiding (correcting mistakes without violating append-only)

You never delete a movement. To correct one you write **two new movements**:

1. A reversal: `delta = -original_delta`, `reason = 'void'`, `ref_id = original_movement_id`.
2. The corrected movement (if applicable).

The voiding reversal sets `voided_at` and `voided_by_id` on the original via a one-time forward-update (this is the **only** allowed update on this table, and is itself audited).

## Multi-counter races (last-item problem)

Two counters try to sell the last unit simultaneously. We resolve at the local-store-server:

1. Local-store-server holds a **per-SKU in-memory lock** for the duration of a sale finalization.
2. Counter A acquires the lock, checks `quantity_on_hand >= line.qty`, writes the movement, releases the lock.
3. Counter B then acquires, sees stock = 0, fails the sale with `OUT_OF_STOCK`.

The lock lives only inside the local-store-server process. Multi-store transfers go through a different protocol (see below).

## Negative stock

By default, sales that would drive `quantity_on_hand` negative are **rejected** by the local-store-server. A per-tenant flag `allow_oversell` may relax this for stores that want to sell on credit / pre-order — when enabled, the movement still goes through but emits an `inventory_oversold` event for the owner.

## Stale cache

If a POS client's local inventory cache disagrees with the local-store-server's authoritative count (e.g. after reconnect), the server's count wins. The client refreshes via `InventoryUpdate` over WebSocket.

## Stock transfers between stores

Transfers are **two-phase**:

1. Source store writes `transfer_out` (negative delta), marks transfer as `IN_TRANSIT`.
2. Destination store writes `transfer_in` (positive delta) when received, marks transfer as `COMPLETED`.

Until step 2, the stock is "in transit" — visible in reports but not sellable anywhere. Conflicts (lost shipments, partial receipts) are resolved by writing a `shrinkage` adjustment, not by editing past movements.

## Refunds

Refunds are reversal events, not edits. A refund line emits:
- `PaymentRefunded` (in `payments` ledger)
- `InventoryAdjusted` with positive delta and `reason = 'refund'` (if goods returned)

The original sale stays intact.

## Edge cases to handle (Development Guide §13)

- Two counters sell the last item → per-SKU lock at local-store-server.
- Negative stock → rejected unless `allow_oversell`.
- Stale cache → server wins; client refresh via WS.
- Stock-transfer conflicts → resolved with `shrinkage`, never by editing past movements.

## Tests required

- Unit: stock derivation from movements, voiding correctness, oversell flag.
- Integration: multi-counter last-item race, stock-transfer two-phase, cache staleness recovery.
- Chaos: power loss between sale write and inventory write (must be atomic — same batch).
