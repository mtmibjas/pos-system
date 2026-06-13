// Package projection turns the cloud's append-only `events` log into a
// double-entry general ledger. Slice 5.2 — Phase 5 — cloud-side only.
//
// Layering:
//
//   - gl.go     — pure event → journal-entry mapping. No I/O. Cross-event
//     state (PaymentRefunded → original method, SaleVoided → prior JEs
//     for the sale) is fetched through the Lookups interface so the
//     mapper stays testable with a fake lookups.
//   - store.go  — DB-backed Lookups + idempotent Apply (inserts JE +
//     lines + on-demand tax sub-account creation in one transaction).
//   - replay.go — cursor-driven worker that reads `events` in (lamport,
//     id) order, calls Map, then store.Apply, and advances the
//     `projection_cursor` row.
//
// Why pure mapping: lets the heavy tests (one-per-event-type, balance,
// reversal symmetry) run without spinning up a DB. The DB-shaped tests
// only need to verify idempotency, on-demand account creation, and the
// cursor advance — all small surface area.
package projection

import (
	"context"
	"errors"
	"fmt"

	posv1 "github.com/mibjas/pos-platform/packages/sdk-go/gen/pos/v1"
)

// Side encodes the debit/credit direction. A magnitude (units+nanos) is
// always positive; the sign lives entirely in Side. See accounting-rules
// "Sign convention" invariant.
type Side string

const (
	SideDebit  Side = "debit"
	SideCredit Side = "credit"
)

// Account codes — must match the seed in 000002_gl_projection.up.sql.
const (
	AccountCash               = "1000"
	AccountCardClearing       = "1100"
	AccountUPIClearing        = "1110"
	AccountAccountsReceivable = "1200"
	AccountRevenue            = "4000"

	// Tax Payable is sub-accounted per tax_category_id. Empty category
	// posts to .unclassified (seeded). Other categories are created on
	// demand by the store layer the first time we see them.
	taxPayablePrefix    = "2100."
	AccountTaxUnclassified = taxPayablePrefix + "unclassified"
)

// TaxPayableAccount returns the account code for a tax category. Empty
// category falls back to the unclassified bucket so older-binary events
// (without the Phase 5 tax_category_id field) post safely.
func TaxPayableAccount(taxCategoryID string) string {
	if taxCategoryID == "" {
		return AccountTaxUnclassified
	}
	return taxPayablePrefix + taxCategoryID
}

// ClearingAccountForMethod maps a PaymentAdded.method string to its
// clearing account. Unknown methods fall back to Card Clearing — caller
// (the worker) should slog.Warn so the operator notices the data drift.
func ClearingAccountForMethod(method string) (account string, fallback bool) {
	switch method {
	case "cash":
		return AccountCash, false
	case "card":
		return AccountCardClearing, false
	case "upi":
		return AccountUPIClearing, false
	default:
		return AccountCardClearing, true
	}
}

// Line is one row destined for journal_lines. Magnitudes are always
// non-negative; Side carries the direction.
type Line struct {
	Account      string
	Side         Side
	CurrencyCode string
	Units        int64
	Nanos        int32
}

// Entry is one journal entry (header + lines), ready to be persisted.
// Seq starts at 0 for the first entry produced by a given source event
// and increments per additional entry — pairs with operation_id to form
// the (operation_id, je_seq) idempotency anchor.
type Entry struct {
	Seq             int
	SourceEventType string
	StoreID         string
	SaleID          string // "" when not applicable
	PaymentID       string // "" when not applicable
	Memo            string
	Lines           []Line
}

