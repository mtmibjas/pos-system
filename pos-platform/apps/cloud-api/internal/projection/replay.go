package projection

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"log/slog"
	"time"
)

// Worker drains the events table into the GL projection in append
// order, advancing `projection_cursor.gl` as it goes. Designed to be
// run as a long-lived background goroutine in cloud-api/main.go, but
// also drivable from tests via RunOnce.
type Worker struct {
	db      *sql.DB
	store   *Store
	logger  *slog.Logger
	tick    time.Duration
	batch   int
	now     func() time.Time
}

// WorkerOption tunes a Worker. Defaults are documented on New.
type WorkerOption func(*Worker)

func WithTick(d time.Duration) WorkerOption  { return func(w *Worker) { w.tick = d } }
func WithBatch(n int) WorkerOption           { return func(w *Worker) { w.batch = n } }
func WithNow(f func() time.Time) WorkerOption { return func(w *Worker) { w.now = f } }

// New wires a Worker. Defaults: tick=1s, batch=500, now=time.Now.UTC.
// Logger is mandatory — observability for the replay loop is the whole
// reason we can debug ordering issues without a SQL session.
func New(db *sql.DB, store *Store, logger *slog.Logger, opts ...WorkerOption) *Worker {
	if db == nil || store == nil || logger == nil {
		panic("projection.New: db, store, logger are all required")
	}
	w := &Worker{
		db:     db,
		store:  store,
		logger: logger,
		tick:   1 * time.Second,
		batch:  500,
		now:    func() time.Time { return time.Now().UTC() },
	}
	for _, o := range opts {
		o(w)
	}
	return w
}

// Run drives the worker until ctx is cancelled. Returns ctx.Err() when
// shut down; never returns nil during normal operation.
func (w *Worker) Run(ctx context.Context) error {
	t := time.NewTicker(w.tick)
	defer t.Stop()
	// Drain once immediately so a fresh process catches up without waiting
	// for the first tick. Subsequent passes happen on tick.
	for {
		if _, err := w.RunOnce(ctx); err != nil && !errors.Is(err, context.Canceled) {
			w.logger.Error("projection: run-once failed", "err", err)
		}
		select {
		case <-ctx.Done():
			return ctx.Err()
		case <-t.C:
		}
	}
}

// RunOnce processes up to one batch worth of events past the current
// cursor. Returns the number of events processed (regardless of whether
// they produced JEs — non-GL events still advance the cursor).
//
// Exposed for tests so they can drive the worker deterministically
// without running the ticker.
func (w *Worker) RunOnce(ctx context.Context) (int, error) {
	cursor, err := w.store.Cursor(ctx)
	if err != nil {
		return 0, err
	}
	rows, err := w.db.QueryContext(ctx, `
		SELECT id, tenant_id, operation_id, operation_type, occurred_at_unix_ns, payload
		  FROM events
		 WHERE id > ?
		 ORDER BY id ASC
		 LIMIT ?
	`, cursor, w.batch)
	if err != nil {
		return 0, fmt.Errorf("projection: scan events: %w", err)
	}
	defer rows.Close()

	type row struct {
		id            int64
		tenant        string
		operationID   string
		operationType string
		occurredAt    int64
		payload       []byte
	}
	batch := make([]row, 0, w.batch)
	for rows.Next() {
		var r row
		if err := rows.Scan(&r.id, &r.tenant, &r.operationID, &r.operationType,
			&r.occurredAt, &r.payload); err != nil {
			return 0, fmt.Errorf("projection: scan row: %w", err)
		}
		batch = append(batch, r)
	}
	if err := rows.Err(); err != nil {
		return 0, fmt.Errorf("projection: rows iterate: %w", err)
	}
	if len(batch) == 0 {
		return 0, nil
	}

	processed := 0
	for _, r := range batch {
		env, err := DecodeEnvelope(r.payload)
		if err != nil {
			w.logger.Error("projection: decode failed; skipping but advancing",
				"event_id", r.id, "op", r.operationID, "err", err)
			// Advance past this row anyway — a malformed payload here means
			// the writer is broken, and stalling the cursor would block the
			// entire tenant. Operator sees the error in logs.
			if err := w.store.AdvanceCursor(ctx, r.id, w.now().UnixNano()); err != nil {
				return processed, err
			}
			processed++
			continue
		}

		entries, err := Map(ctx, env, w.store)
		if err != nil {
			// Lookup failures (e.g. ErrPaymentNotFound) mean upstream events
			// haven't landed yet. Stop here so the next pass re-tries; do
			// NOT advance the cursor past the failed row.
			if errors.Is(err, ErrPaymentNotFound) {
				w.logger.Warn("projection: ordering dependency not yet satisfied; will retry",
					"event_id", r.id, "op", r.operationID, "err", err)
				return processed, nil
			}
			return processed, fmt.Errorf("projection: map event %d (%s): %w", r.id, r.operationType, err)
		}

		if _, err := w.store.Apply(ctx, r.tenant, r.operationID, r.occurredAt, entries); err != nil {
			return processed, fmt.Errorf("projection: apply event %d: %w", r.id, err)
		}

		if err := w.store.AdvanceCursor(ctx, r.id, w.now().UnixNano()); err != nil {
			return processed, err
		}
		processed++
	}
	return processed, nil
}
