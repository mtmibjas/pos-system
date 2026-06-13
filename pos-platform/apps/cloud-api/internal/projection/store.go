package projection

import (
	"context"
	"crypto/sha1"
	"database/sql"
	"encoding/hex"
	"errors"
	"fmt"
	"strings"

	posv1 "github.com/mibjas/pos-platform/packages/sdk-go/gen/pos/v1"
	"google.golang.org/protobuf/proto"
)

// Store persists journal entries derived from events into the cloud DB.
// It is the only writer of `journal_entries` / `journal_lines` /
// `accounts` (tax sub-accounts only) — replay.go calls Apply per event;
// nothing else touches these tables.
type Store struct {
	db *sql.DB
}

func NewStore(db *sql.DB) *Store {
	if db == nil {
		panic("projection: NewStore requires a non-nil *sql.DB")
	}
	return &Store{db: db}
}

// --- Lookups (used by gl.Map) ---

// ClearingAccountForPayment finds the clearing account that was Dr'd
// when the original PaymentAdded for paymentID posted. Returns
// ErrPaymentNotFound (wrapped) when no JE exists yet — the replay
// worker treats this as a transient ordering issue and stops the
// cursor, so the next pass picks it up after the predecessor lands.
func (s *Store) ClearingAccountForPayment(ctx context.Context, tenantID, paymentID string) (string, error) {
	const q = `
		SELECT jl.account_code
		  FROM journal_entries je
		  JOIN journal_lines   jl ON jl.je_id = je.je_id
		 WHERE je.tenant_id = ?
		   AND je.payment_id = ?
		   AND je.source_event_type = 'payment_added'
		   AND jl.side = 'debit'
		   AND jl.account_code <> ?
		 LIMIT 1
	`
	// The original PaymentAdded JE has exactly two lines: Dr Clearing and
	// Cr A/R. Excluding A/R guarantees we return the clearing code even
	// if the join order ever shifts.
	var acct string
	err := s.db.QueryRowContext(ctx, q, tenantID, paymentID, AccountAccountsReceivable).Scan(&acct)
	if errors.Is(err, sql.ErrNoRows) {
		return "", fmt.Errorf("payment %s: %w", paymentID, ErrPaymentNotFound)
	}
	if err != nil {
		return "", fmt.Errorf("projection: clearing lookup: %w", err)
	}
	return acct, nil
}

// LinesForSale returns the journal lines posted under saleID whose
// source event type matches the allow-list. Used by SaleVoided to
// build the reversal entry.
func (s *Store) LinesForSale(ctx context.Context, tenantID, saleID string, sourceEventTypes []string) ([]Line, error) {
	if len(sourceEventTypes) == 0 {
		return nil, nil
	}
	// Build the IN-list. Source event types come from us (gl.go), not
	// from user input — but parameterize anyway to keep this safe to
	// extend later.
	placeholders := make([]string, len(sourceEventTypes))
	args := make([]any, 0, 2+len(sourceEventTypes))
	args = append(args, tenantID, saleID)
	for i, t := range sourceEventTypes {
		placeholders[i] = "?"
		args = append(args, t)
	}
	q := fmt.Sprintf(`
		SELECT jl.account_code, jl.side, jl.currency_code, jl.units, jl.nanos
		  FROM journal_entries je
		  JOIN journal_lines   jl ON jl.je_id = je.je_id
		 WHERE je.tenant_id = ?
		   AND je.sale_id = ?
		   AND je.source_event_type IN (%s)
		 ORDER BY je.je_seq ASC, jl.line_id ASC
	`, strings.Join(placeholders, ","))
	rows, err := s.db.QueryContext(ctx, q, args...)
	if err != nil {
		return nil, fmt.Errorf("projection: lines-for-sale query: %w", err)
	}
	defer rows.Close()

	var out []Line
	for rows.Next() {
		var (
			ln    Line
			side  string
			nanos int64
		)
		if err := rows.Scan(&ln.Account, &side, &ln.CurrencyCode, &ln.Units, &nanos); err != nil {
			return nil, fmt.Errorf("projection: lines-for-sale scan: %w", err)
		}
		ln.Side = Side(side)
		ln.Nanos = int32(nanos)
		out = append(out, ln)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("projection: lines-for-sale iterate: %w", err)
	}
	return out, nil
}

// --- Apply ---

// Apply persists every Entry produced by Map for a single event, in one
// transaction, with the (operation_id, je_seq) idempotency anchor.
// Replays of the same event are no-ops; the function returns
// (applied=false, nil) when every entry was already in the table.
//
// On-demand: any Tax Payable sub-account referenced for the first time
// is INSERTed before the journal_lines insert, so the FK is always
// satisfied.
//
// occurredAtUnixNs comes from the event's `occurred_at`, not the
// cloud's clock — drives period bucketing for reports (invariant #3).
func (s *Store) Apply(
	ctx context.Context,
	tenantID, operationID string,
	occurredAtUnixNs int64,
	entries []Entry,
) (applied bool, err error) {
	if len(entries) == 0 {
		return false, nil
	}
	for _, e := range entries {
		if !IsBalanced(e) {
			return false, fmt.Errorf("projection: entry seq=%d for op %s does not balance", e.Seq, operationID)
		}
	}

	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return false, fmt.Errorf("projection: begin: %w", err)
	}
	defer func() { _ = tx.Rollback() }()

	anyApplied := false
	for _, e := range entries {
		ok, err := s.applyEntry(ctx, tx, tenantID, operationID, occurredAtUnixNs, e)
		if err != nil {
			return false, err
		}
		anyApplied = anyApplied || ok
	}

	if err := tx.Commit(); err != nil {
		return false, fmt.Errorf("projection: commit: %w", err)
	}
	return anyApplied, nil
}

