-- Slice 6.1: users move from the YAML file into the DB so the admin
-- dashboard can manage them. Roles are a JSON array of strings —
-- portable to Postgres (jsonb) later, queryable enough for our needs.
--
-- No DELETE support by design: disable instead, so the username stays
-- reserved and the audit trail (who created which sales) keeps a
-- referent.

CREATE TABLE users (
    username    TEXT PRIMARY KEY,
    tenant_id   TEXT    NOT NULL,
    roles       TEXT    NOT NULL DEFAULT '[]',   -- JSON array of role strings
    bcrypt_hash TEXT    NOT NULL,
    disabled    INTEGER NOT NULL DEFAULT 0,      -- 0/1 boolean
    created_at  INTEGER NOT NULL,                -- unix seconds
    updated_at  INTEGER NOT NULL
);

CREATE INDEX idx_users_tenant ON users (tenant_id);
