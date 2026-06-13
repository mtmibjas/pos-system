package sync

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"math/rand/v2"
	"strconv"
	"time"

	"github.com/google/uuid"

	"github.com/mibjas/pos-platform/apps/local-store-server/internal/opslog"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/syncstate"
	posv1 "github.com/mibjas/pos-platform/packages/sdk-go/gen/pos/v1"
)

// Worker drives the sync loop:
//
//	for {
//	  drain the queue (Batcher.Next → Transport.Send → ack handling)
//	  wait for tick OR wakeup signal
//	}
//
// One worker per local DB. Safe to call Notify from any goroutine.
type Worker struct {
	ops       *opslog.Store
	state     *syncstate.Store
	batcher   *Batcher
	transport Transport
	logger    *slog.Logger

	tick       time.Duration
	maxRetries uint
	bo         *Backoff

	wake chan struct{}

	// shutdownGrace bounds how long Run blocks after ctx is cancelled,
	// waiting for the current in-flight batch's ack to land cleanly.
	shutdownGrace time.Duration

	// startupJitter desynchronizes a fleet of workers booting after a
	// cloud outage. Each worker sleeps for rand(0, startupJitter) before
	// the first drain. Default 0 (off) for tests; main.go sets a few
	// seconds in production.
	startupJitter time.Duration
	jitterRng     *rand.Rand

	// degraded is true while we are in a streak of failed Send attempts.
	// Used to emit "connection degraded"/"recovered" exactly once per
	// outage instead of one log line per retry.
	degraded bool
}

// WorkerOpts configures the Worker. Zero values get sane defaults.
type WorkerOpts struct {
	Tick          time.Duration // floor between drains; default 5s
	MaxRetries    uint          // attempts before MarkFailed; default 10
	Backoff       *Backoff      // injected; default NewBackoff(BackoffOpts{})
	Logger        *slog.Logger  // default: discarded (slog.Default subset)
	ShutdownGrace time.Duration // default 5s
	// StartupJitter spreads first-drain time across a fleet of workers
	// so a recovered cloud isn't slammed by simultaneous reconnects.
	// Default 0 (off — tests want determinism). Production sets a few
	// seconds.
	StartupJitter time.Duration
	// JitterRng is injected for deterministic startup-jitter tests.
	// Default: PCG seeded from time.Now().
	JitterRng *rand.Rand
}

// NewWorker wires the pieces together. tenantID identifies the local
// install's tenant (Phase 1: a single value; Phase 2: per-tenant DBs).
func NewWorker(ops *opslog.Store, state *syncstate.Store, transport Transport, tenantID string, opts WorkerOpts) *Worker {
	if opts.Tick <= 0 {
		opts.Tick = 5 * time.Second
	}
	if opts.MaxRetries == 0 {
		opts.MaxRetries = 10
	}
	if opts.Backoff == nil {
		opts.Backoff = NewBackoff(BackoffOpts{})
	}
	if opts.Logger == nil {
		opts.Logger = slog.Default()
	}
	if opts.ShutdownGrace <= 0 {
		opts.ShutdownGrace = 5 * time.Second
	}
	if opts.JitterRng == nil {
		opts.JitterRng = rand.New(rand.NewPCG(uint64(time.Now().UnixNano()), 0x5a5a5a5a))
	}
	return &Worker{
		ops:           ops,
		state:         state,
		batcher:       NewBatcher(ops, tenantID, 0),
		transport:     transport,
		logger:        opts.Logger,
		tick:          opts.Tick,
		maxRetries:    opts.MaxRetries,
		bo:            opts.Backoff,
		wake:          make(chan struct{}, 1),
		shutdownGrace: opts.ShutdownGrace,
		startupJitter: opts.StartupJitter,
		jitterRng:     opts.JitterRng,
	}
}

// Notify wakes the worker if it is sleeping. Non-blocking — extra
// notifications coalesce (one queued is enough).
func (w *Worker) Notify() {
	select {
	case w.wake <- struct{}{}:
	default:
	}
}

