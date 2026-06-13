# proto

Protobuf contracts — the **single source of truth** for events, sync payloads, WebSocket messages, and internal service RPCs.

> Never hand-duplicate these types in Go or Dart. Always regenerate.

## Layout (planned)
```
proto/
├── buf.yaml                 # buf module config
├── buf.gen.yaml             # codegen plugin config (Go + Dart)
├── pos/
│   ├── v1/
│   │   ├── common.proto     # shared scalars (Money, Timestamp wrappers, IDs)
│   │   ├── events.proto     # domain events (sale_created, payment_added, …)
│   │   ├── sync.proto       # operation_log envelope, sync batch, ack
│   │   └── ws.proto         # websocket message envelope
│   └── internal/v1/
│       └── store.proto      # internal RPC between cloud-api and sync workers
└── gen/                     # generated code (gitignored)
```

## Versioning
Every proto package is versioned (`pos.v1`, `pos.v2`). Breaking changes go in a new version — old versions stay until all clients migrate. See `docs/event-contracts.md`.

## Codegen
`make proto-gen` from the repo root (TODO — wired to `buf generate`).

## Status
Drafted skeleton files in `pos/v1/`. No codegen wired up yet.
