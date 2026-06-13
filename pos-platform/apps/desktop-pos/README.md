# desktop-pos

Flutter desktop POS application (Windows + macOS).

## Talks to
The `local-store-server` running on the same machine (`localhost:8080`) or on the LAN (discovered via mDNS, falls back to manual IP). Never talks directly to `cloud-api`.

See `docs/discovery.md`.

## Status
Scaffold only — no `lib/main.dart` yet. Will be created in Phase 2 (Basic POS).
