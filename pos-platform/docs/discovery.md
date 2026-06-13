# Local Store Server Discovery

How POS clients (`desktop-pos`) find the `local-store-server` on the network.

## Two scenarios

### 1. Single counter (POS app + local-store-server on the same machine)

- Local-store-server binds to `127.0.0.1:8080`.
- POS client connects to `http://localhost:8080`.
- No discovery needed. This is the simplest install.

### 2. Multi-counter LAN (one local-store-server, several POS clients)

Two layers, tried in order:

**Layer A — mDNS auto-discovery (preferred)**

- Local-store-server advertises a Bonjour/mDNS service:
  - Service type: `_pos-store._tcp.local.`
  - TXT records: `version`, `store_id`, `node_id`
- POS clients browse for `_pos-store._tcp.local.` on startup, pick the first healthy responder, and cache its address.
- Libraries (locked):
  - Flutter: [`bonsoir`](https://pub.dev/packages/bonsoir)
  - Go: [`grandcat/zeroconf`](https://github.com/grandcat/zeroconf)

**Layer B — Manual IP fallback**

- If no mDNS responder is found within ~3 seconds, the POS client shows a "Connect to store server" screen with a manual host:port entry.
- Manual entries are persisted per device.

## Health probe

After discovery (either layer), the client does a `GET /healthz` to confirm the server is live and version-compatible. If it's not, fall back to layer B with an error message.

## Reconnection

POS clients keep the WebSocket open. On disconnect:
- Try the last-known address first.
- On failure, re-run discovery (mDNS → manual fallback).
- Use jittered exponential backoff to avoid reconnect storms when the server briefly restarts (see `docs/sync-rules.md` — reconnect storms).

## Security note

mDNS is unauthenticated. The discovery handshake is **not** the auth boundary — JWT validation is. A rogue mDNS responder can claim the service name, but POS clients will refuse to talk to it once auth fails. See `docs/security-rules.md`.
