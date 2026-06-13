// Package payments is the data layer for the payments ledger.
//
// Payments are a separate ledger from invoices (see docs/accounting-rules.md),
// so split / partial / refund flows compose cleanly. All amounts are
// fixed-precision Money — NO FLOATS. Refunds are reversal events linked to
// the original payment via parent_payment_id; we never edit a past payment row.
package payments

import (
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
)

// Method names a payment instrument. Free-form for now (tenants extend this set
// per region/integration); the Go layer rejects empty. A future enum table can
// constrain this — until then the cloud catalog is the source of truth.
type Method string

const (
	MethodCash        Method = "cash"
	MethodCard        Method = "card"
	MethodUPI         Method = "upi"
	MethodWallet      Method = "wallet"
	MethodStoreCredit Method = "store_credit"
)

// Money is a fixed-precision signed amount. See docs/accounting-rules.md:
// "All monetary amounts use fixed-precision Money (currency_code, units, nanos).
// No floats. Ever."
//
//   - Units is the whole-currency portion (signed).
//   - Nanos is the sub-currency portion, range (-1e9, 1e9), and MUST have the
//     same sign as Units when both are non-zero.
//
// Example: $1.50 USD → {CurrencyCode:"USD", Units:1, Nanos:500_000_000}.
// Example: -$0.25 USD → {CurrencyCode:"USD", Units:0, Nanos:-250_000_000}.
type Money struct {
	CurrencyCode string // ISO 4217
	Units        int64
	Nanos        int32
}

const nanosPerUnit = 1_000_000_000

// IsZero reports whether the amount is exactly zero (regardless of currency).
func (m Money) IsZero() bool { return m.Units == 0 && m.Nanos == 0 }

// Sign returns -1, 0, +1.
func (m Money) Sign() int {
	switch {
	case m.Units > 0 || m.Nanos > 0:
		return 1
	case m.Units < 0 || m.Nanos < 0:
		return -1
	default:
		return 0
	}
}

// Validate enforces Money's representation invariants.
func (m Money) Validate() error {
	if m.CurrencyCode == "" {
		return errors.New("payments: Money.CurrencyCode is required")
	}
	if m.Nanos <= -nanosPerUnit || m.Nanos >= nanosPerUnit {
		return fmt.Errorf("payments: Money.Nanos %d out of range (-1e9, 1e9)", m.Nanos)
	}
	// Same-sign rule when both are non-zero. (One being zero is fine — e.g.
	// {Units:5, Nanos:0} or {Units:0, Nanos:-250_000_000}.)
	if m.Units > 0 && m.Nanos < 0 {
		return errors.New("payments: Money.Units positive but Nanos negative")
	}
	if m.Units < 0 && m.Nanos > 0 {
		return errors.New("payments: Money.Units negative but Nanos positive")
	}
	return nil
}

// Add returns m + other. Returns an error on currency mismatch.
// The result is normalized so Nanos stays in (-1e9, 1e9) with matching sign.
func (m Money) Add(other Money) (Money, error) {
	if m.CurrencyCode != other.CurrencyCode {
		return Money{}, fmt.Errorf("payments: currency mismatch %q vs %q", m.CurrencyCode, other.CurrencyCode)
	}
	units := m.Units + other.Units
	nanos := int64(m.Nanos) + int64(other.Nanos)

	// Carry: if |nanos| >= 1e9, move one unit.
	if nanos >= nanosPerUnit {
		units++
		nanos -= nanosPerUnit
	} else if nanos <= -nanosPerUnit {
		units--
		nanos += nanosPerUnit
	}
	// Sign reconciliation: if units and nanos disagree, borrow.
	if units > 0 && nanos < 0 {
		units--
		nanos += nanosPerUnit
	} else if units < 0 && nanos > 0 {
		units++
		nanos -= nanosPerUnit
	}
	return Money{CurrencyCode: m.CurrencyCode, Units: units, Nanos: int32(nanos)}, nil
}

// Neg returns -m.
func (m Money) Neg() Money {
	return Money{CurrencyCode: m.CurrencyCode, Units: -m.Units, Nanos: -m.Nanos}
}