// Lookups is the cross-event state the pure mapper needs. Implemented
// by store.go against the DB; the unit tests use an in-memory fake.
type Lookups interface {
	// ClearingAccountForPayment returns the clearing account that was
	// originally debited when the PaymentAdded for paymentID posted. It
	// is the reverse-lookup pivot used by PaymentRefunded so refund
	// tenders settle back to the same clearing bucket as the original
	// payment, regardless of what method string the refund event happens
	// to carry. Returns an error wrapping ErrPaymentNotFound if no prior
	// PaymentAdded JE exists for paymentID (caller decides whether to
	// fail or fall back).
	ClearingAccountForPayment(ctx context.Context, tenantID, paymentID string) (string, error)

	// LinesForSale returns every journal line previously posted under
	// saleID whose source event type is in the given allow-list. Used by
	// SaleVoided to produce the reversal: the void posts a new JE whose
	// lines are exactly these, with Side flipped.
	LinesForSale(ctx context.Context, tenantID, saleID string, sourceEventTypes []string) ([]Line, error)
}

// ErrPaymentNotFound — Lookups.ClearingAccountForPayment couldn't find
// a prior PaymentAdded JE for the given payment_id. Indicates an
// out-of-order event stream (refund processed before its payment).
var ErrPaymentNotFound = errors.New("projection: original payment JE not found")

// Map converts an EventEnvelope to the JEs it produces. Returns
// (nil, nil) for operational events that don't post (SyncCompleted,
// UserLoggedIn, InventoryAdjusted in Phase 5).
//
// Determinism: same input → same output. No clock reads, no IDs minted
// here (the store assigns je_id from operation_id + seq).
func Map(ctx context.Context, env *posv1.EventEnvelope, l Lookups) ([]Entry, error) {
	if env == nil {
		return nil, errors.New("projection: nil envelope")
	}
	tenantID := env.GetTenantId().GetValue()

	switch p := env.GetPayload().(type) {
	case *posv1.EventEnvelope_SaleCreated:
		return mapSaleCreated(p.SaleCreated), nil
	case *posv1.EventEnvelope_PaymentAdded:
		return mapPaymentAdded(p.PaymentAdded), nil
	case *posv1.EventEnvelope_PaymentRefunded:
		return mapPaymentRefunded(ctx, tenantID, p.PaymentRefunded, l)
	case *posv1.EventEnvelope_SaleRefunded:
		return mapSaleRefunded(p.SaleRefunded), nil
	case *posv1.EventEnvelope_SaleVoided:
		return mapSaleVoided(ctx, tenantID, p.SaleVoided, l)
	default:
		// Non-GL events (InventoryAdjusted, StockTransferred, SyncCompleted,
		// SyncFailed, UserLoggedIn). Phase 5 chooses not to post these.
		return nil, nil
	}
}

// --- per-event mappers ---

func mapSaleCreated(s *posv1.SaleCreated) []Entry {
	if s == nil || s.GetGrandTotal() == nil {
		return nil
	}
	saleID := s.GetSaleId()

	lines := []Line{
		// Dr A/R : grand_total — customer owes us until tender lands.
		moneyLine(AccountAccountsReceivable, SideDebit, s.GetGrandTotal()),
		// Cr Revenue : subtotal
		moneyLine(AccountRevenue, SideCredit, s.GetSubtotal()),
	}
	// Cr Tax Payable per category, splitting by line_tax. Older binaries
	// emit no line_tax / tax_category_id — fall back to a single Cr line
	// against tax_total → unclassified bucket, preserving the balance
	// invariant without losing the tax money.
	lines = append(lines, splitTaxByCategory(s.GetLines(), s.GetTaxTotal())...)

	return []Entry{{
		Seq:             0,
		SourceEventType: "sale_created",
		StoreID:         s.GetStoreId().GetValue(),
		SaleID:          saleID,
		Memo:            "sale " + saleID,
		Lines:           lines,
	}}
}