// Run blocks until ctx is cancelled. On cancellation it gives the current
// in-flight batch up to shutdownGrace to settle, then returns.
func (w *Worker) Run(ctx context.Context) error {
	// Startup jitter spreads fleet reconnects after a cloud outage so
	// the recovered cloud doesn't get a thundering herd of pending
	// backlog from every store at once. Skipped (no sleep) when
	// startupJitter is 0 — tests rely on that.
	if w.startupJitter > 0 {
		wait := time.Duration(w.jitterRng.Int64N(int64(w.startupJitter)))
		w.logger.Info("sync: startup jitter", "wait_ms", wait.Milliseconds())
		select {
		case <-time.After(wait):
		case <-ctx.Done():
			return w.gracefulShutdown()
		}
	}

	// Run an initial drain so a worker started with backlog catches up immediately.
	w.drain(ctx)

	for {
		// Sleep on tick OR wakeup OR ctx done.
		select {
		case <-ctx.Done():
			return w.gracefulShutdown()
		case <-time.After(w.tick):
		case <-w.wake:
		}
		w.drain(ctx)
	}
}

func (w *Worker) gracefulShutdown() error {
	// shutdownGrace allows the in-progress Send/ack to finish. Any ops still
	// stuck in 'in_flight' after grace are picked up by the next boot via
	// list-pending (they remain in_flight in the DB, however — they'll need
	// an out-of-band reaper in a later slice. For Phase 1 we accept that
	// and document it).
	ctx, cancel := context.WithTimeout(context.Background(), w.shutdownGrace)
	defer cancel()
	<-ctx.Done()
	return nil
}

// drain pulls + ships batches until the queue is empty or a permanent
// error stops us. Returns silently — errors are logged.
func (w *Worker) drain(ctx context.Context) {
	for {
		if ctx.Err() != nil {
			return
		}
		batch, ids, err := w.batcher.Next(ctx)
		if errors.Is(err, ErrNothingPending) {
			return
		}
		if err != nil {
			w.logger.Error("sync: batcher next", "err", err)
			return
		}
		w.shipOne(ctx, batch, ids)
	}
}

// shipOne handles one batch end-to-end, including per-batch retry loop.
func (w *Worker) shipOne(ctx context.Context, batch *posv1.SyncBatch, ids []uuid.UUID) {
	batchUUID, err := uuid.Parse(batch.BatchId)
	if err != nil {
		w.logger.Error("sync: invalid batch_id (skipping)", "batch_id", batch.BatchId, "err", err)
		return
	}

	w.bo.Reset()
	for {
		if ctx.Err() != nil {
			return
		}
		ack, sendErr := w.transport.Send(ctx, batch)
		if sendErr == nil {
			w.noteRecovered(batch.BatchId)
			w.handleAck(ctx, batchUUID, ids, ack)
			return
		}

		if !IsTransient(sendErr) {
			// Permanent transport failure → terminal.
			w.markBatchFailed(ctx, ids, fmt.Sprintf("permanent: %v", sendErr))
			return
		}

		// Transient: maybe retry.
		if w.bo.Attempt() >= w.maxRetries {
			w.markBatchFailed(ctx, ids, fmt.Sprintf("retries exhausted (%d): %v", w.maxRetries, sendErr))
			return
		}
		// Put the ops back in pending so a fresh boot would resume cleanly
		// if we die during the sleep. MarkRetry preserves batch_id so the
		// retry reuses the same dedup key — critical for the
		// "cloud committed but ack was dropped" case (slice 3.6 chaos test).
		if _, err := w.ops.MarkRetry(ctx, ids, sendErr.Error()); err != nil {
			w.logger.Error("sync: mark retry", "err", err)
			return
		}

		// Choose wait: server-supplied Retry-After wins over our backoff
		// schedule. When honoring Retry-After we deliberately do NOT
		// advance the backoff counter — the server is telling us the
		// schedule, and we don't want to double-penalize.
		var wait time.Duration
		var serverHinted bool
		if ra, ok := AsRetryAfter(sendErr); ok && ra.RetryAfter > 0 {
			wait = ra.RetryAfter
			serverHinted = true
		} else {
			wait = w.bo.Next()
		}
		w.noteDegraded(batch.BatchId, sendErr)
		w.logger.Warn("sync: transient failure, backing off",
			"batch_id", batch.BatchId, "attempt", w.bo.Attempt(),
			"wait_ms", wait.Milliseconds(), "server_hinted", serverHinted, "err", sendErr)
		select {
		case <-time.After(wait):
		case <-ctx.Done():
			return
		}
		// Re-pull: another writer may have appended to the same group, and
		// the rows are now 'pending' again so MarkInFlight has to re-take them.
		newBatch, newIDs, err := w.batcher.Next(ctx)
		if errors.Is(err, ErrNothingPending) {
			return
		}
		if err != nil {
			w.logger.Error("sync: re-batch on retry", "err", err)
			return
		}
		batch = newBatch
		ids = newIDs
		batchUUID, _ = uuid.Parse(batch.BatchId)
	}
}

