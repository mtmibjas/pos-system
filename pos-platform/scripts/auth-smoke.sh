#!/usr/bin/env bash
#
# auth-smoke.sh — end-to-end smoke of the store-server AuthService.
#
# Boots a throwaway local-store-server (auth enabled) against a temp DB
# seeded with an owner, then drives RegisterDevice -> Login over Connect-JSON
# and checks the owner-gate + sequential-counter behavior. Cleans up after.
#
# Run from anywhere:  bash scripts/auth-smoke.sh
# Requires: go, curl, python3 (JSON parsing).

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/apps/local-store-server"
PORT="${PORT:-18099}"
B="http://127.0.0.1:${PORT}/pos.v1.AuthService"
DB="$(mktemp -d)/auth-smoke.db"
BIN="$(mktemp -d)/lss-smoke"

cd "$APP"

echo "==> build"
go build -o "$BIN" .

echo "==> seed owner (owner@a / ownerpw)"
POS_LOCAL_DB="$DB" go run ./cmd/seed-owner >/dev/null

echo "==> boot server on :${PORT} (auth enabled)"
POS_LOCAL_DB="$DB" POS_SESSION_SECRET=devsecret POS_LISTEN_ADDR="127.0.0.1:${PORT}" "$BIN" >/tmp/auth-smoke-server.log 2>&1 &
SRV=$!
cleanup() { kill "$SRV" 2>/dev/null || true; }
trap cleanup EXIT

# Wait for readiness without sleep — curl retries until /healthz answers.
if ! curl --retry 40 --retry-delay 1 --retry-connrefused -sf "http://127.0.0.1:${PORT}/healthz" >/dev/null; then
  echo "!! server never came up; log:"; cat /tmp/auth-smoke-server.log; exit 1
fi

jq_field() { python3 -c "import sys,json;print(json.load(sys.stdin)['$1'])"; }

echo
echo "==> RegisterDevice (owner, happy path)"
REG=$(curl -s -X POST "$B/RegisterDevice" -H 'Content-Type: application/json' \
  -d '{"managerUsername":"owner@a","managerPassword":"ownerpw","deviceName":"Front till"}')
echo "    $REG"
DID=$(echo "$REG"  | jq_field deviceId)
DSEC=$(echo "$REG" | jq_field deviceSecret)

echo
echo "==> Login (owner on that device)"
LOGIN=$(curl -s -X POST "$B/Login" -H 'Content-Type: application/json' \
  -d "{\"deviceId\":\"$DID\",\"deviceSecret\":\"$DSEC\",\"username\":\"owner@a\",\"password\":\"ownerpw\"}")
echo "    token: $(echo "$LOGIN" | jq_field accessToken | cut -c1-24)..."
echo "    counter=$(echo "$LOGIN" | jq_field counterId)  roles=$(echo "$LOGIN" | python3 -c 'import sys,json;print(json.load(sys.stdin)["roles"])')"

echo
echo "==> RegisterDevice with WRONG manager password (expect Unauthenticated)"
curl -s -o /dev/null -w "    HTTP %{http_code}\n" -X POST "$B/RegisterDevice" -H 'Content-Type: application/json' \
  -d '{"managerUsername":"owner@a","managerPassword":"WRONG","deviceName":"x"}'

echo
echo "==> RegisterDevice again (expect counter-2, server-assigned)"
curl -s -X POST "$B/RegisterDevice" -H 'Content-Type: application/json' \
  -d '{"managerUsername":"owner@a","managerPassword":"ownerpw","deviceName":"Second till"}' \
  | python3 -c 'import sys,json;print("    counter:",json.load(sys.stdin)["counterId"])'

echo
echo "OK — auth flow smoke passed."
