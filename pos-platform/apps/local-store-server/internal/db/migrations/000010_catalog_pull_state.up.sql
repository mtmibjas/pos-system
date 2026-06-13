-- Slice 6.6: cursor for pulling catalog edit intents from cloud-api.
-- Single row (id=1). Advances past conflicts too — a conflicted intent
-- is terminal for this node (the owner re-issues), it must never block
-- the queue (lesson from the GL projection cursor stall).

CREATE TABLE catalog_pull_state (
    id       INTEGER PRIMARY KEY CHECK (id = 1),
    last_seq INTEGER NOT NULL DEFAULT 0
);

INSERT INTO catalog_pull_state (id, last_seq) VALUES (1, 0);