func mapPaymentAdded(p *posv1.PaymentAdded) []Entry {
	if p == nil || p.GetAmount() == nil {
		return nil
	}
	clearing, _ := ClearingAccountForMethod(p.GetMethod())
	return []Entry{{
		Seq:             0,
		SourceEventType: "payment_added",
		SaleID:          p.GetSaleId(),
		PaymentID:       p.GetPaymentId(),
		Memo:            "payment " + p.GetPaymentId() + " (" + p.GetMethod() + ")",
		Lines: []Line{
			// Dr Clearing(method) : amount
			moneyLine(clearing, SideDebit, p.GetAmount()),
			// Cr A/R : amount — settles what the sale Dr'd.
			moneyLine(AccountAccountsReceivable, SideCredit, p.GetAmount()),
		},
	}}
}

func mapPaymentRefunded(ctx context.Context, tenantID string, r *posv1.PaymentRefunded, l Lookups) ([]Entry, error) {
	if r == nil || r.GetAmount() == nil {
		return nil, nil
	}
	clearing, err := l.ClearingAccountForPayment(ctx, tenantID, r.GetOriginalPaymentId())
	if err != nil {
		return nil, fmt.Errorf("payment_refunded %s: %w", r.GetRefundId(), err)
	}
	return []Entry{{
		Seq:             0,
		SourceEventType: "payment_refunded",
		PaymentID:       r.GetRefundId(),
		Memo:            "payment refund " + r.GetRefundId() + " of " + r.GetOriginalPaymentId(),
		Lines: []Line{
			// Dr A/R : amount — customer no longer "paid us" this much.
			moneyLine(AccountAccountsReceivable, SideDebit, r.GetAmount()),
			// Cr Clearing(original method) : amount — money out of the same
			// bucket it came in through.
			moneyLine(clearing, SideCredit, r.GetAmount()),
		},
	}}, nil
}

func mapSaleRefunded(r *posv1.SaleRefunded) []Entry {
	if r == nil {
		return nil
	}
	storeID := r.GetStoreId().GetValue()
	saleID := r.GetSaleId()

	entries := make([]Entry, 0, 1+len(r.GetTenders()))

	// Entry 0: the goods-side reversal of revenue + tax. Mirrors the
	// SaleCreated JE but with sides flipped on the credit/debit (only the
	// magnitudes refunded, not the whole sale).
	if r.GetGrandTotal() != nil {
		lines := []Line{
			// Dr Revenue : subtotal — revenue we no longer keep.
			moneyLine(AccountRevenue, SideDebit, r.GetSubtotal()),
		}
		// Dr Tax Payable[cat] : per-line refund tax
		taxLines := splitTaxByCategoryFromRefund(r.GetLines(), r.GetTaxTotal(), SideDebit)
		lines = append(lines, taxLines...)
		// Cr A/R : grand_total — money owed back to customer (paired by
		// the per-tender JEs below).
		lines = append(lines, moneyLine(AccountAccountsReceivable, SideCredit, r.GetGrandTotal()))

		entries = append(entries, Entry{
			Seq:             0,
			SourceEventType: "sale_refunded",
			StoreID:         storeID,
			SaleID:          saleID,
			Memo:            "refund " + r.GetRefundId(),
			Lines:           lines,
		})
	}

	// Entries 1..N: one per tender returned. Mirror of PaymentAdded with
	// flipped sides.
	for i, t := range r.GetTenders() {
		if t == nil || t.GetAmount() == nil {
			continue
		}
		clearing, _ := ClearingAccountForMethod(t.GetMethod())
		entries = append(entries, Entry{
			Seq:             i + 1,
			SourceEventType: "sale_refunded",
			StoreID:         storeID,
			SaleID:          saleID,
			PaymentID:       t.GetRefundPaymentId(),
			Memo:            "refund tender " + t.GetRefundPaymentId() + " (" + t.GetMethod() + ")",
			Lines: []Line{
				// Dr A/R : amount
				moneyLine(AccountAccountsReceivable, SideDebit, t.GetAmount()),
				// Cr Clearing(method) : amount
				moneyLine(clearing, SideCredit, t.GetAmount()),
			},
		})
	}
	return entries
}