// Equal reports exact equality (currency + amount). Two zero Moneys with
// different currency codes are NOT equal — currency is part of the value.
func (m Money) Equal(other Money) bool {
	return m.CurrencyCode == other.CurrencyCode &&
		m.Units == other.Units &&
		m.Nanos == other.Nanos
}

// Mul returns m * n (signed). Returns an error on int64 overflow.
//
// Use case: unit_price × quantity for a sale line.
// Implementation: scale both Units and Nanos by n, then carry into Units.
func (m Money) Mul(n int64) (Money, error) {
	// Fast path for zero — keeps the currency code.
	if n == 0 || m.IsZero() {
		return Money{CurrencyCode: m.CurrencyCode}, nil
	}

	// Detect Units overflow via division round-trip.
	scaledUnits := m.Units * n
	if m.Units != 0 && scaledUnits/n != m.Units {
		return Money{}, fmt.Errorf("payments: Mul overflow on units (%d * %d)", m.Units, n)
	}

	// Nanos * n fits in int64 because |nanos| < 1e9 and we accept any int64 n
	// only when the product stays in range — guard explicitly.
	nanosWide := int64(m.Nanos) * n
	if m.Nanos != 0 && nanosWide/n != int64(m.Nanos) {
		return Money{}, fmt.Errorf("payments: Mul overflow on nanos (%d * %d)", m.Nanos, n)
	}

	// Carry whole-units worth of nanos up.
	carry := nanosWide / nanosPerUnit
	nanosRem := nanosWide - carry*nanosPerUnit

	// Adding carry must not overflow Units either.
	totalUnits := scaledUnits + carry
	if (carry > 0 && totalUnits < scaledUnits) || (carry < 0 && totalUnits > scaledUnits) {
		return Money{}, fmt.Errorf("payments: Mul overflow after carry (%d + %d)", scaledUnits, carry)
	}

	// Sign reconciliation (same rule as Add): if units & nanos disagree, borrow.
	if totalUnits > 0 && nanosRem < 0 {
		totalUnits--
		nanosRem += nanosPerUnit
	} else if totalUnits < 0 && nanosRem > 0 {
		totalUnits++
		nanosRem -= nanosPerUnit
	}

	return Money{CurrencyCode: m.CurrencyCode, Units: totalUnits, Nanos: int32(nanosRem)}, nil
}

// Payment is one row of payments. Schema is in 000003_payments migration.
type Payment struct {
	PaymentID       uuid.UUID
	SaleID          uuid.UUID // links to SaleCreated.operation_id; invoice_id arrives in Phase 5
	Method          Method
	Amount          Money     // signed: positive = pay-in, negative = refund
	Reference       string    // gateway txn id, cheque #, etc. (optional)
	ParentPaymentID uuid.UUID // uuid.Nil unless this row is a refund of another payment
	CreatedAt       time.Time
}

func (p Payment) validate() error {
	if p.PaymentID == uuid.Nil {
		return errors.New("payments: PaymentID is required")
	}
	if p.SaleID == uuid.Nil {
		return errors.New("payments: SaleID is required")
	}
	if p.Method == "" {
		return errors.New("payments: Method is required")
	}
	if err := p.Amount.Validate(); err != nil {
		return err
	}
	if p.Amount.IsZero() {
		return errors.New("payments: Amount must be non-zero")
	}
	if p.CreatedAt.IsZero() {
		return errors.New("payments: CreatedAt is required")
	}
	// A refund (negative amount) is conventionally linked back to its origin.
	// We don't *require* parent_payment_id on refunds — some flows (e.g.
	// goodwill credits) refund without a single originating payment — but a
	// non-nil parent_payment_id is invalid on a positive payment.
	if p.ParentPaymentID != uuid.Nil && p.Amount.Sign() > 0 {
		return errors.New("payments: parent_payment_id only allowed on refunds (negative Amount)")
	}
	return nil
}

// ErrParentNotFound is returned when an Insert references a parent_payment_id
// that does not exist in the local payments table. (We don't allow inserting
// a refund whose origin isn't on this node — that's a data-integrity issue.)
var ErrParentNotFound = errors.New("payments: parent payment not found")
