// Package reports computes derived sales / tax aggregates straight off
// the GL projection tables (journal_entries × journal_lines). Slice 5.3
// — Phase 5 — read-side companion to slice 5.2's projection worker.
//
// Design:
//   - No pre-aggregation. Reports SUM over journal_lines per request.
//     Rebuildable from the projection at any time (accounting-rules
//     "compute on read" decision).
//   - SQLite-portable SQL. The one date-bucketing expression (strftime
//     over an integer unix-ns column) is the only thing that changes
//     when we eventually move to Postgres — flagged inline.
//   - Tenant scoping is mandatory on every query. Caller passes the
//     JWT-pinned tenant; this package never reads the JWT itself.
//
// What this package does NOT do:
//   - JSON / HTTP framing (lives in internal/api/reports.go)
//   - Auth (handler gates on JWT + RequireRole("owner"))
//   - Top-items / low-stock / cross-store rollups (slice 5.5)
//   - Period locking (out of Phase 5 entirely)
package reports

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"strings"
	"time"
)

// Period buckets supported by the reports endpoints. The string values
// are the wire form on the query-string `?period=day|week|month`.
type Period string

const (
	PeriodDay   Period = "day"
	PeriodWeek  Period = "week"
	PeriodMonth Period = "month"
)

// ParsePeriod validates a wire string and returns the typed value.
// Empty string defaults to PeriodDay — the most common dashboard
// granularity.
func ParsePeriod(s string) (Period, error) {
	switch Period(s) {
	case "":
		return PeriodDay, nil
	case PeriodDay, PeriodWeek, PeriodMonth:
		return Period(s), nil
	}
	return "", fmt.Errorf("reports: invalid period %q (want day|week|month)", s)
}

// Range is the [from, to) date window for any report. Dates are UTC
// midnights — Phase 5 is single-timezone (see accounting-rules scope).
type Range struct {
	From time.Time // inclusive
	To   time.Time // exclusive
}

// ParseDateRange validates and parses ISO-date strings ("YYYY-MM-DD").
// To is taken as exclusive end (so from=2026-05-01, to=2026-06-01 is
// "all of May"). Empty `to` defaults to from+1day; both empty rejects
// — reports must be bounded so a misbehaving client can't scan the
// whole table.
func ParseDateRange(from, to string) (Range, error) {
	if from == "" {
		return Range{}, errors.New("reports: `from` is required (YYYY-MM-DD)")
	}
	f, err := time.Parse("2006-01-02", from)
	if err != nil {
		return Range{}, fmt.Errorf("reports: bad from: %w", err)
	}
	var t time.Time
	if to == "" {
		t = f.AddDate(0, 0, 1)
	} else {
		t, err = time.Parse("2006-01-02", to)
		if err != nil {
			return Range{}, fmt.Errorf("reports: bad to: %w", err)
		}
	}
	if !t.After(f) {
		return Range{}, errors.New("reports: `to` must be strictly after `from`")
	}
	return Range{From: f.UTC(), To: t.UTC()}, nil
}

// Store wraps the cloud DB for read-only aggregate queries. Safe for
// concurrent use (sql.DB handles its own pool).
type Store struct {
	db *sql.DB
}

func NewStore(db *sql.DB) *Store {
	if db == nil {
		panic("reports: NewStore requires non-nil *sql.DB")
	}
	return &Store{db: db}
}

// MoneyAmount is the JSON-friendly Money shape used in report responses.
// We don't reuse posv1.Money because the JSON tags don't match what the
// dashboard wants — and the report tables already aggregate, so the
// proto's per-message semantics aren't carrying anything we need.
type MoneyAmount struct {
	CurrencyCode string `json:"currency_code"`
	Units        int64  `json:"units"`
	Nanos        int32  `json:"nanos"`
}

// nanosPerUnit kept private — mirrors projection.nanosPerUnit; not
// importing across packages because this would create a cycle once
// reports grows.
const nanosPerUnit int64 = 1_000_000_000

func toMoney(currency string, nanos int64) MoneyAmount {
	// Magnitude is always non-negative in the wire shape; callers handle
	// sign explicitly (refunds reduce revenue rather than going negative).
	// But aggregations CAN go negative for over-refunded periods — we
	// honour that as a real value, not clamp.
	units := nanos / nanosPerUnit
	rem := nanos - units*nanosPerUnit
	return MoneyAmount{
		CurrencyCode: currency,
		Units:        units,
		Nanos:        int32(rem),
	}
}

// --- Sales summary ---