func (w *Worker) handleAck(ctx context.Context, batchID uuid.UUID, ids []uuid.UUID, ack *posv1.SyncBatchAck) {
	switch ack.Status {
	case posv1.SyncBatchAck_STATUS_APPLIED, posv1.SyncBatchAck_STATUS_DUPLICATE:
		if _, err := w.ops.MarkAcked(ctx, ids); err != nil {
			w.logger.Error("sync: mark acked", "err", err)
			return
		}
		w.recordSuccess(ctx, batchID)
	case posv1.SyncBatchAck_STATUS_REJECTED:
		w.markBatchFailed(ctx, ids, "cloud rejected: "+ack.Message)
	case posv1.SyncBatchAck_STATUS_RETRY_LATER:
		// Treat as transient — push back to pending; the next tick will retry.
		if _, err := w.ops.MarkRetry(ctx, ids, "cloud RETRY_LATER: "+ack.Message); err != nil {
			w.logger.Error("sync: mark retry (retry_later)", "err", err)
		}
	default:
		w.logger.Error("sync: unknown ack status", "status", ack.Status, "batch_id", batchID)
		// Conservative: push back to pending. An unknown status is most
		// likely a forward-incompatibility issue that we should not turn
		// into data loss.
		_, _ = w.ops.MarkRetry(ctx, ids, fmt.Sprintf("unknown ack status %v", ack.Status))
	}
}

func (w *Worker) markBatchFailed(ctx context.Context, ids []uuid.UUID, reason string) {
	for _, id := range ids {
		if err := w.ops.MarkFailed(ctx, id, reason); err != nil {
			w.logger.Error("sync: mark failed", "op_id", id, "err", err)
		}
	}
	if err := w.bumpFailedCount(ctx, len(ids)); err != nil {
		w.logger.Error("sync: bump failed_ops_count", "err", err)
	}
}

// noteDegraded marks the worker as in a failure streak. Logs WARN
// exactly once per streak so a long outage produces one alert, not a
// flood. Subsequent failures still emit per-attempt WARN logs in the
// caller, but at a lower-noise structure.
func (w *Worker) noteDegraded(batchID string, cause error) {
	if w.degraded {
		return
	}
	w.degraded = true
	w.logger.Warn("sync: cloud connection degraded", "batch_id", batchID, "cause", cause)
}

// noteRecovered fires the matching INFO when a Send succeeds after a
// degraded streak. No-op if we were never degraded — successful happy
// paths stay silent.
func (w *Worker) noteRecovered(batchID string) {
	if !w.degraded {
		return
	}
	w.degraded = false
	w.logger.Info("sync: cloud connection recovered", "batch_id", batchID)
}

func (w *Worker) recordSuccess(ctx context.Context, batchID uuid.UUID) {
	if err := w.state.SetTime(ctx, syncstate.KeyLastSyncAt, time.Now()); err != nil {
		w.logger.Error("sync: set last_sync_at", "err", err)
	}
	if err := w.state.SetUUID(ctx, syncstate.KeyLastSyncBatchID, batchID); err != nil {
		w.logger.Error("sync: set last_sync_batch_id", "err", err)
	}
}

func (w *Worker) bumpFailedCount(ctx context.Context, by int) error {
	cur, err := w.state.GetUint64(ctx, syncstate.KeyFailedOpsCount)
	if err != nil && !errors.Is(err, syncstate.ErrNotFound) {
		return err
	}
	return w.state.Set(ctx, syncstate.KeyFailedOpsCount, strconv.FormatUint(cur+uint64(by), 10))
}