func mapSaleVoided(ctx context.Context, tenantID string, v *posv1.SaleVoided, l Lookups) ([]Entry, error) {
	if v == nil {
		return nil, nil
	}
	// Reverse only the original sale + payments — not prior refunds (per
	// accounting-rules "Reverses every JE previously posted under sale_id
	// (sale + payments)"). Void posts in the current period using its own
	// operation_id, so original JEs stay untouched (invariant #4).
	prior, err := l.LinesForSale(ctx, tenantID, v.GetSaleId(),
		[]string{"sale_created", "payment_added"})
	if err != nil {
		return nil, fmt.Errorf("sale_voided %s: %w", v.GetVoidId(), err)
	}
	if len(prior) == 0 {
		// Nothing to reverse — emit no JE. Could happen if the worker
		// processes a void before its sale (out-of-order delivery). The
		// reorder-chaos slice (5.6) is where we harden this; for 5.2 we
		// at least don't crash.
		return nil, nil
	}
	flipped := make([]Line, 0, len(prior))
	for _, ln := range prior {
		flipped = append(flipped, Line{
			Account:      ln.Account,
			Side:         flipSide(ln.Side),
			CurrencyCode: ln.CurrencyCode,
			Units:        ln.Units,
			Nanos:        ln.Nanos,
		})
	}
	return []Entry{{
		Seq:             0,
		SourceEventType: "sale_voided",
		StoreID:         v.GetStoreId().GetValue(),
		SaleID:          v.GetSaleId(),
		Memo:            "void " + v.GetVoidId() + " of sale " + v.GetSaleId(),
		Lines:           flipped,
	}}, nil
}

// --- helpers ---

func moneyLine(account string, side Side, m *posv1.Money) Line {
	if m == nil {
		return Line{Account: account, Side: side}
	}
	return Line{
		Account:      account,
		Side:         side,
		CurrencyCode: m.GetCurrencyCode(),
		Units:        m.GetUnits(),
		Nanos:        m.GetNanos(),
	}
}

func flipSide(s Side) Side {
	if s == SideDebit {
		return SideCredit
	}
	return SideDebit
}

// splitTaxByCategory builds Cr Tax Payable[cat] lines from per-line
// line_tax fields. If line_tax is missing on every line we fall back to
// a single Cr against tax_total → unclassified bucket so the JE balances
// regardless of emitter version.
func splitTaxByCategory(lines []*posv1.SaleLine, taxTotal *posv1.Money) []Line {
	if hasAnyLineTax(lines) {
		return aggregateLineTax(lines, SideCredit)
	}
	if taxTotal == nil || (taxTotal.GetUnits() == 0 && taxTotal.GetNanos() == 0) {
		return nil
	}
	return []Line{moneyLine(AccountTaxUnclassified, SideCredit, taxTotal)}
}

// splitTaxByCategoryFromRefund is the refund-side mirror: it Drs Tax
// Payable per category, falling back to the unclassified bucket on
// older binaries.
func splitTaxByCategoryFromRefund(lines []*posv1.RefundLine, taxTotal *posv1.Money, side Side) []Line {
	if hasAnyRefundLineTax(lines) {
		return aggregateRefundLineTax(lines, side)
	}
	if taxTotal == nil || (taxTotal.GetUnits() == 0 && taxTotal.GetNanos() == 0) {
		return nil
	}
	return []Line{moneyLine(AccountTaxUnclassified, side, taxTotal)}
}

func hasAnyLineTax(lines []*posv1.SaleLine) bool {
	for _, l := range lines {
		if l.GetLineTax() != nil {
			return true
		}
	}
	return false
}

func hasAnyRefundLineTax(lines []*posv1.RefundLine) bool {
	for _, l := range lines {
		if l.GetLineTax() != nil {
			return true
		}
	}
	return false
}