// SalesSummaryBucket is one row of GET /v1/reports/sales-summary.
// PeriodStart is the ISO date of the bucket (day = that day, week =
// Monday of the ISO week, month = first of month).
//
// GrandTotal = Revenue + Tax (so it correctly nets sales vs refunds /
// voids in the period without being skewed by payments landing on the
// same day). The dashboard should treat this as "amount the customer
// was charged net of any in-period refund", not "still outstanding".
type SalesSummaryBucket struct {
	PeriodStart string      `json:"period_start"`
	Revenue     MoneyAmount `json:"revenue"`     // net of refunds/voids
	Tax         MoneyAmount `json:"tax"`         // net of refunds/voids
	GrandTotal  MoneyAmount `json:"grand_total"` // Revenue + Tax
}

// SalesSummary computes per-period net revenue, tax and grand total
// for the tenant + range, optionally scoped to one store.
//
// Net = SUM(credit) − SUM(debit) for income / liability accounts. This
// correctly handles refunds (Dr Revenue, Dr Tax) and voids (reversal
// lines flipped) without special-casing event types.
func (s *Store) SalesSummary(ctx context.Context, tenantID string, r Range, storeID string, period Period) ([]SalesSummaryBucket, error) {
	bucketExpr := dateBucketExpr(period)

	// We aggregate Revenue + Tax in one pass and pivot in Go — cheaper
	// than two round-trips. Both are income/liability accounts so the
	// "net" is credit-minus-debit (refunds Dr these accounts down).
	// GrandTotal is derived as Revenue+Tax in Go, not from A/R — A/R
	// nets to zero whenever payment lands in the same period as the
	// sale and would understate billings.
	query := fmt.Sprintf(`
		SELECT
		    %s AS bucket,
		    jl.account_code,
		    jl.currency_code,
		    SUM(CASE WHEN jl.side = 'credit' THEN jl.units * %d + jl.nanos ELSE 0 END) AS cr_nanos,
		    SUM(CASE WHEN jl.side = 'debit'  THEN jl.units * %d + jl.nanos ELSE 0 END) AS dr_nanos
		  FROM journal_lines jl
		  JOIN journal_entries je ON je.je_id = jl.je_id
		 WHERE je.tenant_id = ?
		   AND je.posted_at_unix_ns >= ?
		   AND je.posted_at_unix_ns <  ?
		   AND (? = '' OR je.store_id = ?)
		   AND (
		       jl.account_code = '4000'                       -- Revenue (income)
		    OR jl.account_code LIKE '2100.%%'                 -- Tax Payable (liability)
		   )
		 GROUP BY bucket, jl.account_code, jl.currency_code
		 ORDER BY bucket ASC
	`, bucketExpr, nanosPerUnit, nanosPerUnit)

	rows, err := s.db.QueryContext(ctx, query,
		tenantID, r.From.UnixNano(), r.To.UnixNano(), storeID, storeID)
	if err != nil {
		return nil, fmt.Errorf("reports: sales-summary query: %w", err)
	}
	defer rows.Close()

	// Pivot in Go. Stable bucket order driven by first-seen (the SQL
	// ORDER BY guarantees this lines up with chronological order).
	type agg struct {
		revenue  int64
		tax      int64
		currency string
	}
	order := []string{}
	buckets := map[string]*agg{}

	for rows.Next() {
		var (
			bucket   string
			account  string
			currency string
			cr, dr   int64
		)
		if err := rows.Scan(&bucket, &account, &currency, &cr, &dr); err != nil {
			return nil, fmt.Errorf("reports: sales-summary scan: %w", err)
		}
		b, ok := buckets[bucket]
		if !ok {
			b = &agg{currency: currency}
			buckets[bucket] = b
			order = append(order, bucket)
		}
		switch {
		case account == "4000":
			b.revenue += cr - dr // income: Cr is positive
		case strings.HasPrefix(account, "2100."):
			b.tax += cr - dr // liability: Cr is positive
		}
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("reports: sales-summary iterate: %w", err)
	}

	out := make([]SalesSummaryBucket, 0, len(order))
	for _, bk := range order {
		b := buckets[bk]
		out = append(out, SalesSummaryBucket{
			PeriodStart: bk,
			Revenue:     toMoney(b.currency, b.revenue),
			Tax:         toMoney(b.currency, b.tax),
			GrandTotal:  toMoney(b.currency, b.revenue+b.tax),
		})
	}
	return out, nil
}

// --- Sales by method ---

