# Contracts Strategy

Two contract systems coexist. Each has a clearly defined scope.

## Protobuf — `packages/proto`

Use for:
- Domain events (`SaleCreated`, `PaymentAdded`, `InventoryAdjusted`, …)
- Sync payloads (`Operation`, `SyncBatch`, `SyncBatchAck`)
- WebSocket messages (`WsMessage` envelope + body variants)
- Internal RPC between Go services

Why: small, strict, versionable, fast, language-neutral. Right tool for high-volume, append-only event traffic and binary websocket frames.

## OpenAPI — generated into `packages/sdk-go/openapi/`

Use for:
- REST APIs exposed by `cloud-api`
- External SaaS APIs (anything a third-party will call)
- Mobile dashboard APIs (`mobile-owner`)
- Admin APIs

Why: REST/JSON is what dashboards, partners, and third-party integrators expect. OpenAPI gives them browsable docs and SDKs for free.

## Rule of thumb

| If the producer is…           | And the consumer is…                  | Use     |
|-------------------------------|----------------------------------------|---------|
| local-store-server            | cloud-api (sync ingest)               | Proto   |
| local-store-server            | desktop-pos (WebSocket)               | Proto   |
| desktop-pos                   | local-store-server (commands)         | Proto   |
| cloud-api                     | mobile-owner (dashboards)             | OpenAPI |
| cloud-api                     | third-party integrators                | OpenAPI |
| cloud-api (admin endpoints)   | internal tools                        | OpenAPI |
| any Go service ↔ any Go service (internal RPC) | another Go service           | Proto   |

If a case doesn't fit cleanly, raise it before building. Default to Protobuf for high-volume / strict-shape traffic, OpenAPI when humans or partners will read docs.

## Never duplicate

Never hand-author a Go struct or Dart class that mirrors a proto or OpenAPI shape. Regenerate. If codegen is missing, fix the codegen pipeline — don't paper over it by hand-writing.

## Versioning

- Proto: package-versioned (`pos.v1`, `pos.v2`). Breaking change → new version. See `docs/event-contracts.md`.
- OpenAPI: URL-versioned (`/api/v1/…`).

Old versions stay until all clients have migrated.
