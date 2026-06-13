package sales

import (
	"errors"
	"fmt"
)

// Sentinel errors.
var (
	ErrNoLines        = errors.New("sales: at least one line is required")
	ErrNoTenders      = errors.New("sales: at least one tender is required")
	ErrEmptyTenant    = errors.New("sales: TenantID is required (configure SaleService at construction)")
	ErrCurrencyMix    = errors.New("sales: mixed currencies are not allowed")
	ErrNilSaleID      = errors.New("sales: SaleID is required")
	ErrNonPositiveQty = errors.New("sales: line quantity must be positive")
)

// ErrLineTotalMismatch is returned when a SaleLine's LineTotal does not
// equal unit_price * quantity. We do not silently recompute — the caller
// is responsible for arithmetic so the wire payload it built earlier
// matches what we persist.
type ErrLineTotalMismatch struct {
	SKU      string
	Expected string // formatted via fmt for diagnostics
	Got      string
}

func (e *ErrLineTotalMismatch) Error() string {
	return fmt.Sprintf("sales: line total mismatch on sku=%s: expected %s, got %s",
		e.SKU, e.Expected, e.Got)
}

// ErrGrandTotalMismatch is returned when Σ tenders ≠ subtotal + tax.
type ErrGrandTotalMismatch struct {
	GrandTotal string
	TenderSum  string
}

func (e *ErrGrandTotalMismatch) Error() string {
	return fmt.Sprintf("sales: grand total mismatch: grand=%s, tenders=%s",
		e.GrandTotal, e.TenderSum)
}

// ErrTotalsMismatch is returned when the caller supplied a non-zero
// Subtotal / TaxTotal / GrandTotal that disagrees with what the tax engine
// computed. The engine is authoritative; callers that pass zero-valued
// Money let the engine fill them in and never hit this.
type ErrTotalsMismatch struct {
	Field    string // "Subtotal" | "TaxTotal" | "GrandTotal"
	Caller   string
	Computed string
}

func (e *ErrTotalsMismatch) Error() string {
	return fmt.Sprintf("sales: %s mismatch: caller=%s, engine=%s",
		e.Field, e.Caller, e.Computed)
}
