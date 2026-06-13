# scripts/backup

Backup + restore for local SQLite files and cloud PostgreSQL tenants.

## Available
- `snapshot.sh` — atomic `VACUUM INTO` snapshot of both local SQLite dbs
  (`cloud.db`, `pos-local.db`) into a timestamped folder under
  `./backups/`. Writes a `MANIFEST` with sha256 of each file.

  ```sh
  scripts/backup/snapshot.sh                    # ./backups/<UTC>/...
  scripts/backup/snapshot.sh --out /var/backups # custom out dir
  POS_CLOUD_DB=/srv/cloud.db scripts/backup/snapshot.sh
  ```

  Skips DBs that don't exist (so a cloud-only or local-only host
  works); exits 3 if neither source is found.

## Planned
- `cloud-snapshot.sh` — per-tenant `pg_dump` (post-Postgres migration)
- `restore-local.sh` — verify MANIFEST sha256, copy back over a stopped server
- `restore-cloud-tenant.sh`
