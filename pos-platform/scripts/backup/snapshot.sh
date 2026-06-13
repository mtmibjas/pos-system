#!/usr/bin/env bash
# snapshot.sh — atomic SQLite snapshot for the local POS stack.
#
# Hardening item H6. Uses `VACUUM INTO` so the snapshot is consistent
# even with a running writer (cloud-api or local-store-server) — VACUUM
# INTO takes a read transaction internally, so the resulting file is a
# point-in-time copy with no risk of a torn write.
#
# Snapshots both:
#   - cloud-api          (default: ./cloud.db)
#   - local-store-server (default: ./pos-local.db, override via env)
#
# Output layout:
#   <out-dir>/<UTC-timestamp>/cloud.db
#   <out-dir>/<UTC-timestamp>/pos-local.db
#   <out-dir>/<UTC-timestamp>/MANIFEST
#
# A MANIFEST file records sha256 of each snapshot so restore can verify.
#
# Usage:
#   scripts/backup/snapshot.sh [--out DIR] [--cloud-db PATH] [--local-db PATH]
#
# Env:
#   POS_BACKUP_DIR    fallback for --out          (default: ./backups)
#   POS_CLOUD_DB      fallback for --cloud-db     (default: ./cloud.db)
#   POS_LOCAL_DB      fallback for --local-db     (default: ./pos-local.db)
#
# Exit codes:
#   0 ok       1 generic error      2 missing dependency
#   3 source db missing             4 vacuum into failed

set -euo pipefail

OUT_DIR="${POS_BACKUP_DIR:-./backups}"
CLOUD_DB="${POS_CLOUD_DB:-./cloud.db}"
LOCAL_DB="${POS_LOCAL_DB:-./pos-local.db}"

usage() {
  sed -n '2,30p' "$0"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --out)       OUT_DIR="$2";  shift 2 ;;
    --cloud-db)  CLOUD_DB="$2"; shift 2 ;;
    --local-db)  LOCAL_DB="$2"; shift 2 ;;
    -h|--help)   usage; exit 0 ;;
    *)           echo "snapshot: unknown arg: $1" >&2; usage; exit 1 ;;
  esac
done

command -v sqlite3 >/dev/null 2>&1 || {
  echo "snapshot: sqlite3 not on PATH (brew install sqlite)" >&2
  exit 2
}
command -v shasum >/dev/null 2>&1 || {
  echo "snapshot: shasum not on PATH" >&2
  exit 2
}

ts="$(date -u +%Y%m%dT%H%M%SZ)"
dest="${OUT_DIR%/}/${ts}"
mkdir -p "$dest"

# snapshot_one <label> <src> <dest_filename>
snapshot_one() {
  local label="$1" src="$2" dst_name="$3"
  if [[ ! -f "$src" ]]; then
    echo "snapshot: ${label} db missing at ${src} — skipping" >&2
    return 0
  fi
  local dst="${dest}/${dst_name}"
  # VACUUM INTO requires an absolute or current-dir path; pass as-is.
  # Quoting: single-quote inside the SQL literal, escaping any single
  # quotes in the path by doubling them (SQL string escape).
  local escaped="${dst//\'/\'\'}"
  if ! sqlite3 "$src" "VACUUM INTO '${escaped}'"; then
    echo "snapshot: VACUUM INTO failed for ${label}" >&2
    exit 4
  fi
  local sum
  sum="$(shasum -a 256 "$dst" | awk '{print $1}')"
  echo "${dst_name} ${sum}  (from ${src})" >>"${dest}/MANIFEST"
  echo "snapshot: ${label} → ${dst}  sha256=${sum:0:12}"
}

snapshot_one cloud  "$CLOUD_DB"  cloud.db
snapshot_one local  "$LOCAL_DB"  pos-local.db

if [[ ! -s "${dest}/MANIFEST" ]]; then
  # Nothing was snapshotted — clean up the empty dir so we don't leave
  # stale timestamp folders littering OUT_DIR.
  rmdir "$dest"
  echo "snapshot: no source dbs found (looked at ${CLOUD_DB}, ${LOCAL_DB})" >&2
  exit 3
fi

echo "snapshot: done → ${dest}"
