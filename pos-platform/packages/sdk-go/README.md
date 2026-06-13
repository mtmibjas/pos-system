# sdk-go

Shared Go helpers + generated clients (Protobuf, OpenAPI) used by `apps/cloud-api` and `apps/local-store-server`.

## Sub-packages (planned)
- `openapi/` — generated OpenAPI clients
- `protogen/` — generated Protobuf types
- `sync/` — shared sync utilities (idempotency keys, retry, backoff)

## Rule
No business logic. Business rules live in apps or in `packages/shared-domain/`.

## Status
Scaffold only.
