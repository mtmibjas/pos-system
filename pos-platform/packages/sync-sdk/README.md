# sync-sdk

Reusable sync-engine building blocks: idempotency, batching, retry/backoff, ordering.

## Why a separate package
Both `local-store-server` (push side) and `cloud-api` (ingest side) need the same primitives — operation envelopes, retry policy, idempotency-key handling, batch atomicity. Putting them here keeps the rules in one place.

## Planned layout
- `idempotency/` — operation_uuid handling, "already-seen" checks
- `retry/` — exponential backoff, max-retry policy (see `docs/sync-rules.md`)
- `batching/` — group related operations atomically (invoice + payment + stock)
- `ordering/` — lamport-clock helpers, out-of-order acceptance rules

## Implementation language
Go (initially). If a Dart-side sync engine is later required, this package may grow a Dart counterpart, or the rules will be re-expressed in `packages/proto` + thin Dart adapters.

## Status
Scaffold only. Implementation comes in Phase 3.