// SalesByMethodBucket is one row of GET /v1/reports/sales-by-method.
// Method is the wire string ("cash"/"card"/"upi"/"other"); Amount is
// the net flow through the clearing account in the period.
type SalesByMethodBucket struct {
	PeriodStart string      `json:"period_start"`
	Method      string      `json:"method"`
	Amount      MoneyAmount `json:"amount"` // Dr − Cr, so net inflow per period
}

// SalesByMethod aggregates per-day net inflow through each clearing
// account. Always grouped by day — the report is small enough that
// the dashboard can roll its own week/month rollup; keeps the SQL
// uncomplicated.
func (s *Store) SalesByMethod(ctx context.Context, tenantID string, r Range, storeID string) ([]SalesByMethodBucket, error) {
	bucketExpr := dateBucketExpr(PeriodDay)
	const clearingFilter = `jl.account_code IN ('1000','1100','1110')`

	query := fmt.Sprintf(`
		SELECT
		    %s AS bucket,
		    jl.account_code,
		    jl.currency_code,
		    SUM(CASE WHEN jl.side = 'debit'  THEN jl.units * %d + jl.nanos ELSE 0 END) -
		    SUM(CASE WHEN jl.side = 'credit' THEN jl.units * %d + jl.nanos ELSE 0 END) AS net_nanos
		  FROM journal_lines jl
		  JOIN journal_entries je ON je.je_id = jl.je_id
		 WHERE je.tenant_id = ?
		   AND je.posted_at_unix_ns >= ?
		   AND je.posted_at_unix_ns <  ?
		   AND (? = '' OR je.store_id = ?)
		   AND %s
		 GROUP BY bucket, jl.account_code, jl.currency_code
		 ORDER BY bucket ASC, jl.account_code ASC
	`, bucketExpr, nanosPerUnit, nanosPerUnit, clearingFilter)

	rows, err := s.db.QueryContext(ctx, query,
		tenantID, r.From.UnixNano(), r.To.UnixNano(), storeID, storeID)
	if err != nil {
		return nil, fmt.Errorf("reports: sales-by-method query: %w", err)
	}
	defer rows.Close()

	out := []SalesByMethodBucket{}
	for rows.Next() {
		var (
			bucket   string
			account  string
			currency string
			net      int64
		)
		if err := rows.Scan(&bucket, &account, &currency, &net); err != nil {
			return nil, fmt.Errorf("reports: sales-by-method scan: %w", err)
		}
		// Skip zero-amount rows so we honour the skip-empty contract — a
		// clearing account that saw equal inflow + refund within one day
		// contributes nothing.
		if net == 0 {
			continue
		}
		out = append(out, SalesByMethodBucket{
			PeriodStart: bucket,
			Method:      methodFromAccount(account),
			Amount:      toMoney(currency, net),
		})
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("reports: sales-by-method iterate: %w", err)
	}
	return out, nil
}

func methodFromAccount(code string) string {
	switch code {
	case "1000":
		return "cash"
	case "1100":
		return "card"
	case "1110":
		return "upi"
	default:
		return "other"
	}
}

// --- Tax summary ---

// TaxSummaryBucket is one row of GET /v1/reports/tax-summary.
// TaxCategory is the suffix of the 2100.* account, with the sentinel
// "unclassified" preserved as-is.
type TaxSummaryBucket struct {
	PeriodStart string      `json:"period_start"`
	TaxCategory string      `json:"tax_category"`
	Amount      MoneyAmount `json:"amount"` // Cr − Dr, so net tax owed in the period
}