// aggregateLineTax sums line_tax by tax_category_id and emits one Line
// per category. We aggregate (rather than one Line per SaleLine) so JEs
// stay readable and indices on (account_code, je_id) stay tight.
func aggregateLineTax(lines []*posv1.SaleLine, side Side) []Line {
	// Stable order: first-seen category wins. Preserves determinism for
	// snapshot-style tests.
	type bucket struct {
		units int64
		nanos int64
		cur   string
	}
	order := []string{}
	buckets := map[string]*bucket{}
	for _, l := range lines {
		tax := l.GetLineTax()
		if tax == nil {
			continue
		}
		cat := l.GetTaxCategoryId()
		b, ok := buckets[cat]
		if !ok {
			b = &bucket{cur: tax.GetCurrencyCode()}
			buckets[cat] = b
			order = append(order, cat)
		}
		b.units += tax.GetUnits()
		b.nanos += int64(tax.GetNanos())
	}
	out := make([]Line, 0, len(order))
	for _, cat := range order {
		b := buckets[cat]
		units, nanos := normalizeMoney(b.units, b.nanos)
		if units == 0 && nanos == 0 {
			continue
		}
		out = append(out, Line{
			Account:      TaxPayableAccount(cat),
			Side:         side,
			CurrencyCode: b.cur,
			Units:        units,
			Nanos:        int32(nanos),
		})
	}
	return out
}

func aggregateRefundLineTax(lines []*posv1.RefundLine, side Side) []Line {
	type bucket struct {
		units int64
		nanos int64
		cur   string
	}
	order := []string{}
	buckets := map[string]*bucket{}
	for _, l := range lines {
		tax := l.GetLineTax()
		if tax == nil {
			continue
		}
		cat := l.GetTaxCategoryId()
		b, ok := buckets[cat]
		if !ok {
			b = &bucket{cur: tax.GetCurrencyCode()}
			buckets[cat] = b
			order = append(order, cat)
		}
		b.units += tax.GetUnits()
		b.nanos += int64(tax.GetNanos())
	}
	out := make([]Line, 0, len(order))
	for _, cat := range order {
		b := buckets[cat]
		units, nanos := normalizeMoney(b.units, b.nanos)
		if units == 0 && nanos == 0 {
			continue
		}
		out = append(out, Line{
			Account:      TaxPayableAccount(cat),
			Side:         side,
			CurrencyCode: b.cur,
			Units:        units,
			Nanos:        int32(nanos),
		})
	}
	return out
}

// normalizeMoney carries nanos overflow into units. Aggregation can
// push nanos past 1e9 (one whole unit) and we need the magnitude to
// satisfy the journal_lines CHECK (nanos >= 0 AND nanos < 1e9 by
// convention).
const nanosPerUnit int64 = 1_000_000_000

func normalizeMoney(units, nanos int64) (int64, int64) {
	if nanos >= nanosPerUnit {
		units += nanos / nanosPerUnit
		nanos = nanos % nanosPerUnit
	}
	return units, nanos
}

// IsBalanced reports whether Σ debit magnitudes == Σ credit magnitudes
// per currency. Enforces invariant #1 (every JE balances). Called by
// the store before insert.
func IsBalanced(e Entry) bool {
	type tot struct{ units, nanos int64 }
	dr := map[string]*tot{}
	cr := map[string]*tot{}
	for _, l := range e.Lines {
		bucket := dr
		if l.Side == SideCredit {
			bucket = cr
		}
		t, ok := bucket[l.CurrencyCode]
		if !ok {
			t = &tot{}
			bucket[l.CurrencyCode] = t
		}
		t.units += l.Units
		t.nanos += int64(l.Nanos)
	}
	// Currency keys must match exactly.
	if len(dr) != len(cr) {
		return false
	}
	for cur, d := range dr {
		c, ok := cr[cur]
		if !ok {
			return false
		}
		du, dn := normalizeMoney(d.units, d.nanos)
		cu, cn := normalizeMoney(c.units, c.nanos)
		if du != cu || dn != cn {
			return false
		}
	}
	return true
}
