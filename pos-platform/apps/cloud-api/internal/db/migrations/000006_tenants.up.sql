-- Slice 6.7: explicit tenants table for the platform-admin area.
-- Until now tenants were implicit (a tenant_id string on every row).
-- Absence of a row still means "active" (legacy implicit tenant) —
-- enforcement only kicks in when status = 'suspended'.
--
-- No hard delete, same posture as users: suspend keeps the id reserved
-- and the audit trail intact. A real offboarding/retention story is a
-- production concern (see local-env-setup.md §12).

CREATE TABLE tenants (
    tenant_id  TEXT PRIMARY KEY,
    name       TEXT NOT NULL DEFAULT '',
    status     TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'suspended')),
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
);

-- Backfill: every tenant we already know about from the user store.
INSERT OR IGNORE INTO tenants (tenant_id, name, status, created_at, updated_at)
SELECT DISTINCT tenant_id, tenant_id, 'active',
       CAST(strftime('%s', 'now') AS INTEGER),
       CAST(strftime('%s', 'now') AS INTEGER)
FROM users;