// TaxSummary aggregates Tax Payable sub-account balances per period
// and category. Cr − Dr because Tax Payable is a liability (we owe
// the tax authority); refunds Dr it down again.
func (s *Store) TaxSummary(ctx context.Context, tenantID string, r Range, storeID string, period Period) ([]TaxSummaryBucket, error) {
	bucketExpr := dateBucketExpr(period)

	query := fmt.Sprintf(`
		SELECT
		    %s AS bucket,
		    jl.account_code,
		    jl.currency_code,
		    SUM(CASE WHEN jl.side = 'credit' THEN jl.units * %d + jl.nanos ELSE 0 END) -
		    SUM(CASE WHEN jl.side = 'debit'  THEN jl.units * %d + jl.nanos ELSE 0 END) AS net_nanos
		  FROM journal_lines jl
		  JOIN journal_entries je ON je.je_id = jl.je_id
		 WHERE je.tenant_id = ?
		   AND je.posted_at_unix_ns >= ?
		   AND je.posted_at_unix_ns <  ?
		   AND (? = '' OR je.store_id = ?)
		   AND jl.account_code LIKE '2100.%%'
		 GROUP BY bucket, jl.account_code, jl.currency_code
		 ORDER BY bucket ASC, jl.account_code ASC
	`, bucketExpr, nanosPerUnit, nanosPerUnit)

	rows, err := s.db.QueryContext(ctx, query,
		tenantID, r.From.UnixNano(), r.To.UnixNano(), storeID, storeID)
	if err != nil {
		return nil, fmt.Errorf("reports: tax-summary query: %w", err)
	}
	defer rows.Close()

	out := []TaxSummaryBucket{}
	for rows.Next() {
		var (
			bucket   string
			account  string
			currency string
			net      int64
		)
		if err := rows.Scan(&bucket, &account, &currency, &net); err != nil {
			return nil, fmt.Errorf("reports: tax-summary scan: %w", err)
		}
		if net == 0 {
			continue
		}
		out = append(out, TaxSummaryBucket{
			PeriodStart: bucket,
			TaxCategory: strings.TrimPrefix(account, "2100."),
			Amount:      toMoney(currency, net),
		})
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("reports: tax-summary iterate: %w", err)
	}
	return out, nil
}

// --- store list ---

// StoreSummary is one row of GET /v1/reports/stores: a store the tenant
// has any GL activity for, plus the first/last activity dates so the
// dashboard can offer sensible default ranges per store.
type StoreSummary struct {
	StoreID       string `json:"store_id"`
	FirstActivity string `json:"first_activity"` // YYYY-MM-DD (UTC)
	LastActivity  string `json:"last_activity"`  // YYYY-MM-DD (UTC)
}

// ListStores returns every store_id the tenant has journal activity
// for. Empty store_ids are filtered out — they correspond to pre-store
// or HQ-level entries that shouldn't appear in a store picker.
//
// LIMIT 1000 is a defensive cap; in practice a tenant has O(10) stores.
func (s *Store) ListStores(ctx context.Context, tenantID string) ([]StoreSummary, error) {
	const q = `
		SELECT
		    store_id,
		    MIN(posted_at_unix_ns) AS first_ns,
		    MAX(posted_at_unix_ns) AS last_ns
		  FROM journal_entries
		 WHERE tenant_id = ?
		   AND store_id <> ''
		 GROUP BY store_id
		 ORDER BY store_id ASC
		 LIMIT 1000
	`
	rows, err := s.db.QueryContext(ctx, q, tenantID)
	if err != nil {
		return nil, fmt.Errorf("reports: list-stores query: %w", err)
	}
	defer rows.Close()

	out := []StoreSummary{}
	for rows.Next() {
		var (
			storeID          string
			firstNs, lastNs  int64
		)
		if err := rows.Scan(&storeID, &firstNs, &lastNs); err != nil {
			return nil, fmt.Errorf("reports: list-stores scan: %w", err)
		}
		out = append(out, StoreSummary{
			StoreID:       storeID,
			FirstActivity: time.Unix(0, firstNs).UTC().Format("2006-01-02"),
			LastActivity:  time.Unix(0, lastNs).UTC().Format("2006-01-02"),
		})
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("reports: list-stores iterate: %w", err)
	}
	return out, nil
}

// --- date bucket expression ---

// dateBucketExpr builds the SQL expression that turns posted_at_unix_ns
// into a bucket label string for the requested period. The output is
// always an ISO date — week buckets emit the Monday of the ISO week,
// month buckets emit the 1st.
//
// SQLite-specific (strftime / 'unixepoch' modifier). Postgres swap is
// the same shape: `to_char(date_trunc(...), 'YYYY-MM-DD')`.
func dateBucketExpr(p Period) string {
	const tsFromNanos = `(je.posted_at_unix_ns / 1000000000)`
	switch p {
	case PeriodWeek:
		// 'weekday 1' is the Monday on/before the date. So `date(ts, 'unixepoch',
		// 'weekday 1', '-7 days')` if the date isn't already Monday — SQLite's
		// 'weekday N' rolls *forward*, so we subtract 7 days when ts is mid-week
		// to land on the Monday at-or-before. Single expression:
		return `strftime('%Y-%m-%d', ` + tsFromNanos + `, 'unixepoch', 'weekday 1', '-7 days')`
	case PeriodMonth:
		return `strftime('%Y-%m-01', ` + tsFromNanos + `, 'unixepoch')`
	default: // PeriodDay
		return `strftime('%Y-%m-%d', ` + tsFromNanos + `, 'unixepoch')`
	}
}

