-- 000012_devices
-- Registered POS terminals. A device is provisioned once by a manager
-- (AuthService.RegisterDevice) and binds a terminal to a server-assigned
-- counter. The device credential is tier-1 of the two-tier auth model
-- (see docs/store-server-auth-contract.md §3).
--
-- Design:
--   - device_id is a server-minted UUID (the row PK).
--   - secret_bcrypt_hash stores ONLY the bcrypt hash of the device_secret.
--     The plaintext secret is returned to the terminal exactly once at
--     registration and never recoverable server-side — losing it means
--     re-registering. This makes a lost/retired terminal REVOCABLE (a
--     long-lived stateless device JWT could not be revoked without a
--     denylist), which is why we chose an opaque secret over a JWT.
--   - counter_id is server-assigned (sequential per store). A replacement
--     registration revokes the old row (disabled = 1) and reuses its
--     counter_id, so shift reports/audit stay continuous across a till swap.
--   - registered_by records the manager username for audit. No FK to users
--     — it's an audit string, and avoiding the FK keeps migration ordering
--     and the future cloud->store user sync unconstrained.
--   - No DELETE: revoke (disabled = 1) so device_id/counter history survives.

CREATE TABLE devices (
    device_id          TEXT    PRIMARY KEY,        -- server-minted UUID
    tenant_id          TEXT    NOT NULL,
    store_id           TEXT    NOT NULL,
    counter_id         TEXT    NOT NULL,           -- server-assigned
    device_name        TEXT    NOT NULL,           -- human label, e.g. "Front till"
    secret_bcrypt_hash TEXT    NOT NULL,           -- bcrypt(device_secret)
    disabled           INTEGER NOT NULL DEFAULT 0, -- 0/1 boolean (revoked)
    registered_by      TEXT    NOT NULL,           -- manager username (audit)
    created_at         INTEGER NOT NULL,           -- unix seconds
    last_seen_at       INTEGER                     -- unix seconds; NULL until first Login
);

-- One ACTIVE device per counter. Revoked rows are excluded so a replacement
-- can reuse the counter_id. New-counter assignment derives the next number
-- from the count of distinct counters (revoked rows still count, so numbers
-- are never recycled).
CREATE UNIQUE INDEX idx_devices_active_counter
    ON devices (store_id, counter_id) WHERE disabled = 0;

CREATE INDEX idx_devices_tenant ON devices (tenant_id);