func (s *Store) applyEntry(
	ctx context.Context,
	tx *sql.Tx,
	tenantID, operationID string,
	occurredAtUnixNs int64,
	e Entry,
) (bool, error) {
	// Idempotency: deterministic je_id = sha1(operation_id + ":" + seq).
	// Lets the UNIQUE (operation_id, je_seq) and the je_id PK both
	// collapse on replay — no extra existence check needed.
	jeID := deterministicJEID(operationID, e.Seq)

	// Ensure any referenced Tax Payable sub-account exists.
	for _, ln := range e.Lines {
		if strings.HasPrefix(ln.Account, taxPayablePrefix) && ln.Account != AccountTaxUnclassified {
			if err := s.ensureTaxAccount(ctx, tx, ln.Account); err != nil {
				return false, err
			}
		}
	}

	res, err := tx.ExecContext(ctx, `
		INSERT OR IGNORE INTO journal_entries (
			je_id, operation_id, je_seq, tenant_id, store_id,
			posted_at_unix_ns, source_event_type, sale_id, payment_id, memo
		) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
	`,
		jeID, operationID, e.Seq, tenantID, e.StoreID,
		occurredAtUnixNs, e.SourceEventType, e.SaleID, e.PaymentID, e.Memo,
	)
	if err != nil {
		return false, fmt.Errorf("projection: insert je: %w", err)
	}
	n, err := res.RowsAffected()
	if err != nil {
		return false, fmt.Errorf("projection: rows affected: %w", err)
	}
	if n == 0 {
		// Already applied on a prior pass — idempotent replay.
		return false, nil
	}

	for _, ln := range e.Lines {
		if _, err := tx.ExecContext(ctx, `
			INSERT INTO journal_lines (
				je_id, account_code, side, currency_code, units, nanos
			) VALUES (?, ?, ?, ?, ?, ?)
		`,
			jeID, ln.Account, string(ln.Side), ln.CurrencyCode, ln.Units, ln.Nanos,
		); err != nil {
			return false, fmt.Errorf("projection: insert line: %w", err)
		}
	}
	return true, nil
}

// ensureTaxAccount inserts a 2100.<category> row if it doesn't already
// exist. SQLite's INSERT OR IGNORE makes this a single round-trip; no
// SELECT-then-INSERT race window even under concurrent workers.
func (s *Store) ensureTaxAccount(ctx context.Context, tx *sql.Tx, code string) error {
	name := "Tax Payable (" + strings.TrimPrefix(code, taxPayablePrefix) + ")"
	_, err := tx.ExecContext(ctx, `
		INSERT OR IGNORE INTO accounts (code, name, type) VALUES (?, ?, 'liability')
	`, code, name)
	if err != nil {
		return fmt.Errorf("projection: ensure tax account %s: %w", code, err)
	}
	return nil
}

func deterministicJEID(operationID string, seq int) string {
	h := sha1.New()
	fmt.Fprintf(h, "%s:%d", operationID, seq)
	return hex.EncodeToString(h.Sum(nil))
}

// --- Cursor ---

// Cursor returns the highest events.id this projection has processed.
// 0 = haven't processed anything yet.
func (s *Store) Cursor(ctx context.Context) (int64, error) {
	var id int64
	err := s.db.QueryRowContext(ctx,
		`SELECT last_event_id FROM projection_cursor WHERE name = 'gl'`,
	).Scan(&id)
	if errors.Is(err, sql.ErrNoRows) {
		return 0, nil
	}
	if err != nil {
		return 0, fmt.Errorf("projection: cursor read: %w", err)
	}
	return id, nil
}

// AdvanceCursor moves the gl cursor forward to lastEventID. Caller is
// responsible for sequencing — we don't enforce monotonicity here so
// the worker can also use this to "rewind" in dev (not exposed publicly).
func (s *Store) AdvanceCursor(ctx context.Context, lastEventID, updatedAtUnixNs int64) error {
	_, err := s.db.ExecContext(ctx, `
		UPDATE projection_cursor
		   SET last_event_id = ?, updated_at_unix_ns = ?
		 WHERE name = 'gl'
	`, lastEventID, updatedAtUnixNs)
	if err != nil {
		return fmt.Errorf("projection: cursor advance: %w", err)
	}
	return nil
}

// --- Unmarshal helper ---

// DecodeEnvelope parses a raw events.payload column. Exposed for the
// worker and tests; nothing about the projection cares about the wire
// format outside this helper.
func DecodeEnvelope(raw []byte) (*posv1.EventEnvelope, error) {
	env := &posv1.EventEnvelope{}
	if err := proto.Unmarshal(raw, env); err != nil {
		return nil, fmt.Errorf("projection: decode envelope: %w", err)
	}
	return env, nil
}
