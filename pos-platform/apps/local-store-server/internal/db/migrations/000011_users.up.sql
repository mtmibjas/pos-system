-- 000011_users
-- Local user store for store-server auth (AuthService.Login). Until now
-- the store server had no users — all login lived in cloud-api. Offline-
-- first forces users LOCAL: a cashier must log in with the cloud
-- unreachable, so we re-authenticate against this mirror.
--
-- Design (see docs/store-server-auth-contract.md §4):
--   - Ported from cloud-api's 000003_users so the bcrypt shape and column
--     set match, and the future cloud->store user sync (catalog-pull
--     analogue) is a straight copy.
--   - roles is a JSON array of strings — portable to Postgres (jsonb)
--     later, queryable enough for our needs.
--   - display_name is the ONE addition over cloud-api's schema. It sources
--     LoginResponse.user_display_name (falls back to username when empty).
--     cloud-api has no such column yet, so the sync carries it only once
--     cloud-api grows one; until then it stays '' and login shows username.
--     Display-only — never an authorization input.
--   - No DELETE support by design: disable instead, so the username stays
--     reserved (it appears in JWT subjects + sale audit trails).

CREATE TABLE users (
    username     TEXT    PRIMARY KEY,
    tenant_id    TEXT    NOT NULL,
    roles        TEXT    NOT NULL DEFAULT '[]',   -- JSON array of role strings
    bcrypt_hash  TEXT    NOT NULL,
    display_name TEXT    NOT NULL DEFAULT '',     -- LoginResponse.user_display_name
    disabled     INTEGER NOT NULL DEFAULT 0,      -- 0/1 boolean
    created_at   INTEGER NOT NULL,                -- unix seconds
    updated_at   INTEGER NOT NULL
);

CREATE INDEX idx_users_tenant ON users (tenant_id);
